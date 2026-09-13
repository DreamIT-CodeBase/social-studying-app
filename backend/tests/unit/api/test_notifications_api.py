"""Unit tests for the notification API endpoints (Sprint 5.7).

Covers the three routes:

* ``POST /users/me/notification-tokens`` — registration (happy + bad input).
* ``DELETE /users/me/notification-tokens/{installation_id}`` — idempotent.
* ``POST /admin/notifications/run-scheduler`` — admin-only,
  returns the scheduler summary.

Auth scope rules:

* Token routes require any authenticated user, scoped to ``self``
  (the route key is ``/users/me`` — the user_id never comes from the
  client).
* Scheduler route requires a tenant admin.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.notification import DevicePlatform, NotificationToken
from app.models.user import UserRole
from app.workers.notification_scheduler import TickSummary
from tests.unit.conftest import make_user


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


@pytest.fixture
def student():
    user = make_user(
        user_id="stu_a",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: user
    return user


@pytest.fixture
def tenant_admin():
    user = make_user(
        user_id="usr_tadm",
        role=UserRole.tenant_admin,
        workspace_ids=[],
    )
    app.dependency_overrides[get_current_user] = lambda: user
    return user


def _stub_registered_token(
    *,
    installation_id: str = "inst_xyz",
    token_value: str = "fcm-token-xyz",
) -> NotificationToken:
    return NotificationToken(
        **{"_id": "ntk_stub"},
        tenant_id="ten_test001",
        user_id="stu_a",
        installation_id=installation_id,
        token=token_value,
        platform=DevicePlatform.android,
        registered_at="2026-05-23T10:00:00+00:00",
        last_seen_at="2026-05-23T10:00:00+00:00",
    )


# ── Token registration ───────────────────────────────────────────────────


def test_register_token_201_and_echo(client, student):
    with patch(
        "app.api.notifications.notification_service.register_token",
        AsyncMock(return_value=_stub_registered_token()),
    ):
        response = client.post(
            "/api/v1/users/me/notification-tokens",
            json={
                "installation_id": "inst_xyz",
                "token": "fcm-token-xyz",
                "platform": "android",
            },
        )
    assert response.status_code == 201
    body = response.json()
    assert body["installation_id"] == "inst_xyz"
    assert body["token"] == "fcm-token-xyz"
    assert body["platform"] == "android"


def test_register_token_passes_user_from_jwt_not_body(client, student):
    """Even if the request body could carry a user_id, the endpoint must
    use the JWT-bound caller. The signature doesn't accept one, but
    pin the behaviour by asserting register_token was called with the
    caller's id."""
    captured: dict = {}

    async def _capture(**kwargs):
        captured.update(kwargs)
        return _stub_registered_token()

    with patch(
        "app.api.notifications.notification_service.register_token",
        _capture,
    ):
        client.post(
            "/api/v1/users/me/notification-tokens",
            json={
                "installation_id": "inst_xyz",
                "token": "fcm-token-xyz",
                "platform": "android",
            },
        )
    assert captured["user_id"] == "stu_a"
    assert captured["tenant_id"] == "ten_test001"


def test_register_token_rejects_invalid_platform(client, student):
    response = client.post(
        "/api/v1/users/me/notification-tokens",
        json={
            "installation_id": "inst_xyz",
            "token": "fcm-token-xyz",
            "platform": "windows",
        },
    )
    assert response.status_code == 422


def test_register_token_rejects_empty_installation(client, student):
    response = client.post(
        "/api/v1/users/me/notification-tokens",
        json={
            "installation_id": "",
            "token": "fcm-token-xyz",
            "platform": "android",
        },
    )
    assert response.status_code == 422


def test_register_token_requires_auth(client):
    response = client.post(
        "/api/v1/users/me/notification-tokens",
        json={
            "installation_id": "inst_xyz",
            "token": "fcm-token-xyz",
            "platform": "android",
        },
    )
    # Without the dependency override, FastAPI's auth dep should refuse.
    assert response.status_code in (401, 403)


# ── Token deletion ───────────────────────────────────────────────────────


def test_delete_token_204(client, student):
    with patch(
        "app.api.notifications.notification_service.delete_token",
        AsyncMock(return_value=True),
    ):
        response = client.delete(
            "/api/v1/users/me/notification-tokens/inst_xyz",
        )
    assert response.status_code == 204
    assert response.content == b""


