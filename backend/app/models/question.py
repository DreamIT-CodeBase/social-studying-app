"""Question model — AI-generated question stored in the question queue."""

from enum import StrEnum

from pydantic import Field

from app.models.base import CosmosDocument


class QuestionType(StrEnum):
    mcq = "mcq"                    # multiple choice
    short_answer = "short_answer"
    true_false = "true_false"


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
    options: list[McqOption] = Field(default_factory=list)  # populated for MCQ
    answer: str                    # correct answer text (or key for MCQ)
    explanation: str = ""
    source_chunk_ids: list[str] = Field(default_factory=list)
    status: QuestionStatus = QuestionStatus.pending_review
    prompt_version: str = "v1.0"   # tracks which prompt generated this question
    moderation_flagged: bool = False
    times_served: int = 0


class QuestionResponse(CosmosDocument.__base__):
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
