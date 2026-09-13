"""Screen time API — cloud-backed settings and wallet.

Five endpoints:

- ``GET  /workspaces/{ws}/screen-time/settings``   — any member
- ``PUT  /workspaces/{ws}/screen-time/settings``   — admin only
- ``GET  /workspaces/{ws}/screen-time/wallet``     — own wallet (student) or any (admin)
- ``POST /workspaces/{ws}/screen-time/wallet/consume``  — record minutes used
- ``POST /workspaces/{ws}/screen-time/wallet/sync-xp``  — recalculate earned minutes from XP

The Accessibility Service on Android still reads from SharedPreferences
for real-time blocking (no network calls in onAccessibilityEvent).
Flutter is responsible for syncing the backend response into
SharedPreferences on startup and after each XP change.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.core.auth import get_current_user
from app.core.database import (
    GAMIFICATION,
    PERMISSION_STATUS,
    SCREEN_TIME_SETTINGS,
    SCREEN_TIME_WALLETS,
    USERS,
    WORKSPACES,
    get_collection,
)
from app.core.exceptions import ForbiddenError
from app.models.base import utc_now
from app.models.screen_time import ScreenTimeSettings, ScreenTimeWallet
from app.models.user import User, UserRole

logger = logging.getLogger(__name__)

# A student can convert at most two hours of XP into social time during a
# weekly balance period. XP itself continues to accrue normally.
MAX_EARNED_MINUTES_PER_WEEK = 120

router = APIRouter(
    prefix="/workspaces/{workspace_id}/screen-time",
    tags=["screen_time"],
)

# ── Default blocked packages (mirrors models/screen_time.py) ────────────────

_DEFAULT_BLOCKED_PACKAGES: list[str] = [
    "com.instagram.android",
    "com.instagram.barcelona",
    "com.zhiliaoapp.musically",
    "com.google.android.youtube",
    "com.facebook.katana",
    "com.twitter.android",
    "com.snapchat.android",
    "com.reddit.frontpage",
    "com.pinterest",
]


# ── Wire types ───────────────────────────────────────────────────────────────


class ScreenTimeSettingsView(BaseModel):
    """Wire shape of workspace screen time settings."""

    workspace_id: str
    enable_blocking: bool
    blocked_packages: list[str]
    xp_to_minute_ratio: int
    updated_at: str


class ScreenTimeSettingsUpdate(BaseModel):
    """Body for PUT /settings — all fields optional (partial update)."""

    enable_blocking: bool | None = None
    blocked_packages: list[str] | None = None
    xp_to_minute_ratio: int | None = Field(default=None, ge=1, le=1000)


class ScreenTimeWalletView(BaseModel):
    """Wire shape of the per-student wallet."""

    student_id: str
    workspace_id: str
    total_earned_minutes: int
    available_minutes: int
    consumed_minutes: int
    consumed_today: int
    last_known_xp: int
    last_sync_time: str | None
    last_reset_date: str | None
    week_start_date: str | None


class ConsumeMinutesRequest(BaseModel):
    """Body for POST /wallet/consume."""

    minutes: int = Field(..., ge=1, description="Number of minutes consumed.")


class StudentDeviceStatusView(BaseModel):
    """Current blocking-permission health for one workspace student."""

    student_id: str
    display_name: str
    usage_access_permission: bool = False
    overlay_permission: bool = False
    notification_access: bool = False
    accessibility_service: bool = False
    battery_optimization_exempt: bool = False
    last_reported_at: str | None = None

    @property
    def blocking_ready(self) -> bool:
        """Whether both permissions required by the student blocker are active."""
        return self.usage_access_permission and self.accessibility_service


# ── GET /settings ────────────────────────────────────────────────────────────


@router.get("/settings", response_model=ScreenTimeSettingsView)
async def get_settings(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> ScreenTimeSettingsView:
    """Return the workspace screen time configuration.

    Available to all workspace members (students need this to sync
    the blocked-packages list into SharedPreferences on startup).
    Returns defaults when the admin hasn't configured anything yet.
    """
    _assert_workspace_member(current_user, workspace_id)
    settings = await _load_or_default_settings(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
    )
    return _settings_to_view(settings)


# ── PUT /settings ────────────────────────────────────────────────────────────


@router.put("/settings", response_model=ScreenTimeSettingsView)
async def update_settings(
    workspace_id: str,
    body: ScreenTimeSettingsUpdate,
    current_user: User = Depends(get_current_user),
) -> ScreenTimeSettingsView:
    """Update the workspace screen time configuration.

    Admin only (workspace_admin or tenant_admin).
    Creates the settings document if it doesn't exist yet (upsert).
    """
    _assert_admin(current_user, workspace_id)

    # Check workspace type — school workspaces / teachers cannot enforce device blocking
    col_ws = get_collection(current_user.tenant_id, WORKSPACES)
    ws_doc = await col_ws.find_one({"_id": workspace_id, "deleted_at": None})
    if ws_doc and ws_doc.get("type") == "school":
        if body.enable_blocking is True or (body.blocked_packages and len(body.blocked_packages) > 0):
            raise ForbiddenError(
                "School and teacher accounts cannot enforce app blocking on student personal devices. "
                "Device interference is managed by parents or personal self-study."
            )

    settings = await _load_or_default_settings(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
    )

    # Apply partial updates
    if body.enable_blocking is not None:
        settings.enable_blocking = body.enable_blocking
    if body.blocked_packages is not None:
        settings.blocked_packages = body.blocked_packages
    if body.xp_to_minute_ratio is not None:
        settings.xp_to_minute_ratio = body.xp_to_minute_ratio
    settings.updated_at = utc_now()

    col = get_collection(current_user.tenant_id, SCREEN_TIME_SETTINGS)
    await col.replace_one(
        {"_id": settings.id},
        settings.model_dump(by_alias=True),
        upsert=True,
    )

    logger.info(
        "ScreenTimeSettings updated workspace=%s by user=%s",
        workspace_id,
        current_user.id,
    )
    return _settings_to_view(settings)


@router.get("/device-statuses", response_model=list[StudentDeviceStatusView])
async def get_device_statuses(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> list[StudentDeviceStatusView]:
    """Return blocking-permission health for students in this workspace."""
    _assert_admin(current_user, workspace_id)

    users = get_collection(current_user.tenant_id, USERS)
    student_cursor = users.find(
        {
            "role": UserRole.student,
            "workspace_memberships": {"$elemMatch": {"workspace_id": workspace_id}},
            "deleted_at": None,
        }
    )
    students = [User.model_validate(raw) async for raw in student_cursor]
    if not students:
        return []

    statuses = get_collection(current_user.tenant_id, PERMISSION_STATUS)
    status_cursor = statuses.find(
        {
            "student_id": {"$in": [student.id for student in students]},
            "deleted_at": None,
        }
    )
    statuses_by_student = {
        raw["student_id"]: raw async for raw in status_cursor if raw.get("student_id")
    }

    return [
        StudentDeviceStatusView(
            student_id=student.id,
            display_name=student.display_name,
            usage_access_permission=statuses_by_student.get(student.id, {}).get(
                "usage_access_permission", False
            ),
            overlay_permission=statuses_by_student.get(student.id, {}).get(
                "overlay_permission", False
            ),
            notification_access=statuses_by_student.get(student.id, {}).get(
                "notification_access", False
            ),
            accessibility_service=statuses_by_student.get(student.id, {}).get(
                "accessibility_service", False
            ),
            battery_optimization_exempt=statuses_by_student.get(student.id, {}).get(
                "battery_optimization_exempt", False
            ),
            last_reported_at=statuses_by_student.get(student.id, {}).get("last_reported_at"),
        )
        for student in sorted(students, key=lambda item: item.display_name.lower())
    ]


# ── GET /wallet ──────────────────────────────────────────────────────────────


@router.get("/wallet", response_model=ScreenTimeWalletView)
async def get_wallet(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> ScreenTimeWalletView:
    """Return the calling student's screen time wallet.

    Students read their own wallet. Admins may read any wallet in their
    workspace (useful for the admin dashboard — future feature).
    Returns a zero-state wallet on first call (not persisted).
    """
    _assert_workspace_member(current_user, workspace_id)
    wallet = await _load_or_default_wallet(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
    )
    wallet_changed = _apply_wallet_resets(wallet)
    if wallet_changed:
        wallet.updated_at = utc_now()
        await _save_wallet(current_user.tenant_id, wallet)
    return _wallet_to_view(wallet)


# ── POST /wallet/consume ─────────────────────────────────────────────────────


@router.post("/wallet/consume", response_model=ScreenTimeWalletView)
async def consume_minutes(
    workspace_id: str,
    body: ConsumeMinutesRequest,
    current_user: User = Depends(get_current_user),
) -> ScreenTimeWalletView:
    """Record screen time consumption for the calling student.

    Deducts ``minutes`` from ``available_minutes`` (floor 0) and adds to
    ``consumed_minutes`` and ``consumed_today``.  The Accessibility Service
    writes to SharedPreferences in real time; this endpoint is called by
    Flutter to sync those local deductions to the cloud (best-effort,
    may be batched).
    """
    _assert_workspace_member(current_user, workspace_id)

    wallet = await _load_or_default_wallet(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
    )
    _apply_wallet_resets(wallet)

    wallet.available_minutes = max(0, wallet.available_minutes - body.minutes)
    wallet.consumed_minutes += body.minutes
    wallet.consumed_today += body.minutes
    now = utc_now()
    wallet.last_sync_time = now
    wallet.updated_at = now

    await _save_wallet(current_user.tenant_id, wallet)
    return _wallet_to_view(wallet)


# ── POST /wallet/sync-xp ─────────────────────────────────────────────────────


@router.post("/wallet/sync-xp", response_model=ScreenTimeWalletView)
async def sync_xp(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> ScreenTimeWalletView:
    """Recalculate earned minutes from the student's current XP total.

    Reads ``GamificationState.xp_total``, applies the workspace
    ``xp_to_minute_ratio``, and updates ``available_minutes`` if the
    student has earned new minutes since the last sync.

    Flutter calls this after each XP-earning action (question answer,
    flashcard rating) so the wallet stays in sync with gamification.
    """
    _assert_workspace_member(current_user, workspace_id)

    # Fetch XP from gamification state
    gam_col = get_collection(current_user.tenant_id, GAMIFICATION)
    gam_doc = await gam_col.find_one({"workspace_id": workspace_id, "student_id": current_user.id})
    current_xp: int = gam_doc.get("xp_total", 0) if gam_doc else 0

    # Fetch workspace settings for the ratio
    settings = await _load_or_default_settings(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
    )

    wallet = await _load_or_default_wallet(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
    )
    wallet_changed = _apply_wallet_resets(wallet)

    ratio = settings.xp_to_minute_ratio
    weekly_xp_baseline = wallet.weekly_xp_baseline or 0
    expected_earned = min(
        MAX_EARNED_MINUTES_PER_WEEK,
        max(0, current_xp - weekly_xp_baseline) // ratio,
    )

    # Bring wallets created before the cap into compliance without treating
    # already-consumed minutes as available again.
    if wallet.total_earned_minutes > MAX_EARNED_MINUTES_PER_WEEK:
        excess_minutes = wallet.total_earned_minutes - MAX_EARNED_MINUTES_PER_WEEK
        wallet.total_earned_minutes = MAX_EARNED_MINUTES_PER_WEEK
        wallet.available_minutes = max(0, wallet.available_minutes - excess_minutes)
        wallet_changed = True

    delta = expected_earned - wallet.total_earned_minutes

    now = utc_now()
    if delta > 0:
        wallet.total_earned_minutes += delta
        wallet.available_minutes += delta
        wallet.last_known_xp = current_xp
        wallet.last_sync_time = now
        wallet.updated_at = now
        await _save_wallet(current_user.tenant_id, wallet)
        logger.info(
            "ScreenTimeWallet synced student=%s workspace=%s delta_minutes=%d new_available=%d",
            current_user.id,
            workspace_id,
            delta,
            wallet.available_minutes,
        )
    elif current_xp != wallet.last_known_xp or wallet_changed:
        wallet.last_known_xp = current_xp
        wallet.last_sync_time = now
        wallet.updated_at = now
        await _save_wallet(current_user.tenant_id, wallet)

    return _wallet_to_view(wallet)


# ── Helpers ───────────────────────────────────────────────────────────────────


async def _load_or_default_settings(*, tenant_id: str, workspace_id: str) -> ScreenTimeSettings:
    col = get_collection(tenant_id, SCREEN_TIME_SETTINGS)
    raw = await col.find_one({"_id": f"sts_{workspace_id}"})
    if raw:
        return ScreenTimeSettings.model_validate(raw)

    is_school = False
    try:
        col_ws = get_collection(tenant_id, WORKSPACES)
        ws_doc = await col_ws.find_one({"_id": workspace_id, "deleted_at": None})
        is_school = bool(ws_doc and ws_doc.get("type") == "school")
    except Exception:
        pass

    # Return in-memory defaults — only persisted when admin explicitly saves.
    return ScreenTimeSettings(
        **{"_id": f"sts_{workspace_id}"},
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        enable_blocking=not is_school,
        blocked_packages=[] if is_school else _DEFAULT_BLOCKED_PACKAGES,
    )


async def _load_or_default_wallet(
    *, tenant_id: str, workspace_id: str, student_id: str
) -> ScreenTimeWallet:
    col = get_collection(tenant_id, SCREEN_TIME_WALLETS)
    raw = await col.find_one({"_id": f"stw_{student_id}_{workspace_id}"})
    if raw:
        return ScreenTimeWallet.model_validate(raw)
    return ScreenTimeWallet(
        **{"_id": f"stw_{student_id}_{workspace_id}"},
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        available_minutes=30,
        total_earned_minutes=30,
    )


async def _save_wallet(tenant_id: str, wallet: ScreenTimeWallet) -> None:
    col = get_collection(tenant_id, SCREEN_TIME_WALLETS)
    await col.replace_one(
        {"_id": wallet.id},
        wallet.model_dump(by_alias=True),
        upsert=True,
    )


def _apply_wallet_resets(
    wallet: ScreenTimeWallet,
    *,
    now: datetime | None = None,
) -> bool:
    """Apply daily usage and Monday-based weekly balance resets.

    The weekly reset expires unused social time but leaves lifetime
    consumption intact for auditing.  It also snapshots the XP seen at the
    last sync, so an unchanged lifetime XP total cannot recreate a balance in
    the new week.  Existing wallets receive a period marker without losing
    their current balance; their first automatic reset is the next Monday.
    """
    current_time = now or datetime.now(UTC)
    today = current_time.date()
    changed = False

    today_iso = today.isoformat()
    if wallet.last_reset_date != today_iso:
        wallet.consumed_today = 0
        wallet.last_reset_date = today_iso
        changed = True

    week_start = today - timedelta(days=today.weekday())
    week_start_iso = week_start.isoformat()
    if wallet.week_start_date is None:
        # Seamless rollout for existing wallets: preserve the legacy
        # lifetime-earned total until next Monday. A zero baseline keeps the
        # pre-existing XP-to-minute delta calculation intact for this week.
        wallet.week_start_date = week_start_iso
        wallet.weekly_xp_baseline = 0
        changed = True
    elif wallet.week_start_date != week_start_iso:
        wallet.total_earned_minutes = 0
        wallet.available_minutes = 0
        wallet.consumed_today = 0
        wallet.week_start_date = week_start_iso
        wallet.weekly_xp_baseline = wallet.last_known_xp
        changed = True

    return changed


def _settings_to_view(s: ScreenTimeSettings) -> ScreenTimeSettingsView:
    return ScreenTimeSettingsView(
        workspace_id=s.workspace_id,
        enable_blocking=s.enable_blocking,
        blocked_packages=s.blocked_packages,
        xp_to_minute_ratio=s.xp_to_minute_ratio,
        updated_at=s.updated_at,
    )


def _wallet_to_view(w: ScreenTimeWallet) -> ScreenTimeWalletView:
    return ScreenTimeWalletView(
        student_id=w.student_id,
        workspace_id=w.workspace_id,
        total_earned_minutes=w.total_earned_minutes,
        available_minutes=w.available_minutes,
        consumed_minutes=w.consumed_minutes,
        consumed_today=w.consumed_today,
        last_known_xp=w.last_known_xp,
        last_sync_time=w.last_sync_time,
        last_reset_date=w.last_reset_date,
        week_start_date=w.week_start_date,
    )


def _assert_workspace_member(user: User, workspace_id: str) -> None:
    if user.role == UserRole.tenant_admin:
        return
    if workspace_id == f"wsp_self_{user.id}" or (
        workspace_id.startswith("wsp_self_") and user.id in workspace_id
    ):
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")


def _assert_admin(user: User, workspace_id: str) -> None:
    if user.role == UserRole.tenant_admin:
        return
    if workspace_id == f"wsp_self_{user.id}" or (
        workspace_id.startswith("wsp_self_") and user.id in workspace_id
    ):
        return
    if user.role == UserRole.workspace_admin:
        ids = {m.workspace_id for m in user.workspace_memberships}
        if workspace_id in ids:
            return
    raise ForbiddenError("Only workspace or tenant admins can update screen time settings")

