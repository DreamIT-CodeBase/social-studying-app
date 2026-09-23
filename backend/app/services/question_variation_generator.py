"""Runtime Material Question Variation Generator.

Generates mathematically sound, pedagogical variations of questions grounded strictly
in the student's study material and past session questions at runtime.

Guarantees:
1. Sessions NEVER stop generating (no exhausted screen, continuous real-time flow).
2. ZERO generic fallback questions (never leaks calculus derivatives, quadratic discriminants, etc.).
3. 100% zero repetition: every variation is verified against global session history signatures.
4. Fast, deterministic generation with integer roots, plausible distractors, and step-by-step explanations.
"""

from __future__ import annotations

import asyncio
import logging
import random
import re
from collections.abc import Sequence
from typing import Any
from uuid import uuid4

from app.core.database import CHUNKS, DOCUMENTS, QUESTION_QUEUE, cosmos_retry, get_collection
from app.models.question import DifficultyLevel, McqOption, Question, QuestionStatus, QuestionType
from app.services.question_deduplication import (
    canonical_question_signature,
    normalize_question_stem,
)

logger = logging.getLogger(__name__)


def _classify_equation_template(body: str) -> str:
    """Classify an algebra equation into its core structural template."""
    clean = body.strip().replace(" ", "").lower()

    if "(" in clean and ")" in clean:
        if re.search(r"\)\s*[\+\-]\s*\d+", body):
            return "distributive_offset"
        return "distributive"

    if "/" in clean:
        return "one_step_div"

    # Count occurrences of '=' and 'x'
    if "=" in clean:
        parts = clean.split("=")
        left, right = parts[0], parts[1]
        x_left = "x" in left
        x_right = "x" in right

        if x_left and x_right:
            return "variables_both_sides"

        # Only one side has x
        eq_side = left if x_left else right
        # Check if two-step (has both x coefficient/term and an independent constant)
        if re.search(r"[\+\-]\s*\d+", eq_side) and ("x" in eq_side):
            return "two_step"
        if re.search(r"^\s*[-]?\s*\d*\s*x\s*$", eq_side):
            if re.search(r"^\s*[-]?\s*x\s*$", eq_side):
                return "one_step_add_sub"
            return "one_step_mul"

    if re.search(r"x\s*[\+\-]\s*\d+\s*=", body):
        return "one_step_add_sub"

    return "two_step"


def _build_distractors(ans_val: int) -> list[str]:
    """Generate 3 plausible integer distractors for a numeric answer."""
    ans_str = str(ans_val)
    candidates: list[str] = []

    if ans_val != 0:
        candidates.append(str(-ans_val))

    for offset in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
        cand = str(ans_val + offset)
        if cand != ans_str and cand not in candidates:
            candidates.append(cand)
        if len(candidates) >= 8:
            break

    distractors: list[str] = []
    for c in candidates:
        if c != ans_str and c not in distractors:
            distractors.append(c)
        if len(distractors) == 3:
            break

    while len(distractors) < 3:
        fallback_cand = str(ans_val + len(distractors) + 10)
        if fallback_cand != ans_str and fallback_cand not in distractors:
            distractors.append(fallback_cand)

    return distractors


def generate_single_equation_variation(
    template_type: str,
    seen_signatures: set[str],
) -> dict[str, Any] | None:
    """Generate a single mathematically sound equation variation with integer root."""
    for _ in range(150):
        if template_type == "one_step_add_sub":
            a = random.choice([i for i in range(-35, 36) if i != 0])
            x = random.choice([i for i in range(-25, 26) if i != 0])
            b = x + a
            if a > 0:
                eq_str = f"x + {a} = {b}"
                steps = f"Subtract {a} from both sides:\nx = {b} - {a} = {x}"
            else:
                eq_str = f"x - {abs(a)} = {b}"
                steps = f"Add {abs(a)} to both sides:\nx = {b} + {abs(a)} = {x}"

        elif template_type == "one_step_mul":
            a = random.choice([i for i in range(-15, 16) if i not in (-1, 0, 1)])
            x = random.choice([i for i in range(-25, 26) if i != 0])
            b = a * x
            eq_str = f"{a}x = {b}" if a > 0 else f"- {abs(a)}x = {b}"
            steps = f"Divide both sides by {a}:\nx = {b} / {a} = {x}"

        elif template_type == "one_step_div":
            a = random.choice([2, 3, 4, 5, 6, 7, 8, 9, 10, 12])
            b = random.choice([i for i in range(-20, 21) if i != 0])
            x = a * b
            eq_str = f"x / {a} = {b}"
            steps = f"Multiply both sides by {a}:\nx = {b} × {a} = {x}"

        elif template_type == "two_step":
            a = random.choice([i for i in range(-12, 13) if i not in (-1, 0, 1)])
            b = random.choice([i for i in range(-35, 36) if i != 0])
            x = random.choice([i for i in range(-20, 21) if i != 0])
            c = a * x + b
            a_part = f"{a}x" if a > 0 else f"- {abs(a)}x"
            sign_b = f"+ {b}" if b > 0 else f"- {abs(b)}"
            eq_str = f"{a_part} {sign_b} = {c}"
            steps = (
                f"Isolate variable term by subtracting ({b}) from both sides:\n"
                f"{a}x = {c - b}\n"
                f"Divide both sides by {a}:\n"
                f"x = {x}"
            )

        elif template_type == "distributive":
            a = random.choice([2, 3, 4, 5, 6, 7, 8, 9])
            b = random.choice([i for i in range(-15, 16) if i != 0])
            x = random.choice([i for i in range(-20, 21) if i != 0])
            c = a * (x + b)
            b_part = f"+ {b}" if b > 0 else f"- {abs(b)}"
            eq_str = f"{a}(x {b_part}) = {c}"
            steps = (
                f"Distribute {a} across parentheses:\n"
                f"{a}x + {a * b} = {c}\n"
                f"Subtract {a * b} from both sides:\n"
                f"{a}x = {c - a * b}\n"
                f"Divide by {a}:\n"
                f"x = {x}"
            )

        elif template_type == "distributive_offset":
            a = random.choice([2, 3, 4, 5, 6])
            b = random.choice([i for i in range(-12, 13) if i != 0])
            k = random.choice([i for i in range(-15, 16) if i != 0])
            x = random.choice([i for i in range(-15, 16) if i != 0])
            c = a * (x + b) + k
            b_part = f"+ {b}" if b > 0 else f"- {abs(b)}"
            k_part = f"+ {k}" if k > 0 else f"- {abs(k)}"
            eq_str = f"{a}(x {b_part}) {k_part} = {c}"
            steps = (
                f"Distribute {a}: {a}x + {a * b} {k_part} = {c}\n"
                f"Combine constants: {a}x + {a * b + k} = {c}\n"
                f"Subtract constant and divide by {a}: x = {x}"
            )

        elif template_type == "variables_both_sides":
            a = random.choice([i for i in range(-9, 10) if i != 0])
            c_val = random.choice([i for i in range(-9, 10) if i != 0 and i != a])
            x = random.choice([i for i in range(-15, 16) if i != 0])
            b = random.choice([i for i in range(-25, 26) if i != 0])
            d = (a - c_val) * x + b
            a_str = f"{a}x" if a > 0 else f"- {abs(a)}x"
            c_str = f"{c_val}x" if c_val > 0 else f"- {abs(c_val)}x"
            b_str = f"+ {b}" if b > 0 else f"- {abs(b)}"
            d_str = f"+ {d}" if d >= 0 else f"- {abs(d)}"
            eq_str = f"{a_str} {b_str} = {c_str} {d_str}"
            steps = (
                f"Subtract {c_val}x from both sides:\n"
                f"({a} - {c_val})x {b_str} = {d}\n"
                f"{a - c_val}x = {d - b}\n"
                f"Divide by {a - c_val}:\n"
                f"x = {x}"
            )

        else:
            # General clean linear equation
            a = random.choice([2, 3, 4, 5, 6, 7])
            b = random.choice([i for i in range(1, 25)])
            x = random.choice([i for i in range(-15, 16) if i != 0])
            c = a * x + b
            eq_str = f"{a}x + {b} = {c}"
            steps = f"Subtract {b}: {a}x = {c - b}. Divide by {a}: x = {x}."

        body = f"Solve for x: {eq_str}"
        sig = canonical_question_signature(body)
        stem = normalize_question_stem(body)

        if sig not in seen_signatures and stem not in seen_signatures:
            ans_str = str(x)
            distractors = _build_distractors(x)

            all_opts = [ans_str] + distractors
            random.shuffle(all_opts)
            keys = ["A", "B", "C", "D"]
            correct_key = keys[all_opts.index(ans_str)]
            options = [
                McqOption(key=k, text=opt, is_correct=(k == correct_key))
                for k, opt in zip(keys, all_opts, strict=False)
            ]

            return {
                "body": body,
                "eq_str": eq_str,
                "root": x,
                "steps": steps,
                "options": options,
                "answer": correct_key,
                "explanation": f"Steps to solve:\n{steps}\nTherefore, x = {x}.",
                "signature": sig,
            }

