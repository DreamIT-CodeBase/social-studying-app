"""Unit tests for the SymPy-powered symbolic mathematics engine."""

import sympy

from app.services import symbolic_math


def test_clean_math_text():
    assert symbolic_math.clean_math_text("$3x^2 + 2x$") == "3x**2 + 2x"
    assert symbolic_math.clean_math_text(r"\( \sin(x) + \cos(x) \)") == "sin(x) + cos(x)"
    assert symbolic_math.clean_math_text(r"\frac{x}{2} + 3") == "((x)/(2)) + 3"
    assert symbolic_math.clean_math_text("3x – 4") == "3x - 4"
    assert symbolic_math.clean_math_text("2 × 3") == "2 * 3"
    assert symbolic_math.clean_math_text("3x^2 dx") == "3x**2"


def test_parse_symbolic_expression():
    e1 = symbolic_math.parse_symbolic_expression("3x^2 + 2x")
    assert e1 is not None
    x = sympy.Symbol("x")
    assert e1 == 3 * x**2 + 2 * x

    # Implicit multiplication
    e2 = symbolic_math.parse_symbolic_expression("2(x + 3)")
    assert e2 is not None
    assert e2 == 2 * (x + 3)

    # Invalid expression returns None
    assert symbolic_math.parse_symbolic_expression("this is not math @@") is None


def test_are_expressions_equivalent_algebraic():
    # Commutativitythi
    assert symbolic_math.are_expressions_equivalent("2x + 3", "3 + 2x") is True
    # Factored vs expanded
    assert symbolic_math.are_expressions_equivalent("(x - 2)(x + 2)", "x^2 - 4") is True
    assert symbolic_math.are_expressions_equivalent("x*(3x + 2)", "3x^2 + 2x") is True
    # Non-equivalent
    assert symbolic_math.are_expressions_equivalent("2x + 3", "2x + 4") is False


def test_are_expressions_equivalent_trigonometric():
    # Pythagorean identity
    assert symbolic_math.are_expressions_equivalent("sin(x)^2 + cos(x)^2", "1") is True
    # tan * cos = sin
    assert symbolic_math.are_expressions_equivalent("tan(x) * cos(x)", "sin(x)") is True
    # Double angle formula
    assert symbolic_math.are_expressions_equivalent("2*sin(x)*cos(x)", "sin(2x)") is True


def test_check_derivative_polynomial():
    # f(x) = x^3 - 4x + 5 -> f'(x) = 3x^2 - 4
    assert symbolic_math.check_derivative("x^3 - 4x + 5", "x", "3x^2 - 4") is True
    assert symbolic_math.check_derivative("x^3 - 4x + 5", "x", "3x^2 + 4") is False
    assert symbolic_math.check_derivative("4x^4 - 2x^2", "x", "16x^3 - 4x") is True


def test_check_derivative_trig_and_transcendental():
    # d/dx sin(2x) = 2 cos(2x)
    assert symbolic_math.check_derivative("sin(2x)", "x", "2*cos(2x)") is True
    # d/dx (x * e^x) = e^x * (x + 1)
    assert symbolic_math.check_derivative("x * exp(x)", "x", "exp(x)*(x + 1)") is True
    assert symbolic_math.check_derivative("ln(x)", "x", "1/x") is True


def test_check_indefinite_integral_with_and_without_constant():
    # ∫ (3x^2 + 2x) dx = x^3 + x^2 (+ C)
    assert symbolic_math.check_integral("3x^2 + 2x", "x", "x^3 + x^2 + C") is True
    assert symbolic_math.check_integral("3x^2 + 2x", "x", "x^3 + x^2 + c") is True
    assert symbolic_math.check_integral("3x^2 + 2x", "x", "x^3 + x^2") is True
    assert symbolic_math.check_integral("3x^2 + 2x", "x", "x^3 + x^2 + 10") is True
    # Wrong integral
    assert symbolic_math.check_integral("3x^2 + 2x", "x", "6x + 2") is False


def test_check_indefinite_integral_trigonometric():
    # ∫ cos(x) dx = sin(x) + C
    assert symbolic_math.check_integral("cos(x)", "x", "sin(x) + C") is True
    # ∫ sin(2x) dx = -1/2 cos(2x) + C
    assert symbolic_math.check_integral("sin(2x)", "x", "-(1/2)*cos(2x) + C") is True


def test_check_definite_integral():
    # ∫_0^2 3x^2 dx = [x^3]_0^2 = 8
    assert symbolic_math.check_integral("3x^2", "x", "8", lower_limit_str="0", upper_limit_str="2") is True
    assert symbolic_math.check_integral("3x^2", "x", "6", lower_limit_str="0", upper_limit_str="2") is False

    # ∫_1^3 (2x + 1) dx = [x^2 + x]_1^3 = (9+3) - (1+1) = 10
    assert symbolic_math.check_integral("2x + 1", "x", "10", lower_limit_str="1", upper_limit_str="3") is True


def test_solve_equation_and_check_solution():
    sols = symbolic_math.solve_equation("8x", "40", "x")
    assert sols == [5]

    assert symbolic_math.check_equation_solution("8x", "40", "x", 5) is True
    assert symbolic_math.check_equation_solution("8x", "40", "x", 4) is False

    # Two-step with negative numbers
    assert symbolic_math.check_equation_solution("-5x - 4", "-84", "x", 16) is True
    # Distributive property
    assert symbolic_math.check_equation_solution("3(x - 4)", "9", "x", 7) is True
    # Variables on both sides
    assert symbolic_math.check_equation_solution("5x + 7", "3x - 5", "x", -6) is True


def test_detect_calculus_or_advanced_problem():
    # Derivative
    prob1 = symbolic_math.detect_calculus_or_advanced_problem("Find the derivative of f(x) = x^3 - 4x + 5")
    assert prob1 is not None
    assert prob1.problem_type == "derivative"
    assert "x^3" in prob1.expression

    # Leibniz notation
    prob2 = symbolic_math.detect_calculus_or_advanced_problem("What is d/dx [sin(2x)]?")
    assert prob2 is not None
    assert prob2.problem_type == "derivative"
    assert "sin(2x)" in prob2.expression

    # Indefinite Integral
    prob3 = symbolic_math.detect_calculus_or_advanced_problem("Find the indefinite integral of 3x^2 + 2x dx")
    assert prob3 is not None
    assert prob3.problem_type == "indefinite_integral"
    assert "3x^2" in prob3.expression

    # Definite Integral
    prob4 = symbolic_math.detect_calculus_or_advanced_problem("Evaluate the definite integral from 0 to 2 of 3x^2 dx")
    assert prob4 is not None
    assert prob4.problem_type == "definite_integral"
    assert prob4.lower_limit == "0"
    assert prob4.upper_limit == "2"

    # Trig identity
    prob5 = symbolic_math.detect_calculus_or_advanced_problem("Simplify the trigonometric expression: sin^2(x) + cos^2(x)")
    assert prob5 is not None
    assert prob5.problem_type == "trig_identity"
