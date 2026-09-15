"""Azure AI Content Safety — moderates uploaded documents and AI-generated text.

Sprint 2.4 wires this into the document ingestion worker. After Document
Intelligence pulls the text out of an upload (Sprint 2.3), the worker calls
:func:`analyze_extracted_text` to score the four harm categories (Hate,
SelfHarm, Sexual, Violence). Categories that cross the configured threshold
flip the document to ``status=flagged`` for admin review.

Why a service module and not inline in the worker
-------------------------------------------------
Sprint 3 also needs this surface to scan AI-generated questions before
delivery (knowledge.md §10, "Tier 2: detective"). Keep the call shape stable
so the question pipeline can reuse it without copy-paste.

Threshold profile — "educational lenient"
-----------------------------------------
The defaults in :class:`~app.core.config.Settings` are stricter on Hate /
SelfHarm / Sexual (severity ≥ 2 flags) and looser on Violence (severity ≥ 4)
so historical content about wars, conflicts, and biology of injury doesn't
get falsely flagged. See knowledge.md §10.

10K-character API limit
-----------------------
Azure Content Safety's analyze_text accepts up to 10,000 Unicode code points
per call. A typical PDF easily exceeds that, so :func:`analyze_extracted_text`
chunks the input into non-overlapping windows and aggregates the **max**
severity seen per category. Aggregation rule: if any chunk says "Hate=4",
the whole document is "Hate=4" — content safety is not a frequency game.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from azure.ai.contentsafety.aio import ContentSafetyClient
from azure.ai.contentsafety.models import (
    AnalyzeTextOptions,
    AnalyzeTextOutputType,
    TextCategory,
)
from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import HttpResponseError

from app.core.config import settings
from app.core.exceptions import ServiceUnavailableError

logger = logging.getLogger(__name__)


# ── Constants ────────────────────────────────────────────────────────────────

# Hard limit from the service. Splitting at exactly 10,000 risks off-by-one
# rejections in edge cases (CRLF vs LF, surrogate pairs), so we leave headroom.
_CHUNK_SIZE = 9_500

# Four-step scale: max severity is 6. Used to normalize to 0.0–1.0 for the
# audit log's azure_safety_score field.
_MAX_SEVERITY = 6

# All four categories — knowledge.md §10 says scan all of them, every upload.
_CATEGORIES: tuple[TextCategory, ...] = (
    TextCategory.HATE,
    TextCategory.SELF_HARM,
    TextCategory.SEXUAL,
    TextCategory.VIOLENCE,
)


# ── Public types ─────────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class SafetyVerdict:
    """Result of running content safety on a piece of text.

    Attributes:
        flagged: True if any category crossed its configured threshold.
        severities: Per-category max severity (0/2/4/6 on the four-step scale).
            Keys are the SDK's ``TextCategory`` string values ("Hate", "SelfHarm",
            "Sexual", "Violence"). Always contains all four categories — missing
            ones default to 0 so callers don't have to .get().
        flagged_categories: Subset of severities.keys() whose value crossed
            its threshold. Ordered to match :data:`_CATEGORIES` for stable logs.
        max_severity_normalized: max(severities.values()) / 6, suitable for
            ModerationLog.azure_safety_score (0.0–1.0).
    """

    severities: dict[str, int]
    flagged_categories: list[str] = field(default_factory=list)

    @property
    def flagged(self) -> bool:
        return bool(self.flagged_categories)

    @property
    def max_severity_normalized(self) -> float:
        if not self.severities:
            return 0.0
        return max(self.severities.values()) / _MAX_SEVERITY


# ── Threshold lookup ─────────────────────────────────────────────────────────


def _threshold_for(category: str) -> int:
    """Return the configured severity floor at which `category` flags.

    Centralised so tests can monkeypatch settings and the worker stays clean.
    """
    match category:
        case TextCategory.HATE:
            return settings.content_safety_hate_threshold
        case TextCategory.SELF_HARM:
            return settings.content_safety_self_harm_threshold
        case TextCategory.SEXUAL:
            return settings.content_safety_sexual_threshold
        case TextCategory.VIOLENCE:
            return settings.content_safety_violence_threshold
        case _:
            # Unknown category — fail safe and demand severity 2.
            return 2


# ── Client construction ──────────────────────────────────────────────────────


def _client() -> ContentSafetyClient:
    if not settings.content_safety_endpoint or not settings.content_safety_key:
        raise ServiceUnavailableError(
            "Content Safety is not configured (set CONTENT_SAFETY_ENDPOINT and CONTENT_SAFETY_KEY)."
        )
    return ContentSafetyClient(
        endpoint=settings.content_safety_endpoint,
        credential=AzureKeyCredential(settings.content_safety_key),
    )


# ── Internal: single chunk ───────────────────────────────────────────────────


async def _analyze_chunk(client: ContentSafetyClient, text: str) -> dict[str, int]:
    """Send one ≤10K-char window to Content Safety, return per-category severity.

    Returns a dict keyed by the SDK's category string (``"Hate"``, ``"SelfHarm"``,
    …) with int severities. Missing categories default to 0 so the caller can
    safely ``max()`` across chunks without KeyErrors.
    """
    options = AnalyzeTextOptions(
        text=text,
        categories=list(_CATEGORIES),
        output_type=AnalyzeTextOutputType.FOUR_SEVERITY_LEVELS,
    )
    result = await client.analyze_text(options)
    out: dict[str, int] = {c.value: 0 for c in _CATEGORIES}
    for analysis in result.categories_analysis or []:
        # analysis.category is a TextCategory enum; .severity is Optional[int].
        cat = analysis.category
        key = cat.value if hasattr(cat, "value") else str(cat)
        out[key] = analysis.severity or 0
    return out


# ── Internal: chunking ───────────────────────────────────────────────────────


def _chunk(text: str, size: int = _CHUNK_SIZE) -> list[str]:
    """Split text into non-overlapping windows of ``size`` Unicode code points.

    No semantic overlap on purpose — content safety scores the worst chunk,
    so duplicating boundary text only wastes API calls. A category that
    barely crosses threshold on a sentence split across two chunks still
    fires because we take the max.
    """
    if not text:
        return []
    return [text[i : i + size] for i in range(0, len(text), size)]


# ── Public API ───────────────────────────────────────────────────────────────


async def analyze_extracted_text(text: str) -> SafetyVerdict:
    """Score `text` against Azure Content Safety and apply thresholds.

    Empty / whitespace-only text short-circuits to a clean verdict with no
    API call — saves money and avoids a 400 from the service. The Document
    Intelligence step still produces a ``text_extracted`` document; it just
    has nothing to scan.

    Raises:
        ServiceUnavailableError: credentials missing.
        HttpResponseError: transient Content Safety failure (caller in the
            ingestion worker propagates this so Service Bus redelivers).
    """
    if not text or not text.strip():
        logger.info("Content safety: empty text, skipping API call")
        return SafetyVerdict(severities=dict.fromkeys((c.value for c in _CATEGORIES), 0))

    aggregate: dict[str, int] = dict.fromkeys((c.value for c in _CATEGORIES), 0)
    chunks = _chunk(text)
    logger.info(
        "Content safety: analyzing %d chars in %d chunk(s)",
        len(text),
        len(chunks),
    )

    async with _client() as client:
        for idx, chunk in enumerate(chunks):
            try:
                per_chunk = await _analyze_chunk(client, chunk)
            except HttpResponseError:
                logger.exception(
                    "Content safety analyze_text failed on chunk %d/%d",
                    idx + 1,
                    len(chunks),
                )
                raise
            for cat, sev in per_chunk.items():
                if sev > aggregate[cat]:
                    aggregate[cat] = sev

    flagged = [
        cat for cat in (c.value for c in _CATEGORIES) if aggregate[cat] >= _threshold_for(cat)
    ]

    verdict = SafetyVerdict(severities=aggregate, flagged_categories=flagged)
    logger.info(
        "Content safety verdict: flagged=%s severities=%s",
        verdict.flagged,
        verdict.severities,
    )
    return verdict
