"""ModerationLog — audit trail for content safety decisions."""

from enum import StrEnum

from app.models.base import CosmosDocument


class ModerationAction(StrEnum):
    approved = "approved"
    rejected = "rejected"
    flagged = "flagged"       # sent to human review
    auto_approved = "auto_approved"


class ModerationTarget(StrEnum):
    question = "question"
    document = "document"


class ModerationLog(CosmosDocument):
    """Append-only audit log entry.

    Partition key: target_id.
    Stored in the tenant's database, 'moderation_log' collection.
    """

    tenant_id: str
    workspace_id: str
    target_type: ModerationTarget
    target_id: str
    action: ModerationAction
    performed_by: str              # user_id or "system"
    reason: str = ""
    azure_safety_score: float | None = None   # 0.0–1.0 from Azure Content Safety
