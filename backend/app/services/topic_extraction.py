"""Topic extraction — runs GPT-4o over a document's extracted text.

Sprint 2.5. The topic-extraction worker calls :func:`extract_topics` once per
document after Sprint 2.3 has persisted the text blob and Sprint 2.4 has
cleared content safety. Output is a list of :class:`TopicTag` records ready
to write straight onto the document.

Why a standalone service (not inline in the worker)
---------------------------------------------------
Sprint 2.6's taxonomy merge will need to run topic extraction again on
admin demand ("regenerate taxonomy"), and Sprint 3's prompt-eval skill will
fuzz this function with sample documents. Keep the contract narrow so both
callers can use the same seam.

Length handling
---------------
GPT-4o has a 128K context window but billing scales with input tokens.
Documents over ``settings.openai_topic_extraction_max_input_chars`` are
truncated to the configured budget (~60K chars ≈ 15K tokens), keeping any
single call under $0.10 even at gpt-4o pricing. Truncated docs log a warning
so admins know they're not getting full coverage on textbooks.
"""

from __future__ import annotations

import logging
from typing import Any

from app.core.config import settings
from app.models.document import TopicTag
from app.prompts import load_prompt, render, split_system_user
from app.services import azure_openai

logger = logging.getLogger(__name__)

_PROMPT_NAME = "topic_extraction_v1"
# Cached because read_text + split is pure I/O — we never need to re-read
# the prompt mid-process. Cleared by tests that monkeypatch the prompt.
_PROMPT_CACHE: tuple[str, str] | None = None


def _system_user() -> tuple[str, str]:
    global _PROMPT_CACHE
    if _PROMPT_CACHE is None:
        template = load_prompt(_PROMPT_NAME)
        _PROMPT_CACHE = split_system_user(template)
    return _PROMPT_CACHE


def _truncate(text: str, *, max_chars: int) -> str:
    """Take the first ``max_chars`` characters of ``text``, log if truncated.

    Front-truncation (not back) on purpose: textbook tables of contents,
    glossaries, and chapter headings tend to live in the first 60K chars and
    are gold for topic identification. The back tends to be exercises and
    bibliographies, which are noise for this task.
    """
    if len(text) <= max_chars:
        return text
    logger.warning(
        "Truncating extracted text for topic extraction: %d chars → %d chars",
        len(text),
        max_chars,
    )
    return text[:max_chars]


def _coerce_topic(raw: dict[str, Any]) -> TopicTag | None:
    """Convert one model-emitted topic dict into a TopicTag.

    Returns None if the row is too malformed to use. We accept a fairly wide
    range here — clamping out-of-range complexity, dropping unknown fields,
    coercing string page numbers — because the cost of dropping a valid
    topic to a strict parser is high (we'd need to rerun the whole prompt).
    """
    name = (raw.get("name") or "").strip()
    if not name:
        return None

    complexity_raw = raw.get("complexity_level")
    complexity: int | None
    try:
        complexity = int(complexity_raw) if complexity_raw is not None else None
    except (TypeError, ValueError):
        complexity = None
    if complexity is not None:
        complexity = max(1, min(5, complexity))

    page_refs_raw = raw.get("page_refs") or []
    page_refs: list[int] = []
    if isinstance(page_refs_raw, list):
        for p in page_refs_raw:
            try:
                page = int(p)
            except (TypeError, ValueError):
                continue
            if page > 0:
                page_refs.append(page)

    description = raw.get("description")
    if description is not None:
        description = str(description).strip() or None

    return TopicTag(
        name=name,
        confidence=1.0,
        source="ai",
        description=description,
        complexity_level=complexity,
        page_refs=page_refs,
    )


def _dedupe(topics: list[TopicTag]) -> list[TopicTag]:
    """Drop duplicate topic names (case-insensitive), keeping the first.

    The prompt asks for unique names but models occasionally slip — better
    to silently de-dupe than to surface a confusing error downstream.
    """
    seen: set[str] = set()
    out: list[TopicTag] = []
    for t in topics:
        key = t.name.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(t)
    return out


async def extract_topics(text: str) -> list[TopicTag]:
    """Extract a list of topics from a document's extracted text.

    Empty or whitespace-only text returns an empty list without an OpenAI
    call — matches the prompt's "return []" contract and saves money on
    blank documents (cover pages, admin uploads with no body content).

    Raises:
        ServiceUnavailableError: model not reachable / not configured.
        ValueError: response wasn't valid JSON or didn't contain ``topics``.
    """
    if not text or not text.strip():
        logger.info("Topic extraction: empty text, returning []")
        return []

    system_prompt, user_template = _system_user()
    user_prompt = render(
        user_template,
        source_content=_truncate(text, max_chars=settings.openai_topic_extraction_max_input_chars),
    )

    response = await azure_openai.chat_json(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_output_tokens=settings.openai_topic_extraction_max_output_tokens,
    )

    raw_topics = response.get("topics")
    if not isinstance(raw_topics, list):
        # Model returned a different shape — log the keys so we can debug
        # without dumping potentially sensitive document content.
        logger.error(
            "Topic extraction response missing 'topics' list. Got keys=%s",
            list(response.keys()) if isinstance(response, dict) else "non-dict",
        )
        raise ValueError("Topic extraction response missing 'topics' list")

    parsed = [t for t in (_coerce_topic(r) for r in raw_topics if isinstance(r, dict)) if t]
    deduped = _dedupe(parsed)
    logger.info(
        "Topic extraction: %d raw → %d parsed → %d deduped",
        len(raw_topics),
        len(parsed),
        len(deduped),
    )
    return deduped
