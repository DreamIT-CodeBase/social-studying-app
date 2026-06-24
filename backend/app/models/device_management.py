"""Models for Device Management and Parental Control."""

from __future__ import annotations
from pydantic import Field
from app.models.base import CosmosDocument, utc_now

class TimeRange(CosmosDocument.__base__):
    start: str  # HH:MM
    end: str    # HH:MM

class AppRestriction(CosmosDocument):
    """Partition key: student_id."""
    tenant_id: str
    student_id: str
    package_name: str
    app_name: str
    is_blocked: bool = False
    daily_limit_minutes: int | None = None
    weekly_limit_minutes: int | None = None
    study_mode_restricted: bool = False
    allowed_time_ranges: list[TimeRange] = Field(default_factory=list)

class StudyModeDayHours(CosmosDocument.__base__):
    day: str  # "weekday", "weekend", or day names
    start: str
    end: str

class ParentalControl(CosmosDocument):
    """Partition key: student_id."""
    tenant_id: str
    student_id: str
    parent_id: str
    study_mode_enabled: bool = False
    study_mode_hours: list[StudyModeDayHours] = Field(default_factory=list)
    screen_time_enabled: bool = True

class PermissionStatus(CosmosDocument):
    """Partition key: student_id."""
    tenant_id: str
    student_id: str
    overlay_permission: bool = False
    usage_access_permission: bool = False
    notification_access: bool = False
    accessibility_service: bool = False
    battery_optimization_exempt: bool = False
    device_administrator: bool = False
    last_reported_at: str = Field(default_factory=utc_now)

class AppUsageLog(CosmosDocument):
    """Partition key: student_id."""
    tenant_id: str
    student_id: str
    package_name: str
    app_name: str
    open_time: str
    close_time: str | None = None
    duration_seconds: int = 0

class ScreenTimeLog(CosmosDocument):
    """Partition key: student_id."""
    tenant_id: str
    student_id: str
    date: str  # YYYY-MM-DD
    total_usage_seconds: int = 0
    active_study_seconds: int = 0
    idle_seconds: int = 0

class DeviceUsageLog(CosmosDocument):
    """Partition key: student_id."""
    tenant_id: str
    student_id: str
    date: str  # YYYY-MM-DD
    total_screen_time_seconds: int = 0
    learning_time_seconds: int = 0
    social_media_time_seconds: int = 0
    app_stats: dict[str, int] = Field(default_factory=dict)  # package_name -> seconds_used
