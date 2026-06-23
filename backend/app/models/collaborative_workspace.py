"""Models for Collaborative Workspaces."""

from __future__ import annotations
from enum import StrEnum
from pydantic import Field, EmailStr
from app.models.base import CosmosDocument, utc_now

class WorkspaceRole(StrEnum):
    owner = "owner"
    editor = "editor"
    viewer = "viewer"

class WorkspaceMember(CosmosDocument):
    """Partition key: workspace_id."""
    tenant_id: str
    workspace_id: str
    user_id: str
    role: WorkspaceRole = WorkspaceRole.viewer
    joined_at: str = Field(default_factory=utc_now)
    invited_by: str | None = None

class InvitationStatus(StrEnum):
    pending = "pending"
    accepted = "accepted"
    expired = "expired"
    revoked = "revoked"

class WorkspaceInvitation(CosmosDocument):
    """Partition key: workspace_id."""
    tenant_id: str
    workspace_id: str
    inviter_id: str
    invitee_email: EmailStr | None = None
    invitee_username: str | None = None
    invite_link_token: str | None = None
    join_code: str | None = None
    role: WorkspaceRole = WorkspaceRole.viewer
    status: InvitationStatus = InvitationStatus.pending
    expires_at: str

class WorkspaceActivityType(StrEnum):
    member_joined = "member_joined"
    member_left = "member_left"
    role_changed = "role_changed"
    document_uploaded = "document_uploaded"
    flashcards_generated = "flashcards_generated"
    questions_generated = "questions_generated"
    chat_message = "chat_message"

class WorkspaceActivityLog(CosmosDocument):
    """Partition key: workspace_id."""
    tenant_id: str
    workspace_id: str
    user_id: str
    user_name: str
    activity_type: WorkspaceActivityType
    details: dict = Field(default_factory=dict)

class WorkspaceMessage(CosmosDocument):
    """Partition key: workspace_id."""
    tenant_id: str
    workspace_id: str
    sender_id: str
    sender_name: str
    content: str
    attachments: list[str] = Field(default_factory=list)
