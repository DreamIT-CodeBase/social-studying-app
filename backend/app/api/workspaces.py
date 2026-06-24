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


# ── Collaborative Workspaces APIs ─────────────────────────────────────────────

from app.core.database import (
    COLLABORATIVE_WORKSPACES,
    WORKSPACE_MEMBERS,
    WORKSPACE_INVITATIONS,
    WORKSPACE_ACTIVITY_LOGS,
    WORKSPACE_MESSAGES,
)
from app.models.collaborative_workspace import (
    WorkspaceRole,
    WorkspaceMember,
    WorkspaceInvitation,
    WorkspaceActivityType,
    WorkspaceActivityLog,
    WorkspaceMessage,
    InvitationStatus,
)

async def _get_member_role(tenant_id: str, workspace_id: str, user_id: str) -> WorkspaceRole | str | None:
    wsp_col = get_collection(tenant_id, WORKSPACES)
    wsp = await wsp_col.find_one({"_id": workspace_id, "deleted_at": None})
    if not wsp:
        return None
    if wsp.get("type", "personal") == "personal":
        if user_id in wsp.get("admin_ids", []):
            return "owner"
        elif user_id in wsp.get("student_ids", []):
            return "editor"
        return None
    
    members_col = get_collection(tenant_id, WORKSPACE_MEMBERS)
    member = await members_col.find_one({"workspace_id": workspace_id, "user_id": user_id, "deleted_at": None})
    return member.get("role") if member else None

async def _assert_collaborative_owner(tenant_id: str, workspace_id: str, user_id: str) -> None:
    role = await _get_member_role(tenant_id, workspace_id, user_id)
    if role != "owner":
        raise ForbiddenError("Only the workspace owner can perform this action")

async def _assert_collaborative_editor(tenant_id: str, workspace_id: str, user_id: str) -> None:
    role = await _get_member_role(tenant_id, workspace_id, user_id)
    if role not in ("owner", "editor"):
        raise ForbiddenError("Only owners or editors can perform this action")

async def _assert_collaborative_member(tenant_id: str, workspace_id: str, user_id: str) -> None:
    role = await _get_member_role(tenant_id, workspace_id, user_id)
    if not role:
        raise ForbiddenError("You are not a member of this workspace")

async def _log_workspace_activity(
    tenant_id: str,
    workspace_id: str,
    user_id: str,
    user_name: str,
    activity_type: WorkspaceActivityType,
    details: dict,
) -> None:
    col = get_collection(tenant_id, WORKSPACE_ACTIVITY_LOGS)
    log = WorkspaceActivityLog(
        **{"_id": f"act_{uuid4().hex}"},
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        user_id=user_id,
        user_name=user_name,
        activity_type=activity_type,
        details=details,
    )
    await col.insert_one(log.model_dump(by_alias=True))


class WorkspaceInviteRequest(BaseModel):
    email: EmailStr | None = None
    username: str | None = None
    role: WorkspaceRole = WorkspaceRole.viewer


class WorkspaceJoinRequest(BaseModel):
    join_code: str | None = None
    invite_token: str | None = None


class ChangeMemberRoleRequest(BaseModel):
    user_id: str
    role: WorkspaceRole


class WorkspaceMessageCreate(BaseModel):
    content: str
    attachments: list[str] = Field(default_factory=list)


