"""User model — stored in each tenant's database, 'users' collection."""

from enum import StrEnum

from pydantic import EmailStr, Field

from app.models.base import CosmosDocument


class UserRole(StrEnum):
    tenant_admin = "tenant_admin"
    workspace_admin = "workspace_admin"  # teacher in a school, parent in a family
    student = "student"


class WorkspaceMembership(CosmosDocument.__base__):
    workspace_id: str
    role: UserRole
    joined_at: str


class User(CosmosDocument):
    """Partition key: user_id (self)."""

    tenant_id: str
    email: EmailStr
    display_name: str
    b2c_object_id: str | None = None  # populated once B2C auth is wired
    role: UserRole
    workspace_memberships: list[WorkspaceMembership] = Field(default_factory=list)
    subscription_id: str | None = None
    last_login_at: str | None = None
    is_active: bool = True


# ── Request / Response schemas ────────────────────────────────────────────────


class UserCreate(CosmosDocument.__base__):
    email: EmailStr
    display_name: str
    role: UserRole


class UserResponse(CosmosDocument.__base__):
    id: str
    tenant_id: str
    email: EmailStr
    display_name: str
    role: UserRole
    workspace_memberships: list[WorkspaceMembership] = Field(default_factory=list)
    subscription_id: str | None = None
    is_active: bool
    created_at: str

    @classmethod
    def from_doc(cls, doc: User) -> "UserResponse":
        return cls(
            id=doc.id,
            tenant_id=doc.tenant_id,
            email=doc.email,
            display_name=doc.display_name,
            role=doc.role,
            workspace_memberships=doc.workspace_memberships,
            subscription_id=doc.subscription_id,
            is_active=doc.is_active,
            created_at=doc.created_at,
        )

