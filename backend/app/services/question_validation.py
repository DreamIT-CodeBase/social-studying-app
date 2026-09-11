"""Question accuracy validation service.

Provides deterministic mathematical / algebraic verification,
rubric / answer key cross-referencing, and explanation consistency checks.
Auto-corrects minor option-assignment errors (e.g. correct value present in
options but wrong option key marked true) and rejects flawed questions.
"""

from __future__ import annotations

import ast
import logging
import operator
import re
from typing import TYPE_CHECKING, Any

from app.mcp_tools.retrieve_content import RetrievedChunk
from app.models.question import McqOption, QuestionType

if TYPE_CHECKING:
    from app.services.question_generation import GeneratedQuestion

logger = logging.getLogger(__name__)

# Supported AST operators for safe arithmetic evaluation
_SAFE_OPERATORS: dict[type, Any] = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.Pow: operator.pow,
    ast.USub: operator.neg,
    ast.UAdd: operator.pos,
}


def _safe_eval_node(node: ast.AST, var_name: str, var_val: float) -> float:
    """Recursively evaluate an AST node containing only safe math operations and variables."""
    if isinstance(node, ast.Constant):
        if isinstance(node.value, (int, float)):
            return float(node.value)
        raise ValueError(f"Unsupported constant type: {type(node.value)}")
    if isinstance(node, ast.Name):
        if node.id.lower() == var_name.lower():
            return var_val
        raise ValueError(f"Unknown variable in expression: {node.id}")
    if isinstance(node, ast.UnaryOp):
        op_type = type(node.op)
        if op_type in _SAFE_OPERATORS:
            operand = _safe_eval_node(node.operand, var_name, var_val)
            return float(_SAFE_OPERATORS[op_type](operand))
        raise ValueError(f"Unsupported unary operator: {op_type}")
    if isinstance(node, ast.BinOp):
        op_type = type(node.op)
        if op_type in _SAFE_OPERATORS:
            left = _safe_eval_node(node.left, var_name, var_val)
            right = _safe_eval_node(node.right, var_name, var_val)
            if op_type in (ast.Div, ast.FloorDiv, ast.Mod) and abs(right) < 1e-9:
                raise ZeroDivisionError("Division by zero in equation evaluation")
            return float(_SAFE_OPERATORS[op_type](left, right))
        raise ValueError(f"Unsupported binary operator: {op_type}")
    raise ValueError(f"Unsupported AST node: {type(node)}")


def _preprocess_math_expr(expr: str) -> str:
    """Transform standard math notation to Python expression syntax.
    
    e.g. '8x' -> '8*x', '2(x + 3)' -> '2*(x + 3)', 'x/3' -> 'x/3'
    """
    clean = expr.strip()
    # Normalize unicode minus or division symbols
    clean = clean.replace("–", "-").replace("—", "-").replace("×", "*").replace("÷", "/")
    # 8x -> 8*x
    clean = re.sub(r"(\d+)\s*([a-zA-Z])", r"\1*\2", clean)
    # x8 -> x*8 (rare, but handle)
    clean = re.sub(r"([a-zA-Z])\s*(\d+)", r"\1*\2", clean)
    # 2( -> 2*(
    clean = re.sub(r"(\d+)\s*\(", r"\1*(", clean)
    # )x or )2 -> )*x or )*2
    clean = re.sub(r"\)\s*([a-zA-Z0-9])", r")*\1", clean)
    # )( -> )*(
    clean = re.sub(r"\)\s*\(", r")*(", clean)
    return clean


def safe_evaluate_math_expr(expr: str, var_name: str, var_val: float) -> float | None:
    """Safely parse and evaluate a single math expression for a given variable value."""
    try:
        prep = _preprocess_math_expr(expr)
        tree = ast.parse(prep, mode="eval")
        return _safe_eval_node(tree.body, var_name, var_val)
    except Exception:
        return None


