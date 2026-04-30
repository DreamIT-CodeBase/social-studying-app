"""Workspace CRUD endpoints.

A workspace is a classroom or family learning group. Only workspace admins
(teachers / parents) and tenant admins can manage them.
"""

from uuid import uuid4

from fastapi import APIRouter, Depends, status

from app.core.auth import get_current_user, require_role
from app.core.database import WORKSPACES, get_collection
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.base import utc_now
from app.models.user import User, UserRole
from app.models.workspace import (
    InviteCode,
    Workspace,
    WorkspaceCreate,
    WorkspaceResponse,
    WorkspaceUpdate,
)

router = APIRouter(prefix="/workspaces", tags=["workspaces"])


def _admin_roles() -> tuple[UserRole, ...]:
    return (UserRole.tenant_admin, UserRole.workspace_admin)


@router.post("/", response_model=WorkspaceResponse, status_code=status.HTTP_201_CREATED)
async def create_workspace(
    body: WorkspaceCreate,
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> WorkspaceResponse:
    """Create a new workspace inside the caller's tenant."""
    col = get_collection(current_user.tenant_id, WORKSPACES)

    existing = await col.find_one(
        {"name": body.name, "tenant_id": current_user.tenant_id, "deleted_at": None}
    )
    if existing:
        raise ConflictError(f"Workspace '{body.name}' already exists in this tenant")

    workspace = Workspace(
        **{"_id": f"wsp_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        name=body.name,
        description=body.description,
        admin_ids=[current_user.id],
    )
    await col.insert_one(workspace.model_dump(by_alias=True))
    return WorkspaceResponse.from_doc(workspace)


@router.get("/", response_model=list[WorkspaceResponse])
async def list_workspaces(
    current_user: User = Depends(get_current_user),
) -> list[WorkspaceResponse]:
    """List workspaces the caller belongs to.

    Tenant admins see all workspaces; workspace admins and students see only theirs.
    """
    col = get_collection(current_user.tenant_id, WORKSPACES)

    if current_user.role == UserRole.tenant_admin:
        cursor = col.find({"tenant_id": current_user.tenant_id, "deleted_at": None})
    else:
        member_ids = [m.workspace_id for m in current_user.workspace_memberships]
        cursor = col.find({"_id": {"$in": member_ids}, "deleted_at": None})

    return [WorkspaceResponse.from_doc(Workspace.model_validate(doc)) async for doc in cursor]


@router.get("/{workspace_id}", response_model=WorkspaceResponse)
async def get_workspace(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> WorkspaceResponse:
    _assert_member(current_user, workspace_id)
    col = get_collection(current_user.tenant_id, WORKSPACES)
    doc = await col.find_one({"_id": workspace_id, "deleted_at": None})
    if doc is None:
        raise NotFoundError("Workspace", workspace_id)
    return WorkspaceResponse.from_doc(Workspace.model_validate(doc))


@router.patch("/{workspace_id}", response_model=WorkspaceResponse)
async def update_workspace(
    workspace_id: str,
    body: WorkspaceUpdate,
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> WorkspaceResponse:
    _assert_admin(current_user, workspace_id)
    col = get_collection(current_user.tenant_id, WORKSPACES)
    doc = await col.find_one({"_id": workspace_id, "deleted_at": None})
    if doc is None:
        raise NotFoundError("Workspace", workspace_id)

    workspace = Workspace.model_validate(doc)
    if body.name is not None:
        workspace.name = body.name
    if body.description is not None:
        workspace.description = body.description
    if body.settings is not None:
        workspace.settings = body.settings
    workspace.touch()

    await col.replace_one({"_id": workspace_id}, workspace.model_dump(by_alias=True))
    return WorkspaceResponse.from_doc(workspace)


@router.delete("/{workspace_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_workspace(
    workspace_id: str,
    current_user: User = Depends(require_role(UserRole.tenant_admin)),
) -> None:
    col = get_collection(current_user.tenant_id, WORKSPACES)
    result = await col.update_one(
        {"_id": workspace_id, "deleted_at": None},
        {"$set": {"deleted_at": utc_now(), "updated_at": utc_now()}},
    )
    if result.matched_count == 0:
        raise NotFoundError("Workspace", workspace_id)


# ── Invite code sub-resource ──────────────────────────────────────────────────


@router.post(
    "/{workspace_id}/invite-codes",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
)
async def generate_invite_code(
    workspace_id: str,
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> dict:
    """Generate a new invite code for students to join this workspace."""
    _assert_admin(current_user, workspace_id)
    col = get_collection(current_user.tenant_id, WORKSPACES)
    doc = await col.find_one({"_id": workspace_id, "deleted_at": None})
    if doc is None:
        raise NotFoundError("Workspace", workspace_id)

    workspace = Workspace.model_validate(doc)
    code = InviteCode(
        code=uuid4().hex[:8].upper(),
        created_by=current_user.id,
    )
    workspace.invite_codes.append(code)
    workspace.touch()
    await col.replace_one({"_id": workspace_id}, workspace.model_dump(by_alias=True))
    return {"code": code.code, "expires_at": code.expires_at, "max_uses": code.max_uses}


# ── Helpers ───────────────────────────────────────────────────────────────────


def _assert_member(user: User, workspace_id: str) -> None:
    """Raise ForbiddenError if the user has no membership in this workspace."""
    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")


def _assert_admin(user: User, workspace_id: str) -> None:
    """Raise ForbiddenError if the user is not an admin of this workspace."""
    if user.role == UserRole.tenant_admin:
        return
    admin_memberships = {
        m.workspace_id
        for m in user.workspace_memberships
        if m.role in (UserRole.workspace_admin, UserRole.tenant_admin)
    }
    if workspace_id not in admin_memberships:
        raise ForbiddenError("You do not have admin access to this workspace")
