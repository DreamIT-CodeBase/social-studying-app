"""API endpoints for device management, app usage, limits, and parental controls."""

from __future__ import annotations
from typing import Any
import logging
from uuid import uuid4
from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field

from app.core.auth import get_current_user, require_role
from app.core.database import (
    get_collection,
    USERS,
    PERMISSION_STATUS,
    APP_RESTRICTIONS,
    PARENTAL_CONTROLS,
    APP_USAGE_LOGS,
    SCREEN_TIME_LOGS,
    DEVICE_USAGE_LOGS,
    DB_STATS,
)
from app.models.user import User, UserRole, UserResponse
from app.models.device_management import (
    PermissionStatus,
    AppRestriction,
    ParentalControl,
    AppUsageLog,
    ScreenTimeLog,
    DeviceUsageLog,
    TimeRange,
)
from app.models.db_stats import DbStatEvent
from app.core.exceptions import ForbiddenError, NotFoundError
from app.models.base import utc_now

logger = logging.getLogger(__name__)

router = APIRouter(tags=["device_management"])


# ── Wire Types ────────────────────────────────────────────────────────────────

class PermissionStatusUpdate(BaseModel):
    overlay_permission: bool
    usage_access_permission: bool
    notification_access: bool
    accessibility_service: bool
    battery_optimization_exempt: bool
    device_administrator: bool


class AppRestrictionUpdate(BaseModel):
    package_name: str
    app_name: str
    is_blocked: bool
    daily_limit_minutes: int | None = None
    weekly_limit_minutes: int | None = None
    study_mode_restricted: bool = False
    allowed_time_ranges: list[TimeRange] = Field(default_factory=list)


class RestrictionsPayload(BaseModel):
    restrictions: list[AppRestrictionUpdate]


class UsageLogsPayload(BaseModel):
    app_logs: list[AppUsageLog]
    screen_time_log: ScreenTimeLog


class DbStatEventPayload(BaseModel):
    event_type: str
    details: dict[str, Any] = Field(default_factory=dict)
    occurred_at: str


class DbStatsPayload(BaseModel):
    events: list[DbStatEventPayload]


DbStatEventPayload.model_rebuild()
DbStatsPayload.model_rebuild()


# ── Parent Endpoints ─────────────────────────────────────────────────────────

@router.get("/parent/students", response_model=list[UserResponse])
async def list_students(
    current_user: User = Depends(get_current_user),
) -> list[UserResponse]:
    """List all student profiles in the tenant that this parent oversees."""
    if current_user.role not in (UserRole.tenant_admin, UserRole.workspace_admin):
        raise ForbiddenError("Only parents or admins can view students list")

    col = get_collection(current_user.tenant_id, USERS)
    cursor = col.find({"tenant_id": current_user.tenant_id, "role": UserRole.student, "deleted_at": None})
    return [UserResponse.from_doc(User.model_validate(doc)) async for doc in cursor]