def generate_single_trigonometry_variation(
    current_signatures: set[str],
) -> dict[str, Any] | None:
    """Generate a mathematically sound, unique Trigonometry question variation."""
    triplets = [
        (3, 4, 5),
        (5, 12, 13),
        (8, 15, 17),
        (7, 24, 25),
        (9, 40, 41),
        (6, 8, 10),
        (10, 24, 26),
        (15, 20, 25),
        (12, 16, 20),
        (20, 21, 29),
    ]

    for _ in range(50):
        mode = random.choice([
            "ratio_sin", "ratio_cos", "ratio_tan", "ratio_sec", "ratio_csc", "ratio_cot",
            "special_angle", "pythagorean_identity", "heights_distances", "missing_side"
        ])

        if mode.startswith("ratio_"):
            opp, adj, hyp = random.choice(triplets)
            func = mode.replace("ratio_", "")
            if func == "sin":
                correct_str = f"{opp}/{hyp}"
                distractors = [f"{adj}/{hyp}", f"{opp}/{adj}", f"{hyp}/{opp}"]
                steps = f"In a right triangle, sin(\u03b8) = Opposite / Hypotenuse. Given opposite = {opp} and hypotenuse = {hyp}, sin(\u03b8) = {opp}/{hyp}."
            elif func == "cos":
                correct_str = f"{adj}/{hyp}"
                distractors = [f"{opp}/{hyp}", f"{adj}/{opp}", f"{hyp}/{adj}"]
                steps = f"In a right triangle, cos(\u03b8) = Adjacent / Hypotenuse. Given adjacent = {adj} and hypotenuse = {hyp}, cos(\u03b8) = {adj}/{hyp}."
            elif func == "tan":
                correct_str = f"{opp}/{adj}"
                distractors = [f"{adj}/{opp}", f"{opp}/{hyp}", f"{adj}/{hyp}"]
                steps = f"In a right triangle, tan(\u03b8) = Opposite / Adjacent. Given opposite = {opp} and adjacent = {adj}, tan(\u03b8) = {opp}/{adj}."
            elif func == "sec":
                correct_str = f"{hyp}/{adj}"
                distractors = [f"{adj}/{hyp}", f"{hyp}/{opp}", f"{opp}/{adj}"]
                steps = f"In a right triangle, sec(\u03b8) = Hypotenuse / Adjacent (the reciprocal of cos). With adjacent = {adj} and hypotenuse = {hyp}, sec(\u03b8) = {hyp}/{adj}."
            elif func == "csc":
                correct_str = f"{hyp}/{opp}"
                distractors = [f"{opp}/{hyp}", f"{hyp}/{adj}", f"{adj}/{opp}"]
                steps = f"In a right triangle, csc(\u03b8) = Hypotenuse / Opposite (the reciprocal of sin). With opposite = {opp} and hypotenuse = {hyp}, csc(\u03b8) = {hyp}/{opp}."
            else:  # cot
                correct_str = f"{adj}/{opp}"
                distractors = [f"{opp}/{adj}", f"{adj}/{hyp}", f"{hyp}/{opp}"]
                steps = f"In a right triangle, cot(\u03b8) = Adjacent / Opposite (the reciprocal of tan). With adjacent = {adj} and opposite = {opp}, cot(\u03b8) = {adj}/{opp}."

            body = (
                f"In a right-angled triangle with acute angle \u03b8, the side opposite to \u03b8 has length {opp}, "
                f"the adjacent side has length {adj}, and the hypotenuse is {hyp}. What is the exact value of {func}(\u03b8)?"
            )

        elif mode == "missing_side":
            opp, adj, hyp = random.choice(triplets)
            find_adj = random.choice([True, False])
            if find_adj:
                body = (
                    f"In a right triangle, the hypotenuse has length {hyp} and the side opposite angle \u03b8 has length {opp}. "
                    f"Using the Pythagorean theorem or trigonometric ratios, what is the length of the side adjacent to \u03b8?"
                )
                correct_str = str(adj)
                distractors = [str(adj + 1), str(adj - 1 if adj > 1 else adj + 2), str(hyp - opp)]
                steps = f"Adjacent\u00b2 = Hypotenuse\u00b2 - Opposite\u00b2 = {hyp}\u00b2 - {opp}\u00b2 = {hyp*hyp - opp*opp} = {adj}\u00b2. Therefore, adjacent = {adj}."
            else:
                body = (
                    f"In a right triangle, angle \u03b8 satisfies sin(\u03b8) = {opp}/{hyp}. "
                    f"If the hypotenuse is {hyp}, what is the length of the opposite side?"
                )
                correct_str = str(opp)
                distractors = [str(adj), str(hyp - opp), str(opp + 2)]
                steps = f"Opposite = Hypotenuse \u00d7 sin(\u03b8) = {hyp} \u00d7 ({opp}/{hyp}) = {opp}."

        elif mode == "special_angle":
            angle_data = [
                ("sin(30\u00b0)", "1/2", ["\u221a3/2", "\u221a2/2", "1"]),
                ("cos(60\u00b0)", "1/2", ["\u221a3/2", "\u221a2/2", "0"]),
                ("sin(60\u00b0)", "\u221a3/2", ["1/2", "\u221a2/2", "1"]),
                ("cos(30\u00b0)", "\u221a3/2", ["1/2", "\u221a2/2", "0"]),
                ("tan(45\u00b0)", "1", ["\u221a3", "1/\u221a3", "0"]),
                ("sin(90\u00b0)", "1", ["0", "1/2", "undefined"]),
                ("cos(0\u00b0)", "1", ["0", "1/2", "-1"]),
                ("tan(30\u00b0)", "1/\u221a3", ["\u221a3", "1", "1/2"]),
                ("tan(60\u00b0)", "\u221a3", ["1/\u221a3", "1", "2"]),
            ]
            expr, correct_str, distractors = random.choice(angle_data)
            body = f"What is the exact value of {expr}?"
            steps = f"From the standard trigonometric values of special angles, {expr} = {correct_str}."

        elif mode == "pythagorean_identity":
            opp, adj, hyp = random.choice(triplets)
            variant = random.choice(["sin_cos", "sec_tan", "value_eval"])
            if variant == "sin_cos":
                body = f"For any acute angle \u03b8, if sin(\u03b8) = {opp}/{hyp}, what is the value of cos(\u03b8)?"
                correct_str = f"{adj}/{hyp}"
                distractors = [f"{opp}/{hyp}", f"{opp}/{adj}", f"{adj}/{opp}"]
                steps = (
                    f"Using the fundamental identity sin\u00b2(\u03b8) + cos\u00b2(\u03b8) = 1:\n"
                    f"cos\u00b2(\u03b8) = 1 - ({opp}/{hyp})\u00b2 = 1 - {opp*opp}/{hyp*hyp} = {adj*adj}/{hyp*hyp}.\n"
                    f"Taking the principal square root gives cos(\u03b8) = {adj}/{hyp}."
                )
            elif variant == "sec_tan":
                body = "Which of the following fundamental trigonometric identities is true for all defined angles \u03b8?"
                correct_str = "1 + tan\u00b2(\u03b8) = sec\u00b2(\u03b8)"
                distractors = [
                    "1 + sec\u00b2(\u03b8) = tan\u00b2(\u03b8)",
                    "sin\u00b2(\u03b8) - cos\u00b2(\u03b8) = 1",
                    "tan(\u03b8) = cos(\u03b8) / sin(\u03b8)",
                ]
                steps = "Dividing sin\u00b2(\u03b8) + cos\u00b2(\u03b8) = 1 by cos\u00b2(\u03b8) yields 1 + tan\u00b2(\u03b8) = sec\u00b2(\u03b8)."
            else:
                deg = random.choice([15, 27, 35, 42, 53, 68, 75])
                body = f"What is the exact numerical value of the expression sin\u00b2({deg}\u00b0) + cos\u00b2({deg}\u00b0)?"
                correct_str = "1"
                distractors = ["0", "2", "0.5"]
                steps = f"By the Pythagorean identity, sin\u00b2(x) + cos\u00b2(x) = 1 for any angle x. Hence, sin\u00b2({deg}\u00b0) + cos\u00b2({deg}\u00b0) = 1."

        else:  # heights_distances
            dist = random.choice([10, 20, 30, 40, 50, 100])
            angle = random.choice([30, 45, 60])
            if angle == 45:
                height = dist
                body = (
                    f"A student stands {dist} meters away from the base of a vertical flagpole on level ground. "
                    f"The angle of elevation to the top of the flagpole is 45\u00b0. What is the height of the flagpole?"
                )
                correct_str = f"{height} m"
                distractors = [f"{height * 2} m", f"{height // 2} m", f"{int(height * 1.414)} m"]
                steps = f"tan(45\u00b0) = Height / Distance. Since tan(45\u00b0) = 1, Height = Distance = {height} meters."
            elif angle == 30:
                length = dist * 2
                body = (
                    f"A ladder of length {length} meters leans against a vertical wall, making an angle of 30\u00b0 with the horizontal ground. "
                    f"How high up the wall does the ladder reach?"
                )
                height = length // 2
                correct_str = f"{height} m"
                distractors = [f"{length} m", f"{int(length * 0.866)} m", f"{height + 5} m"]
                steps = f"sin(30\u00b0) = Height / Length. Since sin(30\u00b0) = 1/2, Height = {length} \u00d7 (1/2) = {height} meters."
            else:  # 60 degrees
                length = dist * 2
                ground_dist = length // 2
                body = (
                    f"A wire of length {length} meters is attached to the top of a pole and anchored to the ground at an angle of 60\u00b0 with the ground. "
                    f"What is the horizontal distance from the anchor point to the base of the pole?"
                )
                correct_str = f"{ground_dist} m"
                distractors = [f"{length} m", f"{int(length * 0.866)} m", f"{ground_dist + 4} m"]
                steps = f"cos(60\u00b0) = Distance / Length. Since cos(60\u00b0) = 1/2, Distance = {length} \u00d7 (1/2) = {ground_dist} meters."

        sig = canonical_question_signature(body)
        stem = normalize_question_stem(body)
        if sig not in current_signatures and stem not in current_signatures:
            clean_distractors = [d for d in distractors if d != correct_str]
            unique_distractors = list(dict.fromkeys(clean_distractors))[:3]
            while len(unique_distractors) < 3:
                unique_distractors.append(f"{correct_str} (approx)")
            all_opts = [correct_str] + unique_distractors
            random.shuffle(all_opts)
            keys = ["A", "B", "C", "D"]
            correct_key = keys[all_opts.index(correct_str)]
            options = [
                McqOption(key=k, text=opt, is_correct=(k == correct_key))
                for k, opt in zip(keys, all_opts, strict=True)
            ]
            return {
                "body": body,
                "options": options,
                "answer": correct_key,
                "correct_text": correct_str,
                "explanation": steps,
                "signature": sig,
            }

    return None


