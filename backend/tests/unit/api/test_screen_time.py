from __future__ import annotations

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.screen_time import _apply_wallet_resets
from app.core.auth import get_current_user
from app.core.database import (
    GAMIFICATION,
    PERMISSION_STATUS,
    SCREEN_TIME_SETTINGS,
    SCREEN_TIME_WALLETS,
    USERS,
)
from app.main import app
from app.models.screen_time import ScreenTimeWallet
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


def test_weekly_reset_expires_balance_and_records_xp_checkpoint() -> None:
    wallet = ScreenTimeWallet(
        _id="stw_student_workspace",
        tenant_id="tenant_a",
        workspace_id="workspace_a",
        student_id="student_a",
        total_earned_minutes=60,
        available_minutes=35,
        consumed_minutes=25,
        consumed_today=8,
        last_known_xp=620,
        week_start_date="2026-07-06",
        weekly_xp_baseline=500,
    )

    changed = _apply_wallet_resets(
        wallet,
        now=datetime(2026, 7, 13, 8, 0, tzinfo=UTC),
    )

    assert changed is True
    assert wallet.week_start_date == "2026-07-13"
    assert wallet.weekly_xp_baseline == 620
    assert wallet.total_earned_minutes == 0
    assert wallet.available_minutes == 0
    assert wallet.consumed_minutes == 25
    assert wallet.consumed_today == 0


def test_initial_week_marker_preserves_existing_wallet_during_rollout() -> None:
    wallet = ScreenTimeWallet(
        _id="stw_student_workspace",
        tenant_id="tenant_a",
        workspace_id="workspace_a",
        student_id="student_a",
        total_earned_minutes=40,
        available_minutes=15,
        last_known_xp=400,
    )

    changed = _apply_wallet_resets(
        wallet,
        now=datetime(2026, 7, 15, 8, 0, tzinfo=UTC),
    )

    assert changed is True
    assert wallet.week_start_date == "2026-07-13"
    assert wallet.weekly_xp_baseline == 0
    assert wallet.total_earned_minutes == 40
    assert wallet.available_minutes == 15


@pytest.mark.parametrize(
    ("xp_total", "initial_earned", "initial_available", "expected_earned", "expected_available"),
    [
        (1190, 100, 80, 119, 99),
        (1200, 119, 99, 120, 100),
        (5000, 120, 100, 120, 100),
        (5000, 150, 130, 120, 100),
    ],
)
def test_sync_xp_caps_weekly_earned_social_time_at_two_hours(
    client: TestClient,
    xp_total: int,
    initial_earned: int,
    initial_available: int,
    expected_earned: int,
    expected_available: int,
) -> None:
    student = make_user(
        user_id="stu_a",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: student

    gamification = MagicMock()
    gamification.find_one = AsyncMock(return_value={"xp_total": xp_total})
    settings = MagicMock()
    settings.find_one = AsyncMock(return_value=None)
    wallets = MagicMock()
    wallets.find_one = AsyncMock(
        return_value=ScreenTimeWallet(
            _id="stw_stu_a_wsp_a",
            tenant_id=student.tenant_id,
            workspace_id="wsp_a",
            student_id="stu_a",
            total_earned_minutes=initial_earned,
            available_minutes=initial_available,
            week_start_date=(
                datetime.now(UTC).date() - timedelta(days=datetime.now(UTC).date().weekday())
            ).isoformat(),
            weekly_xp_baseline=0,
            last_known_xp=initial_earned * 10,
        ).model_dump(by_alias=True)
    )
    wallets.replace_one = AsyncMock()

    def collection_factory(_tenant_id: str, name: str):
        return {
            GAMIFICATION: gamification,
            SCREEN_TIME_SETTINGS: settings,
            SCREEN_TIME_WALLETS: wallets,
        }[name]

    with patch("app.api.screen_time.get_collection", side_effect=collection_factory):
        response = client.post("/api/v1/workspaces/wsp_a/screen-time/wallet/sync-xp")

    assert response.status_code == 200
    payload = response.json()
    assert payload["total_earned_minutes"] == expected_earned
    assert payload["available_minutes"] == expected_available
