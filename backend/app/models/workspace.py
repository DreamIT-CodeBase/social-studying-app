"""Workspace model — a classroom or family learning group within a tenant."""

from pydantic import Field

from app.models.base import CosmosDocument, utc_now


class WorkspaceSettings(CosmosDocument.__base__):
    questions_per_day: int = 5
    question_types: list[str] = Field(default_factory=lambda: ["mcq", "short_answer"])
    auto_approve_content: bool = True
    leaderboard_visible: bool = True
    adaptive_difficulty: bool = True


class InviteCode(CosmosDocument.__base__):
    code: str
    created_by: str  # user_id of creator
    created_at: str = Field(default_factory=utc_now)
    expires_at: str | None = None
    max_uses: int = 30
    use_count: int = 0
    is_active: bool = True


class Workspace(CosmosDocument):
    """Partition key: workspace_id (self).

    Stored in the tenant's database, 'workspaces' collection.
    """

    tenant_id: str
    name: str
    description: str = ""
    admin_ids: list[str] = Field(default_factory=list)   # user_ids with workspace_admin role
    student_ids: list[str] = Field(default_factory=list)
    settings: WorkspaceSettings = Field(default_factory=WorkspaceSettings)
    invite_codes: list[InviteCode] = Field(default_factory=list)
    document_count: int = 0
    is_active: bool = True


# ── Request / Response schemas ────────────────────────────────────────────────


class WorkspaceCreate(CosmosDocument.__base__):
    name: str
    description: str = ""


class WorkspaceUpdate(CosmosDocument.__base__):
    name: str | None = None
    description: str | None = None
    settings: WorkspaceSettings | None = None


class WorkspaceResponse(CosmosDocument.__base__):
    id: str
    tenant_id: str
    name: str
    description: str
    admin_count: int
    student_count: int
    document_count: int
    settings: WorkspaceSettings
    is_active: bool
    created_at: str

    @classmethod
    def from_doc(cls, doc: Workspace) -> "WorkspaceResponse":
        return cls(
            id=doc.id,
            tenant_id=doc.tenant_id,
            name=doc.name,
            description=doc.description,
            admin_count=len(doc.admin_ids),
            student_count=len(doc.student_ids),
            document_count=doc.document_count,
            settings=doc.settings,
            is_active=doc.is_active,
            created_at=doc.created_at,
        )