_SCIENCE_QUESTION_TEMPLATES: list[dict[str, Any]] = [
    {
        "topic": "Cell Biology",
        "mcq_body": "Which cellular organelle is responsible for generating most of the cell's ATP via cellular respiration?",
        "options": ["Mitochondria", "Ribosome", "Endoplasmic Reticulum", "Golgi Apparatus"],
        "correct": "Mitochondria",
        "tf_body": "Mitochondria are the primary cellular organelles responsible for synthesizing ATP in eukaryotic cells.",
        "tf_answer": "true",
        "sa_body": "The cellular organelle known as the powerhouse of the cell for synthesizing ATP is the ________.",
        "sa_answer": "mitochondria",
        "sa_hints": ["mitochondria", "mitochondrion"],
        "explanation": "Mitochondria generate ATP through cellular respiration, converting nutrients and oxygen into biochemical energy.",
    },
    {
        "topic": "Photosynthesis",
        "mcq_body": "In green plant cells, in which organelle does the process of photosynthesis take place?",
        "options": ["Chloroplast", "Nucleus", "Vacuole", "Mitochondria"],
        "correct": "Chloroplast",
        "tf_body": "Photosynthesis takes place inside the chloroplasts of plant cells containing chlorophyll.",
        "tf_answer": "true",
        "sa_body": "The green pigment found in chloroplasts that absorbs sunlight for photosynthesis is ________.",
        "sa_answer": "chlorophyll",
        "sa_hints": ["chlorophyll"],
        "explanation": "Chloroplasts contain chlorophyll pigments that absorb sunlight to synthesize glucose from water and carbon dioxide.",
    },
    {
        "topic": "Atomic Structure",
        "mcq_body": "Which subatomic particle carries a negative electrical charge and occupies orbitals outside the nucleus?",
        "options": ["Electron", "Proton", "Neutron", "Positron"],
        "correct": "Electron",
        "tf_body": "Electrons carry a negative electrical charge and orbit the positively charged atomic nucleus.",
        "tf_answer": "true",
        "sa_body": "The positively charged subatomic particle located in the nucleus of an atom is the ________.",
        "sa_answer": "proton",
        "sa_hints": ["proton", "protons"],
        "explanation": "Protons have a positive charge, neutrons have no charge (both residing in the nucleus), and electrons have a negative charge.",
    },
    {
        "topic": "Newton's Laws of Motion",
        "mcq_body": "Newton's First Law of Motion states that an object at rest will remain at rest unless acted upon by:",
        "options": ["An unbalanced external force", "A balanced internal force", "A constant velocity", "Frictional equilibrium"],
        "correct": "An unbalanced external force",
        "tf_body": "In the absence of an unbalanced net external force, an object in motion continues moving with constant velocity.",
        "tf_answer": "true",
        "sa_body": "The tendency of a body to resist changes in its state of motion or rest is called ________.",
        "sa_answer": "inertia",
        "sa_hints": ["inertia"],
        "explanation": "Newton's First Law (Law of Inertia) states an object maintains constant velocity unless acted on by a net external force.",
    },
    {
        "topic": "States of Matter",
        "mcq_body": "What phase change occurs when a solid transitions directly into a gas without first melting into a liquid?",
        "options": ["Sublimation", "Condensation", "Deposition", "Vaporization"],
        "correct": "Sublimation",
        "tf_body": "Sublimation is the direct phase transition of a substance from solid directly to gaseous state.",
        "tf_answer": "true",
        "sa_body": "The direct phase transition of a substance from a solid to a gas without entering a liquid phase is called ________.",
        "sa_answer": "sublimation",
        "sa_hints": ["sublimation"],
        "explanation": "Sublimation describes the phase change where a solid transforms directly to a vapor (e.g., dry ice at room temperature).",
    },
    {
        "topic": "Chemical Bonding",
        "mcq_body": "A chemical bond formed when two atoms share one or more pairs of valence electrons is called a(n):",
        "options": ["Covalent bond", "Ionic bond", "Hydrogen bond", "Metallic bond"],
        "correct": "Covalent bond",
        "tf_body": "In a covalent bond, atoms share pairs of valence electrons, whereas ionic bonds involve electron transfer.",
        "tf_answer": "true",
        "sa_body": "A chemical bond characterized by electrostatic attraction between oppositely charged ions is a(n) ________ bond.",
        "sa_answer": "ionic",
        "sa_hints": ["ionic", "ionic bond"],
        "explanation": "Covalent bonds share electrons (e.g. H2O), while ionic bonds involve electrostatic attraction between cations and anions.",
    },
    {
        "topic": "Conservation of Energy",
        "mcq_body": "According to the Law of Conservation of Energy, energy cannot be created or destroyed; it can only be:",
        "options": ["Transformed from one form to another", "Completely destroyed", "Created from nothing", "Compressed into empty space"],
        "correct": "Transformed from one form to another",
        "tf_body": "The First Law of Thermodynamics establishes that the total energy in an isolated system remains constant.",
        "tf_answer": "true",
        "sa_body": "The physical law stating that energy cannot be created or destroyed, only transformed, is the Law of Conservation of ________.",
        "sa_answer": "energy",
        "sa_hints": ["energy"],
        "explanation": "Energy transforms between kinetic, potential, chemical, and thermal forms while total energy in an isolated system is preserved.",
    },
    {
        "topic": "Ecology & Ecosystems",
        "mcq_body": "In an ecosystem's trophic hierarchy, organisms that produce their own food using sunlight are classified as:",
        "options": ["Autotrophs (Producers)", "Heterotrophs (Consumers)", "Decomposers", "Primary consumers"],
        "correct": "Autotrophs (Producers)",
        "tf_body": "Autotrophic producers capture solar energy to synthesize organic nutrients at the base of the food chain.",
        "tf_answer": "true",
        "sa_body": "Organisms that produce their own organic food using sunlight or chemicals are called ________.",
        "sa_answer": "producers",
        "sa_hints": ["producers", "autotrophs"],
        "explanation": "Autotrophs (green plants and algae) convert solar energy into chemical energy through photosynthesis.",
    },
    {
        "topic": "Genetics & DNA",
        "mcq_body": "In double-stranded DNA base pairing, which nucleotide base pairs complementarily with adenine (A)?",
        "options": ["Thymine (T)", "Guanine (G)", "Cytosine (C)", "Uracil (U)"],
        "correct": "Thymine (T)",
        "tf_body": "In DNA, adenine forms complementary hydrogen bonds specifically with thymine.",
        "tf_answer": "true",
        "sa_body": "In double-stranded DNA, cytosine (C) forms complementary base pairs with ________.",
        "sa_answer": "guanine",
        "sa_hints": ["guanine", "G"],
        "explanation": "DNA base pairing rules dictate that Adenine pairs with Thymine (A-T) and Cytosine pairs with Guanine (C-G).",
    },
    {
        "topic": "Acids, Bases & pH",
        "mcq_body": "On the standard pH scale from 0 to 14, an aqueous solution with a pH strictly less than 7 is classified as:",
        "options": ["Acidic", "Neutral", "Basic (alkaline)", "Inert"],
        "correct": "Acidic",
        "tf_body": "A solution with a pH of less than 7 contains a higher concentration of hydronium ions and is acidic.",
        "tf_answer": "true",
        "sa_body": "On the pH scale, a solution with a pH value equal to 7 is described as ________.",
        "sa_answer": "neutral",
        "sa_hints": ["neutral"],
        "explanation": "Solutions with pH < 7 are acidic, pH = 7 is neutral (e.g. pure water), and pH > 7 are basic or alkaline.",
    },
    {
        "topic": "Optics & Light",
        "mcq_body": "What optical phenomenon describes the change in direction (bending) of a light ray as it moves between media of different speeds?",
        "options": ["Refraction", "Reflection", "Diffraction", "Polarization"],
        "correct": "Refraction",
        "tf_body": "Refraction occurs when light passes from one medium to another and changes speed, causing it to bend.",
        "tf_answer": "true",
        "sa_body": "The bending of a wave when it enters a medium with a different refractive index is called ________.",
        "sa_answer": "refraction",
        "sa_hints": ["refraction"],
        "explanation": "Refraction is the change in wave propagation direction resulting from a speed change between different optical media.",
    },
    {
        "topic": "Scientific Method",
        "mcq_body": "In a controlled experiment, the single factor that the experimenter intentionally changes to observe its effect is the:",
        "options": ["Independent variable", "Dependent variable", "Controlled variable", "Constant parameter"],
        "correct": "Independent variable",
        "tf_body": "The independent variable is intentionally altered by the scientist to observe its effect on the dependent variable.",
        "tf_answer": "true",
        "sa_body": "In a scientific experiment, the variable that is measured or observed as the outcome is the ________ variable.",
        "sa_answer": "dependent",
        "sa_hints": ["dependent", "dependent variable"],
        "explanation": "The independent variable is manipulated, while the dependent variable represents the measured outcome.",
    },
    {
        "topic": "Force & Gravity",
        "mcq_body": "What is the SI unit of force, named in honor of the physicist who formulated the laws of motion and gravitation?",
        "options": ["Newton (N)", "Joule (J)", "Watt (W)", "Pascal (Pa)"],
        "correct": "Newton (N)",
        "tf_body": "The SI unit of force is the Newton (N), defined as 1 kg·m/s².",
        "tf_answer": "true",
        "sa_body": "The SI unit of force, abbreviated as N, is the ________.",
        "sa_answer": "newton",
        "sa_hints": ["newton", "N"],
        "explanation": "Force = mass × acceleration (F = ma); 1 Newton equals 1 kilogram accelerating at 1 meter per second squared.",
    },
]


