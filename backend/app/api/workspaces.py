"""Workspace CRUD endpoints.

A workspace is a classroom or family learning group. Only workspace admins
(teachers / parents) and tenant admins can manage them.
"""

from uuid import uuid4

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, EmailStr, Field
from app.core.auth import get_current_user, require_role, invalidate_user_cache
from app.core.database import WORKSPACES, get_collection
from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.base import utc_now
from app.models.user import User, UserRole, WorkspaceMembership, UserResponse
from app.models.workspace import (
    InviteCode,
    Workspace,
    WorkspaceCreate,
    WorkspaceResponse,
    WorkspaceUpdate,
)
from app.services.email import get_email_sender, EmailPayload
from app.services.email_templates import get_invite_email_html

router = APIRouter(prefix="/workspaces", tags=["workspaces"])


def _admin_roles() -> tuple[UserRole, ...]:
    return (UserRole.tenant_admin, UserRole.workspace_admin)


@router.post("/", response_model=WorkspaceResponse, status_code=status.HTTP_201_CREATED)
async def create_workspace(
    body: WorkspaceCreate,
    current_user: User = Depends(get_current_user),
) -> WorkspaceResponse:
    """Create a new workspace inside the caller's tenant."""
    if current_user.role == UserRole.student:
        raise ForbiddenError("Students are not allowed to create workspaces manually.")

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
    
    # Also update the creating user's workspace_memberships
    user_col = get_collection(current_user.tenant_id, "users")
    
    current_user.workspace_memberships.append(
        WorkspaceMembership(
            workspace_id=workspace.id,
            role=UserRole.workspace_admin,
            joined_at=utc_now(),
        )
    )
    current_user.touch()
    await user_col.replace_one({"_id": current_user.id}, current_user.model_dump(by_alias=True))
    await invalidate_user_cache(current_user)

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


# ── Add Workspace Member (Email Invite) ───────────────────────────────────────

class WorkspaceMemberAdd(BaseModel):
    email: EmailStr

@router.post("/{workspace_id}/members", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def add_workspace_member(
    workspace_id: str,
    body: WorkspaceMemberAdd,
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> UserResponse:
    """Invite a student to a workspace via email. 
    
    If the user does not exist, a placeholder user is created.
    An email containing a magic link is dispatched.
    """
    _assert_admin(current_user, workspace_id)
    wsp_col = get_collection(current_user.tenant_id, WORKSPACES)
    workspace_doc = await wsp_col.find_one({"_id": workspace_id, "deleted_at": None})
    if workspace_doc is None:
        raise NotFoundError("Workspace", workspace_id)
        
    workspace = Workspace.model_validate(workspace_doc)
    user_col = get_collection(current_user.tenant_id, "users")
    
    target_email = body.email.strip().lower()
    
    # 1. Lookup or create placeholder user
    user_doc = await user_col.find_one({"email": target_email, "deleted_at": None})
    if user_doc:
        user = User.model_validate(user_doc)
    else:
        user = User(
            **{"_id": f"usr_{uuid4().hex}"},
            tenant_id=current_user.tenant_id,
            email=target_email,
            display_name=target_email.split("@")[0],
            role=UserRole.student,
        )
        await user_col.insert_one(user.model_dump(by_alias=True))
        
    # 2. Add to workspace
    if user.id not in workspace.student_ids:
        workspace.student_ids.append(user.id)
        workspace.touch()
        await wsp_col.replace_one({"_id": workspace.id}, workspace.model_dump(by_alias=True))
        
    already_member = any(m.workspace_id == workspace.id for m in user.workspace_memberships)
    if not already_member:
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
        
    # 3. Dispatch Email
    from app.services.email import get_email_sender, EmailPayload
    from app.services.email_templates import get_invite_email_html
    import os
    
    sender = get_email_sender()
    magic_link = f"socialstudy://app/join?workspace={workspace.id}"
    
    plain_text = (
        f"Hi {user.display_name},\n\n"
        f"You have been invited to join the workspace '{workspace.name}' on Social Study.\n\n"
        f"Click the link below on your mobile device to accept the invitation and sign in:\n\n"
        f"{magic_link}\n\n"
        f"Welcome aboard!"
    )
    
    html_text = get_invite_email_html(user.display_name, workspace.name, magic_link)
    
    backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    project_root = os.path.dirname(backend_dir)
    logo_path = os.path.join(project_root, "flutter_app", "assets", "branding", "app_logo.jpg")
    
    await sender.send(EmailPayload(
        to_email=user.email,
        subject=f"You've been invited to {workspace.name}!",
        body_text=plain_text,
        body_html=html_text,
        logo_path=logo_path if os.path.exists(logo_path) else None
    ))
    
    return UserResponse.from_doc(user)