@router.get("/parent/students/{student_id}/device-status", response_model=dict)
async def get_device_status(
    student_id: str,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Get the current permission configuration and device status of a student."""
    if current_user.role not in (UserRole.tenant_admin, UserRole.workspace_admin):
        raise ForbiddenError("Only parents or admins can query device status")

    col = get_collection(current_user.tenant_id, PERMISSION_STATUS)
    doc = await col.find_one({"student_id": student_id, "deleted_at": None})
    if not doc:
        return {
            "student_id": student_id,
            "overlay_permission": False,
            "usage_access_permission": False,
            "notification_access": False,
            "accessibility_service": False,
            "battery_optimization_exempt": False,
            "device_administrator": False,
            "last_reported_at": None,
        }
    return doc


@router.put("/parent/students/{student_id}/restrictions", response_model=dict)
async def update_student_restrictions(
    student_id: str,
    payload: RestrictionsPayload,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Overwrites the list of restricted/allowed apps for a student."""
    if current_user.role not in (UserRole.tenant_admin, UserRole.workspace_admin):
        raise ForbiddenError("Only parents or admins can manage app restrictions")

    col = get_collection(current_user.tenant_id, APP_RESTRICTIONS)
    
    # Soft delete existing restrictions first
    await col.update_many(
        {"student_id": student_id, "deleted_at": None},
        {"$set": {"deleted_at": utc_now(), "updated_at": utc_now()}}
    )

    saved_restrictions = []
    for r in payload.restrictions:
        doc = AppRestriction(
            **{"_id": f"res_{uuid4().hex}"},
            tenant_id=current_user.tenant_id,
            student_id=student_id,
            package_name=r.package_name,
            app_name=r.app_name,
            is_blocked=r.is_blocked,
            daily_limit_minutes=r.daily_limit_minutes,
            weekly_limit_minutes=r.weekly_limit_minutes,
            study_mode_restricted=r.study_mode_restricted,
            allowed_time_ranges=[TimeRange(start=tr.start, end=tr.end) for tr in r.allowed_time_ranges],
        )
        await col.insert_one(doc.model_dump(by_alias=True))
        saved_restrictions.append(doc.model_dump(by_alias=True))

    return {"status": "ok", "count": len(saved_restrictions)}


@router.get("/parent/students/{student_id}/analytics", response_model=dict)
async def get_student_analytics(
    student_id: str,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Return daily, weekly, and monthly productivity summaries for a student."""
    if current_user.role not in (UserRole.tenant_admin, UserRole.workspace_admin):
        raise ForbiddenError("Only parents or admins can view student analytics")

    col = get_collection(current_user.tenant_id, DEVICE_USAGE_LOGS)
    await col.create_index([("date", -1)])
    cursor = col.find({"student_id": student_id, "deleted_at": None}).sort("date", -1).limit(30)
    logs = [doc async for doc in cursor]

    # Compute summaries
    daily_stats = []
    total_study_seconds = 0
    total_social_seconds = 0
    total_screen_seconds = 0

    for log in logs:
        daily_stats.append({
            "date": log["date"],
            "screen_time_mins": log["total_screen_time_seconds"] // 60,
            "learning_mins": log["learning_time_seconds"] // 60,
            "social_media_mins": log["social_media_time_seconds"] // 60,
        })
        total_study_seconds += log.get("learning_time_seconds", 0)
        total_social_seconds += log.get("social_media_time_seconds", 0)
        total_screen_seconds += log.get("total_screen_time_seconds", 0)

    count = len(logs) or 1
    return {
        "student_id": student_id,
        "days_tracked": len(logs),
        "averages": {
            "daily_screen_time_mins": (total_screen_seconds // count) // 60,
            "daily_learning_time_mins": (total_study_seconds // count) // 60,
            "daily_social_media_time_mins": (total_social_seconds // count) // 60,
        },
        "daily_stats": daily_stats,
    }


# ── Student Sync Endpoints ───────────────────────────────────────────────────

@router.post("/student/device/permission-status", response_model=dict)
async def report_permissions(
    body: PermissionStatusUpdate,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Sync permissions and health status from student device to cloud."""
    col = get_collection(current_user.tenant_id, PERMISSION_STATUS)
    
    # Retrieve existing or insert new status
    doc = await col.find_one({"student_id": current_user.id, "deleted_at": None})
    
    now = utc_now()
    if doc:
        status_obj = PermissionStatus.model_validate(doc)
        status_obj.overlay_permission = body.overlay_permission
        status_obj.usage_access_permission = body.usage_access_permission
        status_obj.notification_access = body.notification_access
        status_obj.accessibility_service = body.accessibility_service
        status_obj.battery_optimization_exempt = body.battery_optimization_exempt
        status_obj.device_administrator = body.device_administrator
        status_obj.last_reported_at = now
        status_obj.touch()
        await col.replace_one({"_id": status_obj.id}, status_obj.model_dump(by_alias=True))
    else:
        status_obj = PermissionStatus(
            **{"_id": f"perm_{uuid4().hex}"},
            tenant_id=current_user.tenant_id,
            student_id=current_user.id,
            overlay_permission=body.overlay_permission,
            usage_access_permission=body.usage_access_permission,
            notification_access=body.notification_access,
            accessibility_service=body.accessibility_service,
            battery_optimization_exempt=body.battery_optimization_exempt,
            device_administrator=body.device_administrator,
            last_reported_at=now,
        )
        await col.insert_one(status_obj.model_dump(by_alias=True))

    return {"status": "ok", "last_reported_at": now}


@router.post("/student/device/usage-logs", response_model=dict)
async def report_usage_logs(
    payload: UsageLogsPayload,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Sync device and app usage logs from the student device."""
    app_col = get_collection(current_user.tenant_id, APP_USAGE_LOGS)
    screen_col = get_collection(current_user.tenant_id, SCREEN_TIME_LOGS)
    device_col = get_collection(current_user.tenant_id, DEVICE_USAGE_LOGS)

    # 1. Insert app usage logs
    for log in payload.app_logs:
        # Avoid duplicate logs if already synced
        existing = await app_col.find_one({"student_id": current_user.id, "package_name": log.package_name, "open_time": log.open_time})
        if not existing:
            doc = AppUsageLog(
                **{"_id": f"ulog_{uuid4().hex}"},
                tenant_id=current_user.tenant_id,
                student_id=current_user.id,
                package_name=log.package_name,
                app_name=log.app_name,
                open_time=log.open_time,
                close_time=log.close_time,
                duration_seconds=log.duration_seconds,
            )
            await app_col.insert_one(doc.model_dump(by_alias=True))

    # 2. Insert or replace screen time log for date
    date_str = payload.screen_time_log.date
    existing_screen = await screen_col.find_one({"student_id": current_user.id, "date": date_str})
    if existing_screen:
        screen_obj = ScreenTimeLog.model_validate(existing_screen)
        screen_obj.total_usage_seconds = max(screen_obj.total_usage_seconds, payload.screen_time_log.total_usage_seconds)
        screen_obj.active_study_seconds = max(screen_obj.active_study_seconds, payload.screen_time_log.active_study_seconds)
        screen_obj.idle_seconds = max(screen_obj.idle_seconds, payload.screen_time_log.idle_seconds)
        screen_obj.touch()
        await screen_col.replace_one({"_id": screen_obj.id}, screen_obj.model_dump(by_alias=True))
    else:
        screen_obj = ScreenTimeLog(
            **{"_id": f"slog_{uuid4().hex}"},
            tenant_id=current_user.tenant_id,
            student_id=current_user.id,
            date=date_str,
            total_usage_seconds=payload.screen_time_log.total_usage_seconds,
            active_study_seconds=payload.screen_time_log.active_study_seconds,
            idle_seconds=payload.screen_time_log.idle_seconds,
        )
        await screen_col.insert_one(screen_obj.model_dump(by_alias=True))

    # 3. Aggregate daily/device usage stats
    # For simplicity, calculate or update total screen time and social media duration
    social_media_packages = {
        "com.instagram.android",
        "com.zhiliaoapp.musically",
        "com.google.android.youtube",
        "com.facebook.katana",
        "com.twitter.android",
        "com.snapchat.android",
    }
    
    # Retrieve all app logs for today
    cursor = app_col.find({"student_id": current_user.id, "open_time": {"$regex": f"^{date_str}"}, "deleted_at": None})
    today_logs = [AppUsageLog.model_validate(doc) async for doc in cursor]

    social_seconds = 0
    app_stats = {}
    for l in today_logs:
        app_stats[l.package_name] = app_stats.get(l.package_name, 0) + l.duration_seconds
        if l.package_name in social_media_packages:
            social_seconds += l.duration_seconds

    existing_device = await device_col.find_one({"student_id": current_user.id, "date": date_str})
    if existing_device:
        device_obj = DeviceUsageLog.model_validate(existing_device)
        device_obj.total_screen_time_seconds = screen_obj.total_usage_seconds
        device_obj.learning_time_seconds = screen_obj.active_study_seconds
        device_obj.social_media_time_seconds = social_seconds
        device_obj.app_stats = app_stats
        device_obj.touch()
        await device_col.replace_one({"_id": device_obj.id}, device_obj.model_dump(by_alias=True))
    else:
        device_obj = DeviceUsageLog(
            **{"_id": f"devu_{uuid4().hex}"},
            tenant_id=current_user.tenant_id,
            student_id=current_user.id,
            date=date_str,
            total_screen_time_seconds=screen_obj.total_usage_seconds,
            learning_time_seconds=screen_obj.active_study_seconds,
            social_media_time_seconds=social_seconds,
            app_stats=app_stats,
        )
        await device_col.insert_one(device_obj.model_dump(by_alias=True))

    return {"status": "ok"}


@router.post("/student/device/db-stats", response_model=dict)
async def report_db_stats(
    payload: DbStatsPayload,
    current_user: User = Depends(get_current_user),
) -> dict:
    """Sync telemetry / DB stats from the student device."""
    col = get_collection(current_user.tenant_id, DB_STATS)
    saved_count = 0
    for event_data in payload.events:
        doc = DbStatEvent(
            **{"_id": f"ev_{uuid4().hex}"},
            tenant_id=current_user.tenant_id,
            student_id=current_user.id,
            event_type=event_data.event_type,
            details=event_data.details,
            occurred_at=event_data.occurred_at,
        )
        await col.insert_one(doc.model_dump(by_alias=True))
        saved_count += 1
    return {"status": "ok", "count": saved_count}


@router.get("/parent/students/{student_id}/db-stats", response_model=list)
async def get_student_db_stats(
    student_id: str,
    current_user: User = Depends(get_current_user),
) -> list[dict]:
    """Get the telemetry/DB stats log history for a specific student."""
    if current_user.role not in (UserRole.tenant_admin, UserRole.workspace_admin):
        raise ForbiddenError("Only parents or admins can query student DB stats")

    col = get_collection(current_user.tenant_id, DB_STATS)
    cursor = col.find({"student_id": student_id, "deleted_at": None}).sort("occurred_at", -1).limit(500)
    
    results = []
    async for doc in cursor:
        doc["id"] = doc.pop("_id")
        results.append(doc)
    return results