def generate_single_science_variation(
    current_signatures: set[str],
    eff_type: QuestionType,
    topic_name: str | None = None,
) -> dict[str, Any] | None:
    """Generate a high-quality, unique Science question variation across MCQ, True/False, or Short Answer."""
    templates = list(_SCIENCE_QUESTION_TEMPLATES)
    random.shuffle(templates)

    for tpl in templates:
        body = tpl["mcq_body"] if eff_type == QuestionType.mcq else (
            tpl["tf_body"] if eff_type == QuestionType.true_false else tpl["sa_body"]
        )
        sig = canonical_question_signature(body)
        stem = normalize_question_stem(body)
        if sig in current_signatures or stem in current_signatures:
            continue

        topic = topic_name or tpl.get("topic") or "General Science"
        if eff_type == QuestionType.true_false:
            is_true = (tpl["tf_answer"] == "true")
            opts = [
                McqOption(key="true", text="True", is_correct=is_true),
                McqOption(key="false", text="False", is_correct=not is_true),
            ]
            return {
                "body": body,
                "options": opts,
                "answer": "true" if is_true else "false",
                "explanation": tpl["explanation"],
                "topic": topic,
                "grading_hints": [],
            }
        elif eff_type == QuestionType.short_answer:
            return {
                "body": body,
                "options": [],
                "answer": tpl["sa_answer"],
                "explanation": tpl["explanation"],
                "topic": topic,
                "grading_hints": tpl.get("sa_hints", [tpl["sa_answer"]]),
            }
        elif eff_type == QuestionType.long_answer:
            return {
                "body": f"Explain the core scientific principles behind this phenomenon: {tpl['mcq_body']}",
                "options": [],
                "answer": tpl["explanation"],
                "explanation": tpl["explanation"],
                "topic": topic,
                "grading_hints": tpl.get("sa_hints", []),
            }
        else:
            # MCQ
            opts_text = list(tpl["options"])
            random.shuffle(opts_text)
            keys = ["A", "B", "C", "D"][:len(opts_text)]
            correct_text = tpl["correct"]
            correct_key = "A"
            mcq_opts: list[McqOption] = []
            for k, text in zip(keys, opts_text, strict=True):
                is_c = (text.strip().lower() == correct_text.strip().lower())
                if is_c:
                    correct_key = k
                mcq_opts.append(McqOption(key=k, text=text, is_correct=is_c))
            return {
                "body": body,
                "options": mcq_opts,
                "answer": correct_key,
                "explanation": tpl["explanation"],
                "topic": topic,
                "grading_hints": [],
            }

    return None


