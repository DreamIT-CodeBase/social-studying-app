"""KnowledgeState — precomputed per-student topic mastery summary.

Updated asynchronously after each interaction; never aggregated live.
"""

from pydantic import Field

from app.models.base import CosmosDocument


class TopicMastery(CosmosDocument.__base__):
    topic: str
    mastery_score: float = Field(ge=0.0, le=1.0, default=0.0)
    questions_attempted: int = 0
    questions_correct: int = 0
    last_seen_at: str | None = None

    @property
    def accuracy(self) -> float:
        if self.questions_attempted == 0:
            return 0.0
        return self.questions_correct / self.questions_attempted


class KnowledgeState(CosmosDocument):
    """One document per student per workspace.

    Partition key: student_id.
    Stored in the tenant's database, 'knowledge_states' collection.
    """

    tenant_id: str
    workspace_id: str
    student_id: str
    topics: list[TopicMastery] = Field(default_factory=list)
    overall_mastery: float = Field(ge=0.0, le=1.0, default=0.0)
    last_recalculated_at: str | None = None
