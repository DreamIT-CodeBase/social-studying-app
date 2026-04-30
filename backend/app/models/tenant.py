"""Tenant model — top-level organisational unit (school or family)."""

from enum import StrEnum

from pydantic import EmailStr, Field

from app.models.base import CosmosDocument


class TenantType(StrEnum):
    school = "school"
    family = "family"


class TenantStatus(StrEnum):
    active = "active"
    suspended = "suspended"
    trial = "trial"


class TenantLimits(CosmosDocument.__base__):  # plain BaseModel, not a document
    max_workspaces: int = 10
    max_students_per_workspace: int = 35
    max_documents_per_workspace: int = 100
    max_questions_per_day: int = 50


class Tenant(CosmosDocument):
    """Stored in the platform-level 'tenants' database, 'tenants' collection."""

    name: str
    type: TenantType
    status: TenantStatus = TenantStatus.trial
    admin_email: EmailStr
    limits: TenantLimits = Field(default_factory=TenantLimits)
    subscription_expires_at: str | None = None


# ── Request / Response schemas ────────────────────────────────────────────────


class TenantCreate(CosmosDocument.__base__):
    name: str
    type: TenantType
    admin_email: EmailStr


class TenantResponse(CosmosDocument.__base__):
    id: str
    name: str
    type: TenantType
    status: TenantStatus
    admin_email: EmailStr
    created_at: str

    @classmethod
    def from_doc(cls, doc: Tenant) -> "TenantResponse":
        return cls(
            id=doc.id,
            name=doc.name,
            type=doc.type,
            status=doc.status,
            admin_email=doc.admin_email,
            created_at=doc.created_at,
        )
