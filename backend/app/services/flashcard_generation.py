"""Flashcard generation — Sprint 3.12.

Sibling of :mod:`app.services.question_generation` but tighter:
flashcards have no difficulty calibration, no per-type variants, no
options or grading hints. One prompt, one parser, one shape out.

Why a separate module + not a question_generation subtype
---------------------------------------------------------
Flashcards aren't graded — the student self-rates after seeing the
back. That makes the post-generation validation different (no
"answer key matches one option" check), the persisted shape
different (separate Cosmos collection), and the eventual SRS pipeline
different (no mastery delta). Smashing flashcards into the question
generator would force every branch to fork on "is this a flashcard?".

Output insufficient-source signal
---------------------------------
Same shape as question generation: the prompt instructs the model to
return ``{"insufficient_source": true}`` when the grounding can't
support a fair flashcard for the requested topic. The orchestrator
maps that to a graceful 'no card available right now' response.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from app.mcp_tools.retrieve_content import RetrievedChunk
from app.prompts import load_prompt, render, split_system_user
from app.services import azure_openai

logger = logging.getLogger(__name__)


# ── Errors ──────────────────────────────────────────────────────────────────


class InsufficientFlashcardSource(RuntimeError):
    """Prompt returned the in-band insufficient_source signal.

    Distinct exception type from
    :class:`app.services.question_generation.InsufficientSource` so the
    orchestrator can distinguish question vs flashcard failure modes in
    logs and metrics; semantically they're handled the same way.
    """


class FlashcardShapeError(ValueError):
    """Generated JSON didn't satisfy the flashcard contract."""


# ── Output ──────────────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class GeneratedFlashcard:
    """In-memory result of one flashcard generation call.

    The orchestrator wraps this with workspace_id / tenant_id /
    document_id / source_chunk_ids to construct the persisted
    :class:`app.models.flashcard.Flashcard`.
    """

    front: str
    back: str
    explanation: str
    prompt_version: str


# ── Constants ───────────────────────────────────────────────────────────────


_PROMPT_NAME = "flashcard_v1"
# Output token budget: a flashcard's worst-case JSON is front (~30
# tokens) + back (~50 tokens) + explanation (~50 tokens) + JSON
# scaffolding. 400 is comfortable headroom.
_MAX_OUTPUT_TOKENS = 400


# ── Public entry point ──────────────────────────────────────────────────────


async def generate_flashcard(
    *,
    topic: str,
    grounding_chunks: list[RetrievedChunk],
    seen_card_fronts: list[str] | None = None,
) -> GeneratedFlashcard:
    """Call GPT-4o with the flashcard prompt and parse the response.

    Args:
        topic: display name from the Learning Path Engine.
        grounding_chunks: retrieved by ``retrieve_content``. Empty list
            raises :class:`InsufficientFlashcardSource` immediately —
            we don't ask the model to invent grounding.
        seen_card_fronts: optional list of previously-served fronts
            (per-student) so the prompt's avoid-duplication block has
            real data.

    Returns:
        :class:`GeneratedFlashcard` with front + back + explanation +
        prompt_version.

    Raises:
        InsufficientFlashcardSource: prompt returned the in-band sentinel.
        FlashcardShapeError: response was valid JSON but missing or
            empty required fields.
        ValueError: response wasn't valid JSON.
        ServiceUnavailableError: GPT-4o transport failure — propagated
            from ``chat_json``.
    """
    if not grounding_chunks:
        raise InsufficientFlashcardSource(
            "No grounding chunks supplied for flashcard generation; "
            "refusing to call GPT-4o without source material."
        )

    template = load_prompt(_PROMPT_NAME)
    system_prompt, user_template = split_system_user(template)
    source_content = _format_source(grounding_chunks)
    seen_section = _format_seen(seen_card_fronts or [])
    user_prompt = render(
        user_template,
        topic=topic,
        source_content=source_content,
        seen_cards=seen_section,
    )

    response = await azure_openai.chat_json(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_output_tokens=_MAX_OUTPUT_TOKENS,
    )

    if response.get("insufficient_source") is True:
        raise InsufficientFlashcardSource(
            f"Model returned insufficient_source for topic={topic!r}."
        )

    front = _require_string(response, "front")
    back = _require_string(response, "back")
    explanation = _require_string(response, "explanation")

    logger.info(
        "Generated flashcard topic=%s front_chars=%d back_chars=%d",
        topic,
        len(front),
        len(back),
    )

    return GeneratedFlashcard(
        front=front,
        back=back,
        explanation=explanation,
        prompt_version=_PROMPT_NAME,
    )


# ── Prompt input formatting ─────────────────────────────────────────────────


def _format_source(chunks: list[RetrievedChunk]) -> str:
    parts = []
    for i, c in enumerate(chunks):
        parts.append(f"[Source {i + 1}]\n{c.text.strip()}")
    return "\n\n---\n\n".join(parts)


def _format_seen(fronts: list[str]) -> str:
    if not fronts:
        return "(none)"
    return "\n".join(f"- {f.strip()}" for f in fronts)


def _require_string(raw: dict[str, Any], field_name: str) -> str:
    value = raw.get(field_name)
    if not isinstance(value, str) or not value.strip():
        raise FlashcardShapeError(
            f"Required field {field_name!r} is missing or empty."
        )
    return value.strip()
