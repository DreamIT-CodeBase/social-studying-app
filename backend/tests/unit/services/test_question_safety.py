"""Unit tests for the question safety reviewer (Sprint 3.8).

Coverage strategy
-----------------
- Happy path: clean Content Safety verdict + no structural issues → approved.
- Each layer's failure path: safety flag → flagged; structural fail → rejected.
- Structural-failure-wins-over-safety: a question that fails both lands
  on rejected (it's unusable regardless of admin review).
- Each MCQ structural rule has at least one dedicated test.
- Anti-leakage for the long-form types (short_answer / long_answer /
  mathematical) checked explicitly; the MCQ + true_false skip is also
  pinned.
- The combined-text payload sent to Content Safety includes every
  field — body alone would miss objectionable options or explanations.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.models.question import DifficultyLevel, McqOption, QuestionType
from app.services.content_safety import SafetyVerdict
from app.services.question_generation import GeneratedQuestion
from app.services.question_safety import (
    ReviewVerdict,
    review_question,
)

# ── Helpers ─────────────────────────────────────────────────────────────────


def _clean_verdict() -> SafetyVerdict:
    return SafetyVerdict(
        severities={"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0},
        flagged_categories=[],
    )


def _flagged_verdict(category: str = "Violence", severity: int = 4) -> SafetyVerdict:
    sevs = {"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0}
    sevs[category] = severity
    return SafetyVerdict(severities=sevs, flagged_categories=[category])


def _mcq(
    *,
    body: str = "Which organelle performs photosynthesis?",
    correct: str = "B",
    options: list[tuple[str, str]] | None = None,
    explanation: str = "Chloroplasts contain the chlorophyll that captures photons.",
) -> GeneratedQuestion:
    """Build a clean MCQ for happy-path tests.

    ``options`` is a list of (key, text) — is_correct is derived from
    ``correct``.
    """
    opt_pairs = options or [
        ("A", "Mitochondria"),
        ("B", "Chloroplast"),
        ("C", "Ribosome"),
        ("D", "Nucleus"),
    ]
    return GeneratedQuestion(
        body=body,
        answer=correct,
        explanation=explanation,
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.beginner,
        prompt_version="question_mcq_v1",
        options=[McqOption(key=k, text=t, is_correct=(k == correct)) for k, t in opt_pairs],
        grading_hints=[],
    )


def _short(
    *,
    body: str = "What pigment captures photons during photosynthesis?",
    answer: str = "chlorophyll",
    explanation: str = "Chlorophyll is the pigment in chloroplasts that absorbs photons.",
    grading_hints: list[str] | None = None,
) -> GeneratedQuestion:
    return GeneratedQuestion(
        body=body,
        answer=answer,
        explanation=explanation,
        question_type=QuestionType.short_answer,
        difficulty=DifficultyLevel.beginner,
        prompt_version="question_short_answer_v1",
        options=[],
        grading_hints=grading_hints or ["Chlorophyll"],
    )


def _tf(
    *,
    body: str = "Photosynthesis occurs in mitochondria.",
    answer: str = "false",
    explanation: str = "Photosynthesis occurs in chloroplasts, not mitochondria.",
) -> GeneratedQuestion:
    return GeneratedQuestion(
        body=body,
        answer=answer,
        explanation=explanation,
        question_type=QuestionType.true_false,
        difficulty=DifficultyLevel.beginner,
        prompt_version="question_true_false_v1",
        options=[],
        grading_hints=[],
    )


def _patch_safety(verdict: SafetyVerdict):
    return patch(
        "app.services.question_safety.content_safety.analyze_extracted_text",
        AsyncMock(return_value=verdict),
    )


# ── Happy path ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_clean_mcq_returns_approved():
    with _patch_safety(_clean_verdict()):
        result = await review_question(_mcq())

    assert result.verdict == ReviewVerdict.approved
    assert result.structural_failures == []
    assert result.safety.flagged is False
    assert "Approved" in result.reason


# ── Content Safety branch ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_safety_flagged_question_returns_flagged_verdict():
    """When Content Safety flags but the structural checks pass, the
    question is sent to admin review (flagged), NOT rejected outright.
    """
    flagged = _flagged_verdict(category="Violence", severity=4)
    with _patch_safety(flagged):
        result = await review_question(_mcq())

    assert result.verdict == ReviewVerdict.flagged
    assert result.safety.flagged_categories == ["Violence"]
    assert "Violence" in result.reason
    # Reason should also surface the severity so the orchestrator can log it.
    assert "4/6" in result.reason


@pytest.mark.asyncio
async def test_combined_text_sent_to_safety_includes_every_field():
    """Body + answer + explanation + options + grading_hints all go into
    the safety scan. Otherwise an objectionable option text could sneak
    past a clean body.
    """
    captured: dict = {}

    async def fake_analyze(text: str) -> SafetyVerdict:
        captured["text"] = text
        return _clean_verdict()

    with patch(
        "app.services.question_safety.content_safety.analyze_extracted_text",
        fake_analyze,
    ):
        q = _mcq(
            body="STEM body",
            explanation="EXPLAIN text",
        )
        # Mutate options to add a recognisable token in option text.
        q = GeneratedQuestion(
            body="STEM body",
            answer="B",
            explanation="EXPLAIN text",
            question_type=q.question_type,
            difficulty=q.difficulty,
            prompt_version=q.prompt_version,
            options=[
                McqOption(key="A", text="OPTION-A-TOKEN", is_correct=False),
                McqOption(key="B", text="OPTION-B-TOKEN", is_correct=True),
                McqOption(key="C", text="OPTION-C-TOKEN", is_correct=False),
                McqOption(key="D", text="OPTION-D-TOKEN", is_correct=False),
            ],
            grading_hints=["HINT-1", "HINT-2"],
        )
        await review_question(q)

    text = captured["text"]
    assert "STEM body" in text
    assert "EXPLAIN text" in text
    assert "OPTION-A-TOKEN" in text
    assert "OPTION-D-TOKEN" in text
    assert "HINT-1" in text
    assert "HINT-2" in text


# ── Structural-fail rejection ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_body_over_length_limit_rejects():
    too_long = "Q? " + ("filler " * 100)
    assert len(too_long) > 500
    with _patch_safety(_clean_verdict()):
        result = await review_question(_mcq(body=too_long))

    assert result.verdict == ReviewVerdict.rejected
    assert any("sanity limit" in f for f in result.structural_failures)


@pytest.mark.asyncio
async def test_mcq_option_with_correct_marker_rejects():
    """Prompt forbids '(correct)' but the model occasionally inserts it."""
    options = [
        ("A", "Mitochondria"),
        ("B", "Chloroplast (correct)"),  # leakage marker
        ("C", "Ribosome"),
        ("D", "Nucleus"),
    ]
    with _patch_safety(_clean_verdict()):
        result = await review_question(_mcq(options=options))

    assert result.verdict == ReviewVerdict.rejected
    assert any("leaks correctness" in f for f in result.structural_failures)


@pytest.mark.asyncio
async def test_mcq_option_with_x_marker_rejects():
    options = [
        ("A", "Mitochondria"),
        ("B", "Chloroplast [x]"),
        ("C", "Ribosome"),
        ("D", "Nucleus"),
    ]
    with _patch_safety(_clean_verdict()):
        result = await review_question(_mcq(options=options))
    assert result.verdict == ReviewVerdict.rejected


@pytest.mark.asyncio
async def test_mcq_option_with_check_mark_rejects():
    options = [
        ("A", "Mitochondria"),
        ("B", "Chloroplast (✓)"),
        ("C", "Ribosome"),
        ("D", "Nucleus"),
    ]
    with _patch_safety(_clean_verdict()):
        result = await review_question(_mcq(options=options))
    assert result.verdict == ReviewVerdict.rejected


@pytest.mark.asyncio
async def test_mcq_all_of_the_above_option_rejects():
    options = [
        ("A", "Mitochondria"),
        ("B", "Chloroplast"),
        ("C", "Ribosome"),
        ("D", "All of the above"),
    ]
    with _patch_safety(_clean_verdict()):
        result = await review_question(_mcq(options=options))

    assert result.verdict == ReviewVerdict.rejected
    assert any("banned phrase" in f for f in result.structural_failures)


@pytest.mark.asyncio
async def test_mcq_none_of_the_above_option_rejects():
    options = [
        ("A", "Mitochondria"),
        ("B", "Chloroplast"),
        ("C", "Ribosome"),
        ("D", "None of the above"),
    ]
    with _patch_safety(_clean_verdict()):
        result = await review_question(_mcq(options=options))
    assert result.verdict == ReviewVerdict.rejected


# ── Anti-leakage: long-form types ──────────────────────────────────────────


@pytest.mark.asyncio
async def test_short_answer_body_leaks_answer_verbatim_rejects():
    q = _short(
        body="Which pigment is chlorophyll in plants?",  # contains the answer
        answer="chlorophyll",
    )
    with _patch_safety(_clean_verdict()):
        result = await review_question(q)
    assert result.verdict == ReviewVerdict.rejected
    assert any("leaks the reference answer" in f for f in result.structural_failures)


@pytest.mark.asyncio
async def test_short_answer_body_not_leaking_passes():
    q = _short(
        body="What green pigment captures photons during photosynthesis?",
        answer="chlorophyll",
    )
    with _patch_safety(_clean_verdict()):
        result = await review_question(q)
    assert result.verdict == ReviewVerdict.approved


@pytest.mark.asyncio
async def test_short_three_char_answer_is_not_checked_against_body():
    """The substring check would false-positive on tiny answers like 'is'
    or 'a'. We only check answers >= 4 chars. A 3-char answer that
    happens to appear in the body must NOT trigger rejection.
    """
    q = _short(
        body="Where is the photosynthesis-related pigment located?",  # contains "is"
        answer="is",
    )
    with _patch_safety(_clean_verdict()):
        result = await review_question(q)
    assert result.verdict == ReviewVerdict.approved


# ── Anti-leakage: skip for MCQ + true_false ────────────────────────────────


@pytest.mark.asyncio
async def test_mcq_answer_key_in_body_does_not_trigger_anti_leakage():
    """For MCQ, the ``answer`` field is a key like 'C'. The substring
    check would false-positive on any body containing the letter — skip
    the check for MCQ entirely.
    """
    q = _mcq(
        body="Carbon dioxide is consumed during photosynthesis. Which organelle is responsible?",  # noqa: E501
        correct="C",
    )
    with _patch_safety(_clean_verdict()):
        result = await review_question(q)
    assert result.verdict == ReviewVerdict.approved


@pytest.mark.asyncio
async def test_true_false_word_in_body_does_not_trigger_anti_leakage():
    """For true_false, the answer is the literal word 'true' or 'false',
    which often legitimately appears in the statement. Skip the check.
    """
    q = _tf(
        body="It is true that photosynthesis occurs in mitochondria.",
        answer="false",
    )
    with _patch_safety(_clean_verdict()):
        result = await review_question(q)
    assert result.verdict == ReviewVerdict.approved


# ── Precedence: structural > safety ────────────────────────────────────────


@pytest.mark.asyncio
async def test_structural_failure_wins_over_safety_flag():
    """A question that fails BOTH layers lands on rejected (not flagged).
    Structural failure means the question is unusable regardless of
    admin review.
    """
    options = [
        ("A", "Mitochondria"),
        ("B", "Chloroplast (correct)"),  # structural fail
        ("C", "Ribosome"),
        ("D", "Nucleus"),
    ]
    with _patch_safety(_flagged_verdict()):  # also flagged
        result = await review_question(_mcq(options=options))

    assert result.verdict == ReviewVerdict.rejected
    # Safety verdict is preserved on the result so the orchestrator can
    # still log it if it wants.
    assert result.safety.flagged is True
    assert any("leaks correctness" in f for f in result.structural_failures)


@pytest.mark.asyncio
async def test_safety_failure_propagates_when_no_structural_issue():
    flagged = _flagged_verdict(category="Hate", severity=4)
    with _patch_safety(flagged):
        result = await review_question(_mcq())

    assert result.verdict == ReviewVerdict.flagged
    assert result.structural_failures == []
    assert result.safety.flagged_categories == ["Hate"]
