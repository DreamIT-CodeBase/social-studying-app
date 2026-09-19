"""Symbolic mathematics engine for the validation and answer evaluation pipeline.

Leverages SymPy for deterministic evaluation of:
- Derivatives: d/dx f(x), f'(x)
- Indefinite integrals: ∫ f(x) dx (handles arbitrary constants of integration)
- Definite integrals: ∫_a^b f(x) dx
- Trigonometric expressions & identities
- Algebraic equations & solution verification
- Symbolic expression equivalence
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass

import sympy
from sympy.parsing.sympy_parser import (
    convert_xor,
    implicit_multiplication_application,
    parse_expr,
    standard_transformations,
)

logger = logging.getLogger(__name__)

# Standard parser transformations enabling implicit multiplication (e.g. 2x, 3(x+1))
# and treating ^ as exponentiation
_TRANSFORMATIONS = standard_transformations + (
    implicit_multiplication_application,
    convert_xor,
)


@dataclass(frozen=True, slots=True)
class CalculusProblem:
    """Parsed calculus or advanced mathematical problem from question text."""

    problem_type: str  # 'derivative', 'indefinite_integral', 'definite_integral', 'trig_identity', 'algebraic_equation'
    variable: str  # 'x', 't', 'theta', etc.
    expression: str
    lower_limit: str | None = None
    upper_limit: str | None = None


def clean_math_text(text: str) -> str:
    """Normalize LaTeX and plain-text math notation into standard SymPy syntax."""
    if not text:
        return ""
    clean = text.strip()
    # Strip enclosing LaTeX delimiters: $...$, \(...\), \[...\]
    clean = re.sub(r"^\$+(.*?)\$+$", r"\1", clean).strip()
    clean = re.sub(r"^\\\((.*?)\\\)$", r"\1", clean).strip()
    clean = re.sub(r"^\\\[(.*?)\\\]$", r"\1", clean).strip()

    # Normalize unicode symbols
    clean = (
        clean.replace("–", "-")
        .replace("—", "-")
        .replace("−", "-")
        .replace("×", "*")
        .replace("÷", "/")
        .replace("·", "*")
        .replace("π", "pi")
        .replace("θ", "theta")
    )

    # Standard LaTeX replacements
    clean = re.sub(r"\\frac\{([^}]+)\}\{([^}]+)\}", r"((\1)/(\2))", clean)
    clean = re.sub(r"\\sqrt\{([^}]+)\}", r"sqrt(\1)", clean)
    clean = re.sub(r"\\left\(", "(", clean)
    clean = re.sub(r"\\right\)", ")", clean)
    clean = clean.replace(r"\cdot", "*").replace(r"\times", "*")
    clean = (
        clean.replace(r"\sin", "sin")
        .replace(r"\cos", "cos")
        .replace(r"\tan", "tan")
        .replace(r"\sec", "sec")
        .replace(r"\csc", "csc")
        .replace(r"\cot", "cot")
        .replace(r"\ln", "ln")
        .replace(r"\log", "log")
        .replace(r"\exp", "exp")
        .replace(r"\pi", "pi")
        .replace(r"\theta", "theta")
    )

    # Normalize dx, dt, dtheta at the end of integrands if attached
    clean = re.sub(r"\s*d[a-zA-Z]\s*$", "", clean)

    # Convert ^ to **
    clean = clean.replace("^", "**")

    return clean.strip()


def parse_symbolic_expression(expr_str: str) -> sympy.Expr | None:
    """Safely parse a mathematical expression string into a SymPy expression.

    Returns None if the string cannot be parsed as valid math.
    """
    cleaned = clean_math_text(expr_str)
    if not cleaned:
        return None
    try:
        # Pre-filter any non-math keywords that could cause issues
        return parse_expr(cleaned, transformations=_TRANSFORMATIONS, evaluate=True)
    except Exception:
        try:
            # Fallback: remove explicit spaces around operators and retry
            compact = re.sub(r"\s*([\+\-\*/])\s*", r"\1", cleaned)
            return parse_expr(compact, transformations=_TRANSFORMATIONS, evaluate=True)
        except Exception:
            return None


def are_expressions_equivalent(
    expr1_str: str,
    expr2_str: str,
    var_str: str = "x",
) -> bool:
    """Return True if two math expressions are symbolically equivalent.

    Tests algebraic simplification, polynomial expansion, trigonometric
    simplification, and handles constant of integration differences for antiderivatives.
    """
    e1 = parse_symbolic_expression(expr1_str)
    e2 = parse_symbolic_expression(expr2_str)
    if e1 is None or e2 is None:
        return False

    # Direct identity check
    if e1 == e2:
        return True

    # 1. Algebraic & trigonometric simplification of difference
    try:
        diff = e1 - e2
        if sympy.simplify(diff) == 0:
            return True
        if sympy.trigsimp(diff) == 0:
            return True
        if sympy.expand(diff) == 0:
            return True
        if sympy.factor(diff) == 0:
            return True
        if e1.equals(e2) is True:
            return True
    except Exception:
        pass

    # 2. Check if expressions differ only by an arbitrary constant (e.g. + C vs + c vs no constant)
    free1 = {s.name for s in e1.free_symbols}
    free2 = {s.name for s in e2.free_symbols}
    has_c = bool({"C", "c"}.intersection(free1 | free2))
    if has_c:
        try:
            var = sympy.Symbol(var_str)
            # If the derivative of the difference with respect to var is 0,
            # the two expressions represent the same antiderivative family!
            diff_wrt_var = sympy.diff(e1 - e2, var)
            if sympy.simplify(diff_wrt_var) == 0 or sympy.trigsimp(diff_wrt_var) == 0:
                return True
        except Exception:
            pass

    return False


def compute_derivative(expr_str: str, var_str: str = "x") -> sympy.Expr | None:
    """Compute the symbolic derivative d/d(var) [expr]."""
    e = parse_symbolic_expression(expr_str)
    if e is None:
        return None
    try:
        var = sympy.Symbol(var_str)
        return sympy.diff(e, var)
    except Exception:
        return None


def check_derivative(
    problem_expr_str: str,
    var_str: str,
    candidate_str: str,
) -> bool:
    """Check if candidate_str is the correct derivative of problem_expr_str."""
    expected = compute_derivative(problem_expr_str, var_str)
    if expected is None:
        return False
    candidate = parse_symbolic_expression(candidate_str)
    if candidate is None:
        return False

    try:
        diff = expected - candidate
        if sympy.simplify(diff) == 0 or sympy.trigsimp(diff) == 0 or expected.equals(candidate) is True:
            return True
    except Exception:
        pass
    return False


def compute_indefinite_integral(expr_str: str, var_str: str = "x") -> sympy.Expr | None:
    """Compute the symbolic indefinite integral ∫ expr d(var)."""
    e = parse_symbolic_expression(expr_str)
    if e is None:
        return None
    try:
        var = sympy.Symbol(var_str)
        return sympy.integrate(e, var)
    except Exception:
        return None


def compute_definite_integral(
    expr_str: str,
    var_str: str,
    lower_limit_str: str,
    upper_limit_str: str,
) -> sympy.Expr | None:
    """Compute the definite integral ∫_{lower}^{upper} expr d(var)."""
    e = parse_symbolic_expression(expr_str)
    low = parse_symbolic_expression(lower_limit_str)
    high = parse_symbolic_expression(upper_limit_str)
    if e is None or low is None or high is None:
        return None
    try:
        var = sympy.Symbol(var_str)
        return sympy.integrate(e, (var, low, high))
    except Exception:
        return None


def check_integral(
    integrand_str: str,
    var_str: str,
    candidate_str: str,
    lower_limit_str: str | None = None,
    upper_limit_str: str | None = None,
) -> bool:
    """Verify an indefinite or definite integral candidate."""
    integrand = parse_symbolic_expression(integrand_str)
    if integrand is None:
        return False
    var = sympy.Symbol(var_str)

    # Definite integral
    if lower_limit_str is not None and upper_limit_str is not None:
        expected = compute_definite_integral(integrand_str, var_str, lower_limit_str, upper_limit_str)
        if expected is None:
            return False
        candidate = parse_symbolic_expression(candidate_str)
        if candidate is None:
            return False
        try:
            diff = expected - candidate
            if sympy.simplify(diff) == 0 or sympy.trigsimp(diff) == 0:
                return True
            # Float comparison if numeric
            if abs(float(expected.evalf()) - float(candidate.evalf())) < 1e-5:
                return True
        except Exception:
            pass
        return False

    # Indefinite integral:
    # A candidate F(x) is an antiderivative of f(x) if and only if d/dx F(x) == f(x).
    # This naturally handles any integration constant (+ C, + c, + K, or omission).
    candidate = parse_symbolic_expression(candidate_str)
    if candidate is None:
        return False

    try:
        candidate_derivative = sympy.diff(candidate, var)
        diff = candidate_derivative - integrand
        if sympy.simplify(diff) == 0 or sympy.trigsimp(diff) == 0:
            return True
        if candidate_derivative.equals(integrand) is True:
            return True
    except Exception:
        pass

    return False


def solve_equation(
    lhs_str: str,
    rhs_str: str,
    var_str: str = "x",
) -> list[sympy.Expr]:
    """Solve the equation LHS = RHS symbolically for the given variable."""
    lhs = parse_symbolic_expression(lhs_str)
    rhs = parse_symbolic_expression(rhs_str)
    if lhs is None or rhs is None:
        return []

    try:
        var = sympy.Symbol(var_str)
        eq = sympy.Eq(lhs, rhs)
        sols = sympy.solve(eq, var)
        return sols if isinstance(sols, list) else [sols]
    except Exception:
        return []


def check_equation_solution(
    lhs_str: str,
    rhs_str: str,
    var_str: str,
    candidate_val_or_expr: str | float,
) -> bool:
    """Check if candidate satisfies the equation LHS = RHS."""
    lhs = parse_symbolic_expression(lhs_str)
    rhs = parse_symbolic_expression(rhs_str)
    if lhs is None or rhs is None:
        return False

    var = sympy.Symbol(var_str)
    if isinstance(candidate_val_or_expr, (int, float)):
        val_expr = sympy.Number(candidate_val_or_expr)
    else:
        val_expr = parse_symbolic_expression(str(candidate_val_or_expr))
        if val_expr is None:
            return False

    try:
        diff = (lhs - rhs).subs(var, val_expr)
        if sympy.simplify(diff) == 0 or sympy.trigsimp(diff) == 0:
            return True
        if abs(float(diff.evalf())) < 1e-5:
            return True
    except Exception:
        pass

    return False


def detect_calculus_or_advanced_problem(text: str) -> CalculusProblem | None:
    r"""Detect whether question text asks for a derivative, integral, or trig identity.

    Examples:
    - 'Find the derivative of f(x) = x^3 - 4x + 5'
    - 'What is d/dx of sin(2x)?'
    - 'Find f\'(x) for f(x) = 3x^2 + 2x'
    - 'Evaluate the indefinite integral of 3x^2 + 2x dx'
    - 'Calculate the integral \int (cos(x) - sin(x)) dx'
    - 'Evaluate the definite integral from 0 to 2 of 3x^2 dx'
    - 'Simplify the trigonometric expression: sin^2(x) + cos^2(x)'
    """
    norm = text.replace("\n", " ").strip()

    # 1. Definite Integral Detection:
    # 'definite integral from A to B of EXPR' or '\int_{A}^{B} EXPR'
    m_def1 = re.search(
        r"(?:definite\s+integral|integral)\s+(?:from\s+([^\s]+)\s+to\s+([^\s]+))\s+of\s+([^?.,;]+)",
        norm,
        re.IGNORECASE,
    )
    if m_def1:
        low, high, expr = m_def1.group(1), m_def1.group(2), m_def1.group(3)
        low = low.replace("$", "").strip()
        high = high.replace("$", "").strip()
        expr = expr.replace("$", "").strip()
        expr = re.sub(r"\s*d[a-zA-Z]$", "", expr).strip()
        var = _extract_primary_variable(expr)
        return CalculusProblem(
            problem_type="definite_integral",
            variable=var,
            expression=expr.strip(),
            lower_limit=low.strip(),
            upper_limit=high.strip(),
        )

    m_def2 = re.search(
        r"\\int_\{?([^}^_]+)\}?\^\{?([^}^_]+)\}?\s*([^d\$\?]+?)(?:\s*d([a-zA-Z]))?(?:\$|\?|\.|\s|$)",
        norm,
    )
    if m_def2:
        low, high, expr, var = m_def2.group(1), m_def2.group(2), m_def2.group(3), m_def2.group(4)
        var = var or _extract_primary_variable(expr)
        return CalculusProblem(
            problem_type="definite_integral",
            variable=var,
            expression=expr.strip(),
            lower_limit=low.strip(),
            upper_limit=high.strip(),
        )

    # 2. Indefinite Integral Detection:
    # 'integral of EXPR', 'indefinite integral of EXPR', '\int EXPR dx', 'antiderivative of EXPR'
    m_indef = re.search(
        r"(?:indefinite\s+integral|antiderivative|integral)\s+of\s+([^?.,;]+)",
        norm,
        re.IGNORECASE,
    )
    if m_indef:
        expr = m_indef.group(1).strip()
        expr = expr.replace("$", "").strip()
        # Clean trailing dx
        expr = re.sub(r"\s*d[a-zA-Z]$", "", expr).strip()
        var = _extract_primary_variable(expr)
        return CalculusProblem(
            problem_type="indefinite_integral",
            variable=var,
            expression=expr,
        )

    m_int_sym = re.search(r"(?:\\int|∫)\s*([^d\$\?]+?)(?:\s*d([a-zA-Z]))?(?:\$|\?|\.|\s|$)", norm)
    if m_int_sym:
        expr = m_int_sym.group(1).strip()
        var = m_int_sym.group(2) or _extract_primary_variable(expr)
        return CalculusProblem(
            problem_type="indefinite_integral",
            variable=var,
            expression=expr,
        )

    # 3. Derivative Detection:
    # 'derivative of f(x) = EXPR', 'derivative of EXPR', 'd/dx [EXPR]', 'f\'(x) where f(x) = EXPR'
    m_deriv1 = re.search(
        r"(?:derivative\s+of)\s+([^?.,;]+)",
        norm,
        re.IGNORECASE,
    )
    if m_deriv1:
        raw_expr = m_deriv1.group(1).strip()
        clean_expr = raw_expr.replace("$", "").strip()
        m_fn = re.match(r"^[a-zA-Z](?:\(([a-zA-Z])\))?\s*=\s*", clean_expr)
        var = m_fn.group(1) if (m_fn and m_fn.group(1)) else None
        clean_expr = re.sub(r"^[a-zA-Z](?:\([a-zA-Z]\))?\s*=\s*", "", clean_expr).strip()
        var = var or _extract_primary_variable(clean_expr)
        return CalculusProblem(
            problem_type="derivative",
            variable=var,
            expression=clean_expr,
        )

    m_deriv2 = re.search(
        r"(?:\\frac\{d\}\{d([a-zA-Z])\}|d/d([a-zA-Z]))\s*(?:of\s+)?(.*)",
        norm,
        re.IGNORECASE,
    )
    if m_deriv2:
        var = m_deriv2.group(1) or m_deriv2.group(2) or "x"
        expr = m_deriv2.group(3).strip().rstrip("?.!,;:")
        if (expr.startswith("[") and expr.endswith("]")) or (expr.startswith("(") and expr.endswith(")")):
            expr = expr[1:-1].strip()
        return CalculusProblem(
            problem_type="derivative",
            variable=var,
            expression=expr,
        )

    m_prime = re.search(
        r"(?:find|what\s+is)\s+[a-zA-Z]'\(([a-zA-Z])\).*?(?:[a-zA-Z]\(\1\)\s*=\s*)([^?.,;]+)",
        norm,
        re.IGNORECASE,
    )
    if m_prime:
        var = m_prime.group(1)
        expr = m_prime.group(2).strip()
        return CalculusProblem(
            problem_type="derivative",
            variable=var,
            expression=expr,
        )

    # 4. Trigonometric Simplification / Identity:
    m_trig = re.search(
        r"(?:simplify|equivalent\s+to)(?:\s+the)?(?:\s+trigonometric)?(?:\s+expression)?[\:\s]+([^?.,;]+)",
        norm,
        re.IGNORECASE,
    )
    if m_trig and any(fn in norm.lower() for fn in ("sin", "cos", "tan", "sec", "csc", "cot")):
        expr = m_trig.group(1).strip()
        var = _extract_primary_variable(expr)
        return CalculusProblem(
            problem_type="trig_identity",
            variable=var,
            expression=expr,
        )

    return None


def _extract_primary_variable(expr_str: str) -> str:
    """Find the most likely variable in an expression string (defaulting to 'x')."""
    vars_found = re.findall(r"\b([a-zA-Z])\b", expr_str)
    candidates = [v for v in vars_found if v.lower() not in ("d", "e", "i", "c")]
    if candidates:
        return candidates[0]
    return "x"