def extract_equation(text: str) -> tuple[str, str, str] | None:
    """Extract (var_name, lhs, rhs) from a question stem containing an equation.

    Examples:
    - 'What is the value of x in the equation 8x = 40?' -> ('x', '8x', '40')
    - 'What is the solution to the equation 2(x + 3) = 16?' -> ('x', '2(x + 3)', '16')
    - 'Solve: x / 3 = -2' -> ('x', 'x / 3', '-2')
    """
    if "=" not in text:
        return None

    # Find each '=' in text
    for eq_match in re.finditer(r"=", text):
        eq_idx = eq_match.start()
        left_sub = text[:eq_idx]
        right_sub = text[eq_idx + 1:]

        # Walk backward from '=' to extract LHS math tokens
        # Stop at word boundaries of words with length > 1 (English words like 'equation', 'solve', etc.)
        lhs_chars: list[str] = []
        for word in reversed(left_sub.split()):
            w = word.strip("?.!,;:()")
            if len(w) > 1 and w.isalpha():
                break
            lhs_chars.insert(0, word)

        lhs_str = " ".join(lhs_chars).strip()
        # Clean leading non-math characters
        lhs_str = re.sub(r"^[^a-zA-Z0-9\(\+\-]+", "", lhs_str).strip()

        # Walk forward from '=' to extract RHS math tokens
        # Stop at English words, punctuation like ?, !, ;, etc.
        rhs_chars: list[str] = []
        for word in right_sub.split():
            clean_word = word.rstrip("?.!,;:")
            if len(clean_word) > 1 and clean_word.isalpha():
                break
            rhs_chars.append(clean_word)
            if any(p in word for p in ("?", "!", ";")):
                break

        rhs_str = " ".join(rhs_chars).strip()
        rhs_str = re.sub(r"[^a-zA-Z0-9\)\+\-]+$", "", rhs_str).strip()

        if not lhs_str or not rhs_str:
            continue

        # Look for single-letter variables in LHS and RHS
        lhs_vars = re.findall(r"\b([a-zA-Z])\b", lhs_str)
        # Also catch variables attached to numbers, like 8x
        lhs_attached_vars = re.findall(r"\d+([a-zA-Z])", lhs_str)
        all_lhs_vars = set(lhs_vars + lhs_attached_vars)

        rhs_vars = re.findall(r"\b([a-zA-Z])\b", rhs_str)
        rhs_attached_vars = re.findall(r"\d+([a-zA-Z])", rhs_str)
        all_rhs_vars = set(rhs_vars + rhs_attached_vars)

        all_vars = (all_lhs_vars | all_rhs_vars)
        valid_vars = [v for v in all_vars if v.lower() in ("x", "y", "z", "n", "m", "t", "a", "b", "c", "k", "p", "r")]

        if len(valid_vars) == 1:
            var_name = valid_vars[0]
            # Ensure both sides can be evaluated safely
            if safe_evaluate_math_expr(lhs_str, var_name, 1.0) is not None and \
               safe_evaluate_math_expr(rhs_str, var_name, 1.0) is not None:
                return var_name, lhs_str, rhs_str

    return None


def parse_candidate_value(text: str) -> float | None:
    """Extract numeric value from option text like 'x = 5', '5', '-6', 'x = -2.5'."""
    clean = text.strip()
    # Match 'x = 5' or 'x = -5.2'
    m_eq = re.search(r"=\s*([+-]?\d+(?:\.\d+)?)", clean)
    if m_eq:
        try:
            return float(m_eq.group(1))
        except ValueError:
            pass

    # Match raw number at start or end of text
    m_num = re.search(r"^([+-]?\d+(?:\.\d+)?)$", clean)
    if m_num:
        try:
            return float(m_num.group(1))
        except ValueError:
            pass

    # Match number anywhere in short option text
    m_any = re.search(r"([+-]?\d+(?:\.\d+)?)", clean)
    if m_any:
        try:
            return float(m_any.group(1))
        except ValueError:
            pass

    return None


def _check_equation_satisfaction(lhs: str, rhs: str, var_name: str, val: float) -> bool:
    """Return True if val satisfies lhs = rhs within float tolerance."""
    lhs_res = safe_evaluate_math_expr(lhs, var_name, val)
    rhs_res = safe_evaluate_math_expr(rhs, var_name, val)
    if lhs_res is None or rhs_res is None:
        return False
    return abs(lhs_res - rhs_res) < 1e-5


