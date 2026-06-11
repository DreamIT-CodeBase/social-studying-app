"""ModerationLog — audit trail for content safety decisions."""

from enum import StrEnum

from pydantic import Field

from app.models.base import CosmosDocument


class ModerationAction(StrEnum):
    approved = "approved"
    rejected = "rejected"
    flagged = "flagged"       # sent to human review
    auto_approved = "auto_approved"


class ModerationTarget(StrEnum):
    question = "question"
    document = "document"
    flashcard = "flashcard"


class SafetyCategory(StrEnum):
    """Azure Content Safety harm categories.

    Values match the SDK's ``TextCategory`` enum (lowercase) so the worker
    can serialize the analysis result directly without translation.
    """

    hate = "Hate"
    self_harm = "SelfHarm"
    sexual = "Sexual"
    violence = "Violence"


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
    azure_safety_score: float | None = None   # 0.0–1.0 — max severity normalized
    # Per-category severities returned by Azure Content Safety (0/2/4/6 on the
    # four-step scale). Empty dict for non-content-safety actions (e.g., admin
    # approval of a previously flagged item).
    severities: dict[str, int] = Field(default_factory=dict)
    # Categories whose severity crossed the configured threshold. Drives the
    # admin moderation UI ("flagged for Hate, Violence").
    flagged_categories: list[str] = Field(default_factory=list)