def test_delete_token_idempotent_no_row(client, student):
    """Deleting a non-existent row still returns 204 — the client cares
    that the row is gone, not how it got that way."""
    with patch(
        "app.api.notifications.notification_service.delete_token",
        AsyncMock(return_value=False),
    ):
        response = client.delete(
            "/api/v1/users/me/notification-tokens/inst_ghost",
        )
    assert response.status_code == 204


# ── Scheduler endpoint ───────────────────────────────────────────────────


def test_run_scheduler_returns_summary_to_tenant_admin(client, tenant_admin):
    summary = TickSummary(
        students_evaluated=42,
        study_reminders_sent=15,
        streak_warnings_sent=4,
        unanswered_reprompts_sent=7,
        failures=0,
    )
    with patch(
        "app.api.notifications.scheduler.run_tick_for_tenant",
        AsyncMock(return_value=summary),
    ):
        response = client.post("/api/v1/admin/notifications/run-scheduler")
    assert response.status_code == 200
    body = response.json()
    assert body == {
        "students_evaluated": 42,
        "study_reminders_sent": 15,
        "streak_warnings_sent": 4,
        "unanswered_reprompts_sent": 7,
        "failures": 0,
    }


def test_run_scheduler_uses_callers_tenant_id(client, tenant_admin):
    """An operator can't scope the tick to another tenant — the route
    pulls tenant_id from current_user, not from the request."""
    captured: dict = {}

    async def _capture(*, tenant_id):
        captured["tenant_id"] = tenant_id
        return TickSummary(
            students_evaluated=0,
            study_reminders_sent=0,
            streak_warnings_sent=0,
            unanswered_reprompts_sent=0,
            failures=0,
        )

    with patch("app.api.notifications.scheduler.run_tick_for_tenant", _capture):
        client.post("/api/v1/admin/notifications/run-scheduler")
    assert captured["tenant_id"] == "ten_test001"


def test_run_scheduler_refused_for_workspace_admin(client):
    workspace_admin = make_user(
        user_id="usr_wadm",
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: workspace_admin
    response = client.post("/api/v1/admin/notifications/run-scheduler")
    assert response.status_code == 403


def test_run_scheduler_refused_for_student(client, student):
    response = client.post("/api/v1/admin/notifications/run-scheduler")
    assert response.status_code == 403


def test_activity_feed_allowed_for_workspace_admin(client):
    workspace_admin = make_user(
        user_id="usr_wadm",
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: workspace_admin

    class _MockCursor:
        def __init__(self, items):
            self.items = items
        async def to_list(self, length=100):
            return self.items

    class _MockCollection:
        def __init__(self, data=None):
            self.data = data or []
        def find(self, *args, **kwargs):
            return _MockCursor(self.data)

    def _mock_get_collection(tenant_id, name):
        if name == "adaptive_sessions":
            return _MockCollection([
                {
                    "_id": "ses_1",
                    "student_id": "stu_a",
                    "workspace_id": "wsp_a",
                    "mode": "study",
                    "plan": {"subject": "Chemistry", "subcategory": "Atomic Structure"},
                    "accuracy_percentage": 85.0,
                    "xp_gained": 40,
                    "completed_count": 5,
                    "completed_at": "2026-09-01T12:00:00Z",
                }
            ])
        if name == "users":
            return _MockCollection([
                {"_id": "stu_a", "display_name": "Alice"}
            ])
        if name == "workspaces":
            return _MockCollection([
                {"_id": "wsp_a", "name": "Grade 10 Chemistry"}
            ])
        if name == "gamification":
            return _MockCollection([
                {
                    "_id": "gam_1",
                    "student_id": "stu_a",
                    "workspace_id": "wsp_a",
                    "streak_days": 5,
                    "level": 3,
                    "xp_total": 350,
                    "updated_at": "2026-09-01T12:00:00Z",
                }
            ])
        return _MockCollection([])

    with patch("app.core.database.get_collection", _mock_get_collection):
        response = client.get("/api/v1/admin/notifications/activity-feed")

    assert response.status_code == 200
    data = response.json()
    assert "items" in data
    types = [item["type"] for item in data["items"]]
    assert "child_progress" in types
    assert "streak_milestone" in types
    assert "mastery_milestone" in types


def test_activity_feed_refused_for_student(client, student):
    response = client.get("/api/v1/admin/notifications/activity-feed")
    assert response.status_code == 403
