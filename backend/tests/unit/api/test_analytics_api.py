"""Unit tests for the analytics API endpoints (Sprint 5.9 + 5.13).

The service layer is mocked — its aggregation math is pinned in
``test_analytics.py``. These tests cover the endpoint surface:
access control across the three endpoints, response shape, and the
wire-contract match with Flutter's ``StudentProgress``.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.user import UserRole
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
def workspace_admin():
    user = make_user(
        user_id="usr_wadm",
        role=UserRole.workspace_admin,
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


def _progress_payload() -> dict:
    return {
        "level": 2,
        "total_xp": 250,
        "xp_into_level": 150,
        "xp_for_next_level": 300,
        "overall_mastery": 0.5,
        "topics": [
            {
                "topic_id": "Photosynthesis",
                "topic_name": "Photosynthesis",
                "mastery": 0.6,
                "attempts": 10,
                "success_rate": 0.7,
            }
        ],
        "recent_activity": [
            {
                "kind": "question",
                "topic": "Photosynthesis",
                "is_correct": True,
                "xp_earned": 15,
                "occurred_at": "2026-05-23T10:00:00+00:00",
            }
        ],
    }


# ── Student progress endpoint ──────────────────────────────────────────────


def test_student_progress_happy_path(client, student):
    with patch(
        "app.api.analytics.analytics_service.build_student_progress",
        AsyncMock(return_value=_progress_payload()),
    ):
        response = client.get(
            "/api/v1/workspaces/wsp_a/users/stu_a/progress",
        )
    assert response.status_code == 200
    body = response.json()
    # Wire-contract match: Flutter's StudentProgress expects this exact shape.
    assert body["level"] == 2
    assert body["total_xp"] == 250
    assert body["xp_into_level"] == 150
    assert body["xp_for_next_level"] == 300
    assert body["overall_mastery"] == 0.5
    assert body["topics"][0]["topic_name"] == "Photosynthesis"
    assert body["recent_activity"][0]["kind"] == "question"


def test_student_progress_student_cannot_read_others(client, student):
    response = client.get(
        "/api/v1/workspaces/wsp_a/users/stu_other/progress",
    )
    assert response.status_code == 403


def test_student_progress_workspace_admin_reads_any_member(client, workspace_admin):
    with patch(
        "app.api.analytics.analytics_service.build_student_progress",
        AsyncMock(return_value=_progress_payload()),
    ):
        response = client.get(
            "/api/v1/workspaces/wsp_a/users/stu_a/progress",
        )
    assert response.status_code == 200


def test_student_progress_workspace_admin_outside_workspace_gets_403(client):
    """A workspace admin in wsp_a can't read wsp_b progress."""
    user = make_user(
        user_id="usr_wadm",
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: user

    response = client.get(
        "/api/v1/workspaces/wsp_b/users/stu_b/progress",
    )
    assert response.status_code == 403


def test_student_progress_tenant_admin_bypasses_workspace_check(client, tenant_admin):
    with patch(
        "app.api.analytics.analytics_service.build_student_progress",
        AsyncMock(return_value=_progress_payload()),
    ):
        response = client.get(
            "/api/v1/workspaces/wsp_other/users/stu_x/progress",
        )
    assert response.status_code == 200


# ── Workspace analytics endpoint ───────────────────────────────────────────


def _workspace_analytics_payload() -> dict:
    return {
        "workspace_id": "wsp_a",
        "total_students": 5,
        "active_students_7d": 3,
        "avg_overall_mastery": 0.42,
        "avg_questions_per_student": 8.5,
        "avg_correct_rate": 0.71,
        "topic_distribution": [
            {
                "topic": "Photosynthesis",
                "attempts": 20,
                "avg_mastery": 0.55,
                "correct_rate": 0.7,
            }
        ],
        "difficulty_distribution": {
            "beginner": {"attempts": 0, "correct": 0},
            "intermediate": {"attempts": 0, "correct": 0},
            "advanced": {"attempts": 0, "correct": 0},
        },
        "engagement_heatmap": [{"date": "2026-05-23", "events": 4}],
    }


def test_workspace_analytics_workspace_admin_happy_path(client, workspace_admin):
    with patch(
        "app.api.analytics.analytics_service.build_workspace_analytics",
        AsyncMock(return_value=_workspace_analytics_payload()),
    ):
        response = client.get("/api/v1/workspaces/wsp_a/analytics")
    assert response.status_code == 200
    body = response.json()
    assert body["total_students"] == 5
    assert body["avg_overall_mastery"] == 0.42
    assert body["topic_distribution"][0]["topic"] == "Photosynthesis"


def test_workspace_analytics_student_gets_403(client, student):
    """Students hit the progress endpoint, not analytics."""
    response = client.get("/api/v1/workspaces/wsp_a/analytics")
    assert response.status_code == 403


def test_workspace_analytics_admin_outside_workspace_gets_403(client):
    """Workspace admin in wsp_a can't read wsp_b analytics."""
    user = make_user(
        user_id="usr_wadm",
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: user

    response = client.get("/api/v1/workspaces/wsp_b/analytics")
    assert response.status_code == 403


def test_workspace_analytics_tenant_admin_can_read_any(client, tenant_admin):
    with patch(
        "app.api.analytics.analytics_service.build_workspace_analytics",
        AsyncMock(return_value=_workspace_analytics_payload()),
    ):
        response = client.get("/api/v1/workspaces/wsp_anywhere/analytics")
    assert response.status_code == 200


# ── Tenant analytics endpoint ──────────────────────────────────────────────


def _tenant_analytics_payload() -> dict:
    return {
        "tenant_id": "ten_test001",
        "total_workspaces": 2,
        "total_students": 12,
        "active_students_7d": 8,
        "workspaces": [
            {
                "workspace_id": "wsp_a",
                "name": "Class A",
                "total_students": 5,
                "active_students_7d": 3,
                "avg_mastery": 0.5,
                "total_questions_answered": 40,
                "total_flashcards_reviewed": 10,
            }
        ],
    }


def test_tenant_analytics_tenant_admin_happy_path(client, tenant_admin):
    with patch(
        "app.api.analytics.analytics_service.build_tenant_analytics",
        AsyncMock(return_value=_tenant_analytics_payload()),
    ):
        response = client.get("/api/v1/tenants/ten_test001/analytics")
    assert response.status_code == 200
    body = response.json()
    assert body["total_workspaces"] == 2
    assert body["total_students"] == 12
    assert body["workspaces"][0]["name"] == "Class A"


def test_tenant_analytics_workspace_admin_gets_403(client, workspace_admin):
    response = client.get("/api/v1/tenants/ten_test001/analytics")
    assert response.status_code == 403


def test_tenant_analytics_cross_tenant_read_gets_403(client, tenant_admin):
    """A tenant admin in ten_test001 can't read ten_other's analytics."""
    response = client.get("/api/v1/tenants/ten_other/analytics")
    assert response.status_code == 403
