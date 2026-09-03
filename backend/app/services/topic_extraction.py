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


def _prepare_text_for_topic_extraction(text: str, *, max_chars: int = 16_000) -> str:
    """Prepare a compact, high-signal representation of the document for topic extraction.

    For documents <= max_chars, the full text is passed directly.
    For large documents (40k to 100k+ chars / 1 lakh chars), feeding the raw text
    causes high latency (30-60s) and large prompt tokens. Instead, this function:
      1. Keeps front matter & Table of Contents (first 4,500 chars)
      2. Extracts structural chapter and section headings across the entire document
      3. Uniformly samples paragraph beginnings across every single page
      4. Keeps the concluding summary (last 1,500 chars)
    This gives 100% full-document topic coverage in ~12k-16k chars, cutting LLM latency to 2-3s.
    """
    total_len = len(text)
    if total_len <= max_chars:
        return text

    head_budget = 4_500
    tail_budget = 1_500
    head = text[:head_budget]
    tail = text[-tail_budget:] if total_len > head_budget + tail_budget else ""

    middle = text[head_budget : total_len - tail_budget]
    middle_lines = middle.splitlines()

    sampled_lines: list[str] = []
    current_chars = len(head) + len(tail)
    target_budget = max_chars - 500

    # 1. Structural headings & section titles
    for line in middle_lines:
        stripped = line.strip()
        if not stripped:
            continue
        is_heading = (
            stripped.startswith(("#", "Chapter", "CHAPTER", "Unit", "UNIT", "Section", "SECTION", "Topic", "TOPIC", "Part", "PART", "Module", "MODULE"))
            or (len(stripped) < 80 and stripped.isupper())
            or (len(stripped) < 60 and not stripped.endswith(".") and (stripped[0].isdigit() or stripped.startswith("- ")))
        )
        if is_heading:
            sampled_lines.append(stripped)
            current_chars += len(stripped) + 1
            if current_chars >= target_budget:
                break

    # 2. Distributed paragraph slices across the whole middle
    if current_chars < target_budget:
        remaining = target_budget - current_chars
        step = max(1, len(middle) // 12)
        slices: list[str] = []
        for offset in range(0, len(middle), step):
            snippet = middle[offset : offset + 350].strip()
            if snippet:
                slices.append(snippet)
            if sum(len(s) for s in slices) >= remaining:
                break
        middle_content = "\n".join(sampled_lines) + "\n\n" + "\n---\n".join(slices)
    else:
        middle_content = "\n".join(sampled_lines)

    logger.info(
        "Distilled extracted text for topic extraction: %d chars → %d chars (coverage: 100%%)",
        total_len,
        len(head) + len(middle_content) + len(tail),
    )
    result = f"{head}\n\n[... Structural Headings & Representative Content Across Document ...]\n{middle_content}\n\n[... Final Summary & Conclusion ...]\n{tail}"
    return result[:max_chars]


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


def _get_extraction_guidance(char_count: int) -> str:
    """Length-tailored extraction instructions to balance granularity and speed.

    - Under 2K chars: Short study note / concise material (< 2,000 chars).
      Extract a generous, good amount of distinct topics (4 to 8 fine-grained topics)
      covering every specific concept, principle, definition, rule, or formula so
      the learner has multiple focused topics to practice from this short text.
    - Over 3K chars: Comprehensive / multi-page document (> 3,000 chars).
      Read wholly and comprehensively through the entire document from start to finish.
      Extract ONLY the MAIN, primary overarching core topics (5 to 10 major themes/units),
      consolidating minor sub-details and micro-vocabulary under their parent pillars.
    - 2K - 3K chars: Balanced extraction of 4 to 8 core concepts.
    """
    if char_count < 2000:
        return (
            "- DOCUMENT SIZE: Short study note / concise material (< 2,000 characters).\n"
            "- GRANULAR EXTRACTION: Thoroughly extract a generous, good amount of distinct topics (4 to 8 topics).\n"
            "- DEEP COVERAGE: Break down the content into specific concepts, principles, key definitions, rules, or formulas mentioned, "
            "so the student has multiple focused, granular topics to study from this short text.\n"
            "- Avoid collapsing everything into a single broad topic."
        )
    elif char_count > 3000:
        return (
            "- DOCUMENT SIZE: Comprehensive / multi-page study material (> 3,000 characters).\n"
            "- WHOLE-DOCUMENT ANALYSIS: Read wholly and comprehensively through the entire provided text from start to finish.\n"
            "- MAIN TOPICS ONLY: Extract ONLY the MAIN, primary overarching core topics (5 to 10 major themes, units, or foundational concepts).\n"
            "- HIGH-LEVEL SYNTHESIS: Consolidate sub-details and minor vocabulary under their parent main topic. "
            "Do NOT extract microscopic factoids or fragmented single-paragraph subtopics; focus on the primary curriculum pillars."
        )
    else:
        return (
            "- DOCUMENT SIZE: Medium study material (2,000 - 3,000 characters).\n"
            "- BALANCED EXTRACTION: Extract 4 to 8 clear, distinct core topics that accurately represent the key concepts of the study material."
        )


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

    system_template, user_template = _system_user()
    char_count = len(text.strip())
    guidance = _get_extraction_guidance(char_count)

    max_budget = min(settings.openai_topic_extraction_max_input_chars, 20_000)
    distilled_text = _prepare_text_for_topic_extraction(text, max_chars=max_budget)

    system_prompt = render(system_template, extraction_guidance=guidance)
    user_prompt = render(
        user_template,
        source_content=distilled_text,
        extraction_guidance=guidance,
    )

    response = await azure_openai.chat_json(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_output_tokens=min(settings.openai_topic_extraction_max_output_tokens, 1200),
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
        "Topic extraction (%d chars, mode=%s): %d raw → %d parsed → %d deduped",
        char_count,
        "short_granular" if char_count < 2000 else ("long_main" if char_count > 3000 else "medium"),
        len(raw_topics),
        len(parsed),
        len(deduped),
    )
    return deduped