def _extract_rubric_solutions(grounding_chunks: list[RetrievedChunk]) -> dict[str, str]:
    """Extract problem-number-to-answer mappings from rubric / answer key chunks.
    
    e.g. '55. x = 5', '56. x = -6', '41. x = 2' -> {'55': '5', '56': '-6', '41': '2'}
    """
    solutions: dict[str, str] = {}
    for chunk in grounding_chunks:
        text = chunk.text
        # Look for patterns like '55. x = 5' or '55. 5' or '55: x = 5'
        matches = re.finditer(r"(?:^|\s)(\d{1,3})\s*[\.:]\s*(?:[a-zA-Z]\s*=\s*)?([+-]?\d+(?:\.\d+)?)", text)
        for m in matches:
            prob_num = m.group(1)
            val = m.group(2)
            solutions[prob_num] = val
    return solutions


def validate_and_sanitize_question(
    gq: GeneratedQuestion,
    grounding_chunks: list[RetrievedChunk] | None = None,
) -> GeneratedQuestion | None:
    """Validate a generated question for mathematical, factual, and structural correctness.
    
    If the question has a minor option-assignment flaw (e.g. LLM marked option A as
    correct when option B is mathematically correct for the equation), this function
    repairs it.
    If the question is unfixable, contradictory, or lacks a valid answer, returns None.
    """
    if not gq.body or not gq.body.strip():
        return None

    # 1. Structural checks for MCQ
    if gq.question_type == QuestionType.mcq:
        if len(gq.options) != 4:
            return None
        option_keys = [opt.key for opt in gq.options]
        if option_keys != ["A", "B", "C", "D"]:
            return None

        # Check option texts are not duplicates
        norm_texts = [opt.text.strip().lower() for opt in gq.options]
        if len(set(norm_texts)) != 4:
            return None

        # Check if question has an algebraic equation
        eq_info = extract_equation(gq.body)
        if eq_info is not None:
            var_name, lhs, rhs = eq_info
            logger.debug("Validating equation %s: %s = %s", var_name, lhs, rhs)

            # Test each option against the equation
            valid_keys: list[str] = []
            for opt in gq.options:
                val = parse_candidate_value(opt.text)
                if val is not None and _check_equation_satisfaction(lhs, rhs, var_name, val):
                    valid_keys.append(opt.key)

            if len(valid_keys) == 1:
                correct_key = valid_keys[0]
                correct_opt = next(o for o in gq.options if o.key == correct_key)
                correct_val = parse_candidate_value(correct_opt.text)

                # Check if question currently has the wrong answer marked
                current_marked = [o.key for o in gq.options if o.is_correct]
                if current_marked != [correct_key] or gq.answer != correct_key:
                    logger.warning(
                        "Auto-correcting question equation '%s = %s': changing correct answer from %s to %s (%s)",
                        lhs, rhs, gq.answer, correct_key, correct_opt.text
                    )
                    new_options = [
                        McqOption(
                            key=o.key,
                            text=o.text,
                            is_correct=(o.key == correct_key),
                        )
                        for o in gq.options
                    ]
                    # Update explanation to guarantee it states the verified answer
                    clean_val_str = f"{int(correct_val)}" if correct_val is not None and correct_val.is_integer() else str(correct_val)
                    new_explanation = (
                        f"Solving the equation {lhs} = {rhs} gives {var_name} = {clean_val_str}. "
                        f"Substituting {var_name} = {clean_val_str} into the equation confirms {lhs} = {rhs}."
                    )
                    return gq.__class__(
                        body=gq.body,
                        answer=correct_key,
                        explanation=new_explanation,
                        question_type=gq.question_type,
                        difficulty=gq.difficulty,
                        prompt_version=gq.prompt_version,
                        options=new_options,
                        grading_hints=gq.grading_hints,
                    )
            elif len(valid_keys) == 0:
                logger.warning(
                    "Rejecting question: no option satisfies equation '%s = %s' in body '%s'",
                    lhs, rhs, gq.body
                )
                return None
            else:
                logger.warning(
                    "Rejecting question: multiple options %s satisfy equation '%s = %s'",
                    valid_keys, lhs, rhs
                )
                return None

        # Cross-reference with rubric if available
        if grounding_chunks:
            rubric_solutions = _extract_rubric_solutions(grounding_chunks)
            if rubric_solutions:
                # Check if question mentions a problem number like '#55' or '55.' or 'Problem 55'
                prob_match = re.search(r"(?:problem|question|#)\s*(\d{1,3})", gq.body, re.IGNORECASE)
                if prob_match:
                    prob_num = prob_match.group(1)
                    if prob_num in rubric_solutions:
                        expected_val_str = rubric_solutions[prob_num]
                        try:
                            expected_val = float(expected_val_str)
                            # Verify if marked answer matches rubric
                            marked_opt = next((o for o in gq.options if o.is_correct), None)
                            marked_val = parse_candidate_value(marked_opt.text) if marked_opt else None
                            if marked_val is not None and abs(marked_val - expected_val) > 1e-5:
                                # Look for the option that matches expected rubric value
                                matching_opts = [
                                    o for o in gq.options
                                    if parse_candidate_value(o.text) is not None
                                    and abs(parse_candidate_value(o.text) - expected_val) < 1e-5
                                ]
                                if len(matching_opts) == 1:
                                    correct_opt = matching_opts[0]
                                    logger.warning(
                                        "Aligning question problem #%s with rubric answer %s: changing to %s",
                                        prob_num, expected_val_str, correct_opt.key
                                    )
                                    new_options = [
                                        McqOption(key=o.key, text=o.text, is_correct=(o.key == correct_opt.key))
                                        for o in gq.options
                                    ]
                                    return gq.__class__(
                                        body=gq.body,
                                        answer=correct_opt.key,
                                        explanation=f"According to the solution rubric, the correct answer for problem {prob_num} is {correct_opt.text}.",
                                        question_type=gq.question_type,
                                        difficulty=gq.difficulty,
                                        prompt_version=gq.prompt_version,
                                        options=new_options,
                                        grading_hints=gq.grading_hints,
                                    )
                                else:
                                    return None
                        except ValueError:
                            pass

        # Check for blatant contradiction between explanation and marked answer
        # e.g. explanation says "x = 5" or "answer is B" but answer is "D" ("x = 2")
        marked_opt = next((o for o in gq.options if o.is_correct), None)
        if marked_opt:
            marked_val = parse_candidate_value(marked_opt.text)
            # Check if explanation concludes with another option's value
            for opt in gq.options:
                if opt.key != marked_opt.key:
                    opt_val = parse_candidate_value(opt.text)
                    if opt_val is not None and marked_val is not None and abs(opt_val - marked_val) > 1e-5:
                        clean_opt_val = f"{int(opt_val)}" if opt_val.is_integer() else str(opt_val)
                        clean_marked_val = f"{int(marked_val)}" if marked_val.is_integer() else str(marked_val)
                        # If explanation says 'results in x = <opt_val>' or 'x = <opt_val>' but NOT marked_val
                        concl_pattern = rf"(?:results in|to find|gives|solution is)\s*x\s*=\s*{re.escape(clean_opt_val)}\b"
                        if re.search(concl_pattern, gq.explanation, re.IGNORECASE) and not re.search(rf"x\s*=\s*{re.escape(clean_marked_val)}\b", gq.explanation):
                            logger.warning(
                                "Explanation contradiction detected: explanation derives x = %s, but marked answer was %s (x = %s). Auto-correcting to %s.",
                                clean_opt_val, marked_opt.key, clean_marked_val, opt.key
                            )
                            new_options = [
                                McqOption(key=o.key, text=o.text, is_correct=(o.key == opt.key))
                                for o in gq.options
                            ]
                            return gq.__class__(
                                body=gq.body,
                                answer=opt.key,
                                explanation=gq.explanation,
                                question_type=gq.question_type,
                                difficulty=gq.difficulty,
                                prompt_version=gq.prompt_version,
                                options=new_options,
                                grading_hints=gq.grading_hints,
                            )

    # 2. General validation for non-MCQ mathematical questions
    elif gq.question_type == QuestionType.mathematical:
        eq_info = extract_equation(gq.body)
        if eq_info is not None:
            var_name, lhs, rhs = eq_info
            ans_val = parse_candidate_value(gq.answer)
            if ans_val is not None:
                if not _check_equation_satisfaction(lhs, rhs, var_name, ans_val):
                    logger.warning(
                        "Rejecting mathematical question: answer %s does not satisfy %s = %s",
                        gq.answer, lhs, rhs
                    )
                    return None

    # Must have exactly 1 correct answer for MCQ
    if gq.question_type == QuestionType.mcq:
        correct_count = sum(1 for o in gq.options if o.is_correct)
        if correct_count != 1:
            return None
        if gq.answer != next(o.key for o in gq.options if o.is_correct):
            return None

    return gq