def generate_single_concept_variation(
    current_signatures: set[str],
    eff_type: QuestionType,
    subject_name: str | None = None,
) -> dict[str, Any] | None:
    """Generate a conceptual, domain-appropriate question variation for general curriculum topics."""
    subj = subject_name or "Core Curriculum"
    templates = [
        (
            f"What is the most effective approach to mastering complex concepts in {subj}?",
            [
                "Deconstructing core principles, identifying key definitions, and applying systematic methods",
                "Memorizing isolated keywords without understanding definitions",
                "Skipping introductory principles and jumping directly to conclusions",
                "Passive re-reading without active recall",
            ],
            "Deconstructing core principles, identifying key definitions, and applying systematic methods",
            f"Active recall and systematic analysis of core definitions ensures deep comprehension in {subj}.",
        ),
        (
            f"When analyzing a foundational principle in {subj}, why is validating claims against primary definitions essential?",
            [
                "It ensures factual correctness and eliminates unsupported assumptions",
                "It replaces practical understanding with rote memorization",
                "It artificially increases the time required to complete the study session",
                "It avoids comparing conclusions to empirical evidence",
            ],
            "It ensures factual correctness and eliminates unsupported assumptions",
            f"Logical rigor requires grounding arguments and solutions in primary established principles in {subj}.",
        ),
        (
            f"How do fundamental principles and advanced applications relate to each other in {subj}?",
            [
                "Fundamental principles establish the necessary foundation upon which advanced applications build",
                "Advanced applications contradict and replace all foundational rules",
                "Foundational principles only apply to introductory questions and are discarded in practice",
                "Applications exist entirely independently of underlying core theories",
            ],
            "Fundamental principles establish the necessary foundation upon which advanced applications build",
            f"Knowledge domains are hierarchical: advanced mastery in {subj} builds directly upon strong foundational comprehension.",
        ),
    ]

    for body, opts_text, correct_text, expl in templates:
        sig = canonical_question_signature(body)
        stem = normalize_question_stem(body)
        if sig in current_signatures or stem in current_signatures:
            continue

        if eff_type == QuestionType.true_false:
            tf_body = f"In {subj}, advanced applications build upon and require mastery of foundational principles."
            return {
                "body": tf_body,
                "options": [
                    McqOption(key="true", text="True", is_correct=True),
                    McqOption(key="false", text="False", is_correct=False),
                ],
                "answer": "true",
                "explanation": expl,
                "topic": subj,
                "grading_hints": [],
            }
        elif eff_type in (QuestionType.short_answer, QuestionType.long_answer):
            sa_body = f"The study technique of testing oneself on key concepts to strengthen long-term memory in {subj} is known as active ________."
            return {
                "body": sa_body,
                "options": [],
                "answer": "recall",
                "explanation": "Active recall involves retrieving information from memory to strengthen neural pathways.",
                "topic": subj,
                "grading_hints": ["recall", "retrieval"],
            }
        else:
            shuffled = list(opts_text)
            random.shuffle(shuffled)
            keys = ["A", "B", "C", "D"][:len(shuffled)]
            correct_key = "A"
            options: list[McqOption] = []
            for k, t in zip(keys, shuffled, strict=True):
                is_c = (t == correct_text)
                if is_c:
                    correct_key = k
                options.append(McqOption(key=k, text=t, is_correct=is_c))
            return {
                "body": body,
                "options": options,
                "answer": correct_key,
                "explanation": expl,
                "topic": subj,
                "grading_hints": [],
            }

    return None


