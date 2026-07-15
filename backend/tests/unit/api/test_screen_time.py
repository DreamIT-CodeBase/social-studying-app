from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.core.database import PERMISSION_STATUS, USERS
from app.main import app
from app.models.user import UserRole
from tests.unit.conftest import make_user


class AsyncCursor:
    """Small async cursor used by the screen-time endpoint tests."""

    def __init__(self, documents: list[dict]) -> None:
        self._documents = documents
        self._index = 0

    def __aiter__(self) -> AsyncCursor:
        return self

    async def __anext__(self) -> dict:
        if self._index >= len(self._documents):
            raise StopAsyncIteration
        document = self._documents[self._index]
        self._index += 1
        return document


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


def test_admin_lists_student_blocking_health(client: TestClient) -> None:
    admin = make_user(
        user_id="usr_admin",
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: admin

    alice = make_user(
        user_id="stu_alice",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    ).model_copy(update={"display_name": "Alice"})
    bob = make_user(
        user_id="stu_bob",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    ).model_copy(update={"display_name": "Bob"})

    users = MagicMock()
    users.find.return_value = AsyncCursor(
        [bob.model_dump(by_alias=True), alice.model_dump(by_alias=True)]
    )
    statuses = MagicMock()
    statuses.find.return_value = AsyncCursor(
        [
            {
                "student_id": "stu_alice",
                "usage_access_permission": True,
                "overlay_permission": False,
                "notification_access": True,
                "accessibility_service": True,
                "battery_optimization_exempt": False,
                "last_reported_at": "2026-07-15T08:00:00+00:00",
                "deleted_at": None,
            }
        ]
    )

    def collection_factory(_tenant_id: str, name: str):
        return {USERS: users, PERMISSION_STATUS: statuses}[name]

    with patch("app.api.screen_time.get_collection", side_effect=collection_factory):
        response = client.get("/api/v1/workspaces/wsp_a/screen-time/device-statuses")

    assert response.status_code == 200
    payload = response.json()
    assert [item["display_name"] for item in payload] == ["Alice", "Bob"]
    assert payload[0]["accessibility_service"] is True
    assert payload[0]["usage_access_permission"] is True
    assert payload[1]["accessibility_service"] is False
    assert payload[1]["last_reported_at"] is None


def test_student_cannot_list_workspace_device_health(client: TestClient) -> None:
    student = make_user(
        user_id="stu_a",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.get("/api/v1/workspaces/wsp_a/screen-time/device-statuses")

    assert response.status_code == 403


def test_device_health_returns_empty_for_workspace_without_students(
    client: TestClient,
) -> None:
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    users = MagicMock()
    users.find.return_value = AsyncCursor([])

    with patch("app.api.screen_time.get_collection", return_value=users):
        response = client.get("/api/v1/workspaces/wsp_empty/screen-time/device-statuses")

    assert response.status_code == 200
    assert response.json() == []
