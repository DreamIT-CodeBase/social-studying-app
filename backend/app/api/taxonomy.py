"""Workspace taxonomy CRUD — Sprint 2.11.

Three endpoints nested under a workspace:

- ``GET    /workspaces/{ws}/taxonomy``             — read current taxonomy
- ``PUT    /workspaces/{ws}/taxonomy``             — admin overrides (with CAS)
- ``POST   /workspaces/{ws}/taxonomy/regenerate``  — rebuild from documents (async)

Read access is granted to any workspace member (students see the topic
list to navigate study material). Write + regenerate are admin-only.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, BackgroundTasks, Depends, status

from app.core.auth import get_current_user, require_role
from app.core.database import WORKSPACES, get_collection
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ValidationError,
)
from app.models.user import User, UserRole
from app.models.workspace import (
    TaxonomyResponse,
    TaxonomyUpdate,
    Workspace,
)
from app.services import taxonomy as taxonomy_service
from app.services.taxonomy import (
    TaxonomyValidationError,
    TaxonomyVersionConflict,
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/workspaces/{workspace_id}/taxonomy",
    tags=["taxonomy"],
)


# ── Helpers ──────────────────────────────────────────────────────────────────


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    """Same access rule as documents.py: tenant admin OR a workspace member."""
    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")


async def _load_workspace(tenant_id: str, workspace_id: str) -> Workspace:
    col = get_collection(tenant_id, WORKSPACES)
    raw = await col.find_one(
        {
            "_id": workspace_id,
            "tenant_id": tenant_id,
            "deleted_at": None,
        }
    )
    if raw is None:
        raise NotFoundError("Workspace", workspace_id)
    return Workspace.model_validate(raw)


# ── GET ──────────────────────────────────────────────────────────────────────


@router.get("", response_model=TaxonomyResponse)
async def get_taxonomy(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> TaxonomyResponse:
    """Return the workspace's current canonical taxonomy + version.

    Open to any workspace member. Students need this for the topic tree
    view in the study UI; admins for editing.
    """
    _assert_workspace_access(current_user, workspace_id)
    workspace = await _load_workspace(current_user.tenant_id, workspace_id)
    return TaxonomyResponse.from_workspace(workspace)


# ── PUT ──────────────────────────────────────────────────────────────────────


@router.put("", response_model=TaxonomyResponse)
async def update_taxonomy(
    workspace_id: str,
    body: TaxonomyUpdate,
    current_user: User = Depends(
        require_role(UserRole.tenant_admin, UserRole.workspace_admin)
    ),
) -> TaxonomyResponse:
    """Admin-driven taxonomy edit: rename / merge / re-parent / drop topics.

    Admin first GETs the taxonomy, edits it locally, then PUTs the full
    new state back along with the ``taxonomy_version`` they read. We CAS
    against that version so concurrent edits don't silently clobber each
    other; on conflict the client gets 409 and should re-fetch.

    Validation rejects payloads that would corrupt the graph (duplicate
    ids, dangling parent refs, cycles, duplicate names). See
    :func:`app.services.taxonomy.validate_taxonomy_shape` for details.
    """
    _assert_workspace_access(current_user, workspace_id)

    try:
        refreshed = await taxonomy_service.replace_taxonomy(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            expected_version=body.taxonomy_version,
            topics=body.topics,
        )
    except TaxonomyValidationError as exc:
        raise ValidationError(str(exc)) from exc
    except TaxonomyVersionConflict as exc:
        raise ConflictError(
            f"Taxonomy was modified by another writer. Re-fetch and retry. ({exc})"
        ) from exc
    except RuntimeError as exc:
        # _read_workspace returning None — workspace doesn't exist.
        raise NotFoundError("Workspace", workspace_id) from exc

    logger.info(
        "Taxonomy updated by user=%s workspace=%s new_version=%d topics=%d",
        current_user.id,
        workspace_id,
        refreshed.taxonomy_version,
        len(refreshed.taxonomy.topics),
    )
    return TaxonomyResponse.from_workspace(refreshed)


# ── POST /regenerate ─────────────────────────────────────────────────────────


@router.post("/regenerate", status_code=status.HTTP_202_ACCEPTED)
async def regenerate_taxonomy(
    workspace_id: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(
        require_role(UserRole.tenant_admin, UserRole.workspace_admin)
    ),
) -> dict[str, str]:
    """Kick off an async rebuild of the workspace taxonomy from documents.

    Returns 202 immediately and schedules the rebuild as a BackgroundTask
    on this API replica. The taxonomy resets to empty inline (so GET
    reflects "rebuilding" until replay finishes) and then merges every
    document's ``topic_tags`` back in, in upload order, followed by one
    dep-inference pass.

    Note: BackgroundTasks runs only on the API replica that received the
    request. For prod-scale workspaces a Service Bus queue + dedicated
    worker is the right answer; for the demo and most workspaces of
    Sprint 2 scale, this is fine.
    """
    _assert_workspace_access(current_user, workspace_id)

    # Confirm the workspace exists before scheduling work — saves us from
    # a background task that fails immediately on the lookup.
    workspace = await _load_workspace(current_user.tenant_id, workspace_id)

    background_tasks.add_task(
        _regenerate_in_background,
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
    )

    logger.info(
        "Taxonomy regenerate scheduled by user=%s workspace=%s current_version=%d",
        current_user.id,
        workspace_id,
        workspace.taxonomy_version,
    )
    return {
        "status": "accepted",
        "workspace_id": workspace_id,
        "message": "Taxonomy rebuild started; poll GET /taxonomy for new version.",
    }


async def _regenerate_in_background(*, tenant_id: str, workspace_id: str) -> None:
    """Wrapper that logs the outcome — BackgroundTasks swallows return values."""
    try:
        outcome = await taxonomy_service.regenerate_from_documents(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
        )
        logger.info(
            "Taxonomy regenerate complete workspace=%s docs=%d topics=%d version=%d",
            workspace_id,
            outcome.documents_merged,
            outcome.topics_total,
            outcome.final_version,
        )
    except Exception:
        logger.exception(
            "Taxonomy regenerate failed for workspace=%s — taxonomy may be partially rebuilt",
            workspace_id,
        )
