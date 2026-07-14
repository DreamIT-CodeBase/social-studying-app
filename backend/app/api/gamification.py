"""Gamification API endpoints — Sprint 5.2.

Four read endpoints over the ``gamification`` Cosmos collection:

- ``GET /workspaces/{wsp}/users/{usr}/gamification`` — full profile
  (XP totals, level + level-progress hints, streak, daily activity).
- ``GET /workspaces/{wsp}/leaderboard`` — ranked roster, gated by the
  workspace's ``leaderboard_visible`` setting for students.
- ``GET /workspaces/{wsp}/users/{usr}/badges`` — earned + available
  badge lists, derived from the catalog in :mod:`app.services.badges`.
- ``GET /workspaces/{wsp}/users/{usr}/streak`` — streak summary.

Write side lives in :mod:`app.services.gamification` and is called
from the answer and flashcard rate endpoints — these endpoints are
strictly read-only. The first read on a brand-new student returns a
zero-state (but does not persist it) so the UI can render an empty
profile before the student has answered anything.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.core.auth import get_current_user
from app.core.database import USERS, WORKSPACES, get_collection
from app.core.exceptions import ForbiddenError, NotFoundError
from app.models.gamification import GamificationState
from app.models.user import User, UserRole
from app.models.workspace import Workspace
from app.services import badges as badges_module
from app.services import gamification as gamification_service
from app.services.gamification import xp_for_next_level, xp_into_level

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/workspaces/{workspace_id}",
    tags=["gamification"],
)


# ── Wire types ──────────────────────────────────────────────────────────────


class EarnedBadgeView(BaseModel):
    """One badge already on the student's profile, with earn timestamp."""

    badge_id: str
    name: str
    description: str
    icon: str
    earned_at: str
    xp_reward: int = 0


class AvailableBadgeView(BaseModel):
    """Badge catalog entry the student hasn't unlocked yet.

    No ``earned_at`` (they haven't earned it). Useful for the
    showcase grid's "locked" tiles so students can see what's
    available to chase.
    """

    badge_id: str
    name: str
    description: str
    icon: str
    xp_reward: int = 0


class DailyLoginFeedback(BaseModel):
    awarded: bool
    xp_earned: int
    xp_total: int
    new_level: int
    leveled_up: bool
    badges_unlocked: list[EarnedBadgeView]


class GamificationProfile(BaseModel):
    """Wire view of :class:`GamificationState` for the profile endpoint.

    Adds two computed fields (``xp_into_level``, ``xp_for_next_level``)
    so the level-progress bar can render without re-deriving the curve
    in the UI.
    """

    student_id: str
    workspace_id: str

    xp_total: int
    xp_this_week: int
    xp_by_topic: dict[str, int]

    level: int
    xp_into_level: int
    xp_for_next_level: int

    streak_days: int
    longest_streak_days: int
    last_active_date: str | None

    questions_answered: int
    questions_correct: int
    flashcards_reviewed: int

    badges: list[EarnedBadgeView]
    daily_activity: dict[str, int]
    daily_xp: dict[str, int]


class StreakSummary(BaseModel):
    """Just the streak block — cheap to fetch for the home page card."""

    student_id: str
    streak_days: int
    longest_streak_days: int
    last_active_date: str | None
    active_today: bool


class BadgesSummary(BaseModel):
    """Earned + available badges in a single payload.

    The catalog is small (~17 entries) so we return both in one
    request. The ``earned_count`` / ``total_count`` fields let the UI
    render "5 of 17 unlocked" without re-counting.
    """

    student_id: str
    earned: list[EarnedBadgeView]
    available: list[AvailableBadgeView]
    earned_count: int
    total_count: int


class LeaderboardEntry(BaseModel):
    """One row of the workspace leaderboard."""

    student_id: str
    display_name: str
    level: int
    xp_total: int
    xp_this_week: int
    rank: int
    streak_days: int


class LeaderboardResponse(BaseModel):
    """Ranked roster + the caller's own rank (for the "you are #N" UI).

    ``entries`` is sorted by ``xp_total`` descending. The caller's own
    rank is repeated in ``current_user_rank`` for the cases where
    they fell off the end of the visible window.
    """

    workspace_id: str
    entries: list[LeaderboardEntry]
    current_user_rank: int | None
    visible: bool = Field(
        default=True,
        description=(
            "False when the workspace has ``leaderboard_visible=False``"
            " and the caller is a student — entries is empty in that case."
        ),
    )


# ── Profile endpoint ────────────────────────────────────────────────────────


