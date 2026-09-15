"""User management API — direct creation and invite-code redemption.

Direct creation (tenant admin only): used to bulk-import teachers / students.
Invite code redemption: the self-service path where a student joins via a code.
"""

from uuid import uuid4

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from app.core.auth import get_current_user, invalidate_user_cache, require_role
from app.core.database import USERS, WORKSPACES, get_collection
from app.core.exceptions import ConflictError, NotFoundError, ValidationError
from app.models.base import utc_now
from app.models.user import User, UserCreate, UserResponse, UserRole, WorkspaceMembership
from app.models.workspace import InviteCode, Workspace

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    body: UserCreate,
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> UserResponse:
    """Directly create a user in the caller's tenant.

    Students created this way still need to redeem an invite code to join a workspace.
    """
    col = get_collection(current_user.tenant_id, USERS)
    existing = await col.find_one({"email": body.email, "deleted_at": None})
    if existing:
        raise ConflictError(f"User with email '{body.email}' already exists")

    user = User(
        **{"_id": f"usr_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        email=body.email,
        display_name=body.display_name,
        role=body.role,
    )
    await col.insert_one(user.model_dump(by_alias=True))
    return UserResponse.from_doc(user)


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)) -> UserResponse:
    """Return the authenticated caller's own profile."""
    response = UserResponse.from_doc(current_user)
    if current_user.role != UserRole.student:
        response.workspace_memberships = [
            membership
            for membership in response.workspace_memberships
            if not membership.workspace_id.startswith("wsp_self_")
        ]
    return response


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> UserResponse:
    """Fetch any user within the caller's tenant."""
    col = get_collection(current_user.tenant_id, USERS)
    doc = await col.find_one({"_id": user_id, "deleted_at": None})
    if doc is None:
        raise NotFoundError("User", user_id)
    return UserResponse.from_doc(User.model_validate(doc))


@router.get("/", response_model=list[UserResponse])
async def list_users(
    workspace_id: str | None = None,
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> list[UserResponse]:
    """List users in the caller's tenant, optionally filtered by workspace."""
    col = get_collection(current_user.tenant_id, USERS)
    query: dict = {"tenant_id": current_user.tenant_id, "deleted_at": None}

    if current_user.role == UserRole.workspace_admin:
        admin_wsp_ids = [
            m.workspace_id
            for m in current_user.workspace_memberships
            if m.role == UserRole.workspace_admin
        ]

        if workspace_id is not None:
            if workspace_id not in admin_wsp_ids:
                from app.core.exceptions import ForbiddenError

                raise ForbiddenError("You do not have access to view users in this workspace")
            query["workspace_memberships"] = {"$elemMatch": {"workspace_id": workspace_id}}
        else:
            query["workspace_memberships"] = {
                "$elemMatch": {"workspace_id": {"$in": admin_wsp_ids}}
            }
    else:
        if workspace_id is not None:
            query["workspace_memberships"] = {"$elemMatch": {"workspace_id": workspace_id}}

    cursor = col.find(query)
    return [UserResponse.from_doc(User.model_validate(doc)) async for doc in cursor]


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def deactivate_user(
    user_id: str,
    current_user: User = Depends(require_role(UserRole.tenant_admin)),
) -> None:
    """Soft-delete a user (sets deleted_at). Auth cache will expire within 5 minutes."""
    col = get_collection(current_user.tenant_id, USERS)
    user_doc = await col.find_one({"_id": user_id, "deleted_at": None})
    if user_doc is None:
        raise NotFoundError("User", user_id)

    user = User.model_validate(user_doc)

    result = await col.update_one(
        {"_id": user_id, "deleted_at": None},
        {"$set": {"deleted_at": utc_now(), "updated_at": utc_now(), "is_active": False}},
    )
    if result.matched_count == 0:
        raise NotFoundError("User", user_id)

    # Remove user from all their workspaces
    wsp_col = get_collection(current_user.tenant_id, "workspaces")
    for membership in user.workspace_memberships:
        await wsp_col.update_one(
            {"_id": membership.workspace_id},
            {"$pull": {"student_ids": user_id, "admin_ids": user_id}},
        )
    await invalidate_user_cache(user)


# ── Invite code redemption ────────────────────────────────────────────────────


class InviteCodeBody(BaseModel):
    code: str


@router.post("/join", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def redeem_invite_code(
    body: InviteCodeBody,
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    """Student redeems an invite code to join a workspace.

    Finds the workspace that owns the code, validates it, and adds the student
    to both the workspace's student_ids list and the user's workspace_memberships.
    """
    wsp_col = get_collection(current_user.tenant_id, WORKSPACES)
    workspace_doc = await wsp_col.find_one(
        {
            "invite_codes": {"$elemMatch": {"code": body.code, "is_active": True}},
            "deleted_at": None,
        }
    )
    if workspace_doc is None:
        raise ValidationError("Invalid or expired invite code")

    workspace = Workspace.model_validate(workspace_doc)

    # Find and validate the matching code
    matching: InviteCode | None = next(
        (c for c in workspace.invite_codes if c.code == body.code and c.is_active), None
    )
    if matching is None:
        raise ValidationError("Invalid or expired invite code")

    if matching.max_uses > 0 and matching.use_count >= matching.max_uses:
        raise ValidationError("Invite code has reached its maximum uses")

    already_member = any(m.workspace_id == workspace.id for m in current_user.workspace_memberships)
    if already_member:
        raise ConflictError("You are already a member of this workspace")

    # Update workspace
    matching.use_count += 1
    if matching.use_count >= matching.max_uses:
        matching.is_active = False

    if current_user.id not in workspace.student_ids:
        workspace.student_ids.append(current_user.id)
    workspace.touch()
    await wsp_col.replace_one({"_id": workspace.id}, workspace.model_dump(by_alias=True))

    # Update user membership
    user_col = get_collection(current_user.tenant_id, USERS)
    user_doc = await user_col.find_one({"_id": current_user.id})
    if user_doc is None:
        raise NotFoundError("User", current_user.id)

    user = User.model_validate(user_doc)
    user.workspace_memberships.append(
        WorkspaceMembership(
            workspace_id=workspace.id,
            role=UserRole.student,
            joined_at=utc_now(),
        )
    )
    user.touch()
    await user_col.replace_one({"_id": user.id}, user.model_dump(by_alias=True))
    await invalidate_user_cache(user)
    return UserResponse.from_doc(user)
