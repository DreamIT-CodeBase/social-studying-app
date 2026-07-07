"""Flashcard model — Sprint 3.12.

Distinct from :class:`app.models.question.Question`: flashcards are
self-rated recall cues, not graded answers. The student sees the
front (a cue), tries to recall the back in their head, flips to see
the back, and then self-rates how well they did (easy / medium / hard).
There's no "correct" or "wrong" — just a confidence signal that
feeds a future spaced-repetition scheduler (Sprint 5/6 polish).

Why a separate collection, not a question type
----------------------------------------------
Two reasons:
1. The student-facing UI is fundamentally different (swipe + flip vs
   multi-choice / typed answer). Splitting the model keeps the
   shapes honest.
2. The grading shape is incompatible — questions have a single
   canonical answer; flashcards have a self-rating with no truth
   value. Smashing both into one schema would force the answer-eval
   pipeline to branch on type at every step.

Spaced repetition (deferred)
----------------------------
v1 stores rating events in their own append-only collection
(``flashcard_ratings``). Sprint 5/6 polish will:
- Aggregate ratings per (student, flashcard) into a confidence row.
- Compute ``next_due_at`` from ease factor + interval (SM-2 or
  similar).
- Bias :func:`Flashcard` selection toward due cards.

For now, ``GET /flashcards/next`` just picks an approved flashcard the
student hasn't seen recently. The rating endpoint records the event
for the future scheduler.
"""

from enum import StrEnum

from pydantic import Field

from app.models.base import CosmosDocument


class FlashcardStatus(StrEnum):
    """Same state machine as :class:`app.models.question.QuestionStatus`."""

    pending_review = "pending_review"
    approved = "approved"
    rejected = "rejected"
    flagged = "flagged"


class FlashcardRating(StrEnum):
    """Self-rating values the student submits via ``/flashcards/{id}/rate``.

    Three buckets matches the established flashcard UX (SuperMemo /
    Anki / Quizlet all use either 3 or 4 buckets; 3 is the smaller
    cognitive load on the student).
    """

    easy = "easy"          # recalled instantly, push out the next review
    medium = "medium"      # recalled with some effort
    hard = "hard"          # didn't recall, surface again soon


class Flashcard(CosmosDocument):
    """Partition key: workspace_id.

    Stored in the tenant's database, ``flashcards`` collection.
    """

    tenant_id: str
    workspace_id: str
    document_id: str       # source attribution (first grounding chunk's doc)
    topic: str             # display name
    front: str             # the cue side
    back: str              # the recall target
    explanation: str = ""  # optional extra context shown after the rating
    source_chunk_ids: list[str] = Field(default_factory=list)
    status: FlashcardStatus = FlashcardStatus.pending_review
    prompt_version: str = "v1.0"
    moderation_flagged: bool = False
    times_served: int = 0


class FlashcardRatingEvent(CosmosDocument):
    """Append-only rating record. Partition key: ``student_id``.

    Stored in the tenant's database, ``flashcard_ratings`` collection.
    One row per rating submission — no updates. Sprint 5/6's SRS will
    aggregate over these.
    """

    tenant_id: str
    workspace_id: str
    student_id: str
    flashcard_id: str
    topic: str
    rating: FlashcardRating
    rated_at: str          # ISO 8601 UTC
    selected_option: str | None = None
    is_correct: bool | None = None
    response_time_ms: int | None = None
    session_progress: int | None = None
    accuracy_percentage: float | None = None


# ── Request / Response schemas ────────────────────────────────────────────────


class FlashcardForStudent(CosmosDocument.__base__):
    """The student-facing view of a flashcard.

    Includes BOTH ``front`` and ``back`` (and ``explanation``) — unlike
    :class:`app.models.question.QuestionForStudent`, flashcards reveal
    everything up front. The student is self-rating their recall, not
    being tested against a hidden answer.
    """

    id: str
    topic: str
    front: str
    back: str
    explanation: str

    @classmethod
    def from_doc(cls, doc: "Flashcard") -> "FlashcardForStudent":
        return cls(
            id=doc.id,
            topic=doc.topic,
            front=doc.front,
            back=doc.back,
            explanation=doc.explanation,
        )


class FlashcardRatingSubmission(CosmosDocument.__base__):
    """Request body for ``POST /flashcards/{id}/rate``."""

    rating: FlashcardRating
    selected_option: str | None = None
    is_correct: bool | None = None
    response_time_ms: int | None = None
    session_progress: int | None = None
    accuracy_percentage: float | None = None


class FlashcardRatingBadgeUnlock(CosmosDocument.__base__):
    """Wire shape for a freshly-earned badge on a flashcard rating.

    Mirrors :class:`app.models.gamification.Badge` and
    :class:`app.models.question.BadgeUnlock`. Kept separate from those
    so the flashcard response schema stays self-contained.
    """

    badge_id: str
    name: str
    description: str
    icon: str


class FlashcardRatingResponse(CosmosDocument.__base__):
    """Response body for ``POST /flashcards/{id}/rate``.

    Echoes back the stored rating + timestamp so the UI can update its
    local state without a separate fetch. Sprint 5 added the
    gamification block (XP, level, streak, badge unlocks) so the
    celebration UI fires on flashcard reviews too.
    """

    flashcard_id: str
    rating: FlashcardRating
    rated_at: str

    # ── Sprint 5 gamification ─────────────────────────────────────────
    xp_earned: int = 0
    new_level: int = 1
    leveled_up: bool = False
    streak_days: int = 0
    streak_extended: bool = False
    badges_unlocked: list[FlashcardRatingBadgeUnlock] = []