@router.post(
    "/users/me/gamification/daily-login",
    response_model=DailyLoginFeedback,
)
async def claim_daily_login(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> DailyLoginFeedback:
    """Claim the once-per-calendar-day +2 XP login reward."""
    _assert_workspace_member(current_user, workspace_id)
    result = await gamification_service.record_daily_login(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
    )
    delta = result.delta
    return DailyLoginFeedback(
        awarded=result.awarded,
        xp_earned=delta.xp_earned,
        xp_total=delta.state.xp_total if delta.state is not None else 0,
        new_level=delta.new_level,
        leveled_up=delta.leveled_up,
        badges_unlocked=[
            EarnedBadgeView(
                badge_id=badge.badge_id,
                name=badge.name,
                description=badge.description,
                icon=badge.icon,
                earned_at=badge.earned_at,
                xp_reward=badge.xp_reward,
            )
            for badge in delta.badges_unlocked
        ],
    )


@router.get(
    "/users/{user_id}/gamification",
    response_model=GamificationProfile,
)
async def get_profile(
    workspace_id: str,
    user_id: str,
    current_user: User = Depends(get_current_user),
) -> GamificationProfile:
    """Return the full gamification profile for ``user_id``.

    Access rule: a student can read their own profile; an admin
    (tenant or workspace) can read any profile in their workspace.

    A zero-state is returned (not persisted) on first read so the UI
    can render an empty profile before the student has answered
    anything.
    """
    _assert_can_view(current_user, workspace_id=workspace_id, target_user_id=user_id)

    state = await gamification_service.get_state(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=user_id,
    )
    return _state_to_profile(state)


# ── Streak endpoint ─────────────────────────────────────────────────────────


@router.get(
    "/users/{user_id}/streak",
    response_model=StreakSummary,
)
async def get_streak(
    workspace_id: str,
    user_id: str,
    current_user: User = Depends(get_current_user),
) -> StreakSummary:
    """Return just the streak fields — cheap call for the home card."""
    _assert_can_view(current_user, workspace_id=workspace_id, target_user_id=user_id)
    state = await gamification_service.get_state(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=user_id,
    )
    today_iso = datetime.now(UTC).date().isoformat()
    return StreakSummary(
        student_id=state.student_id,
        streak_days=state.streak_days,
        longest_streak_days=state.longest_streak_days,
        last_active_date=state.last_active_date,
        active_today=state.last_active_date == today_iso,
    )


# ── Badges endpoint ─────────────────────────────────────────────────────────


@router.get(
    "/users/{user_id}/badges",
    response_model=BadgesSummary,
)
async def get_badges(
    workspace_id: str,
    user_id: str,
    current_user: User = Depends(get_current_user),
) -> BadgesSummary:
    """Return earned + available badges.

    Earned are pulled from the persisted ``state.badges`` so their
    ``earned_at`` timestamp is preserved. Available are everything in
    the catalog (:data:`app.services.badges.BADGES`) that isn't earned
    yet — so the showcase grid can render locked tiles for upcoming
    goals.
    """
    _assert_can_view(current_user, workspace_id=workspace_id, target_user_id=user_id)

    state = await gamification_service.get_state(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=user_id,
    )
    earned_ids = {b.badge_id for b in state.badges}
    earned = [
        EarnedBadgeView(
            badge_id=b.badge_id,
            name=b.name,
            description=b.description,
            icon=b.icon,
            earned_at=b.earned_at,
            xp_reward=b.xp_reward,
        )
        for b in state.badges
    ]
    available = [
        AvailableBadgeView(
            badge_id=definition.id,
            name=definition.name,
            description=definition.description,
            icon=definition.icon,
            xp_reward=definition.xp_reward,
        )
        for definition in badges_module.BADGES
        if definition.id not in earned_ids
    ]
    return BadgesSummary(
        student_id=state.student_id,
        earned=earned,
        available=available,
        earned_count=len(earned),
        total_count=len(badges_module.BADGES),
    )


# ── Leaderboard endpoint ────────────────────────────────────────────────────


@router.get(
    "/leaderboard",
    response_model=LeaderboardResponse,
)
async def get_leaderboard(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> LeaderboardResponse:
    """Return the workspace leaderboard, sorted by ``xp_total`` desc.

    Students are gated by the workspace's ``leaderboard_visible``
    setting — if it's off, students get ``visible=False`` with an
    empty roster. Admins always see the leaderboard so they can
    monitor engagement even when it's hidden from students.

    Ranks are 1-based and assigned in descending XP order; ties
    resolve by ``student_id`` so the order is stable across calls.
    """
    _assert_workspace_member(current_user, workspace_id)
    workspace = await _read_workspace(current_user.tenant_id, workspace_id)

    is_admin = current_user.role in {UserRole.tenant_admin, UserRole.workspace_admin}
    if not is_admin and not workspace.settings.leaderboard_visible:
        return LeaderboardResponse(
            workspace_id=workspace_id,
            entries=[],
            current_user_rank=None,
            visible=False,
        )

    states = await gamification_service.list_workspace_states(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
    )
    # Stable sort: primary by xp_total desc, tiebreaker by student_id asc.
    states.sort(key=lambda s: (-s.xp_total, s.student_id))

    # Look up display names in one batch query.
    display_names = await _fetch_display_names(
        tenant_id=current_user.tenant_id,
        student_ids=[s.student_id for s in states],
    )

    entries: list[LeaderboardEntry] = []
    current_rank: int | None = None
    for rank, state in enumerate(states, start=1):
        entries.append(
            LeaderboardEntry(
                student_id=state.student_id,
                display_name=display_names.get(state.student_id, "Unknown"),
                level=state.level,
                xp_total=state.xp_total,
                xp_this_week=state.xp_this_week,
                rank=rank,
                streak_days=state.streak_days,
            )
        )
        if state.student_id == current_user.id:
            current_rank = rank

    return LeaderboardResponse(
        workspace_id=workspace_id,
        entries=entries,
        current_user_rank=current_rank,
        visible=True,
    )


# ── Helpers ────────────────────────────────────────────────────────────────


def _state_to_profile(state: GamificationState) -> GamificationProfile:
    """Materialise the wire view, including computed level-progress fields."""
    return GamificationProfile(
        student_id=state.student_id,
        workspace_id=state.workspace_id,
        xp_total=state.xp_total,
        xp_this_week=state.xp_this_week,
        xp_by_topic=state.xp_by_topic,
        level=state.level,
        xp_into_level=xp_into_level(state.xp_total),
        xp_for_next_level=xp_for_next_level(state.xp_total),
        streak_days=state.streak_days,
        longest_streak_days=state.longest_streak_days,
        last_active_date=state.last_active_date,
        questions_answered=state.questions_answered,
        questions_correct=state.questions_correct,
        flashcards_reviewed=state.flashcards_reviewed,
        badges=[
            EarnedBadgeView(
                badge_id=b.badge_id,
                name=b.name,
                description=b.description,
                icon=b.icon,
                earned_at=b.earned_at,
                xp_reward=b.xp_reward,
            )
            for b in state.badges
        ],
        daily_activity=state.daily_activity,
        daily_xp=state.daily_xp,
    )


def _assert_workspace_member(user: User, workspace_id: str) -> None:
    """Tenant admins pass through; everyone else must be a member."""
    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")


def _assert_can_view(
    user: User,
    *,
    workspace_id: str,
    target_user_id: str,
) -> None:
    """Profile / badges / streak access rule.

    - Tenant admin: any user in the tenant.
    - Workspace admin: any user in their workspace (caller must be a
      member of ``workspace_id``).
    - Student: only their own profile.
    """
    if user.role == UserRole.tenant_admin:
        return
    _assert_workspace_member(user, workspace_id)
    if user.role == UserRole.workspace_admin:
        return
    # Student fall-through.
    if user.id != target_user_id:
        raise ForbiddenError("Students can only view their own gamification profile")


async def _read_workspace(tenant_id: str, workspace_id: str) -> Workspace:
    col = get_collection(tenant_id, WORKSPACES)
    raw = await col.find_one({"_id": workspace_id, "deleted_at": None})
    if raw is None:
        raise NotFoundError("Workspace", workspace_id)
    return Workspace.model_validate(raw)


async def _fetch_display_names(*, tenant_id: str, student_ids: list[str]) -> dict[str, str]:
    """Batch-fetch ``display_name`` for the given users.

    One ``find({"_id": {"$in": ids}})`` query instead of N point reads.
    Missing users fall through to a generic ``"Unknown"`` in the
    caller — no exception, since a deleted user shouldn't 500 the
    leaderboard.
    """
    if not student_ids:
        return {}
    col = get_collection(tenant_id, USERS)
    cursor = col.find(
        {
            "_id": {"$in": student_ids},
            "deleted_at": None,
        }
    )
    return {doc["_id"]: doc.get("display_name", "Unknown") async for doc in cursor}


class SessionCompletionRequest(BaseModel):
    session_type: str = Field(pattern="^(study|revision|flashcard)$")


class SessionCompletionFeedback(BaseModel):
    xp_earned: int
    new_level: int
    leveled_up: bool
    streak_days: int
    streak_extended: bool
    badges_unlocked: list[EarnedBadgeView]


@router.post(
    "/users/{student_id}/gamification/complete-session",
    response_model=SessionCompletionFeedback,
)
async def complete_session(
    workspace_id: str,
    student_id: str,
    payload: SessionCompletionRequest,
    current_user: User = Depends(get_current_user),
) -> SessionCompletionFeedback:
    """Award XP for completing a study, revision, or flashcard session."""
    if current_user.id != student_id and current_user.role != UserRole.admin:
        raise ForbiddenError("Cannot submit session completion for another student.")

    await _read_workspace(current_user.tenant_id, workspace_id)
    is_member = any(m.workspace_id == workspace_id for m in current_user.workspace_memberships)
    if not is_member and current_user.role != UserRole.admin:
        raise ForbiddenError("Not a member of this workspace.")

    delta = await gamification_service.record_session_completion(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        session_type=payload.session_type,
    )

    return SessionCompletionFeedback(
        xp_earned=delta.xp_earned,
        new_level=delta.new_level,
        leveled_up=delta.leveled_up,
        streak_days=delta.streak_days,
        streak_extended=delta.streak_extended,
        badges_unlocked=[
            EarnedBadgeView(
                badge_id=b.badge_id,
                name=b.name,
                description=b.description,
                icon=b.icon,
                earned_at=b.earned_at,
                xp_reward=b.xp_reward,
            )
            for b in delta.badges_unlocked
        ],
    )
