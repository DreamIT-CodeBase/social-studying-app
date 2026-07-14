"""Question model — AI-generated question stored in the question queue."""

from enum import StrEnum

from pydantic import Field

from app.models.base import CosmosDocument


class QuestionType(StrEnum):
    """Question formats the generator can produce.

    Sprint 3.7 calibrated five prompts: MCQ + short_answer + long_answer +
    true_false + mathematical. Adding a new type means a new prompt file
    in ``app/prompts/`` AND a new dispatch row in
    :mod:`app.services.question_generation`.
    """

    mcq = "mcq"  # multiple choice (4 options, 1 correct)
    short_answer = "short_answer"  # 1-10 word factual recall
    long_answer = "long_answer"  # essay-style, show your reasoning
    true_false = "true_false"  # boolean with explanation
    mathematical = "mathematical"  # LaTeX-aware computational, with solution steps


class DifficultyLevel(StrEnum):
    beginner = "beginner"
    intermediate = "intermediate"
    advanced = "advanced"


class QuestionStatus(StrEnum):
    pending_review = "pending_review"  # waiting for admin moderation
    approved = "approved"
    rejected = "rejected"


class McqOption(CosmosDocument.__base__):
    key: str  # "A", "B", "C", "D"
    text: str
    is_correct: bool


class Question(CosmosDocument):
    """Partition key: workspace_id.

    Stored in the tenant's database, 'question_queue' collection.
    """

    tenant_id: str
    workspace_id: str
    document_id: str
    topic: str
    question_type: QuestionType
    difficulty: DifficultyLevel
    body: str
    options: list[McqOption] = Field(default_factory=list)  # populated for MCQ only
    answer: str  # correct answer text (or key for MCQ; "true"/"false" for T/F)
    explanation: str = ""
    # ── Per-type grading hints (Sprint 3.7) ──────────────────────────────────
    # Generic list whose semantics depend on ``question_type``:
    #   - short_answer: acceptable case-insensitive answer variants for matching
    #   - long_answer:  rubric key points the evaluator looks for
    #   - mathematical: solution steps (LaTeX-aware) the evaluator can check
    #   - mcq / true_false: empty (the option list / boolean is the full grading rubric)
    # Single field keeps Cosmos schema flat; Sprint 3.10's evaluator
    # branches on question_type to interpret the contents.
    grading_hints: list[str] = Field(default_factory=list)
    source_chunk_ids: list[str] = Field(default_factory=list)
    status: QuestionStatus = QuestionStatus.pending_review
    prompt_version: str = "v1.0"  # tracks which prompt generated this question
    moderation_flagged: bool = False
    times_served: int = 0
    # ── Sprint 3.13: prefetch ─────────────────────────────────────────────────
    # When non-null, this question was generated in advance for the named
    # student via the answer-endpoint's background-task prefetch. The /next
    # endpoint pops the field (atomic find-and-update to null) before
    # serving so two concurrent /next calls can't both consume the same
    # prefetched row. None = live-generated, no reserved consumer.
    prefetched_for: str | None = None

    # ── Sprint 5.12: unanswered queue ─────────────────────────────────────────
    # A student saw this question, declined to answer it, and asked to
    # see it again later. ``deferred_for`` is the student id; the
    # ``deferred_until`` ISO 8601 UTC timestamp is the earliest the
    # scheduler may fire an ``unanswered_reprompt`` push for it. After
    # the push fires the scheduler clears ``deferred_until`` so the
    # student is only nudged once per defer. ``defer_count`` tracks how
    # many times the student has skipped this same question across
    # sessions — three+ skips drops it from the rotation entirely
    # (treated as a topic the student isn't ready for).
    deferred_for: str | None = None
    deferred_until: str | None = None
    defer_count: int = 0


class StudentMcqOption(CosmosDocument.__base__):
    """MCQ option as the student sees it — ``is_correct`` removed.

    A trivial projection of :class:`McqOption` with the answer-revealing
    field stripped. The /questions/next endpoint uses this so the
    correct answer isn't shipped to the client before the student
    submits their attempt.
    """

    key: str
    text: str


