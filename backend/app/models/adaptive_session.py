"""Wire models for fully prepared adaptive study sessions.

The prepare endpoint intentionally returns the complete session payload,
including answer keys and explanations.  The authenticated mobile client keeps
that payload in memory so advancing between items never requires a network
request.  The completion endpoint remains authoritative for grading, accuracy,
mastery, and permanent XP.
"""

from enum import StrEnum

from pydantic import BaseModel, Field

from app.models.flashcard import FlashcardRating
from app.models.question import DifficultyLevel, QuestionType


class AdaptiveSessionMode(StrEnum):
    study = "study"
    revision = "revision"
    flashcard = "flashcard"


class AdaptiveLevel(StrEnum):
    beginner = "beginner"
    intermediate = "intermediate"
    expert = "expert"


class SessionCompletionReason(StrEnum):
    completed = "completed"
    timed_out = "timed_out"
    exited = "exited"


class PreparedOption(BaseModel):
    key: str
    text: str


class PreparedQuestion(BaseModel):
    id: str
    topic: str
    question_type: QuestionType
    difficulty: DifficultyLevel
    body: str
    options: list[PreparedOption] = Field(default_factory=list)
    answer: str
    explanation: str = ""
    grading_hints: list[str] = Field(default_factory=list)


class PreparedFlashcard(BaseModel):
    id: str
    topic: str
    front: str
    back: str
    explanation: str = ""


class AdaptiveSessionPlan(BaseModel):
    session_id: str
    mode: AdaptiveSessionMode
    level: AdaptiveLevel
    mastery_score: float = Field(ge=0.0, le=1.0)
    duration_minutes: int = Field(gt=0)
    item_count: int = Field(gt=0)
    estimated_xp_min: int
    estimated_xp_max: int
    questions: list[PreparedQuestion] = Field(default_factory=list)
    flashcards: list[PreparedFlashcard] = Field(default_factory=list)
    content_ready: bool = True


class PrepareAdaptiveSessionRequest(BaseModel):
    mode: AdaptiveSessionMode = AdaptiveSessionMode.study


class SessionQuestionAttempt(BaseModel):
    question_id: str
    answer: str = Field(min_length=1, max_length=4000)
    time_spent_seconds: int = Field(default=0, ge=0, le=3600)


class EvaluateAdaptiveAnswerRequest(BaseModel):
    question_id: str
    answer: str = Field(min_length=1, max_length=4000)


class AdaptiveAnswerEvaluation(BaseModel):
    is_correct: bool
    canonical_answer: str
    rubric_score: float | None = Field(default=None, ge=0.0, le=1.0)
    matched_hints: list[str] = Field(default_factory=list)


class SessionFlashcardAttempt(BaseModel):
    flashcard_id: str
    rating: FlashcardRating
    response_time_ms: int = Field(default=0, ge=0, le=3_600_000)


class CompleteAdaptiveSessionRequest(BaseModel):
    completion_reason: SessionCompletionReason = SessionCompletionReason.completed
    elapsed_seconds: int = Field(default=0, ge=0, le=7200)
    question_attempts: list[SessionQuestionAttempt] = Field(default_factory=list)
    flashcard_attempts: list[SessionFlashcardAttempt] = Field(default_factory=list)


class SessionAchievementUnlock(BaseModel):
    badge_id: str
    name: str
    description: str
    icon: str
    xp_reward: int = 0


class AdaptiveSessionSummary(BaseModel):
    session_id: str
    mode: AdaptiveSessionMode
    status: SessionCompletionReason
    planned_count: int
    completed_count: int
    correct_count: int = 0
    wrong_count: int = 0
    remembered_count: int = 0
    needs_review_count: int = 0
    accuracy_percentage: float | None = Field(default=None, ge=0.0, le=100.0)
    xp_gained: int = 0
    action_xp: int = 0
    completion_bonus: int = 0
    achievement_xp: int = 0
    achievements_unlocked: list[SessionAchievementUnlock] = Field(default_factory=list)
    mastery_before: float = Field(ge=0.0, le=1.0)
    mastery_after: float = Field(ge=0.0, le=1.0)
    level: AdaptiveLevel
    gamification_level: int = Field(default=1, ge=1)
    elapsed_seconds: int = Field(default=0, ge=0)
    performance_message: str
    completed_at: str
