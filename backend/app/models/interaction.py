"""Interaction — a single student answer to a question."""

from pydantic import Field

from app.models.base import CosmosDocument


class Interaction(CosmosDocument):
    """Append-only interaction log. Never updated after write.

    Partition key: student_id.
    Stored in the tenant's database, 'interactions' collection.
    """

    tenant_id: str
    workspace_id: str
    student_id: str
    question_id: str
    topic: str
    is_correct: bool
    answer_given: str
    time_spent_seconds: int = Field(ge=0, default=0)
    xp_earned: int = 0
    answered_at: str          # ISO 8601 UTC