class QuestionForStudent(CosmosDocument.__base__):
    """The student-facing view of a question.

    Excludes the fields that would reveal the answer before the student
    submits their attempt:

    - ``answer``, ``explanation``, ``grading_hints`` — the answer +
      reasoning, surfaced only by ``POST /questions/{id}/answer``.
    - ``McqOption.is_correct`` per-option — replaced by
      :class:`StudentMcqOption` which omits that field.

    Includes everything the UI legitimately needs: stem, options,
    topic + difficulty labels, type for rendering.
    """

    id: str
    topic: str
    question_type: QuestionType
    difficulty: DifficultyLevel
    body: str
    options: list[StudentMcqOption] = Field(default_factory=list)

    @classmethod
    def from_doc(cls, doc: "Question") -> "QuestionForStudent":
        return cls(
            id=doc.id,
            topic=doc.topic,
            question_type=doc.question_type,
            difficulty=doc.difficulty,
            body=doc.body,
            options=[StudentMcqOption(key=o.key, text=o.text) for o in doc.options],
        )


class AnswerSubmission(CosmosDocument.__base__):
    """Request body for ``POST /questions/{question_id}/answer``.

    ``answer`` is the student's response in the type-specific format:
    - mcq:           option key — ``"A"``, ``"B"``, ``"C"``, or ``"D"``
    - true_false:    ``"true"`` or ``"false"`` (case-insensitive)
    - short_answer:  the 1-10 word recall response
    - long_answer:   the essay-style response
    - mathematical:  the final answer (LaTeX OK)

    ``time_spent_seconds`` is optional and feeds the gamification XP
    boost in Sprint 5. Defaults to 0 when the client doesn't track it.
    """

    answer: str = Field(min_length=1, max_length=4000)
    time_spent_seconds: int = Field(default=0, ge=0, le=3600)


class BadgeUnlock(CosmosDocument.__base__):
    """Wire shape for a freshly-earned badge on an answer response.

    Mirrors :class:`app.models.gamification.Badge` but lives here so
    the answer-endpoint response stays self-contained. Sprint 5.5
    celebration UI reads this to render the badge unlock modal.
    """

    badge_id: str
    name: str
    description: str
    icon: str
    xp_reward: int = 0


class AnswerFeedback(CosmosDocument.__base__):
    """Response body for ``POST /questions/{question_id}/answer``.

    Surfaces correctness, the canonical answer, the explanation
    (revealed only AFTER submission), the XP awarded, the rubric score
    (rubric-scored types only), and a Sprint 5 gamification block: the
    student's new level, whether they just levelled up, their current
    streak length, whether the streak grew today, and any newly-earned
    badges.
    """

    question_id: str
    is_correct: bool
    canonical_answer: str
    explanation: str
    xp_earned: int
    new_topic_mastery: float = Field(ge=0.0, le=1.0)
    new_overall_mastery: float = Field(ge=0.0, le=1.0)
    rubric_score: float | None = Field(default=None, ge=0.0, le=1.0)
    matched_hints: list[str] = Field(default_factory=list)

    # ── Sprint 5 gamification ─────────────────────────────────────────
    new_level: int = Field(default=1, ge=1)
    leveled_up: bool = False
    streak_days: int = Field(default=0, ge=0)
    streak_extended: bool = False
    badges_unlocked: list[BadgeUnlock] = Field(default_factory=list)


class QuestionResponse(CosmosDocument.__base__):
    """Admin-facing question view — includes the answer + explanation.

    Used by admin endpoints (moderation review, question queue listing)
    where the answer is legitimately viewable. NEVER returned from
    student-facing endpoints — use :class:`QuestionForStudent` instead.
    """

    id: str
    workspace_id: str
    topic: str
    question_type: QuestionType
    difficulty: DifficultyLevel
    body: str
    options: list[McqOption]
    answer: str
    explanation: str
    status: QuestionStatus
    created_at: str

    @classmethod
    def from_doc(cls, doc: Question) -> "QuestionResponse":
        return cls(
            id=doc.id,
            workspace_id=doc.workspace_id,
            topic=doc.topic,
            question_type=doc.question_type,
            difficulty=doc.difficulty,
            body=doc.body,
            options=doc.options,
            answer=doc.answer,
            explanation=doc.explanation,
            status=doc.status,
            created_at=doc.created_at,
        )
