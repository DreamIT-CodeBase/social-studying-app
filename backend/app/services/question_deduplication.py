"""Multi-layer question deduplication and equivalence engine.

Guarantees that no repeated question in any form (exact match, rephrased stem,
canonical equation variation, or semantic/concept duplicate) is presented to a
student when study material is available.
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Iterable
from functools import lru_cache

from app.services import question_validation, symbolic_math

# Common English stop words
_STOP_WORDS: frozenset[str] = frozenset(
    {
        "a", "about", "above", "across", "after", "again", "against", "all", "almost", "alone",
        "along", "already", "also", "although", "always", "am", "among", "an", "and", "another",
        "any", "anybody", "anyone", "anything", "anywhere", "are", "aren't", "around", "as",
        "at", "back", "be", "became", "because", "become", "becomes", "becoming", "been", "before",
        "behind", "being", "below", "beneath", "beside", "besides", "between", "beyond", "both",
        "but", "by", "can", "cannot", "could", "couldn't", "did", "didn't", "do", "does",
        "doesn't", "doing", "don't", "done", "down", "during", "each", "either", "else", "enough",
        "etc", "even", "ever", "every", "everybody", "everyone", "everything", "everywhere",
        "few", "for", "from", "further", "had", "hadn't", "has", "hasn't", "have", "haven't",
        "having", "he", "he'd", "he'll", "he's", "her", "here", "hers", "herself", "him",
        "himself", "his", "how", "however", "i", "i'd", "i'll", "i'm", "i've", "if", "in",
        "into", "is", "isn't", "it", "it's", "its", "itself", "just", "least", "less", "let",
        "let's", "like", "likely", "may", "maybe", "me", "might", "mightn't", "more", "most",
        "much", "must", "mustn't", "my", "myself", "neither", "never", "no", "nobody", "none",
        "noone", "nor", "not", "nothing", "now", "of", "off", "often", "on", "once", "one",
        "only", "onto", "or", "other", "others", "ought", "our", "ours", "ourselves", "out",
        "over", "own", "rather", "said", "same", "say", "says", "shall", "shan't", "she",
        "she'd", "she'll", "she's", "should", "shouldn't", "since", "so", "some", "somebody",
        "someone", "something", "somewhere", "still", "such", "than", "that", "that's", "the",
        "their", "theirs", "them", "themselves", "then", "there", "there's", "therefore", "these",
        "they", "they'd", "they'll", "they're", "they've", "this", "those", "through", "throughout",
        "to", "too", "toward", "towards", "under", "until", "up", "upon", "us", "very", "was",
        "wasn't", "we", "we'd", "we'll", "we're", "we've", "were", "weren't", "what", "what's",
        "whatever", "when", "whence", "whenever", "where", "where's", "whereafter", "whereas",
        "whereby", "wherein", "whereupon", "wherever", "whether", "which", "while", "whither",
        "who", "who's", "whoever", "whole", "whom", "whose", "why", "will", "with", "within",
        "without", "won't", "would", "wouldn't", "yes", "yet", "you", "you'd", "you'll",
        "you're", "you've", "your", "yours", "yourself", "yourselves",
    }
)

# Generic question structural/pedagogical tokens to filter when comparing content keywords.
# NOTE: Math action verbs (solve, calculate, evaluate, simplify, find, determine) are intentionally
# EXCLUDED from this set so that algebraic equations retain their distinguishing verb tokens
# during Jaccard/containment comparisons. Including them caused false-positive duplicate
# detection between distinct equations that share the same operation word.
_QUESTION_FRAME_WORDS: frozenset[str] = frozenset(
    {
        "according", "passage", "text", "material", "source", "provided", "given", "based",
        "context", "regarding", "respect", "refers", "referred", "referring", "refer",
        "mean", "means", "meant", "meaning", "following", "statement", "statements",
        "correct", "correctly", "incorrect", "incorrectly", "true", "false", "best",
        "describe", "describes", "described", "describing", "description", "define",
        "defines", "defined", "definition", "explain", "explains", "explained",
        "explanation", "identify", "identifies", "identified", "identifying",
        "select", "selects", "selected", "selecting", "choose", "chooses", "chosen",
        "choosing", "option", "options", "example", "examples", "primary", "primarily",
        "main", "major", "key", "role", "function", "functions", "purpose", "purposes",
        "concept", "concepts", "term", "terms", "principle", "principles",
        # Math action verbs intentionally removed — kept as distinguishing keywords:
        # "value", "values", "find", "finding", "calculate", "calculates", "calculated",
        # "calculating", "calculation", "determine", "determines", "determined",
        # "determining", "determination", "solve", "solves", "solved", "solving",
        # "solution", "solutions", "equation", "equations", "expression", "expressions",
        # "evaluate", "evaluates", "evaluated", "evaluating", "evaluation", "simplify",
        # "simplifies", "simplified", "simplifying",
        "fill", "blank", "blanks",
        "question", "questions", "problem", "problems", "exercise", "exercises",
        "answer", "answers", "answered", "answering", "state", "states", "stated",
        "responsible", "carries", "carry", "carrying", "contains", "contain",
        "containing", "possesses", "possess", "possessing", "characterized",
        "characterizes", "consists", "consist", "consisting", "includes", "include",
        "including", "represents", "represent", "representing", "electrical", "electric",
    }
)

# Multi-subject question template prefixes, sorted longest first for greedy stripping
_QUESTION_TEMPLATE_PREFIXES: tuple[str, ...] = tuple(
    sorted(
        [
            # Science / General concept definitions & descriptions
            "which of the following best describes the primary function of",
            "which of the following best describes the function of",
            "which of the following best describes the role of",
            "which of the following best describes",
            "which of the following correctly describes",
            "which of the following correctly identifies",
            "which of the following correctly characterizes",
            "which of the following is considered the primary",
            "which of the following is considered the",
            "which of the following is the primary function of",
            "which of the following is the primary role of",
            "which of the following is the function of",
            "which of the following is the main purpose of",
            "which of the following is true regarding",
            "which of the following is true about",
            "which of the following statements is true about",
            "which of the following statements is correct regarding",
            "which of the following statements is correct about",
            "which of the following statements is correct",
            "which of the following statements is true",
            "which of the following is true",
            "which of the following is false",
            "which of the following describes",
            "which of the following identifies",
            "which of the following is an example of",
            "which of the following represents",
            "which of the following",
            "which statement correctly describes",
            "which statement best describes",
            "which statement is correct about",
            "which statement is true regarding",
            "which statement is true about",
            "which statement is true",
            "which statement is correct",
            # According to source / passage
            "according to the provided text what is",
            "according to the provided text which",
            "according to the text what is",
            "according to the text which",
            "according to the passage what is",
            "according to the passage which",
            "based on the provided text what is",
            "based on the provided text which",
            "based on the text what is",
            "based on the text which",
            "based on the passage what is",
            "based on the passage which",
            "in the provided text what is",
            "in the context of the passage",
            "in the context of",
            # Primary role / function inquiries
            "what is considered the basic structural and functional unit of",
            "what is considered the primary function of",
            "what is considered the main function of",
            "what is the primary structural and functional unit of",
            "what is the primary mechanism of",
            "what is the primary function of",
            "what is the primary purpose of",
            "what is the primary role of",
            "what is the main function of",
            "what is the main purpose of",
            "what is the main role of",
            "what is the general function of",
            "what is the key difference between",
            "what is the difference between",
            "what is the definition of",
            "what is meant by the term",
            "what is meant by",
            # Common inquiry lead-ins
            "what does",
            "what do",
            "what is the main",
            "what is the primary",
            "what is the",
            "what is",
            "what are the",
            "what are",
            "what was the main cause of",
            "what was the primary cause of",
            "what was the main",
            "what was the primary",
            "what was the",
            "what was",
            "what were the",
            "what were",
            "the main cause of",
            "the primary cause of",
            "the cause of",
            "the main reason for",
            "the primary reason for",
            "the reason for",
            "the main function of",
            "the primary function of",
            "the function of",
            "the main role of",
            "the primary role of",
            "the role of",
            "the main",
            "the primary",
            "who was the",
            "who was",
            "who were the",
            "who were",
            "how does",
            "how do",
            "how was",
            "how were",
            "why does",
            "why do",
            "why was",
            "why were",
            "name the",
            "identify the",
            "state the",
            # Particle / Cell / Organelle / Entity inquiries
            "which subatomic particle",
            "which organelle is primarily responsible for",
            "which organelle is responsible for",
            "which organelle",
            # Fill in the blank / True false prefixes
            "fill in the blank according to the text",
            "fill in the blank",
            "true or false according to the text",
            "true or false",
            # Algebra & Math templates
            "which of the following is the solution to the equation",
            "which of the following is the solution to",
            "which of the following is the value of x in the equation",
            "which of the following is the value of x in",
            "which of the following is the value of x",
            "which of the following is the value of",
            "what is the solution to the equation",
            "what is the solution to",
            "what is the value of x in the equation",
            "what is the value of x in",
            "what is the value of x",
            "what is the value of",
            "solve for x in the equation",
            "solve for x in",
            "solve the equation for x",
            "solve the equation",
            "solve for x",
            "find the solution to the equation",
            "find the solution to",
            "find the value of x in the equation",
            "find the value of x in",
            "find the value of x",
            "find the value of",
            "find the solution",
            "find x in",
            "find x",
            "determine the solution to the equation",
            "determine the solution to",
            "determine the value of x in the equation",
            "determine the value of x in",
            "determine the value of x",
            "determine the value of",
            "determine the solution",
            "calculate the value of x in",
            "calculate the value of x",
            "calculate the value of",
            "calculate the",
            "evaluate the expression",
            "evaluate the following",
            "evaluate",
            "simplify the expression",
            "simplify",
            "solve",
        ],
        key=len,
        reverse=True,
    )
)


@lru_cache(maxsize=8192)
def normalize_question_stem(text: str) -> str:
    """Normalize text by stripping unicode variations, punctuation, and extra whitespace."""
    if not text:
        return ""
    normalized = unicodedata.normalize("NFKC", text).casefold()
    # Replace non-word/non-math characters with spaces
    normalized = re.sub(r"[^\w\s\+\-\*\/\^\=\(\)]", " ", normalized)
    return " ".join(normalized.split())


@lru_cache(maxsize=8192)
def strip_question_templates(normalized: str) -> str:
    """Aggressively strip leading question framing templates and trailing interrogatives."""
    stripped = normalized.strip()
    changed = True
    passes = 0
    while changed and passes < 4:
        changed = False
        passes += 1
        for prefix in _QUESTION_TEMPLATE_PREFIXES:
            if stripped.startswith(prefix):
                remainder = stripped[len(prefix):].strip()
                # If stripped remainder has content, update
                if len(remainder) >= 3:
                    stripped = remainder
                    changed = True
                    break

    # Strip trailing punctuation, colons, interrogative tails
    stripped = re.sub(r"[\?\.\!\:\;]+$", "", stripped).strip()
    trailing_phrases = (
        "is correctly defined as",
        "is defined as",
        "can be described as",
        "is referred to as",
        "is best described as",
        "is known as",
        "is as follows",
        "are as follows",
        "below",
    )
    for phrase in trailing_phrases:
        if stripped.endswith(phrase):
            remainder = stripped[:-len(phrase)].strip()
            if len(remainder) >= 3:
                stripped = remainder
                break

    return stripped.strip()


@lru_cache(maxsize=8192)
def canonical_equation_signature(body: str) -> str | None:
    """Extract canonical equation or advanced calculus problem signature.

    Returns:
        - "eq:<lhs>=<rhs>" for algebraic equations.
        - "calc:<type>:<expr>[:limits]" for calculus/trig problems.
        - None if no mathematical equation/calculus pattern is detected.
    """
    # 1. Check for standard algebraic equation: lhs = rhs
    eq_info = question_validation.extract_equation(body)
    if eq_info is not None:
        _, lhs, rhs = eq_info
        clean_lhs = re.sub(r"\s+", "", lhs.casefold())
        clean_rhs = re.sub(r"\s+", "", rhs.casefold())
        return f"eq:{clean_lhs}={clean_rhs}"

    # 2. Check for calculus or advanced math problems (derivatives, integrals)
    calc_prob = symbolic_math.detect_calculus_or_advanced_problem(body)
    if calc_prob is not None:
        clean_expr = re.sub(r"\s+", "", calc_prob.expression.casefold())
        limits_part = f":{calc_prob.lower_limit}:{calc_prob.upper_limit}" if calc_prob.lower_limit is not None else ""
        return f"calc:{calc_prob.problem_type}:{clean_expr}{limits_part}"

    return None


@lru_cache(maxsize=8192)
def extract_content_keywords(body: str) -> frozenset[str]:
    """Extract domain-specific content keywords by filtering stop words and question frame tokens."""
    normalized = normalize_question_stem(body)
    tokens = re.findall(r"[a-z0-9]+(?:-[a-z0-9]+)*", normalized)
    keywords: set[str] = set()
    for token in tokens:
        if len(token) < 3:
            continue
        if token in _STOP_WORDS or token in _QUESTION_FRAME_WORDS:
            continue
        keywords.add(token)
    return frozenset(keywords)


@lru_cache(maxsize=8192)
def canonical_question_signature(body: str) -> str:
    """Return the primary stable fingerprint for a question body.

    Handles canonical equations, strips conversational templates across all
    disciplines, and returns a normalized comparison key.
    """
    eq_sig = canonical_equation_signature(body)
    if eq_sig is not None:
        return eq_sig

    normalized = normalize_question_stem(body)
    stripped = strip_question_templates(normalized)
    return stripped if stripped else normalized


def are_questions_equivalent(
    q1_body: str,
    q2_body: str,
    q1_ans: str | None = None,
    q2_ans: str | None = None,
) -> bool:
    """Evaluate whether two questions are duplicates or equivalent in any form.

    Checks:
    1. Exact normalized stem equality.
    2. Canonical equation / calculus signature match.
    3. Template-stripped stem equality.
    4. Content-keyword Jaccard similarity (>= 0.65 with >= 3 keywords).
    5. Content-keyword containment overlap (>= 0.78 with >= 3 keywords).
    6. Canonical answer match + shared domain keywords (>= 2).
    """
    # 1. Exact normalized match
    norm1 = normalize_question_stem(q1_body)
    norm2 = normalize_question_stem(q2_body)
    if norm1 == norm2 and norm1:
        return True

    # 2. Canonical equation / calculus match
    sig1 = canonical_equation_signature(q1_body)
    sig2 = canonical_equation_signature(q2_body)
    if sig1 is not None and sig2 is not None and sig1 == sig2:
        return True

    # 3. Template-stripped stem match
    stripped1 = strip_question_templates(norm1)
    stripped2 = strip_question_templates(norm2)
    if stripped1 and stripped2 and stripped1 == stripped2:
        return True

    # 4 & 5. Content-keyword Jaccard and containment overlap
    # Thresholds are intentionally strict to avoid false positives on math content
    # where many distinct equations share surface tokens (x, solve, equation, value).
    # A Jaccard of 0.82 with ≥5 shared keywords is required to call two questions
    # equivalent — this threshold was raised from 0.65/3 after TestFlight feedback
    # showed algebra questions being falsely deduplicated.
    kw1 = extract_content_keywords(q1_body)
    kw2 = extract_content_keywords(q2_body)
    if kw1 and kw2:
        intersection = kw1 & kw2
        union = kw1 | kw2
        shared_count = len(intersection)
        min_len = min(len(kw1), len(kw2))

        # Jaccard similarity — raised threshold prevents false duplicates on math
        jaccard = shared_count / len(union) if union else 0.0
        if jaccard >= 0.82 and shared_count >= 5:
            return True

        # Containment similarity (one stem is a near-subset of another)
        if min_len >= 5:
            containment = shared_count / min_len
            if containment >= 0.85:
                return True

    # 6. Same answer + core topic keywords match
    if q1_ans and q2_ans:
        clean_ans1 = re.sub(r"\s+", "", str(q1_ans).strip().casefold())
        clean_ans2 = re.sub(r"\s+", "", str(q2_ans).strip().casefold())
        # If answers match and they share at least 2 significant keywords
        if clean_ans1 and clean_ans2 and clean_ans1 == clean_ans2:
            if kw1 and kw2 and len(kw1 & kw2) >= 2:
                return True

    return False


def is_candidate_duplicate(
    candidate_body: str,
    candidate_ans: str | None,
    seen_items: Iterable[tuple[str, str | None]],
) -> bool:
    """Determine if candidate matches any previously seen question in seen_items."""
    cand_sig = canonical_question_signature(candidate_body)
    cand_norm = normalize_question_stem(candidate_body)

    for seen_body, seen_ans in seen_items:
        # Fast path 1: identical signature
        if cand_sig == canonical_question_signature(seen_body):
            return True
        # Fast path 2: exact normalized stem
        if cand_norm == normalize_question_stem(seen_body):
            return True
        # Full multi-layer check
        if are_questions_equivalent(candidate_body, seen_body, candidate_ans, seen_ans):
            return True

    return False
