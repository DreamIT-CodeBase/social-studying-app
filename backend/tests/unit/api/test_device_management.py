from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

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


def test_report_db_stats_happy_path(client, student):
    mock_collection = AsyncMock()
    mock_collection.insert_one = AsyncMock(return_value=None)

    payload = {
        "events": [
            {
                "event_type": "tab_switch",
                "details": {"from_tab": "Home", "to_tab": "Study"},
                "occurred_at": "2026-07-07T10:00:00Z"
            }
        ]
    }

    with patch("app.api.device_management.get_collection", return_value=mock_collection):
        response = client.post(
            "/api/v1/student/device/db-stats",
            json=payload,
        )

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["count"] == 1
    assert mock_collection.insert_one.call_count == 1


def test_get_student_db_stats_happy_path(client, workspace_admin):
    mock_cursor = MagicMock()
    mock_cursor.sort = MagicMock(return_value=mock_cursor)
    mock_cursor.limit = MagicMock(return_value=mock_cursor)
    
    mock_docs = [
        {
            "_id": "ev_abc123",
            "tenant_id": "ten_smoke001",
            "student_id": "stu_a",
            "event_type": "tab_switch",
            "details": {"from_tab": "Home", "to_tab": "Study"},
            "occurred_at": "2026-07-07T10:00:00Z",
            "deleted_at": None
        }
    ]
    
    async def mock_async_iterator(*args, **kwargs):
        for doc in mock_docs:
            yield doc
            
    mock_cursor.__aiter__ = mock_async_iterator

    mock_collection = MagicMock()
    mock_collection.find = MagicMock(return_value=mock_cursor)

    with patch("app.api.device_management.get_collection", return_value=mock_collection):
        response = client.get(
            "/api/v1/parent/students/stu_a/db-stats",
        )

    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["id"] == "ev_abc123"
    assert response.json()[0]["event_type"] == "tab_switch"


def test_get_student_db_stats_forbidden_for_student(client, student):
    response = client.get(
        "/api/v1/parent/students/stu_b/db-stats",
    )
    assert response.status_code == 403
