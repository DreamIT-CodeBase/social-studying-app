"""Unit tests for the question generation service (Sprint 3.7).

Coverage strategy
-----------------
- Per question type: at least one happy-path test that builds a
  realistic prompt response, calls the service through the mocked
  azure_openai seam, and asserts the parsed GeneratedQuestion shape.
- Per type: at least one validator-rejection test exercising the
  type's specific contract (e.g. MCQ with 3 options, T/F with answer
  "yes" instead of "true").
- One test per cross-cutting concern: insufficient_source sentinel,
  empty grounding refusal, prompt-variable substitution.

The Azure OpenAI call is mocked at ``azure_openai.chat_json``. The
prompt files are real and loaded from disk — substituting them with
fixtures would defeat half the point of this test suite (catching prompt
drift).
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.mcp_tools.retrieve_content import RetrievedChunk
from app.models.question import DifficultyLevel, QuestionType
from app.services import question_generation
from app.services.question_generation import (
    InsufficientSource,
    QuestionShapeError,
    generate_question,
)

# ── Helpers ─────────────────────────────────────────────────────────────────


def _chunk(idx: int = 0, text: str | None = None) -> RetrievedChunk:
    return RetrievedChunk(
        chunk_id=f"chk_{idx}",
        chunk_index=idx,
        document_id="doc_a",
        text=text
        or (
            "Photosynthesis is the process by which plants convert sunlight "
            "into chemical energy stored in glucose. The reaction occurs in "
            "chloroplasts, using chlorophyll to capture photons."
        ),
        topic_ids=["tpc_photo"],
        score=0.9,
    )


def _mock_chat_json(response: dict):
    """Patch ``chat_json`` to return ``response`` once and capture inputs."""
    mock = AsyncMock(return_value=response)
    return patch.object(question_generation.azure_openai, "chat_json", mock), mock


# ── MCQ happy path + validators ─────────────────────────────────────────────


def _mcq_response(correct_key: str = "B") -> dict:
    """Build a minimal-but-valid MCQ JSON response from the model."""
    return {
        "body": "Which organelle is the primary site of photosynthesis?",
        "options": [
            {"key": "A", "text": "Mitochondria", "is_correct": correct_key == "A"},
            {"key": "B", "text": "Chloroplast", "is_correct": correct_key == "B"},
            {"key": "C", "text": "Ribosome", "is_correct": correct_key == "C"},
            {"key": "D", "text": "Nucleus", "is_correct": correct_key == "D"},
        ],
        "answer": correct_key,
        "explanation": (
            "Chloroplasts contain chlorophyll, which captures photons during photosynthesis."
        ),
    }


@pytest.mark.asyncio
async def test_mcq_happy_path_returns_parsed_question():
    patched, mock = _mock_chat_json(_mcq_response("B"))
    with patched:
        result = await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk()],
        )

    assert result.body == "Which organelle is the primary site of photosynthesis?"
    assert result.answer == "B"
    assert result.question_type == QuestionType.mcq
    assert result.difficulty == DifficultyLevel.beginner
    assert result.prompt_version == "question_mcq_v1"
    assert len(result.options) == 4
    assert [o.key for o in result.options] == ["A", "B", "C", "D"]
    correct = [o for o in result.options if o.is_correct]
    assert len(correct) == 1
    assert correct[0].key == "B"
    assert result.grading_hints == []  # MCQ doesn't use grading_hints

    # Prompt was actually rendered with the topic + source variables.
    user_prompt = mock.await_args.kwargs["user_prompt"]
    assert "Photosynthesis" in user_prompt
    assert "beginner" in user_prompt
    assert "chloroplasts" in user_prompt.lower()  # source text bled through


@pytest.mark.asyncio
async def test_mcq_rejects_wrong_number_of_options():
    bad = _mcq_response()
    bad["options"] = bad["options"][:3]  # drop one
    patched, _ = _mock_chat_json(bad)
    with patched, pytest.raises(QuestionShapeError, match="exactly 4 options"):
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk()],
        )


@pytest.mark.asyncio
async def test_mcq_rejects_two_correct_options():
    bad = _mcq_response("A")
    bad["options"][1]["is_correct"] = True  # now both A and B are correct
    patched, _ = _mock_chat_json(bad)
    with patched, pytest.raises(QuestionShapeError, match="exactly 1 correct option"):
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk()],
        )


@pytest.mark.asyncio
async def test_mcq_rejects_answer_key_mismatch():
    bad = _mcq_response("B")
    bad["answer"] = "A"  # says A but B is is_correct
    patched, _ = _mock_chat_json(bad)
    with patched, pytest.raises(QuestionShapeError, match="doesn't match the correct"):
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk()],
        )


@pytest.mark.asyncio
async def test_mcq_rejects_non_bool_is_correct():
    bad = _mcq_response()
    bad["options"][0]["is_correct"] = "false"  # string, not bool
    patched, _ = _mock_chat_json(bad)
    with patched, pytest.raises(QuestionShapeError, match="must be a bool"):
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk()],
        )


# ── Short answer ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_short_answer_happy_path():
    response = {
        "body": "What pigment captures photons during photosynthesis?",
        "answer": "chlorophyll",
        "acceptable_variants": ["Chlorophyll"],
        "explanation": "Chlorophyll is the green pigment in chloroplasts that absorbs photons.",
    }
    patched, _ = _mock_chat_json(response)
    with patched:
        result = await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.short_answer,
            grounding_chunks=[_chunk()],
        )

    assert result.answer == "chlorophyll"
    assert result.grading_hints == ["Chlorophyll"]
    assert result.options == []
    assert result.prompt_version == "question_short_answer_v1"


@pytest.mark.asyncio
async def test_short_answer_accepts_empty_variants_list():
    """Variants are optional — an answer with no variants is fine."""
    response = {
        "body": "What gas is released during photosynthesis?",
        "answer": "oxygen",
        "acceptable_variants": [],
        "explanation": "Plants split water and release the oxygen as a byproduct.",
    }
    patched, _ = _mock_chat_json(response)
    with patched:
        result = await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.short_answer,
            grounding_chunks=[_chunk()],
        )
    assert result.grading_hints == []


@pytest.mark.asyncio
async def test_short_answer_rejects_non_list_variants():
    response = {
        "body": "What gas is released?",
        "answer": "oxygen",
        "acceptable_variants": "oxygen, O2",  # should be a list
        "explanation": "...",
    }
    patched, _ = _mock_chat_json(response)
    with patched, pytest.raises(QuestionShapeError, match="acceptable_variants"):
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.short_answer,
            grounding_chunks=[_chunk()],
        )


# ── Long answer ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_long_answer_happy_path():
    response = {
        "body": "Explain how plants convert sunlight into chemical energy.",
        "reference_answer": (
            "Plants absorb sunlight using chlorophyll in their chloroplasts. "
            "The captured photons energize electrons that split water into "
            "oxygen and protons. The electrons drive the synthesis of ATP and "
            "NADPH, which the Calvin cycle then uses to fix CO2 into glucose."
        ),
        "key_points": [
            "Chlorophyll absorbs photons",
            "Water is split releasing oxygen",
            "ATP and NADPH are produced",
            "Calvin cycle fixes CO2 into glucose",
        ],
        "explanation": (
            "Captures the full light-then-dark reaction sequence taught at the intro level."
        ),
    }
    patched, _ = _mock_chat_json(response)
    with patched:
        result = await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.intermediate,
            question_type=QuestionType.long_answer,
            grounding_chunks=[_chunk()],
        )

    assert "Plants absorb sunlight" in result.answer
    assert len(result.grading_hints) == 4
    assert "Chlorophyll absorbs photons" in result.grading_hints
    assert result.options == []
    assert result.prompt_version == "question_long_answer_v1"


@pytest.mark.asyncio
async def test_long_answer_rejects_fewer_than_three_key_points():
    response = {
        "body": "Explain photosynthesis.",
        "reference_answer": "...",
        "key_points": ["one", "two"],  # only 2; need 3+
        "explanation": "...",
    }
    patched, _ = _mock_chat_json(response)
    with patched, pytest.raises(QuestionShapeError, match="at least 3 key_points"):
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.intermediate,
            question_type=QuestionType.long_answer,
            grounding_chunks=[_chunk()],
        )


# ── True / False ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_true_false_happy_path_true():
    response = {
        "body": "Photosynthesis occurs in the chloroplasts of plant cells.",
        "answer": "true",
        "explanation": "Chloroplasts are the organelles where the reaction takes place.",
    }
    patched, _ = _mock_chat_json(response)
    with patched:
        result = await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.true_false,
            grounding_chunks=[_chunk()],
        )

    assert result.answer == "true"
    assert result.grading_hints == []
    assert result.prompt_version == "question_true_false_v1"


@pytest.mark.asyncio
async def test_true_false_happy_path_false():
    response = {
        "body": "Photosynthesis occurs primarily in the mitochondria.",
        "answer": "false",
        "explanation": "Mitochondria perform respiration; chloroplasts perform photosynthesis.",
    }
    patched, _ = _mock_chat_json(response)
    with patched:
        result = await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.true_false,
            grounding_chunks=[_chunk()],
        )
    assert result.answer == "false"


@pytest.mark.asyncio
async def test_true_false_rejects_non_boolean_string():
    """The answer must be exactly 'true' or 'false' — case-sensitive,
    no synonyms. Anything else risks the answer-eval step doing the
    wrong comparison.
    """
    response = {
        "body": "Photosynthesis is real.",
        "answer": "yes",  # should be 'true'/'false'
        "explanation": "...",
    }
    patched, _ = _mock_chat_json(response)
    with patched, pytest.raises(
        QuestionShapeError, match=r"must be boolean or 'true'/'false'"
    ):
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.true_false,
            grounding_chunks=[_chunk()],
        )


# ── Mathematical ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_mathematical_happy_path():
    response = {
        "body": "Find the derivative of $f(x) = x^2 + 3x$.",
        "answer": "$2x + 3$",
        "solution_steps": [
            "Apply the power rule to $x^2$: $\\frac{d}{dx}x^2 = 2x$.",
            "The derivative of $3x$ is $3$.",
            "Sum: $f'(x) = 2x + 3$.",
        ],
        "explanation": "Applies the power rule and the linearity of differentiation.",
    }
    patched, _ = _mock_chat_json(response)
    with patched:
        result = await generate_question(
            topic="Derivatives",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mathematical,
            grounding_chunks=[_chunk(text="The power rule states d/dx(x^n) = n*x^(n-1).")],
        )

    assert result.answer == "$2x + 3$"
    assert len(result.grading_hints) == 3
    assert "power rule" in result.grading_hints[0]
    assert result.options == []
    assert result.prompt_version == "question_mathematical_v1"


@pytest.mark.asyncio
async def test_mathematical_rejects_fewer_than_two_solution_steps():
    response = {
        "body": "Find $f'(x)$ for $f(x) = x^2$.",
        "answer": "$2x$",
        "solution_steps": ["Apply the power rule."],  # only 1
        "explanation": "...",
    }
    patched, _ = _mock_chat_json(response)
    with patched, pytest.raises(QuestionShapeError, match="at least 2 solution_steps"):
        await generate_question(
            topic="Derivatives",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mathematical,
            grounding_chunks=[_chunk(text="The power rule applies.")],
        )


# ── Cross-cutting concerns ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_insufficient_source_sentinel_raises_insufficient_source():
    """When the prompt returns the in-band signal, raise the typed
    exception so the orchestrator can map it to a graceful 'no question
    available' response instead of a 500.
    """
    patched, _ = _mock_chat_json({"insufficient_source": True})
    with patched, pytest.raises(InsufficientSource, match="insufficient_source"):
        await generate_question(
            topic="Quantum Field Theory",
            difficulty=DifficultyLevel.advanced,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk(text="Plants like sunlight.")],
        )


@pytest.mark.asyncio
async def test_empty_grounding_chunks_raises_immediately():
    """Refusing to call GPT-4o without source material avoids wasting a
    token budget and avoids the temptation for the model to invent
    grounding from its own knowledge.
    """
    # NB: chat_json must NOT be called — we'd raise before getting there.
    with (
        patch.object(question_generation.azure_openai, "chat_json", AsyncMock()) as mock_call,
        pytest.raises(InsufficientSource, match="No grounding chunks"),
    ):
        await generate_question(
            topic="Anything",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[],
        )
    mock_call.assert_not_awaited()


@pytest.mark.asyncio
async def test_missing_body_field_raises_shape_error():
    """The model returned valid JSON but forgot the body field. Surface
    as QuestionShapeError so the caller can decide whether to retry or
    skip.
    """
    response = _mcq_response()
    del response["body"]
    patched, _ = _mock_chat_json(response)
    with patched, pytest.raises(QuestionShapeError, match="'body'"):
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk()],
        )


@pytest.mark.asyncio
async def test_prompt_variables_render_topic_difficulty_source_and_seen_questions():
    patched, mock = _mock_chat_json(_mcq_response())
    with patched:
        await generate_question(
            topic="Cellular Respiration",
            difficulty=DifficultyLevel.advanced,
            question_type=QuestionType.mcq,
            grounding_chunks=[
                _chunk(idx=0, text="Glycolysis breaks glucose into pyruvate."),
                _chunk(idx=1, text="The Krebs cycle produces NADH and CO2."),
            ],
            seen_question_bodies=[
                "What gas is released during respiration?",
                "Name the first step of glycolysis.",
            ],
        )

    user_prompt = mock.await_args.kwargs["user_prompt"]
    assert "Cellular Respiration" in user_prompt
    assert "advanced" in user_prompt
    # Both chunks rendered with explicit source boundaries.
    assert "[Source 1]" in user_prompt
    assert "[Source 2]" in user_prompt
    assert "Glycolysis" in user_prompt
    assert "Krebs cycle" in user_prompt
    # Seen question stems rendered as bullets.
    assert "- What gas is released during respiration?" in user_prompt
    assert "- Name the first step of glycolysis." in user_prompt


@pytest.mark.asyncio
async def test_no_seen_questions_renders_explicit_none_placeholder():
    """Empty seen-list must render as something the model parses
    sensibly — leaving the prompt with a bare label after a colon
    confuses GPT-4o.
    """
    patched, mock = _mock_chat_json(_mcq_response())
    with patched:
        await generate_question(
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk()],
        )
    user_prompt = mock.await_args.kwargs["user_prompt"]
    assert "(none)" in user_prompt


@pytest.mark.asyncio
async def test_prompt_version_in_output_matches_registry_name():
    """The persisted Question.prompt_version field is how Sprint 5's
    prompt-tuning UI tracks which prompt produced which question. Pin
    that the value comes from the registry, not a hand-edited string.
    """
    patched, _ = _mock_chat_json(_mcq_response())
    with patched:
        result = await generate_question(
            topic="x",
            difficulty=DifficultyLevel.beginner,
            question_type=QuestionType.mcq,
            grounding_chunks=[_chunk()],
        )
    assert result.prompt_version == "question_mcq_v1"


@pytest.mark.asyncio
async def test_all_five_question_types_map_to_distinct_prompt_files():
    """Sanity: every QuestionType is registered with a unique prompt
    name. Catches the 'forgot to add the new type to the registry' bug
    at unit-test time.
    """
    from app.services.question_generation import _PROMPT_REGISTRY

    assert set(_PROMPT_REGISTRY) == set(QuestionType)
    names = {spec.name for spec in _PROMPT_REGISTRY.values()}
    assert len(names) == len(QuestionType)  # all distinct
