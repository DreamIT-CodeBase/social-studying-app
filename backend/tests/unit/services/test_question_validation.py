"""Unit tests for the question validation and accuracy service."""

import pytest

from app.mcp_tools.retrieve_content import RetrievedChunk
from app.models.question import DifficultyLevel, McqOption, QuestionType
from app.services.question_generation import GeneratedQuestion
from app.services.question_validation import (
    extract_equation,
    parse_candidate_value,
    safe_evaluate_math_expr,
    validate_and_sanitize_question,
)


def _mcq(body: str, options: list[tuple[str, str, bool]], answer: str, explanation: str) -> GeneratedQuestion:
    return GeneratedQuestion(
        body=body,
        answer=answer,
        explanation=explanation,
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.beginner,
        prompt_version="question_batch_v1",
        options=[McqOption(key=k, text=t, is_correct=c) for k, t, c in options],
    )


def test_extract_equation_and_evaluate():
    eq1 = extract_equation("What is the value of x in the equation 8x = 40?")
    assert eq1 is not None
    var, lhs, rhs = eq1
    assert var == "x"
    assert safe_evaluate_math_expr(lhs, var, 5.0) == 40.0
    assert safe_evaluate_math_expr(rhs, var, 5.0) == 40.0

    eq2 = extract_equation("What is the solution to the equation 2(x + 3) = 16?")
    assert eq2 is not None
    var, lhs, rhs = eq2
    assert var == "x"
    assert safe_evaluate_math_expr(lhs, var, 5.0) == 16.0
    assert safe_evaluate_math_expr(rhs, var, 5.0) == 16.0

    eq3 = extract_equation("Solve: x / 3 = -2")
    assert eq3 is not None
    var, lhs, rhs = eq3
    assert var == "x"
    assert safe_evaluate_math_expr(lhs, var, -6.0) == -2.0


def test_parse_candidate_value():
    assert parse_candidate_value("x = 5") == 5.0
    assert parse_candidate_value("5") == 5.0
    assert parse_candidate_value("x = -6") == -6.0
    assert parse_candidate_value("-2.5") == -2.5
    assert parse_candidate_value("non-number") is None


def test_auto_correct_8x_equals_40():
    """Matches the exact issue in user screenshot where 8x = 40 had option A (4) marked correct instead of B (5)."""
    flawed_q = _mcq(
        body="What is the value of x in the equation 8x = 40?",
        options=[
            ("A", "4", True),   # Wrong: 8*4=32
            ("B", "5", False),  # Correct: 8*5=40
            ("C", "6", False),
            ("D", "8", False),
        ],
        answer="A",
        explanation="Divide both sides of the equation by 8 to find x = 4.",
    )

    validated = validate_and_sanitize_question(flawed_q)
    assert validated is not None
    assert validated.answer == "B"
    correct_opt = next(o for o in validated.options if o.key == "B")
    assert correct_opt.is_correct is True
    wrong_opt = next(o for o in validated.options if o.key == "A")
    assert wrong_opt.is_correct is False
    assert "5" in validated.explanation


def test_auto_correct_2_times_x_plus_3_equals_16():
    """Matches the exact issue in user screenshot where 2(x + 3) = 16 had option D (x = 2) marked correct instead of B (x = 5)."""
    flawed_q = _mcq(
        body="What is the solution to the equation 2(x + 3) = 16?",
        options=[
            ("A", "x = 4", False),
            ("B", "x = 5", False),  # Correct
            ("C", "x = 8", False),
            ("D", "x = 2", True),   # Wrong
        ],
        answer="D",
        explanation="To solve, divide both sides by 2 to get x + 3 = 8. Then subtract 3 from both sides results in x = 5.",
    )

    validated = validate_and_sanitize_question(flawed_q)
    assert validated is not None
    assert validated.answer == "B"
    assert next(o for o in validated.options if o.key == "B").is_correct is True
    assert next(o for o in validated.options if o.key == "D").is_correct is False


def test_reject_when_no_option_satisfies_equation():
    flawed_q = _mcq(
        body="What is the value of x in the equation 8x = 40?",
        options=[
            ("A", "1", True),
            ("B", "2", False),
            ("C", "3", False),
            ("D", "4", False),
        ],
        answer="A",
        explanation="No option is actually 5.",
    )

    validated = validate_and_sanitize_question(flawed_q)
    assert validated is None


def test_rubric_cross_referencing():
    chunk = RetrievedChunk(
        chunk_id="chk_rubric",
        chunk_index=0,
        document_id="doc_rubric",
        text="Worksheet Answers:\n55. x = 5\n56. x = -6\n",
        topic_ids=["tpc_math"],
        score=1.0,
    )
    flawed_q = _mcq(
        body="Problem 55: What is the solution to 8x = 40?",
        options=[
            ("A", "4", True),
            ("B", "5", False),
            ("C", "6", False),
            ("D", "8", False),
        ],
        answer="A",
        explanation="Problem 55 solution.",
    )

    validated = validate_and_sanitize_question(flawed_q, grounding_chunks=[chunk])
    assert validated is not None
    assert validated.answer == "B"
