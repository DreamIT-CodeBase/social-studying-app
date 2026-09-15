"""Comprehensive validation and accuracy tests for the Algebra 1 study material

Covers:
- Part A: One-Step Equations
- Part B: Multiplication & Division Equations
- Part C: Two-Step Equations
- Part D: Distributive Property Equations
- Part E: Variables on Both Sides
- Part F: Mixed Algebra 1 Equations
- Complete Answer Key (pages 12–13) cross-referencing & rubric extraction
- Advanced Topics: Calculus derivatives, indefinite & definite integrals, trigonometry
"""

import pytest

from app.mcp_tools.retrieve_content import RetrievedChunk
from app.models.question import DifficultyLevel, McqOption, QuestionType
from app.services.question_generation import GeneratedQuestion
from app.services.question_validation import (
    extract_equation,
    validate_and_sanitize_question,
)


def _mcq(
    body: str,
    options: list[tuple[str, str, bool]],
    answer: str,
    explanation: str = "Explanation",
) -> GeneratedQuestion:
    return GeneratedQuestion(
        body=body,
        answer=answer,
        explanation=explanation,
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.intermediate,
        prompt_version="question_batch_v1",
        options=[McqOption(key=k, text=t, is_correct=c) for k, t, c in options],
    )


def _math_q(body: str, answer: str) -> GeneratedQuestion:
    return GeneratedQuestion(
        body=body,
        answer=answer,
        explanation="Mathematical explanation",
        question_type=QuestionType.mathematical,
        difficulty=DifficultyLevel.intermediate,
        prompt_version="question_batch_v1",
    )


# ── 1. Testing Equations across all parts of the Algebra 1 Study Material ───────

@pytest.mark.parametrize(
    ("problem_text", "expected_var", "expected_val"),
    [
        # Part A — One-Step Equations
        ("1. x + 9 = 32", "x", 23.0),
        ("5. x + 12 = -2", "x", -14.0),
        ("10. x + 4 = -4", "x", -8.0),
        ("18. x + 16 = 18", "x", 2.0),
        ("21. x - 18 = -27", "x", -9.0),
        ("24. x - 8 = -6", "x", 2.0),
        ("33. x - 16 = 0", "x", 16.0),
        ("40. x - 13 = 7", "x", 20.0),
        # Part B — Multiplication & Division Equations
        ("41. 9x = 18", "x", 2.0),
        ("45. 9x = -99", "x", -11.0),
        ("55. 8x = 40", "x", 5.0),
        ("56. x / 3 = -2", "x", -6.0),
        ("58. x / 6 = -9", "x", -54.0),
        ("61. x / 6 = -10", "x", -60.0),
        ("71. -4x + 6 = 18", "x", -3.0),
        ("80. -9x - 3 = 15", "x", -2.0),
        # Part C — Two-Step Equations
        ("81. -5x - 4 = -84", "x", 16.0),
        ("84. 9x - 6 = 147", "x", 17.0),
        ("96. 9x - 2 = 169", "x", 19.0),
        ("101. 1x - 2 = 3", "x", 5.0),
        ("116. 8x + 2 = 114", "x", 14.0),
        ("120. 7x - 14 = 119", "x", 19.0),
        # Part D — Distributive Property Equations
        ("121. 3(x - 4) = 9", "x", 7.0),
        ("122. 6(x - 1) = 84", "x", 15.0),
        ("130. 3(x + 3) = 0", "x", -3.0),
        ("136. 6(x + 4) = -24", "x", -8.0),
        ("146. 4(x - 8) = -72", "x", -10.0),
        ("150. 5(x - 5) = 25", "x", 10.0),
        # Part E — Variables on Both Sides
        ("151. 5x + 7 = 3x - 5", "x", -6.0),
        ("157. 4x - 2 = 5x + 4", "x", -6.0),
        ("161. 8x + 2 = 3x + 32", "x", 6.0),
        ("168. 7x + 9 = 5x + 33", "x", 12.0),
        ("174. 2x + 0 = 3x - 12", "x", 12.0),
        ("180. 4x + 12 = 1x + 30", "x", 6.0),
        # Part F — Mixed Algebra 1 Equations
        ("181. 2(x + 1) - 3 = 23", "x", 12.0),
        ("182. 3(x - 3) + 1 = 10", "x", 6.0),
        ("184. 5(x + 6) + 1 = -4", "x", -7.0),
        ("185. 4(x + 5) - 10 = 50", "x", 10.0),
        ("191. 4x + 7 = 1x + 40", "x", 11.0),
        ("196. 3x - 4 = 2x - 5", "x", -1.0),
        ("200. 5x + 0 = 3x + 20", "x", 10.0),
    ],
)
def test_study_material_equations_extraction_and_solution(problem_text, expected_var, expected_val):
    eq = extract_equation(problem_text)
    assert eq is not None, f"Failed to extract equation from {problem_text}"
    var_name, lhs, rhs = eq
    assert var_name == expected_var

    # Validate with validation helper
    from app.services.question_validation import _check_equation_satisfaction
    assert _check_equation_satisfaction(lhs, rhs, var_name, expected_val) is True


