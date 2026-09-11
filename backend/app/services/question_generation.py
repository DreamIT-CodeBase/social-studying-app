"""Question generation orchestrator — Sprint 3.7.

Given a topic, a difficulty, a question type, and grounding chunks
retrieved from AI Search, calls GPT-4o with the right prompt and parses
the structured response into a :class:`GeneratedQuestion` the caller
can persist (or hand to the Sprint 3.8 output-safety check).

Why a single seam for all five types
------------------------------------
The five prompts (MCQ, short_answer, long_answer, true_false,
mathematical) share most of their plumbing: load + render the prompt,
call ``azure_openai.chat_json``, validate the response shape against
the type's contract, and project into a uniform Python object. Putting
each step in its own module would double the surface area without
adding meaning. The per-type differences are:

- which prompt file to load
- which output-token budget to allocate
- which JSON fields are required
- how to project type-specific fields onto Question's ``grading_hints``

All of that lives in :data:`_PROMPT_REGISTRY` and the small parser fns
at the bottom of this file. A new question type means one new prompt
file plus one new row in the registry.

What this service does NOT do
-----------------------------
- Persist to Cosmos — that's the orchestrator's (Sprint 3.9) job, which
  needs the workspace + tenant + source_chunk_ids context.
- Run Content Safety on the AI output — that's Sprint 3.8's seam.
- Pick the topic / difficulty / type — the Learning Path Engine
  (Sprint 3.3) + Difficulty Calibrator (Sprint 3.4) do that upstream.

Output insufficient-source signal
---------------------------------
Each prompt is instructed to return ``{"insufficient_source": true}``
as the JSON response when the grounding doesn't support a fair question
at the requested type + difficulty. Keeping the signal inside JSON
(rather than a sentinel string) preserves JSON-mode discipline and
avoids an extra API call when the model declines — we just check one
field on the parsed response.

The parser raises :class:`InsufficientSource` on that signal, which the
orchestrator maps to a graceful 'no question available' response
instead of a 500.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

from app.mcp_tools.retrieve_content import RetrievedChunk
from app.models.question import DifficultyLevel, McqOption, QuestionType
from app.prompts import load_prompt, render, split_system_user
from app.services import azure_openai, question_validation

logger = logging.getLogger(__name__)


# ── Errors ──────────────────────────────────────────────────────────────────


class InsufficientSource(RuntimeError):
    """The prompt returned the ``INSUFFICIENT_SOURCE`` sentinel.

    The model judged that the grounding chunks don't support a fair
    question at the requested topic + difficulty + type. Caller maps
    to a graceful response (skip + try a different topic, or surface
    "no questions available" to the student).
    """


class QuestionShapeError(ValueError):
    """The model returned JSON that doesn't match the type's contract.

    Most common cause: an MCQ response with !=4 options, or !=1
    is_correct option. Caller should NOT retry the same prompt
    without changing inputs — re-rolling on shape failures wastes
    GPT-4o budget without changing the prompt's fundamental output
    distribution.
    """


# ── Output ──────────────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class GeneratedQuestion:
    """In-memory result of one question generation call.

    Sprint 3.9's orchestrator wraps this with workspace_id / tenant_id /
    document_id / source_chunk_ids to construct the persisted
    :class:`app.models.question.Question`.

    Field-to-Question mapping
    -------------------------
    - ``body`` → ``Question.body``
    - ``answer`` → ``Question.answer``
    - ``explanation`` → ``Question.explanation``
    - ``options`` → ``Question.options`` (empty list for non-MCQ types)
    - ``grading_hints`` → ``Question.grading_hints`` (per-type semantics —
      see :class:`app.models.question.Question`)
    - ``question_type`` → ``Question.question_type``
    - ``difficulty`` → ``Question.difficulty``
    - ``prompt_version`` → ``Question.prompt_version``
    """

    body: str
    answer: str
    explanation: str
    question_type: QuestionType
    difficulty: DifficultyLevel
    prompt_version: str
    options: list[McqOption] = field(default_factory=list)
    grading_hints: list[str] = field(default_factory=list)


# ── Per-type registry ───────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class _PromptSpec:
    """How to call ``chat_json`` and parse the response for one question type.

    ``parser`` takes the parsed JSON dict and returns
    ``(answer, explanation, options, grading_hints)``. Doing the
    projection in a per-type function keeps the dispatch in
    ``generate_question`` linear instead of nested.
    """

    name: str
    max_output_tokens: int
    parser: _ParserFn


# Type alias for the per-type parser signature.
_ParserFn = Callable[
    [dict[str, Any]],
    tuple[str, str, list[McqOption], list[str]],
]


# ── Public entry point ──────────────────────────────────────────────────────


async def generate_question(
    *,
    topic: str,
    difficulty: DifficultyLevel,
    question_type: QuestionType,
    grounding_chunks: list[RetrievedChunk],
    seen_question_bodies: list[str] | None = None,
) -> GeneratedQuestion:
    """Call GPT-4o with the right prompt and parse the structured response.

    Args:
        topic: display name from the Learning Path Engine. Used verbatim
            in the prompt.
        difficulty: from the difficulty calibrator. Drives the prompt's
            difficulty calibration block.
        question_type: which of the five formats to generate.
        grounding_chunks: retrieved by ``retrieve_content``. Their
            ``text`` fields are concatenated into the ``source_content``
            prompt variable. Empty list = immediate
            :class:`InsufficientSource`; we don't ask GPT-4o to invent
            grounding.
        seen_question_bodies: optional list of previously-served question
            stems for this student (from ``retrieve_student_context``).
            Used by the prompt's "avoid duplication" instruction.

    Returns:
        :class:`GeneratedQuestion` with the parsed fields.

    Raises:
        InsufficientSource: prompt returned the sentinel string.
        QuestionShapeError: response was valid JSON but failed the
            per-type contract (e.g. MCQ with 3 options).
        ValueError: response wasn't valid JSON at all.
        ServiceUnavailableError: GPT-4o transport failure — propagated
            from the underlying ``chat_json`` call.
    """
    if not grounding_chunks:
        # Refuse to ask the model to invent grounding. Same shape as the
        # prompt's INSUFFICIENT_SOURCE sentinel — caller treats both alike.
        raise InsufficientSource(
            "No grounding chunks supplied for question generation; refusing "
            "to call GPT-4o without source material."
        )

    spec = _PROMPT_REGISTRY[question_type]
    template = load_prompt(spec.name)
    system_prompt, user_template = split_system_user(template)

    source_content = _format_source(grounding_chunks)
    seen_section = _format_seen(seen_question_bodies or [])
    user_prompt = render(
        user_template,
        topic=topic,
        difficulty=difficulty.value,
        source_content=source_content,
        seen_questions=seen_section,
    )

    response = await azure_openai.chat_json(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_output_tokens=spec.max_output_tokens,
    )

    if response.get("insufficient_source") is True:
        # The prompt's in-band signal that the grounding can't support a
        # fair question. Single-field response — no other validation.
        raise InsufficientSource(
            f"Model returned insufficient_source for topic={topic!r} "
            f"difficulty={difficulty.value} type={question_type.value}."
        )

    answer, explanation, options, grading_hints = spec.parser(response)

    body = response.get("body")
    if not isinstance(body, str) or not body.strip():
        raise QuestionShapeError(
            f"Missing or empty 'body' field for {question_type.value} response."
        )

    logger.info(
        "Generated question topic=%s type=%s difficulty=%s prompt=%s "
        "body_chars=%d options=%d grading_hints=%d",
        topic,
        question_type.value,
        difficulty.value,
        spec.name,
        len(body),
        len(options),
        len(grading_hints),
    )

    generated = GeneratedQuestion(
        body=body.strip(),
        answer=answer,
        explanation=explanation,
        question_type=question_type,
        difficulty=difficulty,
        prompt_version=spec.name,
        options=options,
        grading_hints=grading_hints,
    )

    validated = question_validation.validate_and_sanitize_question(
        generated,
        grounding_chunks=grounding_chunks,
    )
    if validated is None:
        raise QuestionShapeError(
            f"Generated question failed accuracy validation for topic={topic!r}."
        )

    return validated


# ── Prompt input formatting ─────────────────────────────────────────────────


def _format_source(chunks: list[RetrievedChunk]) -> str:
    """Concatenate retrieved chunk texts with explicit boundaries.

    Two-line ``---`` boundaries between chunks help GPT-4o treat them
    as distinct passages and keep its citations honest (an MCQ
    explanation that says "according to chunk 2" reflects which chunk
    actually supports the answer).
    """
    parts = []
    for i, c in enumerate(chunks):
        parts.append(f"[Source {i + 1}]\n{c.text.strip()}")
    return "\n\n---\n\n".join(parts)


def _format_seen(bodies: list[str]) -> str:
    """Format the seen-question list for the prompt's avoid-duplication block.

    Returns "(none)" when empty so the prompt doesn't end with a
    bare label, which can confuse the model.
    """
    if not bodies:
        return "(none)"
    return "\n".join(f"- {b.strip()}" for b in bodies)


# ── Per-type parsers ────────────────────────────────────────────────────────


def _parse_mcq(raw: dict[str, Any]) -> tuple[str, str, list[McqOption], list[str]]:
    """Validate MCQ shape: exactly 4 options, exactly 1 correct, answer key matches."""
    raw_options = raw.get("options")
    if not isinstance(raw_options, list) or len(raw_options) != 4:
        got = len(raw_options) if isinstance(raw_options, list) else "non-list"
        raise QuestionShapeError(f"MCQ requires exactly 4 options; got {got}.")

    options: list[McqOption] = []
    correct_keys: list[str] = []
    for entry in raw_options:
        if not isinstance(entry, dict):
            raise QuestionShapeError("MCQ options must be objects.")
        key = entry.get("key")
        text = entry.get("text")
        is_correct = entry.get("is_correct")
        if not isinstance(key, str) or not key:
            raise QuestionShapeError(f"MCQ option missing 'key': {entry!r}")
        if not isinstance(text, str) or not text.strip():
            raise QuestionShapeError(f"MCQ option {key!r} missing 'text'.")
        if not isinstance(is_correct, bool):
            raise QuestionShapeError(
                f"MCQ option {key!r} 'is_correct' must be a bool; got {type(is_correct).__name__}."
            )
        options.append(McqOption(key=key, text=text.strip(), is_correct=is_correct))
        if is_correct:
            correct_keys.append(key)

    if len(correct_keys) != 1:
        raise QuestionShapeError(
            f"MCQ must have exactly 1 correct option; got {len(correct_keys)} ({correct_keys!r})."
        )

    answer = raw.get("answer")
    if answer != correct_keys[0]:
        raise QuestionShapeError(
            f"MCQ 'answer' field ({answer!r}) doesn't match the correct "
            f"option key ({correct_keys[0]!r})."
        )

    explanation = _require_string(raw, "explanation")
    return answer, explanation, options, []  # MCQ has no separate grading_hints


def _parse_short_answer(
    raw: dict[str, Any],
) -> tuple[str, str, list[McqOption], list[str]]:
    answer = _require_string(raw, "answer")
    explanation = _require_string(raw, "explanation")
    variants_raw = raw.get("acceptable_variants") or []
    if not isinstance(variants_raw, list):
        raise QuestionShapeError(
            "short_answer 'acceptable_variants' must be a list (use [] for none)."
        )
    variants = [str(v).strip() for v in variants_raw if isinstance(v, str) and v.strip()]
    return answer, explanation, [], variants


def _parse_long_answer(
    raw: dict[str, Any],
) -> tuple[str, str, list[McqOption], list[str]]:
    answer = _require_string(raw, "reference_answer")
    explanation = _require_string(raw, "explanation")
    key_points_raw = raw.get("key_points") or []
    if not isinstance(key_points_raw, list) or len(key_points_raw) < 3:
        got = len(key_points_raw) if isinstance(key_points_raw, list) else "non-list"
        raise QuestionShapeError(f"long_answer requires at least 3 key_points; got {got}.")
    key_points = [str(p).strip() for p in key_points_raw if isinstance(p, str) and p.strip()]
    if len(key_points) < 3:
        raise QuestionShapeError(
            f"long_answer key_points must each be a non-empty string; "
            f"got {len(key_points)} valid after filtering."
        )
    return answer, explanation, [], key_points


def _parse_true_false(
    raw: dict[str, Any],
) -> tuple[str, str, list[McqOption], list[str]]:
    answer_val = raw.get("answer")
    if isinstance(answer_val, bool):
        answer_str = "true" if answer_val else "false"
    elif isinstance(answer_val, str):
        answer_str = answer_val.strip().lower()
    else:
        answer_str = ""
    if answer_str not in ("true", "false"):
        raise QuestionShapeError(
            f"true_false 'answer' must be boolean or 'true'/'false'; got {answer_val!r}."
        )
    explanation = _require_string(raw, "explanation")
    return answer_str, explanation, [], []


def _parse_mathematical(
    raw: dict[str, Any],
) -> tuple[str, str, list[McqOption], list[str]]:
    answer = _require_string(raw, "answer")
    explanation = _require_string(raw, "explanation")
    steps_raw = raw.get("solution_steps") or []
    if not isinstance(steps_raw, list) or len(steps_raw) < 2:
        got = len(steps_raw) if isinstance(steps_raw, list) else "non-list"
        raise QuestionShapeError(f"mathematical requires at least 2 solution_steps; got {got}.")
    steps = [str(s).strip() for s in steps_raw if isinstance(s, str) and s.strip()]
    if len(steps) < 2:
        raise QuestionShapeError("mathematical solution_steps must each be a non-empty string.")
    return answer, explanation, [], steps


def _require_string(raw: dict[str, Any], field_name: str) -> str:
    value = raw.get(field_name)
    if not isinstance(value, str) or not value.strip():
        raise QuestionShapeError(f"Required field {field_name!r} is missing or empty.")
    return value.strip()


# ── Registry ────────────────────────────────────────────────────────────────

_PROMPT_REGISTRY: dict[QuestionType, _PromptSpec] = {
    QuestionType.mcq: _PromptSpec(
        name="question_mcq_v1",
        max_output_tokens=350,
        parser=_parse_mcq,
    ),
    QuestionType.short_answer: _PromptSpec(
        name="question_short_answer_v1",
        max_output_tokens=200,
        parser=_parse_short_answer,
    ),
    QuestionType.long_answer: _PromptSpec(
        name="question_long_answer_v1",
        max_output_tokens=1200,
        parser=_parse_long_answer,
    ),
    QuestionType.true_false: _PromptSpec(
        name="question_true_false_v1",
        max_output_tokens=300,
        parser=_parse_true_false,
    ),
    QuestionType.mathematical: _PromptSpec(
        name="question_mathematical_v1",
        max_output_tokens=1500,
        parser=_parse_mathematical,
    ),
}


async def generate_batch_questions(
    *,
    topic: str,
    difficulty: DifficultyLevel,
    count: int = 5,
    grounding_chunks: list[RetrievedChunk],
    seen_question_bodies: list[str] | None = None,
    target_type: QuestionType | None = None,
) -> list[GeneratedQuestion]:
    """Generate a batch of diverse questions using question_batch_v1 prompt."""
    if not grounding_chunks:
        raise InsufficientSource(
            "No grounding chunks supplied for batch generation; refusing "
            "to call GPT-4o without source material."
        )

    template = load_prompt("question_batch_v1")
    system_prompt, user_template = split_system_user(template)

    source_content = _format_source(grounding_chunks)
    seen_section = _format_seen(seen_question_bodies or [])

    type_instruction = ""
    if target_type:
        type_desc_map = {
            QuestionType.mcq: "Multiple Choice Question (mcq) — 4 options, exactly 1 correct",
            QuestionType.short_answer: "Short Answer (short_answer) — concise 1-10 word factual recall answer",
            QuestionType.true_false: "True / False (true_false) — answer must be exactly 'true' or 'false', with explanation",
            QuestionType.long_answer: "Long Answer (long_answer) — essay-style answer with at least 3 key_points and a reference_answer",
        }
        type_desc = type_desc_map.get(target_type, target_type.value)
        type_instruction = (
            f"\nCRITICAL REQUIREMENT: Generate EXACTLY {count} questions in the 'questions' list. "
            f"Every single question in the 'questions' list MUST have question_type = '{target_type.value}' ({type_desc}). "
            f"Do not include any other question types. Ensure there are exactly {count} questions.\n"
        )

    user_prompt = render(
        user_template,
        topic=topic,
        difficulty=difficulty.value,
        source_content=source_content,
        seen_questions=seen_section,
        count=str(count),
        type_instruction=type_instruction,
    )

    response = await azure_openai.chat_json(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_output_tokens=1500,
        temperature=0.7,
    )

    if response.get("insufficient_source") is True:
        raise InsufficientSource(f"Model returned insufficient_source for batch topic={topic!r}")

    raw_questions = response.get("questions")
    if not isinstance(raw_questions, list):
        raise QuestionShapeError("Expected 'questions' field to be a list in response.")

    results: list[GeneratedQuestion] = []
    for raw in raw_questions:
        try:
            q_type_str = raw.get("question_type")
            q_type = QuestionType(q_type_str)
            if target_type and q_type != target_type:
                logger.info(
                    "Skipping question with mismatched type %s (expected %s)",
                    q_type,
                    target_type,
                )
                continue

            spec = _PROMPT_REGISTRY[q_type]
            answer, explanation, options, grading_hints = spec.parser(raw)

            body = raw.get("body")
            if not isinstance(body, str) or not body.strip():
                continue

            candidate_gq = GeneratedQuestion(
                body=body.strip(),
                answer=answer,
                explanation=explanation,
                question_type=q_type,
                difficulty=difficulty,
                prompt_version="question_batch_v1",
                options=options,
                grading_hints=grading_hints,
            )

            validated = question_validation.validate_and_sanitize_question(
                candidate_gq,
                grounding_chunks=grounding_chunks,
            )
            if validated is not None:
                results.append(validated)
            else:
                logger.warning("Question failed accuracy validation in batch; discarded: %s", body)
        except Exception as e:
            logger.warning("Failed to parse question in batch: %s", e)

    return results
