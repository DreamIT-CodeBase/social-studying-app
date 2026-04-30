"""Tenant CRUD endpoints.

Tenants are the top-level organisational unit (a school or a family).
Only system admins create tenants; this API is intentionally minimal for Sprint 1.
"""

from uuid import uuid4

from fastapi import APIRouter, Depends, status

from app.core.auth import get_current_user, require_role
from app.core.database import get_collection
from app.core.exceptions import ConflictError, NotFoundError
from app.models.base import utc_now
from app.models.tenant import Tenant, TenantCreate, TenantResponse
from app.models.user import User, UserRole

# Tenants are stored in a dedicated platform database, not inside a tenant shard.
_PLATFORM_DB = "platform"
_TENANTS = "tenants"

router = APIRouter(prefix="/tenants", tags=["tenants"])


@router.post("/", response_model=TenantResponse, status_code=status.HTTP_201_CREATED)
async def create_tenant(
    body: TenantCreate,
    _: User = Depends(require_role(UserRole.tenant_admin)),
) -> TenantResponse:
    """Create a new tenant.

    Checks for duplicate email before inserting.
    """
    col = get_collection(_PLATFORM_DB, _TENANTS)

    existing = await col.find_one({"admin_email": body.admin_email, "deleted_at": None})
    if existing:
        raise ConflictError(f"A tenant with admin email '{body.admin_email}' already exists")

    tenant = Tenant(
        **{"_id": f"ten_{uuid4().hex}"},
        name=body.name,
        type=body.type,
        admin_email=body.admin_email,
    )
    await col.insert_one(tenant.model_dump(by_alias=True))
    return TenantResponse.from_doc(tenant)


@router.get("/{tenant_id}", response_model=TenantResponse)
async def get_tenant(
    tenant_id: str,
    current_user: User = Depends(get_current_user),
) -> TenantResponse:
    """Fetch a single tenant.

    Users may only read their own tenant; tenant admins have no cross-tenant visibility.
    """
    if current_user.tenant_id != tenant_id:
        raise NotFoundError("Tenant", tenant_id)

    col = get_collection(_PLATFORM_DB, _TENANTS)
    doc = await col.find_one({"_id": tenant_id, "deleted_at": None})
    if doc is None:
        raise NotFoundError("Tenant", tenant_id)

    return TenantResponse.from_doc(Tenant.model_validate(doc))


@router.delete("/{tenant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tenant(
    tenant_id: str,
    current_user: User = Depends(require_role(UserRole.tenant_admin)),
) -> None:
    """Soft-delete a tenant. Irreversible via API — requires manual data cleanup."""
    if current_user.tenant_id != tenant_id:
        raise NotFoundError("Tenant", tenant_id)

    col = get_collection(_PLATFORM_DB, _TENANTS)
    result = await col.update_one(
        {"_id": tenant_id, "deleted_at": None},
        {"$set": {"deleted_at": utc_now(), "updated_at": utc_now()}},
    )
    if result.matched_count == 0:
        raise NotFoundError("Tenant", tenant_id)