# ── 2. Testing MCQ Auto-Correction on Study Material Equations ───────────────────

def test_auto_correct_study_material_part_c_problem_81():
    """Problem 81: -5x - 4 = -84. Solution is x = 16.

    Simulate LLM miskeying option A (12) instead of C (16).
    """
    gq = _mcq(
        body="Solve problem 81: -5x - 4 = -84",
        options=[
            ("A", "x = 12", True),  # LLM erroneously marked A
            ("B", "x = 14", False),
            ("C", "x = 16", False),  # Mathematically correct
            ("D", "x = 18", False),
        ],
        answer="A",
        explanation="Solving gives x = 12.",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "C"
    assert next(o for o in validated.options if o.key == "C").is_correct is True
    assert next(o for o in validated.options if o.key == "A").is_correct is False
    assert "16" in validated.explanation


def test_auto_correct_study_material_part_d_problem_121():
    """Problem 121: 3(x - 4) = 9. Solution is x = 7."""
    gq = _mcq(
        body="What is the solution to 121. 3(x - 4) = 9?",
        options=[
            ("A", "x = 5", False),
            ("B", "x = 6", False),
            ("C", "x = 7", False),  # Correct
            ("D", "x = 8", True),   # LLM miskeyed
        ],
        answer="D",
        explanation="Divide by 3 to get x - 4 = 3, so x = 8.",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "C"
    assert next(o for o in validated.options if o.key == "C").is_correct is True


def test_auto_correct_study_material_part_e_problem_151():
    """Problem 151: 5x + 7 = 3x - 5. Solution is x = -6."""
    gq = _mcq(
        body="Solve for x: 5x + 7 = 3x - 5",
        options=[
            ("A", "x = -6", False),  # Correct
            ("B", "x = -4", False),
            ("C", "x = 4", False),
            ("D", "x = 6", True),   # Wrong
        ],
        answer="D",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "A"


def test_auto_correct_study_material_part_f_problem_181():
    """Problem 181: 2(x + 1) - 3 = 23. Solution is x = 12."""
    gq = _mcq(
        body="Find the value of x in 181. 2(x + 1) - 3 = 23",
        options=[
            ("A", "x = 10", False),
            ("B", "x = 12", False),  # Correct
            ("C", "x = 14", True),   # Wrong
            ("D", "x = 16", False),
        ],
        answer="C",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "B"


def test_reject_study_material_when_no_valid_option_exists():
    """If no option satisfies the equation from the study material, reject it."""
    gq = _mcq(
        body="Solve problem 56: x / 3 = -2",
        options=[
            ("A", "x = -4", True),
            ("B", "x = -2", False),
            ("C", "x = 2", False),
            ("D", "x = 6", False),
        ],
        answer="A",
    )
    assert validate_and_sanitize_question(gq) is None


# ── 3. Testing Complete Answer Key Rubric Integration ───────────────────────────

def test_rubric_answer_key_alignment_from_pages_12_and_13():
    """Simulate retrieval of chunks from the Complete Answer Key (pages 12 & 13)."""
    page_12_text = (
        "COMPLETE ANSWER KEY\n"
        "1. x = 23  2. x = 22  3. x = 16  4. x = 0  5. x = -14\n"
        "81. x = 16  82. x = 13  83. x = 4  84. x = 17  85. x = 1\n"
        "111. x = 14 112. x = 4 113. x = -2 114. x = 8 115. x = 11\n"
    )
    page_13_text = (
        "121. x = 7  122. x = 15 123. x = 2 124. x = -3 125. x = 6\n"
        "181. x = 12 182. x = 6  183. x = 9 184. x = -7 185. x = 10\n"
        "200. x = 10\n"
    )
    chunks = [
        RetrievedChunk(
            chunk_id="c1",
            chunk_index=0,
            document_id="d1",
            text=page_12_text,
            topic_ids=["tpc_math"],
            score=1.0,
        ),
        RetrievedChunk(
            chunk_id="c2",
            chunk_index=1,
            document_id="d1",
            text=page_13_text,
            topic_ids=["tpc_math"],
            score=1.0,
        ),
    ]

    # Question referencing problem 121
    gq = _mcq(
        body="What is the answer to Problem 121: 3(x - 4) = 9?",
        options=[
            ("A", "x = 5", True),  # LLM erroneously marked A
            ("B", "x = 7", False), # Rubric says 7
            ("C", "x = 9", False),
            ("D", "x = 11", False),
        ],
        answer="A",
    )

    validated = validate_and_sanitize_question(gq, grounding_chunks=chunks)
    assert validated is not None
    assert validated.answer == "B"


# ── 4. Advanced Topics: Calculus Derivatives & Integrals ────────────────────────

def test_calculus_derivative_mcq_auto_correction():
    """Auto-correct when LLM miskeys derivative option."""
    gq = _mcq(
        body="What is the derivative of f(x) = x^3 - 4x + 5?",
        options=[
            ("A", "3x^2 - 4", False),  # Correct derivative
            ("B", "3x^2 + 4", False),
            ("C", "x^2 - 4", False),
            ("D", "3x - 4", True),     # Miskeyed
        ],
        answer="D",
        explanation="The derivative is 3x - 4.",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "A"
    assert next(o for o in validated.options if o.key == "A").is_correct is True
    assert next(o for o in validated.options if o.key == "D").is_correct is False
    assert "derivative" in validated.explanation.lower()


def test_calculus_trigonometric_derivative_mcq():
    """Verify derivative of trig function with chain rule."""
    gq = _mcq(
        body="Find d/dx [sin(2x)]",
        options=[
            ("A", "cos(2x)", False),
            ("B", "2*cos(2x)", True),  # Correct
            ("C", "-2*cos(2x)", False),
            ("D", "2*sin(2x)", False),
        ],
        answer="B",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "B"


def test_calculus_indefinite_integral_mcq_auto_correction():
    """Auto-correct indefinite integral with constant of integration."""
    gq = _mcq(
        body="Find the indefinite integral of 3x^2 + 2x dx",
        options=[
            ("A", "6x + 2 + C", True),  # LLM erroneously gave derivative instead of integral
            ("B", "x^3 + x^2 + C", False),  # Correct integral
            ("C", "3x^3 + 2x^2 + C", False),
            ("D", "x^3 + 2x + C", False),
        ],
        answer="A",
        explanation="Integrate to get 6x + 2.",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "B"
    assert next(o for o in validated.options if o.key == "B").is_correct is True


def test_calculus_definite_integral_mcq():
    """Verify definite integral calculation."""
    gq = _mcq(
        body="Evaluate the definite integral from 0 to 2 of 3x^2 dx",
        options=[
            ("A", "6", False),
            ("B", "8", True),   # Correct: [x^3]_0^2 = 8
            ("C", "12", False),
            ("D", "16", False),
        ],
        answer="B",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "B"


def test_trigonometric_simplification_mcq():
    """Verify trigonometric identity simplification."""
    gq = _mcq(
        body="Simplify the trigonometric expression: sin^2(x) + cos^2(x)",
        options=[
            ("A", "0", False),
            ("B", "1", False),  # Correct
            ("C", "2", True),   # LLM miskeyed
            ("D", "tan(x)", False),
        ],
        answer="C",
    )

    validated = validate_and_sanitize_question(gq)
    assert validated is not None
    assert validated.answer == "B"


def test_calculus_rejection_when_options_are_flawed():
    """Reject question when none of the options are correct."""
    gq = _mcq(
        body="What is the derivative of f(x) = x^3 - 4x + 5?",
        options=[
            ("A", "10x", True),
            ("B", "x^2", False),
            ("C", "4", False),
            ("D", "0", False),
        ],
        answer="A",
    )
    assert validate_and_sanitize_question(gq) is None


# ── 5. Testing QuestionType.mathematical Direct Answer Validation ───────────────

def test_direct_mathematical_derivative():
    valid_q = _math_q(
        body="What is the derivative of f(x) = x^3 - 4x + 5?",
        answer="3x^2 - 4",
    )
    assert validate_and_sanitize_question(valid_q) is not None

    invalid_q = _math_q(
        body="What is the derivative of f(x) = x^3 - 4x + 5?",
        answer="3x^2 + 4",  # Wrong sign
    )
    assert validate_and_sanitize_question(invalid_q) is None


def test_direct_mathematical_indefinite_integral():
    valid_q = _math_q(
        body="Find the indefinite integral of 3x^2 + 2x dx",
        answer="x^3 + x^2 + C",
    )
    assert validate_and_sanitize_question(valid_q) is not None

    invalid_q = _math_q(
        body="Find the indefinite integral of 3x^2 + 2x dx",
        answer="6x + 2",  # Derivative instead of integral
    )
    assert validate_and_sanitize_question(invalid_q) is None


def test_direct_mathematical_equation_from_study_material():
    valid_q = _math_q(
        body="Solve 181. 2(x + 1) - 3 = 23",
        answer="x = 12",
    )
    assert validate_and_sanitize_question(valid_q) is not None

    invalid_q = _math_q(
        body="Solve 181. 2(x + 1) - 3 = 23",
        answer="x = 99",
    )
    assert validate_and_sanitize_question(invalid_q) is None