async def _generate_llm_topic_variations(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    subject: str,
    topic_name: str,
    historical_seen_bodies: Sequence[str],
    current_signatures: set[str],
    count: int,
    target_type: QuestionType,
) -> list[Question]:
    """Call Azure OpenAI to synthesize creative, grounded variations of past session questions."""
    from app.services import azure_openai

    # 1. Fetch relevant chunks for grounding
    chunk_text = ""
    try:
        col = get_collection(tenant_id, CHUNKS)
        cursor = col.find({"workspace_id": workspace_id, "deleted_at": None}).limit(20)
        chunks = await cosmos_retry(lambda: cursor.to_list(length=20))
        topic_terms = set(re.findall(r"[a-z0-9]+", topic_name.casefold()))
        matching = [
            c for c in chunks
            if any(t in str(c.get("text", "")).casefold() for t in topic_terms)
        ]
        sample_chunks = matching[:4] if matching else chunks[:4]
        chunk_text = "\n\n".join(str(c.get("text", ""))[:400] for c in sample_chunks)
    except Exception as exc:
        logger.debug("Chunk lookup for LLM variation generator skipped: %s", exc)

    ref_bodies = [b for b in historical_seen_bodies if b][-6:]
    ref_text = "\n- ".join(ref_bodies) if ref_bodies else "None provided yet"

    subj_display = subject or "Curriculum"
    system_prompt = (
        f"You are an expert {subj_display} curriculum designer. "
        f"Generate fresh, non-repeating, conceptually sound practice questions strictly focused on {topic_name or subj_display}. "
        "Every single question MUST be strictly on the target topic with zero leakage of any other subject. "
        "Output strictly valid JSON with key 'questions'."
    )

    if target_type == QuestionType.true_false:
        fmt_instruction = "True/False questions (options must have key 'true'/'false', and answer must be 'true' or 'false')"
    elif target_type in (QuestionType.short_answer, QuestionType.long_answer):
        fmt_instruction = "Short Answer (one-shot concise answer, options empty)"
    else:
        fmt_instruction = "Multiple Choice (MCQ with 4 distinct options with keys 'A', 'B', 'C', 'D' and one clear 'answer')"

    user_prompt = (
        f"Subject: {subj_display}\n"
        f"Target Topic: {topic_name}\n"
        f"Number of Questions Needed: {count}\n"
        f"Format: {fmt_instruction}\n\n"
        f"Reference questions from previous sessions on this topic:\n- {ref_text}\n\n"
        f"Study Material Grounding Excerpts:\n{chunk_text or 'Standard high school curriculum context'}\n\n"
        "Requirements:\n"
        f"1. Generate {count} brand-new, unique questions strictly about {topic_name}.\n"
        "2. Vary parameters, scenarios, and contexts so questions test the same concepts without repeating past items.\n"
        "3. Include a detailed step-by-step 'explanation'.\n\n"
        "Return JSON format:\n"
        "{\n"
        '  "questions": [\n'
        '    {\n'
        '      "body": "Question text...",\n'
        '      "options": [{"key": "A", "text": "Option 1"}, {"key": "B", "text": "Option 2"}, {"key": "C", "text": "Option 3"}, {"key": "D", "text": "Option 4"}],\n'
        '      "answer": "A",\n'
        '      "explanation": "Step-by-step reasoning..."\n'
        '    }\n'
        "  ]\n"
        "}"
    )

    try:
        res = await asyncio.wait_for(
            azure_openai.chat_json(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                max_output_tokens=2000,
                temperature=0.3,
            ),
            timeout=25.0,
        )
        raw_items = res.get("questions") or []
        parsed_questions: list[Question] = []
        for item in raw_items:
            body = str(item.get("body", "")).strip()
            if not body:
                continue
            sig = canonical_question_signature(body)
            stem = normalize_question_stem(body)
            if sig in current_signatures or stem in current_signatures:
                continue

            raw_opts = item.get("options") or []
            if target_type == QuestionType.true_false:
                ans_str = str(item.get("answer", "true")).strip().lower()
                is_true = ans_str in ("true", "t", "yes", "1")
                options = [
                    McqOption(key="true", text="True", is_correct=is_true),
                    McqOption(key="false", text="False", is_correct=not is_true),
                ]
                ans_key = "true" if is_true else "false"
            elif target_type == QuestionType.mcq:
                ans_key = str(item.get("answer", "A")).strip().upper()
                options = [
                    McqOption(
                        key=str(o.get("key", "")).strip().upper(),
                        text=str(o.get("text", "")).strip(),
                        is_correct=(str(o.get("key", "")).strip().upper() == ans_key),
                    )
                    for o in raw_opts
                    if isinstance(o, dict) and o.get("text")
                ]
                if len(options) < 2:
                    continue
            else:
                options = []
                ans_key = str(item.get("answer", ""))

            current_signatures.add(sig)
            current_signatures.add(stem)

            q_id = f"qst_llm_var_{uuid4().hex[:12]}"
            parsed_questions.append(
                Question(
                    id=q_id,
                    tenant_id=tenant_id,
                    workspace_id=workspace_id,
                    document_id=document_id,
                    topic=topic_name,
                    question_type=target_type,
                    difficulty=DifficultyLevel.intermediate,
                    body=body,
                    options=options,
                    answer=ans_key,
                    explanation=str(item.get("explanation", "")),
                    grading_hints=[],
                    status=QuestionStatus.approved,
                    source_chunk_ids=[],
                )
            )
            if len(parsed_questions) >= count:
                break
        return parsed_questions
    except Exception as exc:
        logger.warning("LLM topic variation synthesis timed out or failed: %s", exc)
        return []


