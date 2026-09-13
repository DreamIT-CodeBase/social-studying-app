"""Unit tests for the answer evaluator (Sprint 3.10).

Per-type matrix of correctness rules. Pure function, no I/O, so the
tests are fast and exhaustive — every type gets a happy-correct,
happy-wrong, and at least one edge case (case folding, whitespace,
LaTeX delimiters).

The v1 evaluators are deterministic substring/equality matches;
Sprint 5/6 may swap in AI-graded long_answer + mathematical without
changing this contract. Whenever that swap lands, every test below
should still pass — they pin the spec, not the implementation.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest

from app.models.question import (
    DifficultyLevel,
    McqOption,
    Question,
    QuestionStatus,
    QuestionType,
)
from app.services.answer_evaluation import evaluate

pytestmark = pytest.mark.asyncio

# ── Helpers ─────────────────────────────────────────────────────────────────


def _question(
    *,
    question_type: QuestionType,
    answer: str,
    grading_hints: list[str] | None = None,
    options: list[McqOption] | None = None,
    body: str = "Q?",
) -> Question:
    return Question(
        **{"_id": "qst_x"},
        tenant_id="ten_a",
        workspace_id="wsp_a",
        document_id="doc_a",
        topic="Photosynthesis",
        question_type=question_type,
        difficulty=DifficultyLevel.beginner,
        body=body,
        options=options or [],
        answer=answer,
        explanation="(test)",
        grading_hints=grading_hints or [],
        status=QuestionStatus.approved,
    )


# ── MCQ ─────────────────────────────────────────────────────────────────────


async def test_mcq_correct_key_matches():
    q = _question(question_type=QuestionType.mcq, answer="B")
    result = await evaluate(q, "B")
    assert result.is_correct is True
    assert result.canonical_answer == "B"


async def test_mcq_wrong_key_is_marked_wrong():
    q = _question(question_type=QuestionType.mcq, answer="B")
    assert (await evaluate(q, "A")).is_correct is False


async def test_mcq_is_case_insensitive():
    """Curl-style lowercased keys still grade — UI sends "B" but a
    debug client might send "b".
    """
    q = _question(question_type=QuestionType.mcq, answer="C")
    assert (await evaluate(q, "c")).is_correct is True


async def test_mcq_trims_whitespace():
    q = _question(question_type=QuestionType.mcq, answer="A")
    assert (await evaluate(q, "  A  ")).is_correct is True


# ── True / False ────────────────────────────────────────────────────────────


async def test_true_false_correct_true():
    q = _question(question_type=QuestionType.true_false, answer="true")
    assert (await evaluate(q, "true")).is_correct is True


async def test_true_false_correct_false():
    q = _question(question_type=QuestionType.true_false, answer="false")
    assert (await evaluate(q, "false")).is_correct is True


async def test_true_false_accepts_t_shorthand():
    """A one-character button on the mobile UI is the most likely
    submission shape — the evaluator must accept "t" / "f".
    """
    q = _question(question_type=QuestionType.true_false, answer="true")
    assert (await evaluate(q, "T")).is_correct is True
    assert (await evaluate(q, "f")).is_correct is False


async def test_true_false_rejects_synonyms_as_wrong():
    """ "yes"/"no" aren't t/f synonyms in this evaluator — they grade
    as wrong rather than triggering an error. The client should have
    constrained the input.
    """
    q = _question(question_type=QuestionType.true_false, answer="true")
    assert (await evaluate(q, "yes")).is_correct is False


# ── Short answer ────────────────────────────────────────────────────────────


async def test_short_answer_exact_match():
    q = _question(question_type=QuestionType.short_answer, answer="chlorophyll")
    assert (await evaluate(q, "chlorophyll")).is_correct is True


async def test_short_answer_case_insensitive():
    q = _question(question_type=QuestionType.short_answer, answer="chlorophyll")
    assert (await evaluate(q, "CHLOROPHYLL")).is_correct is True


async def test_short_answer_strips_trailing_punctuation_and_whitespace():
    q = _question(question_type=QuestionType.short_answer, answer="DNA")
    assert (await evaluate(q, "  dna. ")).is_correct is True


async def test_short_answer_normalizes_diacritics():
    """A student answering "cafe" for a canonical "café" matches —
    keyboard-tier UX is worse for matching diacritics than the actual
    correctness picture.
    """
    q = _question(question_type=QuestionType.short_answer, answer="café")
    assert (await evaluate(q, "cafe")).is_correct is True


async def test_short_answer_matches_acceptable_variants():
    q = _question(
        question_type=QuestionType.short_answer,
        answer="deoxyribonucleic acid",
        grading_hints=["DNA", "d.n.a."],
    )
    assert (await evaluate(q, "DNA")).is_correct is True
    assert (await evaluate(q, "d.n.a")).is_correct is True


async def test_short_answer_wrong_response_is_marked_wrong():
    q = _question(
        question_type=QuestionType.short_answer,
        answer="chlorophyll",
        grading_hints=["chlorophyll a"],
    )
    assert (await evaluate(q, "mitochondria")).is_correct is False


async def test_short_answer_collapses_internal_whitespace():
    q = _question(question_type=QuestionType.short_answer, answer="two words")
    assert (await evaluate(q, "two   words")).is_correct is True


async def test_short_answer_two_blanks_comma_spacing_normalizes():
    q = _question(question_type=QuestionType.short_answer, answer="oxygen, glucose")
    assert (await evaluate(q, "oxygen,glucose")).is_correct is True
    assert (await evaluate(q, "oxygen , glucose")).is_correct is True
    assert (await evaluate(q, "oxygen,  glucose")).is_correct is True


async def test_short_answer_two_blanks_symmetric_order_allowed():
    q = _question(question_type=QuestionType.short_answer, answer="oxygen, glucose")
    assert (await evaluate(q, "glucose, oxygen")).is_correct is True
    assert (await evaluate(q, "glucose,oxygen")).is_correct is True
    assert (await evaluate(q, "nitrogen, oxygen")).is_correct is False


@patch("app.services.answer_evaluation.azure_openai.chat_json")
async def test_short_answer_accepts_semantic_synonyms(mock_chat):
    """If exact substring / normalisation fails, semantic grading kicks in.
    'spirilla' isn't exactly 'spirochetes', but the AI grades it correct.
    """
    mock_chat.return_value = {"is_correct": True}
    q = _question(
        question_type=QuestionType.short_answer,
        answer="spirochetes",
    )
    result = await evaluate(q, "spirilla")
    assert result.is_correct is True
    mock_chat.assert_called_once()
    args, kwargs = mock_chat.call_args
    assert "spirilla" in kwargs["user_prompt"]


# ── Long answer ─────────────────────────────────────────────────────────────


def _long(answer: str = "Reference text.") -> Question:
    return _question(
        question_type=QuestionType.long_answer,
        answer=answer,
        grading_hints=[
            "Chlorophyll absorbs photons",
            "Water is split into oxygen and protons",
            "ATP and NADPH are produced",
            "Calvin cycle fixes CO2 into glucose",
        ],
    )


async def test_long_answer_correct_when_all_hints_present():
    q = _long()
    response = (
        "Chlorophyll absorbs photons. Water is split into oxygen and protons. "
        "ATP and NADPH are produced. Calvin cycle fixes CO2 into glucose."
    )
    result = await evaluate(q, response)
    assert result.is_correct is True
    assert result.rubric_score == pytest.approx(1.0)
    assert len(result.matched_hints) == 4


async def test_long_answer_correct_at_half_threshold():
    """Exactly 2 of 4 hints = 50% = passes the threshold."""
    q = _long()
    response = "Chlorophyll absorbs photons and ATP and NADPH are produced."
    result = await evaluate(q, response)
    assert result.is_correct is True
    assert result.rubric_score == pytest.approx(0.5)
    assert len(result.matched_hints) == 2


@patch("app.services.answer_evaluation.azure_openai.chat_json")
async def test_long_answer_wrong_below_threshold(mock_chat):
    """1 of 4 hints = 25% = below the 50% threshold."""
    q = _long()
    mock_chat.return_value = {"is_correct": False, "rubric_score": 0.25}
    response = "Chlorophyll absorbs photons and that is all I remember."
    result = await evaluate(q, response)
    assert result.is_correct is False
    assert result.rubric_score == pytest.approx(0.25)
    assert result.matched_hints == ["Chlorophyll absorbs photons"]


@patch("app.services.answer_evaluation.azure_openai.chat_json")
async def test_long_answer_accepts_semantically_equivalent_paraphrase(mock_chat):
    mock_chat.return_value = {"is_correct": True, "rubric_score": 0.75}
    q = _long()
    result = await evaluate(
        q,
        "Light energy drives reactions that release oxygen and create the "
        "energy carriers later used to build sugar from carbon dioxide.",
    )
    assert result.is_correct is True
    assert result.rubric_score == pytest.approx(0.75)
    mock_chat.assert_called_once()


async def test_long_answer_accepts_paraphrased_token_overlap():
    """A student who paraphrases the key points in different word order
    should still pass — the token-overlap fallback kicks in when the
    exact-substring check misses. The response below mentions every
    hint's key tokens but reorders them.
    """
    q = _long()
    response = (
        "Photons get absorbed by chlorophyll molecules. The water "
        "molecule is split into oxygen and protons. NADPH and ATP "
        "are produced as energy carriers. Then the Calvin cycle uses "
        "those carriers to fix CO2 into glucose."
    )
    result = await evaluate(q, response)
    assert result.is_correct is True
    # At least three of four hints should match via token overlap even
    # though none appear as exact substrings. The fourth ("Chlorophyll
    # absorbs photons") doesn't match because v1 has no stemmer —
    # "absorbed" doesn't normalize to "absorbs". Pin the score so a
    # future stemmer addition trips this test deliberately.
    assert len(result.matched_hints) >= 3
    assert result.rubric_score == pytest.approx(0.75)


async def test_long_answer_with_no_hints_falls_back_to_non_empty():
    """A degenerate question with no hints (shouldn't happen post-3.7
    but be defensive) treats any non-empty submission as correct.
    """
    q = _question(
        question_type=QuestionType.long_answer,
        answer="ref",
        grading_hints=[],
    )
    assert (await evaluate(q, "any answer")).is_correct is True
    assert (await evaluate(q, "   ")).is_correct is False


# ── Mathematical ────────────────────────────────────────────────────────────


async def test_mathematical_exact_latex_match():
    q = _question(
        question_type=QuestionType.mathematical,
        answer="$2x + 3$",
    )
    assert (await evaluate(q, "$2x + 3$")).is_correct is True


async def test_mathematical_strips_latex_delimiters_and_spaces():
    """The student writes ``2x+3`` (no LaTeX dollars, no spaces); the
    canonical is ``$2x + 3$``. The normalization should collapse both
    to ``2x+3`` and grade correct.
    """
    q = _question(
        question_type=QuestionType.mathematical,
        answer="$2x + 3$",
    )
    assert (await evaluate(q, "2x+3")).is_correct is True


async def test_mathematical_symbolic_equivalence_deterministic():
    """Algebraic equivalence like 3 + 2x vs $2x + 3$ matches deterministically via SymPy."""
    q = _question(
        question_type=QuestionType.mathematical,
        answer="$2x + 3$",
    )
    assert (await evaluate(q, "3 + 2x")).is_correct is True


@patch("app.services.answer_evaluation.azure_openai.chat_json")
async def test_mathematical_accepts_semantic_equivalence(mock_chat):
    """Verbal or natural language phrasing falls back to semantic AI grading."""
    mock_chat.return_value = {"is_correct": True}
    q = _question(
        question_type=QuestionType.mathematical,
        answer="$2x + 3$",
    )
    assert (await evaluate(q, "two x plus three")).is_correct is True
    mock_chat.assert_called_once()


@patch("app.services.answer_evaluation.azure_openai.chat_json")
async def test_mathematical_wrong_answer_is_marked_wrong(mock_chat):
    mock_chat.return_value = {"is_correct": False}
    q = _question(
        question_type=QuestionType.mathematical,
        answer="$2x + 3$",
    )
    assert (await evaluate(q, "$x + 1$")).is_correct is False


@patch("app.services.answer_evaluation.azure_openai.chat_json")
async def test_mathematical_rubric_score_is_one_or_zero(mock_chat):
    """v1 mathematical scoring is boolean — no partial credit. The
    rubric_score still populates so the response shape stays uniform
    across rubric-scored types.
    """
    q = _question(question_type=QuestionType.mathematical, answer="$2x$")
    mock_chat.return_value = {"is_correct": False}
    assert (await evaluate(q, "$2x$")).rubric_score == 1.0
    assert (await evaluate(q, "$3x$")).rubric_score == 0.0


# ── Unknown question type ───────────────────────────────────────────────────


async def test_unknown_question_type_raises_value_error():
    """Adding a QuestionType without an evaluator branch should fail
    loud, not silently grade everything as wrong.
    """

    class _FakeType:
        pass

    q = _question(question_type=QuestionType.mcq, answer="A")
    # Mutate via model_copy with update — Pydantic will complain about
    # the bogus enum value, so we use object.__setattr__ as the test
    # backdoor.
    object.__setattr__(q, "question_type", "unknown_type")
    with pytest.raises(ValueError, match="No evaluation branch"):
        await evaluate(q, "A")
