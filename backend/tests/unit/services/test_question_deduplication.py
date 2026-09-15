"""Unit tests for the unified question deduplication engine."""

from app.services.question_deduplication import (
    are_questions_equivalent,
    canonical_equation_signature,
    canonical_question_signature,
    extract_content_keywords,
    is_candidate_duplicate,
    normalize_question_stem,
    strip_question_templates,
)


def test_normalize_question_stem_removes_cosmetics():
    stem1 = "  What is   PHOTOSYNTHESIS??? "
    stem2 = "what is photosynthesis"
    assert normalize_question_stem(stem1) == normalize_question_stem(stem2)


def test_canonical_equation_signature_algebra():
    stem1 = "What is the solution to the equation 2(x + 3) = 16?"
    stem2 = "Solve: 2(x+3) = 16"
    stem3 = "Which of the following is the value of x in 2(x + 3) = 16?"
    diff = "What is the value of x in the equation 8x = 40?"

    sig1 = canonical_equation_signature(stem1)
    sig2 = canonical_equation_signature(stem2)
    sig3 = canonical_equation_signature(stem3)
    sig_diff = canonical_equation_signature(diff)

    assert sig1 == "eq:2(x+3)=16"
    assert sig1 == sig2 == sig3
    assert sig_diff == "eq:8x=40"
    assert sig1 != sig_diff


def test_strip_question_templates_across_subjects():
    # Science template
    s1 = normalize_question_stem("What is the primary function of ribosomes in living cells?")
    s2 = normalize_question_stem("Which of the following best describes the function of ribosomes in living cells?")
    assert strip_question_templates(s1) == strip_question_templates(s2)

    # Passage reference
    p1 = normalize_question_stem("According to the provided text, what does the atomic number represent?")
    p2 = normalize_question_stem("What is the definition of the atomic number?")
    assert "atomic number" in strip_question_templates(p1)
    assert "atomic number" in strip_question_templates(p2)

    # Humanities / History template
    h1 = normalize_question_stem("What was the main cause of the French Revolution?")
    h2 = normalize_question_stem("Which of the following best describes the main cause of the French Revolution?")
    assert "french revolution" in strip_question_templates(h1)
    assert strip_question_templates(h1) == strip_question_templates(h2)


def test_content_keywords_extraction():
    body = "According to the provided text, which organelle is primarily responsible for protein synthesis in eukaryotic cells?"
    keywords = extract_content_keywords(body)

    # Stop words and question frame tokens should be absent
    assert "according" not in keywords
    assert "which" not in keywords
    assert "the" not in keywords
    assert "primarily" not in keywords
    assert "responsible" not in keywords

    # Content keywords should be present
    assert "organelle" in keywords
    assert "protein" in keywords
    assert "synthesis" in keywords
    assert "eukaryotic" in keywords
    assert "cells" in keywords


def test_are_questions_equivalent_detects_semantic_duplicates():
    # 1. Template variation of the same biology question
    q1 = "What is the primary function of ribosomes in living cells?"
    q2 = "Which of the following best describes the function of ribosomes in living cells?"
    assert are_questions_equivalent(q1, q2) is True

    # 2. Math equation variation
    q_math1 = "Find the value of x in 2(x + 3) = 16"
    q_math2 = "Which of the following solves the equation 2(x + 3) = 16?"
    assert are_questions_equivalent(q_math1, q_math2) is True

    # 3. High keyword overlap and paraphrase
    q_para1 = "Explain how transcription operates during protein synthesis in living organisms."
    q_para2 = "During protein synthesis in living organisms, describe how transcription operates."
    assert are_questions_equivalent(q_para1, q_para2) is True

    # 4. Same answer + core concept keywords
    q_ans1 = "Which subatomic particle carries no electric charge?"
    q_ans2 = "Identify the neutral subatomic particle located in the nucleus."
    assert are_questions_equivalent(q_ans1, q_ans2, q1_ans="Neutron", q2_ans="Neutron") is True

    # 5. Distinct questions should NOT be marked equivalent
    q_distinct1 = "What is the primary function of mitochondria in living cells?"
    q_distinct2 = "What is the function of the cell wall in plant cells?"
    assert are_questions_equivalent(q_distinct1, q_distinct2) is False


def test_is_candidate_duplicate_against_history():
    seen_history = [
        ("What is the primary function of ribosomes?", "Protein synthesis"),
        ("Solve for x: 2(x + 3) = 16", "5"),
        ("Which subatomic particle has no electrical charge?", "Neutron"),
    ]

    # Candidate with reworded math
    cand_math = "Which of the following is the solution to 2(x + 3) = 16?"
    assert is_candidate_duplicate(cand_math, "5", seen_history) is True

    # Candidate with reworded science template
    cand_bio = "Which of the following best describes the function of ribosomes?"
    assert is_candidate_duplicate(cand_bio, "Protein synthesis", seen_history) is True

    # Candidate with same answer and core terms
    cand_chem = "Which subatomic particle carries no charge?"
    assert is_candidate_duplicate(cand_chem, "Neutron", seen_history) is True

    # Completely fresh candidate
    cand_fresh = "What is the power rule for differentiating x^n?"
    assert is_candidate_duplicate(cand_fresh, "n*x^(n-1)", seen_history) is False


def test_canonical_question_signature():
    sig1 = canonical_question_signature("Solve for x: 3x + 9 = 24")
    sig2 = canonical_question_signature("What is the solution to 3x + 9 = 24?")
    assert sig1 == sig2 == "eq:3x+9=24"

    sig_concept1 = canonical_question_signature("What is the primary function of chloroplasts in plant cells?")
    sig_concept2 = canonical_question_signature("Which of the following best describes the function of chloroplasts in plant cells?")
    assert sig_concept1 == sig_concept2

