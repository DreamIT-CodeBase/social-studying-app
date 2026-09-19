"""Question output safety + structural review — Sprint 3.8.

Sits between :mod:`app.services.question_generation` and the persistence
step in Sprint 3.9's ``/questions/next`` endpoint. Every freshly-
generated question goes through here BEFORE it's stored or served to a
student.

Two layers, evaluated in order
------------------------------
1. **Azure Content Safety** on the combined question text (body +
   answer + explanation + options + grading_hints). If any harm category
   crosses its workspace-configured threshold, the question is flagged
   for admin review. Same seam Sprint 2.4 uses for uploaded documents
   (``content_safety.analyze_extracted_text``).

2. **Structural anti-leakage checks** on the GeneratedQuestion shape.
   These catch pedagogical leakage the type-specific parser in
   ``question_generation`` can't see — e.g. an MCQ option text that
   literally says "(correct)", or a question body that reveals the
   reference answer verbatim. The Sprint 3.7 prompts forbid these but
   the model occasionally slips them through; this is the safety net.

Three possible outcomes
-----------------------
- :attr:`ReviewVerdict.approved`  — clean. Orchestrator persists with
  ``status=approved``.
- :attr:`ReviewVerdict.flagged`   — Content Safety flagged. Orchestrator
  persists with ``status=pending_review`` and
  ``moderation_flagged=true``, writes a ``moderation_log`` entry, does
  NOT serve to the student.
- :attr:`ReviewVerdict.rejected`  — structural failure (the model output
  is malformed enough that it can't be served even after admin review).
  Orchestrator does NOT persist; logs and either retries with a
  different topic + difficulty or surfaces "no question available".

A question that hits BOTH a content-safety flag AND a structural
rejection lands on ``rejected`` — the structural failure means the
question is unusable regardless of the safety verdict.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from enum import StrEnum

from app.models.question import QuestionType
from app.services import content_safety
from app.services.content_safety import SafetyVerdict
from app.services.question_generation import GeneratedQuestion

logger = logging.getLogger(__name__)


# ── Verdict ─────────────────────────────────────────────────────────────────


class ReviewVerdict(StrEnum):
    """Outcome of :func:`review_question`."""

    approved = "approved"
    flagged = "flagged"
    rejected = "rejected"


@dataclass(frozen=True, slots=True)
class QuestionReview:
    """Result of running a question through Content Safety + structural checks.

    The ``safety`` field is always populated (even on approved verdicts)
    so the orchestrator can include severity scores in the moderation
    audit log when persisting a borderline question.
    """

    verdict: ReviewVerdict
    safety: SafetyVerdict
    structural_failures: list[str] = field(default_factory=list)
    reason: str = ""


# ── Structural-check thresholds ─────────────────────────────────────────────

# Question body sanity limit. Anything past this is almost certainly a
# prompt-format runaway (the model started writing the next question
# instead of stopping). 500 chars ≈ 100 words, more than enough for a
# question stem at any of our types.
_MAX_BODY_CHARS = 500

# Patterns that leak the correct option in MCQ text. Case-insensitive
# match; any one occurrence rejects the question. ``\b`` boundaries on
# the parenthetical forms keep us from false-positiving inside genuine
# vocabulary words like "incorrect" or "selection".
_MCQ_LEAKAGE_PATTERNS = (
    re.compile(r"\(correct\)", re.IGNORECASE),
    re.compile(r"\(answer\)", re.IGNORECASE),
    re.compile(r"\[x\]", re.IGNORECASE),
    re.compile(r"\(✓\)"),
    re.compile(r"<<correct>>", re.IGNORECASE),
)

# MCQ stem patterns that violate the prompt's "no 'all of the above'"
# rule. Catching at the safety layer means the prompt can drift without
# breaking the contract downstream.
_MCQ_BANNED_STEM_OPTIONS = (
    re.compile(r"\ball\s+of\s+the\s+above\b", re.IGNORECASE),
    re.compile(r"\bnone\s+of\s+the\s+above\b", re.IGNORECASE),
)


# ── Public entry point ──────────────────────────────────────────────────────


async def review_question(question: GeneratedQuestion) -> QuestionReview:
    """Run a question through Content Safety + structural checks.

    Args:
        question: the output of :func:`question_generation.generate_question`.

    Returns:
        :class:`QuestionReview` with verdict + safety verdict +
        structural failure list + human-readable reason.

    Raises:
        ServiceUnavailableError: Content Safety call failed. The
            orchestrator must NOT persist or serve the question — a
            failed safety scan means the moderation gate hasn't actually
            been crossed, same policy as the document-ingestion worker.

    Determinism: structural checks are pure functions of the input.
    Content Safety is non-deterministic in principle (Azure may tune
    classifiers) but stable within a single deploy.
    """
    combined_text = _combine_for_safety(question)
    safety = await content_safety.analyze_extracted_text(combined_text)

    structural_failures = _structural_checks(question)

    if structural_failures:
        # Structural failure wins regardless of safety result — the
        # question is malformed enough to not be servable even with
        # admin review.
        verdict = ReviewVerdict.rejected
        reason = (
            f"Rejected: structural check failed "
            f"({len(structural_failures)} issue(s)): "
            f"{'; '.join(structural_failures)}"
        )
    elif safety.flagged:
        verdict = ReviewVerdict.flagged
        reason = (
            f"Flagged for admin review: Content Safety triggered on "
            f"{', '.join(safety.flagged_categories)} "
            f"(max severity {max(safety.severities.values())}/6)."
        )
    else:
        verdict = ReviewVerdict.approved
        reason = "Approved: Content Safety clean and structural checks passed."

    logger.info(
        "Question review topic=%s type=%s verdict=%s safety_flagged=%s structural_failures=%d",
        question.question_type.value,
        question.difficulty.value,
        verdict.value,
        safety.flagged,
        len(structural_failures),
    )

    return QuestionReview(
        verdict=verdict,
        safety=safety,
        structural_failures=structural_failures,
        reason=reason,
    )


# ── Text combination for Content Safety ─────────────────────────────────────


def _combine_for_safety(question: GeneratedQuestion) -> str:
    """Concatenate every text-bearing field into one safety-scan payload.

    Content Safety scores the WHOLE payload — feeding it the body alone
    would miss a clean stem with an objectionable explanation or
    option. Sections are separated by ``\\n\\n`` so the scanner treats
    them as paragraphs rather than one runon sentence.
    """
    parts: list[str] = [question.body, question.answer, question.explanation]
    parts.extend(opt.text for opt in question.options)
    parts.extend(question.grading_hints)
    return "\n\n".join(p for p in parts if p)


# ── Structural checks ──────────────────────────────────────────────────────


def _structural_checks(question: GeneratedQuestion) -> list[str]:
    """Run every applicable structural check and return failure messages.

    Empty list = no failures. Each failure message is a short
    human-readable reason suitable for inclusion in the moderation log
    and the rejected-question debug output.

    Checks are split into universal + type-specific so a new question
    type can opt into the universal ones for free.
    """
    failures: list[str] = []

    # ── Universal ──
    if len(question.body) > _MAX_BODY_CHARS:
        failures.append(
            f"body exceeds {_MAX_BODY_CHARS}-char sanity limit (got {len(question.body)})"
        )

    # Anti-leakage: the body must not reveal the answer verbatim.
    # Skip for MCQ (the answer is a key like "C"; checking for it in
    # the body would false-positive) and true_false (the answer is
    # literally the word "true"/"false", which often legitimately
    # appears in the statement).
    if question.question_type not in (QuestionType.mcq, QuestionType.true_false):
        body_lower = question.body.casefold()
        ans_lower = question.answer.casefold().strip()
        # Only check meaningful-length answers; "is" or "a" would
        # false-positive on any sentence.
        if len(ans_lower) >= 4 and ans_lower in body_lower:
            failures.append(f"body leaks the reference answer ({question.answer!r}) verbatim")

    # ── Type-specific ──
    if question.question_type == QuestionType.mcq:
        failures.extend(_mcq_checks(question))

    return failures


def _mcq_checks(question: GeneratedQuestion) -> list[str]:
    """MCQ-specific anti-leakage and rule-compliance checks.

    The Sprint 3.7 prompt forbids these patterns but the model
    occasionally slips them through. Catching them here means a
    prompt-drift bug doesn't reach the student.
    """
    failures: list[str] = []

    for opt in question.options:
        for pat in _MCQ_LEAKAGE_PATTERNS:
            if pat.search(opt.text):
                failures.append(
                    f"MCQ option {opt.key!r} text leaks correctness ({pat.pattern!r} matched)"
                )
                break  # one match per option is enough

    for pat in _MCQ_BANNED_STEM_OPTIONS:
        for opt in question.options:
            if pat.search(opt.text):
                failures.append(f"MCQ option {opt.key!r} uses a banned phrase ({pat.pattern!r})")
                break

    return failures