@router.post("/collaborative", response_model=WorkspaceResponse, status_code=status.HTTP_201_CREATED)
async def create_collaborative_workspace(
    body: WorkspaceCreate,
    current_user: User = Depends(get_current_user),
) -> WorkspaceResponse:
    """Create a collaborative workspace where multiple students can study together."""
    col = get_collection(current_user.tenant_id, WORKSPACES)
    
    existing = await col.find_one(
        {"name": body.name, "tenant_id": current_user.tenant_id, "deleted_at": None}
    )
    if existing:
        raise ConflictError(f"Workspace '{body.name}' already exists")

    wsp_id = f"wsp_{uuid4().hex}"
    join_code = uuid4().hex[:6].upper()

    workspace = Workspace(
        **{"_id": wsp_id},
        tenant_id=current_user.tenant_id,
        name=body.name,
        description=body.description,
        type="collaborative",
        owner_id=current_user.id,
        join_code=join_code,
        admin_ids=[current_user.id],
        student_ids=[current_user.id],
    )
    await col.insert_one(workspace.model_dump(by_alias=True))

    # Create membership record
    members_col = get_collection(current_user.tenant_id, WORKSPACE_MEMBERS)
    member = WorkspaceMember(
        **{"_id": f"mb_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        workspace_id=wsp_id,
        user_id=current_user.id,
        role=WorkspaceRole.owner,
    )
    await members_col.insert_one(member.model_dump(by_alias=True))

    # Log activity
    await _log_workspace_activity(
        tenant_id=current_user.tenant_id,
        workspace_id=wsp_id,
        user_id=current_user.id,
        user_name=current_user.display_name,
        activity_type=WorkspaceActivityType.member_joined,
        details={"role": WorkspaceRole.owner},
    )

    # Update creating user's workspace memberships list
    user_col = get_collection(current_user.tenant_id, "users")
    current_user.workspace_memberships.append(
        WorkspaceMembership(
            workspace_id=wsp_id,
            role=UserRole.student,
            joined_at=utc_now(),
        )
    )
    current_user.touch()
    await user_col.replace_one({"_id": current_user.id}, current_user.model_dump(by_alias=True))
    await invalidate_user_cache(current_user)

    return WorkspaceResponse.from_doc(workspace)


@router.post("/{workspace_id}/invite", status_code=status.HTTP_201_CREATED)
async def invite_to_workspace(
    workspace_id: str,
    body: WorkspaceInviteRequest,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Invite another student to join this collaborative workspace."""
    await _assert_collaborative_owner(current_user.tenant_id, workspace_id, current_user.id)
    wsp_col = get_collection(current_user.tenant_id, WORKSPACES)
    workspace_doc = await wsp_col.find_one({"_id": workspace_id, "deleted_at": None})
    if not workspace_doc:
        raise NotFoundError("Workspace", workspace_id)

    workspace = Workspace.model_validate(workspace_doc)
    invites_col = get_collection(current_user.tenant_id, WORKSPACE_INVITATIONS)

    token = f"tok_{uuid4().hex}"
    from datetime import UTC, datetime, timedelta
    expires_at = (datetime.now(UTC) + timedelta(days=7)).isoformat()

    invitation = WorkspaceInvitation(
        **{"_id": f"inv_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        inviter_id=current_user.id,
        invitee_email=body.email,
        invitee_username=body.username,
        invite_link_token=token,
        join_code=workspace.join_code,
        role=body.role,
        status=InvitationStatus.pending,
        expires_at=expires_at,
    )
    await invites_col.insert_one(invitation.model_dump(by_alias=True))

    if body.email:
        user_col = get_collection(current_user.tenant_id, "users")
        target_user_doc = await user_col.find_one({"email": body.email, "deleted_at": None})
        if target_user_doc:
            target_user = User.model_validate(target_user_doc)
            members_col = get_collection(current_user.tenant_id, WORKSPACE_MEMBERS)
            existing_member = await members_col.find_one({"workspace_id": workspace.id, "user_id": target_user.id, "deleted_at": None})
            
            if not existing_member:
                member = WorkspaceMember(
                    **{"_id": f"mb_{uuid4().hex}"},
                    tenant_id=current_user.tenant_id,
                    workspace_id=workspace.id,
                    user_id=target_user.id,
                    role=body.role,
                )
                await members_col.insert_one(member.model_dump(by_alias=True))
                
                if target_user.id not in workspace.student_ids:
                    workspace.student_ids.append(target_user.id)
                if body.role == WorkspaceRole.owner and target_user.id not in workspace.admin_ids:
                    workspace.admin_ids.append(target_user.id)
                
                workspace.touch()
                await wsp_col.replace_one({"_id": workspace.id}, workspace.model_dump(by_alias=True))
                
                already_member = any(m.workspace_id == workspace.id for m in target_user.workspace_memberships)
                if not already_member:
                    target_user.workspace_memberships.append(
                        WorkspaceMembership(
                            workspace_id=workspace.id,
                            role=UserRole.student,
                            joined_at=utc_now(),
                        )
                    )
                    target_user.touch()
                    await user_col.replace_one({"_id": target_user.id}, target_user.model_dump(by_alias=True))
                    await invalidate_user_cache(target_user)
                
                await _log_workspace_activity(
                    tenant_id=current_user.tenant_id,
                    workspace_id=workspace.id,
                    user_id=target_user.id,
                    user_name=target_user.display_name,
                    activity_type=WorkspaceActivityType.member_joined,
                    details={"role": body.role},
                )
                
        magic_link = f"socialstudyapp://workspace/join/{token}"
        display_name = body.username or body.email.split('@')[0]
        html_body = get_invite_email_html(
            display_name=display_name,
            workspace_name=workspace.name,
            magic_link=magic_link
        )
        payload = EmailPayload(
            to_email=body.email,
            subject=f"You've been invited to {workspace.name}",
            body_text=f"You've been invited to join {workspace.name} on Social Study. Join code: {workspace.join_code} or use link: {magic_link}",
            body_html=html_body,
        )
        sender = get_email_sender()
        await sender.send(payload)

    return {
        "invite_token": token,
        "join_code": workspace.join_code,
        "role": body.role,
        "expires_at": expires_at,
    }


@router.post("/{workspace_id}/join", response_model=WorkspaceResponse)
async def join_workspace(
    workspace_id: str,
    body: WorkspaceJoinRequest,
    current_user: User = Depends(get_current_user),
) -> WorkspaceResponse:
    """Join a collaborative workspace using a join code or invitation token."""
    wsp_col = get_collection(current_user.tenant_id, WORKSPACES)
    workspace_doc = None

    assigned_role = WorkspaceRole.editor  # Default role when joining via code

    if body.join_code:
        workspace_doc = await wsp_col.find_one({"join_code": body.join_code, "deleted_at": None})
    elif body.invite_token:
        invites_col = get_collection(current_user.tenant_id, WORKSPACE_INVITATIONS)
        invite = await invites_col.find_one({"invite_link_token": body.invite_token, "status": "pending"})
        if invite:
            workspace_doc = await wsp_col.find_one({"_id": invite["workspace_id"], "deleted_at": None})
            assigned_role = WorkspaceRole(invite["role"])
            # Update invite status
            await invites_col.update_one({"_id": invite["_id"]}, {"$set": {"status": "accepted", "updated_at": utc_now()}})

    if not workspace_doc:
        raise NotFoundError("Workspace or invitation code not found")

    workspace = Workspace.model_validate(workspace_doc)
    
    # Check if already a member
    members_col = get_collection(current_user.tenant_id, WORKSPACE_MEMBERS)
    existing_member = await members_col.find_one({"workspace_id": workspace.id, "user_id": current_user.id, "deleted_at": None})
    if existing_member:
        return WorkspaceResponse.from_doc(workspace)

    # Insert membership
    member = WorkspaceMember(
        **{"_id": f"mb_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace.id,
        user_id=current_user.id,
        role=assigned_role,
    )
    await members_col.insert_one(member.model_dump(by_alias=True))

    # Add user to student_ids or admin_ids depending on role
    if current_user.id not in workspace.student_ids:
        workspace.student_ids.append(current_user.id)
    if assigned_role == WorkspaceRole.owner and current_user.id not in workspace.admin_ids:
        workspace.admin_ids.append(current_user.id)
    
    workspace.touch()
    await wsp_col.replace_one({"_id": workspace.id}, workspace.model_dump(by_alias=True))

    # Update user's memberships
    user_col = get_collection(current_user.tenant_id, "users")
    already_member = any(m.workspace_id == workspace.id for m in current_user.workspace_memberships)
    if not already_member:
        current_user.workspace_memberships.append(
            WorkspaceMembership(
                workspace_id=workspace.id,
                role=UserRole.student,
                joined_at=utc_now(),
            )
        )
        current_user.touch()
        await user_col.replace_one({"_id": current_user.id}, current_user.model_dump(by_alias=True))
        await invalidate_user_cache(current_user)

    # Log activity
    await _log_workspace_activity(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace.id,
        user_id=current_user.id,
        user_name=current_user.display_name,
        activity_type=WorkspaceActivityType.member_joined,
        details={"role": assigned_role},
    )

    return WorkspaceResponse.from_doc(workspace)


@router.post("/{workspace_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
async def leave_workspace(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> None:
    """Leave a collaborative workspace."""
    wsp_col = get_collection(current_user.tenant_id, WORKSPACES)
    workspace_doc = await wsp_col.find_one({"_id": workspace_id, "deleted_at": None})
    if not workspace_doc:
        raise NotFoundError("Workspace", workspace_id)

    workspace = Workspace.model_validate(workspace_doc)
    members_col = get_collection(current_user.tenant_id, WORKSPACE_MEMBERS)
    member = await members_col.find_one({"workspace_id": workspace_id, "user_id": current_user.id, "deleted_at": None})
    if not member:
         raise ForbiddenError("You are not a member of this workspace")

    if member["role"] == WorkspaceRole.owner:
        # Owner cannot leave unless they are the only member
        member_count = await members_col.count_documents({"workspace_id": workspace_id, "deleted_at": None})
        if member_count > 1:
            raise ForbiddenError("Owner cannot leave workspace. Please transfer ownership first.")

    # Remove membership
    await members_col.update_one({"_id": member["_id"]}, {"$set": {"deleted_at": utc_now(), "updated_at": utc_now()}})

    # Remove user from student_ids / admin_ids
    if current_user.id in workspace.student_ids:
        workspace.student_ids.remove(current_user.id)
    if current_user.id in workspace.admin_ids:
        workspace.admin_ids.remove(current_user.id)
    workspace.touch()
    await wsp_col.replace_one({"_id": workspace.id}, workspace.model_dump(by_alias=True))

    # Update user object
    user_col = get_collection(current_user.tenant_id, "users")
    current_user.workspace_memberships = [m for m in current_user.workspace_memberships if m.workspace_id != workspace_id]
    current_user.touch()
    await user_col.replace_one({"_id": current_user.id}, current_user.model_dump(by_alias=True))
    await invalidate_user_cache(current_user)

    # Log activity
    await _log_workspace_activity(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        user_id=current_user.id,
        user_name=current_user.display_name,
        activity_type=WorkspaceActivityType.member_left,
        details={},
    )


@router.post("/{workspace_id}/role", response_model=dict)
async def change_member_role(
    workspace_id: str,
    body: ChangeMemberRoleRequest,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Change the role of a member (Owner only)."""
    await _assert_collaborative_owner(current_user.tenant_id, workspace_id, current_user.id)
    
    if body.user_id == current_user.id:
        raise ForbiddenError("You cannot modify your own role")

    members_col = get_collection(current_user.tenant_id, WORKSPACE_MEMBERS)
    member = await members_col.find_one({"workspace_id": workspace_id, "user_id": body.user_id, "deleted_at": None})
    if not member:
        raise NotFoundError("Member", body.user_id)

    old_role = member["role"]
    await members_col.update_one({"_id": member["_id"]}, {"$set": {"role": body.role, "updated_at": utc_now()}})

    # Log activity
    await _log_workspace_activity(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        user_id=body.user_id,
        user_name=current_user.display_name, # or lookup target user name
        activity_type=WorkspaceActivityType.role_changed,
        details={"old_role": old_role, "new_role": body.role},
    )

    return {"user_id": body.user_id, "new_role": body.role}


@router.get("/{workspace_id}/members", response_model=list[dict])
async def list_workspace_members(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> list[dict]:
    """List members of a collaborative workspace."""
    await _assert_collaborative_member(current_user.tenant_id, workspace_id, current_user.id)
    
    members_col = get_collection(current_user.tenant_id, WORKSPACE_MEMBERS)
    cursor = members_col.find({"workspace_id": workspace_id, "deleted_at": None})
    members = [WorkspaceMember.model_validate(doc) async for doc in cursor]

    # Join with users collection
    user_col = get_collection(current_user.tenant_id, "users")
    out = []
    for m in members:
        user_doc = await user_col.find_one({"_id": m.user_id})
        out.append({
            "user_id": m.user_id,
            "role": m.role,
            "display_name": user_doc.get("display_name", "Unknown") if user_doc else "Unknown",
            "email": user_doc.get("email", "") if user_doc else "",
            "joined_at": m.joined_at,
        })
    return out


@router.get("/{workspace_id}/activity", response_model=list[dict])
async def list_workspace_activity(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> list[dict]:
    """List recent activity logs for a collaborative workspace."""
    await _assert_collaborative_member(current_user.tenant_id, workspace_id, current_user.id)
    
    col = get_collection(current_user.tenant_id, WORKSPACE_ACTIVITY_LOGS)
    await col.create_index([("created_at", -1)])
    cursor = col.find({"workspace_id": workspace_id, "deleted_at": None}).sort("created_at", -1).limit(50)
    return [doc async for doc in cursor]


@router.get("/{workspace_id}/messages", response_model=list[WorkspaceMessage])
async def get_workspace_messages(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> list[WorkspaceMessage]:
    """Retrieve chat messages for the collaborative workspace."""
    await _assert_collaborative_member(current_user.tenant_id, workspace_id, current_user.id)
    
    col = get_collection(current_user.tenant_id, WORKSPACE_MESSAGES)
    await col.create_index([("created_at", -1)])
    cursor = col.find({"workspace_id": workspace_id, "deleted_at": None}).sort("created_at", -1).limit(100)
    
    messages = [WorkspaceMessage(**doc) async for doc in cursor]
    # Reverse to return chronological order
    messages.reverse()
    return messages


@router.post("/{workspace_id}/messages", response_model=dict)
async def post_workspace_message(
    workspace_id: str,
    body: WorkspaceMessageCreate,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Post a new discussion board message in the workspace."""
    await _assert_collaborative_editor(current_user.tenant_id, workspace_id, current_user.id)
    
    col = get_collection(current_user.tenant_id, WORKSPACE_MESSAGES)
    msg = WorkspaceMessage(
        **{"_id": f"msg_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        sender_id=current_user.id,
        sender_name=current_user.display_name,
        content=body.content,
        attachments=body.attachments,
    )
    await col.insert_one(msg.model_dump(by_alias=True))

    # Log activity
    await _log_workspace_activity(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        user_id=current_user.id,
        user_name=current_user.display_name,
        activity_type=WorkspaceActivityType.chat_message,
        details={"message_id": msg.id},
    )

    return msg.model_dump(by_alias=True)