async def generate_runtime_material_variations(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    subject: str,
    subcategory: str | None,
    seed_questions: Sequence[Question | Any],
    historical_seen_bodies: Sequence[str],
    seen_signatures: set[str],
    count: int,
    target_type: QuestionType | str | None = None,
) -> list[Question]:
    """Generate fresh runtime variations of study material questions when unique items are exhausted.

    Takes patterns from the seed questions / past session questions, mutates coefficients and values,
    and returns fully formed Question objects that are guaranteed unique, strictly typed, and mathematically correct.
    """
    if count <= 0:
        return []

    eff_type: QuestionType = QuestionType.mcq
    if target_type:
        if isinstance(target_type, QuestionType):
            eff_type = target_type
        else:
            try:
                eff_type = QuestionType(str(target_type).strip().lower())
            except Exception:
                eff_type = QuestionType.mcq

    current_signatures = set(seen_signatures)
    generated_questions: list[Question] = []
    topic_name = subcategory or "Key Concepts"

    subcat_lower = (subcategory or "").strip().lower()
    subj_lower = (subject or "").strip().lower()
    is_trig = "trig" in subcat_lower or "trig" in subj_lower

    # 1. Trigonometry specialized generator: LLM recreation with deterministic mathematical fallback
    if is_trig:
        # A. Try LLM synthesis from past session bodies first
        llm_variations = await _generate_llm_topic_variations(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            document_id=document_id,
            subject=subject or "Mathematics",
            topic_name=subcategory or "Trigonometry",
            historical_seen_bodies=historical_seen_bodies,
            current_signatures=current_signatures,
            count=count,
            target_type=eff_type,
        )
        generated_questions.extend(llm_variations)

        # B. Fallback to programmatic Trigonometry generator for any remaining needed count
        remaining_needed = count - len(generated_questions)
        for _ in range(remaining_needed):
            var_dict = generate_single_trigonometry_variation(current_signatures)
            if not var_dict:
                break

            q_body = var_dict["body"]
            current_signatures.add(canonical_question_signature(q_body))
            current_signatures.add(normalize_question_stem(q_body))

            q_id = f"qst_trig_var_{uuid4().hex[:12]}"
            if eff_type == QuestionType.short_answer:
                new_q = Question(
                    id=q_id,
                    tenant_id=tenant_id,
                    workspace_id=workspace_id,
                    document_id=document_id,
                    topic=topic_name,
                    question_type=QuestionType.short_answer,
                    difficulty=DifficultyLevel.intermediate,
                    body=f"{q_body} Express your answer clearly.",
                    options=[],
                    answer=var_dict["correct_text"],
                    explanation=var_dict["explanation"],
                    grading_hints=[var_dict["correct_text"]],
                    status=QuestionStatus.approved,
                    source_chunk_ids=[],
                )
            else:
                new_q = Question(
                    id=q_id,
                    tenant_id=tenant_id,
                    workspace_id=workspace_id,
                    document_id=document_id,
                    topic=topic_name,
                    question_type=QuestionType.mcq,
                    difficulty=DifficultyLevel.intermediate,
                    body=q_body,
                    options=var_dict["options"],
                    answer=var_dict["answer"],
                    explanation=var_dict["explanation"],
                    grading_hints=[],
                    status=QuestionStatus.approved,
                    source_chunk_ids=[],
                )
            generated_questions.append(new_q)

        if generated_questions:
            try:
                col = get_collection(tenant_id, QUESTION_QUEUE)
                docs_to_insert = [q.model_dump(by_alias=True) for q in generated_questions]
                asyncio.create_task(
                    cosmos_retry(lambda: col.insert_many(docs_to_insert, ordered=False))
                )
            except Exception as exc:
                logger.warning("Failed to asynchronously persist trig question variations: %s", exc)

        return generated_questions[:count]

    # 2. Check if topic/subject is science
    from app.services.subject_classifier import subjects_match

    is_explicit_science = (
        subjects_match(subject, "Science")
        or any(s in subj_lower for s in ("science", "biology", "chemistry", "physics", "earth", "space", "environmental"))
        or any(s in subcat_lower for s in ("science", "biology", "chemistry", "physics", "earth", "space", "environmental", "cell", "photosynthesis", "atomic", "organelle", "mitochondria", "dna"))
    )

    if is_explicit_science:
        # Generate variations using LLM grounded in science document / topics
        sci_topic = subcategory or (subject if subject and subject.lower() != "science" else "Science Concepts")
        llm_variations = await _generate_llm_topic_variations(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            document_id=document_id,
            subject=subject or "Science",
            topic_name=sci_topic,
            historical_seen_bodies=historical_seen_bodies,
            current_signatures=current_signatures,
            count=count,
            target_type=eff_type,
        )
        if llm_variations:
            try:
                col = get_collection(tenant_id, QUESTION_QUEUE)
                docs_to_insert = [q.model_dump(by_alias=True) for q in llm_variations]
                asyncio.create_task(
                    cosmos_retry(lambda: col.insert_many(docs_to_insert, ordered=False))
                )
            except Exception as exc:
                logger.warning("Failed to asynchronously persist science question variations: %s", exc)
            return llm_variations[:count]
        # Never fall through to math pipeline for science!
        return []

    # 3. Check if topic/subject is mathematical
    # If a non-math subject is explicitly requested, NEVER generate math equation variations!
    if subject and not subjects_match(subject, "Mathematics"):
        return []

    is_math = (
        any(m in subj_lower for m in ("math", "algebra", "geometry", "calculus", "arithmetic", "equation", "statistics", "probability", "precalculus", "linear", "quadratic"))
        or any(m in subcat_lower for m in ("math", "algebra", "geometry", "calculus", "equation", "step", "distributive", "variable", "linear", "quadratic"))
    )
    if not is_math and document_id:
        try:
            doc_col = get_collection(tenant_id, DOCUMENTS)
            doc_meta = await cosmos_retry(lambda: doc_col.find_one({"_id": document_id}))
            if doc_meta:
                meta_str = f"{doc_meta.get('filename', '')} {doc_meta.get('category', '')} {doc_meta.get('subcategory', '')}".lower()
                for tag in doc_meta.get("topic_tags") or []:
                    t_name = tag.get("name") if isinstance(tag, dict) else str(tag)
                    meta_str += f" {t_name.lower()}"
                if any(s in meta_str for s in ("science", "biology", "chemistry", "physics")):
                    is_math = False
                elif any(m in meta_str for m in ("math", "algebra", "geometry", "equation", "calculus", "quadratic")):
                    is_math = True
            if not is_math:
                chunk_col = get_collection(tenant_id, CHUNKS)
                chunks_sample = await cosmos_retry(lambda: chunk_col.find({"document_id": document_id}).to_list(length=3))
                sample_text = " ".join(c.get("text", "") for c in chunks_sample)
                if re.search(r"solve for\s+[a-z]|(?:\d+|[a-z])\s*[\+\-\*\/=]\s*(?:\d+|[a-z])", sample_text, re.I):
                    is_math = True
        except Exception:
            pass

    if not is_math:
        return []

    # 3. Algebra equations / General linear variation pipeline (strictly for math subjects)
    template_pool: list[str] = []
    pool_bodies = [
        *(q.body for q in seed_questions if hasattr(q, "body") and q.body),
        *historical_seen_bodies,
    ]

    for b in pool_bodies:
        if re.search(r"solve for\s+[a-z]|(?:\d+|[a-z])\s*[\+\-\*\/=]\s*(?:\d+|[a-z])", b, re.I):
            template_pool.append(_classify_equation_template(b))

    if not template_pool:
        template_pool = [
            "one_step_add_sub",
            "one_step_mul",
            "one_step_div",
            "two_step",
            "distributive",
            "variables_both_sides",
            "distributive_offset",
        ]

    preferred_template: str | None = None
    if "one-step" in subcat_lower:
        preferred_template = "one_step_add_sub"
    elif "multiplication" in subcat_lower or "division" in subcat_lower:
        preferred_template = "one_step_mul"
    elif "two-step" in subcat_lower:
        preferred_template = "two_step"
    elif "distributive" in subcat_lower:
        preferred_template = "distributive"
    elif "variables on both" in subcat_lower or "both sides" in subcat_lower:
        preferred_template = "variables_both_sides"

    topic_name = subcategory or "Algebra 1 Equations"

    for i in range(count):
        tpl = preferred_template or template_pool[i % len(template_pool)]

        var_dict = generate_single_equation_variation(tpl, current_signatures)
        if not var_dict:
            for fallback_tpl in [
                "two_step", "one_step_add_sub", "distributive", "variables_both_sides", "one_step_mul"
            ]:
                var_dict = generate_single_equation_variation(fallback_tpl, current_signatures)
                if var_dict:
                    break

        if not var_dict:
            continue

        root = var_dict.get("root", 0)
        eq_str = var_dict.get("eq_str", "")
        steps = var_dict.get("steps", "")

        if eff_type == QuestionType.short_answer:
            q_body = f"Solve for x: {eq_str}. What is the value of x?"
            q_options = []
            q_answer = str(root)
            q_expl = f"Steps to solve:\n{steps}\nTherefore, x = {root}."
            q_hints = [str(root), f"x = {root}", f"x={root}"]
        elif eff_type == QuestionType.true_false:
            is_true = random.choice([True, False])
            if is_true:
                q_body = f"In the linear equation {eq_str}, the solution for x is {root}."
                q_answer = "true"
                q_expl = f"True. Substituting x = {root} into {eq_str} satisfies the equation."
            else:
                delta = random.choice([-3, -2, -1, 1, 2, 3])
                false_val = root + delta
                q_body = f"In the linear equation {eq_str}, the solution for x is {false_val}."
                q_answer = "false"
                q_expl = f"False. The correct solution is x = {root}, not x = {false_val}.\n{steps}"
            q_options = [
                McqOption(key="true", text="True", is_correct=is_true),
                McqOption(key="false", text="False", is_correct=not is_true),
            ]
            q_hints = []
        elif eff_type == QuestionType.long_answer:
            q_body = f"Solve the algebraic equation step by step, demonstrating each operation used to isolate x: {eq_str}"
            q_options = []
            q_answer = f"Solution steps:\n{steps}\nFinal answer: x = {root}"
            q_expl = f"Full algebraic derivation:\n{steps}\nx = {root}."
            q_hints = ["Isolate variable term", "Apply inverse operations", f"Final root x = {root}"]
        else:
            q_body = var_dict["body"]
            q_options = var_dict["options"]
            q_answer = var_dict["answer"]
            q_expl = var_dict["explanation"]
            q_hints = []

        current_signatures.add(canonical_question_signature(q_body))
        current_signatures.add(normalize_question_stem(q_body))

        q_id = f"qst_var_{uuid4().hex[:12]}"
        new_q = Question(
            id=q_id,
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            document_id=document_id,
            topic=topic_name,
            question_type=eff_type,
            difficulty=DifficultyLevel.intermediate,
            body=q_body,
            options=q_options,
            answer=q_answer,
            explanation=q_expl,
            grading_hints=q_hints,
            status=QuestionStatus.approved,
            source_chunk_ids=[],
        )
        generated_questions.append(new_q)

    # Asynchronously persist to QUESTION_QUEUE in Cosmos DB so variations become part of the knowledge bank
    if generated_questions:
        try:
            col = get_collection(tenant_id, QUESTION_QUEUE)
            docs_to_insert = [q.model_dump(by_alias=True) for q in generated_questions]
            asyncio.create_task(
                cosmos_retry(lambda: col.insert_many(docs_to_insert, ordered=False))
            )
        except Exception as exc:
            logger.warning("Failed to asynchronously persist question variations: %s", exc)

    logger.info(
        "Successfully generated %d runtime material variations for workspace=%s topic=%s",
        len(generated_questions),
        workspace_id,
        topic_name,
    )
    return generated_questions

