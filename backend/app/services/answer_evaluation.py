"""Answer evaluation — Sprint 3.10.

Pure (no I/O) per-type scoring of a student's submitted answer against
a persisted :class:`Question`. Returns an :class:`EvaluationResult`
the orchestrator turns into a database write + a user-facing feedback
response.

Why deterministic, not AI-graded
--------------------------------
Sprint 3 v1 ships with substring-and-equality matching across all five
question types. Sprint 5/6 polish can swap in GPT-4o rubric grading
for ``long_answer`` and symbolic-equivalence grading for
``mathematical``. The contract here — one function, ``evaluate``,
returning a fixed-shape :class:`EvaluationResult` — stays stable
across that change.

Two v1 approximations are worth knowing:

- ``long_answer`` correctness = "≥ 50% of grading_hints (key points)
  appear as case-insensitive substrings in the student response".
  Captures most well-organised answers; misses paraphrased ones.
- ``mathematical`` correctness = "normalized canonical answer appears
  as substring of normalized student answer". Catches identical
  surface forms (``$2x+3$`` vs ``2x+3``) but not algebraic
  equivalence (``$2x+3$`` vs ``$3+2x$``).

Both v1 rules are intentionally conservative: false-negatives (marking
a correct-but-paraphrased answer wrong) are recoverable via the admin
moderation flow, but false-positives (marking a wrong answer right)
poison the knowledge state and erode student trust. When in doubt,
mark wrong.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field

from app.models.question import Question, QuestionType

# ── Result type ─────────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class EvaluationResult:
    """Outcome of evaluating one student answer.

    ``rubric_score`` is populated for the rubric-scored types
    (``long_answer``, ``mathematical``) and ``None`` for the
    exact-match types where the boolean is the full picture.
    ``matched_hints`` lists which grading_hints fired (long_answer
    only). The orchestrator surfaces both in the feedback response so
    a student can see why they got the score they did.
    """

    is_correct: bool
    canonical_answer: str
    rubric_score: float | None = None
    matched_hints: list[str] = field(default_factory=list)


# ── Public entry point ──────────────────────────────────────────────────────


def evaluate(question: Question, submitted: str) -> EvaluationResult:
    """Grade ``submitted`` against ``question``.

    Args:
        question: the persisted Question being answered. Provides the
            answer, type, and any per-type grading hints.
        submitted: the student's response. For MCQ this should be an
            option key like ``"B"``; for true_false either ``"true"``
            or ``"false"``; for the rest free-form text.

    Returns:
        :class:`EvaluationResult` with correctness + canonical answer
        + (optional) rubric score + (optional) matched hints.

    The function is pure and synchronous — no I/O, no AI calls. Adding
    AI grading later means swapping the long_answer / mathematical
    branches; the contract above stays.
    """
    submitted = (submitted or "").strip()

    if question.question_type == QuestionType.mcq:
        return _evaluate_mcq(question, submitted)
    if question.question_type == QuestionType.true_false:
        return _evaluate_true_false(question, submitted)
    if question.question_type == QuestionType.short_answer:
        return _evaluate_short_answer(question, submitted)
    if question.question_type == QuestionType.long_answer:
        return _evaluate_long_answer(question, submitted)
    if question.question_type == QuestionType.mathematical:
        return _evaluate_mathematical(question, submitted)

    # The QuestionType enum is closed; a new value without a branch
    # here means a missing test branch. Fail loud.
    raise ValueError(
        f"No evaluation branch for question_type={question.question_type!r}"
    )


# ── Per-type evaluators ─────────────────────────────────────────────────────


def _evaluate_mcq(question: Question, submitted: str) -> EvaluationResult:
    """Exact match on the option key, case-insensitive.

    Why case-insensitive: the Flutter UI submits the key as it appears
    on the option ("A"/"B"/...), but a curl test or a buggy client
    might lower-case. The canonical answer is the question's stored
    ``answer`` field (which is the correct key).
    """
    submitted_key = submitted.upper()
    is_correct = submitted_key == question.answer.upper()
    return EvaluationResult(
        is_correct=is_correct,
        canonical_answer=question.answer,
    )


def _evaluate_true_false(
    question: Question, submitted: str
) -> EvaluationResult:
    """Accept ``true``/``false``/``t``/``f`` case-insensitively.

    The expanded set isn't generosity — a one-character button on the
    mobile UI is the most likely submission shape, so the evaluator
    has to normalise.
    """
    normalised = submitted.lower()
    if normalised in ("true", "t"):
        submitted_canonical = "true"
    elif normalised in ("false", "f"):
        submitted_canonical = "false"
    else:
        # Anything else is wrong — refuse to guess. The student's
        # client should have constrained their input.
        return EvaluationResult(
            is_correct=False,
            canonical_answer=question.answer,
        )
    return EvaluationResult(
        is_correct=submitted_canonical == question.answer.lower(),
        canonical_answer=question.answer,
    )


def _evaluate_short_answer(
    question: Question, submitted: str
) -> EvaluationResult:
    """Match against the canonical answer + every acceptable variant.

    Normalisation drops whitespace, lowercases, and strips trailing
    punctuation. ``"DNA"`` and ``"dna."`` and ``" DNA "`` all collapse
    to ``"dna"`` for comparison. Diacritics are stripped via Unicode
    NFKD so ``"café"`` and ``"cafe"`` match.
    """
    norm_submitted = _normalize_short(submitted)
    candidates = [question.answer, *question.grading_hints]
    for candidate in candidates:
        if _normalize_short(candidate) == norm_submitted:
            return EvaluationResult(
                is_correct=True,
                canonical_answer=question.answer,
            )
    return EvaluationResult(
        is_correct=False,
        canonical_answer=question.answer,
    )


def _evaluate_long_answer(
    question: Question, submitted: str
) -> EvaluationResult:
    """Substring-match the student response against each grading_hint.

    Each hit increments the score numerator. Correctness threshold is
    ≥ 50% of hints present (rounded up — ceiling division). For a
    question with 4 grading_hints, the student needs at least 2 hits.

    ``rubric_score`` reports the raw matched / total ratio so the UI
    can surface "you got 2 of 4 key points" feedback even when the
    overall verdict is correct.

    Empty grading_hints (shouldn't happen for long_answer per the 3.7
    parser's >= 3 minimum) falls back to non-empty-response =
    correct. That's a degenerate path and a logged warning is
    appropriate — but not a 500.
    """
    if not question.grading_hints:
        # Degenerate — would have been blocked by 3.7's parser. Treat
        # as "any non-empty response is fair credit" to avoid 500'ing
        # a student's submission on a system-side data bug.
        is_correct = bool(submitted.strip())
        return EvaluationResult(
            is_correct=is_correct,
            canonical_answer=question.answer,
            rubric_score=1.0 if is_correct else 0.0,
            matched_hints=[],
        )

    norm_submitted = submitted.lower()
    matched: list[str] = []
    for hint in question.grading_hints:
        if hint.lower() in norm_submitted:
            matched.append(hint)
            continue
        # Token-overlap fallback: many key points read like noun phrases
        # ("Chlorophyll absorbs photons") that students paraphrase
        # ("absorption of photons by chlorophyll"). Accept when >=70%
        # of the hint's non-trivial tokens appear (in any order).
        if _token_overlap_at_least(hint, submitted, threshold=0.7):
            matched.append(hint)

    score = len(matched) / len(question.grading_hints)
    threshold = 0.5
    return EvaluationResult(
        is_correct=score >= threshold,
        canonical_answer=question.answer,
        rubric_score=score,
        matched_hints=matched,
    )


def _evaluate_mathematical(
    question: Question, submitted: str
) -> EvaluationResult:
    """Normalize whitespace + symbol-strip; check substring match.

    LaTeX delimiters (``$``, ``\\(``, ``\\)``), whitespace, and braces
    don't carry meaning for the v1 comparison, so we strip them and
    look for the canonical answer's stripped form inside the student's
    stripped form. ``"$2x + 3$"`` and ``"2x+3"`` match; algebraic
    equivalences like ``"2x+3"`` and ``"3+2x"`` do NOT match — that's
    the Sprint 5/6 polish.

    rubric_score is 1.0 when matched, 0.0 otherwise — there's no
    partial credit in the v1 evaluator. The orchestrator can still
    award attempt XP for incorrect answers.
    """
    norm_submitted = _normalize_math(submitted)
    norm_answer = _normalize_math(question.answer)
    if not norm_answer:
        # Same degenerate-data guard as long_answer — don't 500 the
        # student on a system bug.
        return EvaluationResult(
            is_correct=False,
            canonical_answer=question.answer,
            rubric_score=0.0,
        )
    is_correct = norm_answer in norm_submitted
    return EvaluationResult(
        is_correct=is_correct,
        canonical_answer=question.answer,
        rubric_score=1.0 if is_correct else 0.0,
    )


# ── Normalisation helpers ───────────────────────────────────────────────────

# Punctuation we strip from short_answer ends. Keep this conservative —
# stripping ``-`` would conflate ``"non-fiction"`` and ``"non fiction"``,
# which the prompt's acceptable_variants are supposed to handle
# explicitly.
_SHORT_TRAILING_PUNCT = re.compile(r"[.\s,;:!?]+$")
_SHORT_LEADING_PUNCT = re.compile(r"^[\s.,;:!?]+")


def _normalize_short(text: str) -> str:
    """Lowercase + strip diacritics + strip leading/trailing punct."""
    if not text:
        return ""
    # NFKD splits "é" into "e" + combining acute, which we then drop.
    decomposed = unicodedata.normalize("NFKD", text)
    no_diacritics = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    lowered = no_diacritics.lower().strip()
    lowered = _SHORT_LEADING_PUNCT.sub("", lowered)
    lowered = _SHORT_TRAILING_PUNCT.sub("", lowered)
    # Collapse internal whitespace runs so "two  words" matches "two words".
    return re.sub(r"\s+", " ", lowered)


_MATH_STRIP_CHARS = re.compile(r"[\s${}\\]+")


def _normalize_math(text: str) -> str:
    """Lowercase + drop LaTeX punctuation + whitespace.

    Strips ``$`` delimiters, whitespace, ``{}``, and backslashes (the
    last so ``\\frac{1}{2}`` and ``frac12`` align after normalisation).
    Doesn't attempt symbol parsing — that's the AI grading future.
    """
    if not text:
        return ""
    return _MATH_STRIP_CHARS.sub("", text.lower())


def _token_overlap_at_least(hint: str, response: str, *, threshold: float) -> bool:
    """True iff ≥ ``threshold`` fraction of ``hint``'s non-stopword tokens
    appear in ``response`` (each as a case-insensitive substring).

    Used by long_answer scoring as a paraphrase-tolerant fallback after
    the strict substring match misses. Drops short stopwords (``"the"``,
    ``"a"``, ``"is"``, ``"of"``) so a hint like "Chlorophyll absorbs
    photons" matches a response that says "absorption of photons by
    chlorophyll" even though the verb form changed.
    """
    tokens = [t for t in re.findall(r"\w+", hint.lower()) if t not in _STOPWORDS]
    if not tokens:
        return False
    response_lower = response.lower()
    hits = sum(1 for t in tokens if t in response_lower)
    return (hits / len(tokens)) >= threshold


# Tight stopword list — only the tokens that would make a hint trivially
# match almost any paragraph. Deliberately NOT a full NLP stopword list
# (those drop too many content words for our short hints).
_STOPWORDS = frozenset(
    {
        "the",
        "a",
        "an",
        "is",
        "are",
        "was",
        "were",
        "be",
        "of",
        "to",
        "in",
        "on",
        "for",
        "and",
        "or",
        "that",
        "this",
        "by",
        "with",
        "as",
        "it",
        "its",
    }
)
