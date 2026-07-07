from __future__ import annotations

from typing import Any
from pydantic import BaseModel, Field
from app.models.base import CosmosDocument, utc_now

class DbStatEvent(CosmosDocument):
    """Partition key: student_id.
    Stored in tenant's database under 'db_stats' collection.
    Tracks client-side analytics telemetry.
    """
    tenant_id: str
    student_id: str
    event_type: str  # "screen_time", "login_activity", "tab_switch", "question_card_time", "app_lifecycle", "app_switch", "question_answered", "button_click"
    details: dict[str, Any] = Field(default_factory=dict)
    occurred_at: str = Field(default_factory=utc_now)
