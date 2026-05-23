"""Analytics API endpoints — Sprint 5.9.

Three read endpoints that delegate to :mod:`app.services.analytics`:

- ``GET /workspaces/{ws}/users/{usr}/progress`` — student progress view
  (Flutter 4.11 + admin 5.10 detail view share this).
- ``GET /workspaces/{ws}/analytics`` — workspace analytics dashboard
  (5.11).
- ``GET /tenants/{tid}/analytics`` — tenant-wide roll-up (5.11).

The wire shape is locked to what Flutter's ``StudentProgress`` model
(``shared/models/progress.dart``) already expects — those models
declare the field names that this endpoint must return.

Access rules
------------
- Student progress: a student reads their own, admins (workspace or
  tenant) read anyone in their workspace.
- Workspace analytics: workspace admins + tenant admins.
- Tenant analytics: tenant admins only.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.core.auth import get_current_user, require_role
from app.core.exceptions import ForbiddenError
from app.models.user import User, UserRole
from app.services import analytics as analytics_service

logger = logging.getLogger(__name__)


# Two routers: one for the workspace-scoped endpoints, one for the
# tenant-scoped endpoint. The tenant route lives outside the
# workspaces prefix so the URL reads naturally.
workspace_router = APIRouter(prefix="/workspaces/{workspace_id}", tags=["analytics"])
tenant_router = APIRouter(prefix="/tenants/{tenant_id}", tags=["analytics"])


# ── Wire types ──────────────────────────────────────────────────────────────


class TopicMasteryView(BaseModel):
    """One topic's mastery summary on the student progress view."""

    topic_id: str
    topic_name: str
    mastery: float
    attempts: int
    success_rate: float


class ActivityEntryView(BaseModel):
    """One row in the recent-activity timeline.

    ``is_correct`` is ``None`` for flashcards (self-rated, no graded
    verdict).
    """

    kind: str  # "question" or "flashcard"
    topic: str
    is_correct: bool | None = None
    xp_earned: int = 0
    occurred_at: str


class StudentProgressView(BaseModel):
    """Wire view of one student's progress.

    Field names mirror ``flutter_app/lib/shared/models/progress.dart``
    — that file is the source of truth for the contract.
    """

    level: int
    total_xp: int
    xp_into_level: int
    xp_for_next_level: int
    overall_mastery: float
    topics: list[TopicMasteryView]
    recent_activity: list[ActivityEntryView]


class TopicStatsView(BaseModel):
    """Per-topic row on the workspace analytics dashboard."""

    topic: str
    attempts: int
    avg_mastery: float
    correct_rate: float


class DifficultyStatsView(BaseModel):
    """Per-difficulty attempts + correct counts."""

    attempts: int = 0
    correct: int = 0


class HeatmapCellView(BaseModel):
    """One day on the engagement heatmap."""

    date: str
    events: int


class WorkspaceAnalyticsView(BaseModel):
    """Wire view of the workspace analytics dashboard."""

    workspace_id: str
    total_students: int
    active_students_7d: int
    avg_overall_mastery: float
    avg_questions_per_student: float
    avg_correct_rate: float
    topic_distribution: list[TopicStatsView]
    difficulty_distribution: dict[str, DifficultyStatsView]
    engagement_heatmap: list[HeatmapCellView]


class TenantWorkspaceSummary(BaseModel):
    """Per-workspace row on the tenant analytics dashboard."""

    workspace_id: str
    name: str
    total_students: int
    active_students_7d: int
    avg_mastery: float
    total_questions_answered: int
    total_flashcards_reviewed: int


class TenantAnalyticsView(BaseModel):
    """Wire view of the tenant analytics dashboard."""

    tenant_id: str
    total_workspaces: int
    total_students: int
    active_students_7d: int
    workspaces: list[TenantWorkspaceSummary] = Field(default_factory=list)


# ── Student progress endpoint ───────────────────────────────────────────────


@workspace_router.get(
    "/users/{user_id}/progress",
    response_model=StudentProgressView,
)
async def get_student_progress(
    workspace_id: str,
    user_id: str,
    current_user: User = Depends(get_current_user),
) -> StudentProgressView:
    """Return the complete progress snapshot for ``user_id``.

    Access rule: student reads own; admins (workspace or tenant) read
    anyone in their workspace.
    """
    _assert_can_view(current_user, workspace_id=workspace_id, target_user_id=user_id)
    payload = await analytics_service.build_student_progress(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=user_id,
    )
    return StudentProgressView(**payload)


# ── Workspace analytics endpoint ────────────────────────────────────────────


@workspace_router.get(
    "/analytics",
    response_model=WorkspaceAnalyticsView,
)
async def get_workspace_analytics(
    workspace_id: str,
    current_user: User = Depends(
        require_role(UserRole.tenant_admin, UserRole.workspace_admin)
    ),
) -> WorkspaceAnalyticsView:
    """Aggregate analytics across every student in the workspace.

    Restricted to admins — students see their own progress via the
    progress endpoint. Workspace admins must be members; tenant
    admins always pass.
    """
    if current_user.role == UserRole.workspace_admin:
        ids = {m.workspace_id for m in current_user.workspace_memberships}
        if workspace_id not in ids:
            raise ForbiddenError("You are not a member of this workspace")

    payload = await analytics_service.build_workspace_analytics(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
    )
    return WorkspaceAnalyticsView(**payload)


# ── Tenant analytics endpoint ───────────────────────────────────────────────


@tenant_router.get(
    "/analytics",
    response_model=TenantAnalyticsView,
)
async def get_tenant_analytics(
    tenant_id: str,
    current_user: User = Depends(require_role(UserRole.tenant_admin)),
) -> TenantAnalyticsView:
    """Tenant-wide roll-up. Tenant admins only.

    A workspace admin who wants their workspace's view should hit
    ``/workspaces/{ws}/analytics`` — tenant analytics expose all
    workspaces in the tenant.
    """
    if current_user.tenant_id != tenant_id:
        raise ForbiddenError("You can only read analytics for your own tenant")

    payload = await analytics_service.build_tenant_analytics(tenant_id=tenant_id)
    return TenantAnalyticsView(**payload)


# ── Access helper ──────────────────────────────────────────────────────────


def _assert_can_view(
    user: User,
    *,
    workspace_id: str,
    target_user_id: str,
) -> None:
    """Same access ladder as the gamification endpoints."""
    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")
    if user.role == UserRole.workspace_admin:
        return
    if user.id != target_user_id:
        raise ForbiddenError(
            "Students can only view their own progress"
        )
