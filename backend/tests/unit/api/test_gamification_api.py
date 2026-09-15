"""Unit tests for the gamification API endpoints (Sprint 5.2 + 5.13).

Covers the four read endpoints (profile, streak, badges, leaderboard)
across happy path, access rules, and the leaderboard visibility gate.
The engine layer is mocked — its own math is pinned in
``test_gamification.py``.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.gamification import Badge, GamificationState
from app.models.user import UserRole
from app.models.workspace import Workspace, WorkspaceSettings
from app.services.badges import BADGES
from tests.unit.conftest import make_user

# ── Fixtures ────────────────────────────────────────────────────────────────


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
def admin():
    """Tenant admin — full visibility across the tenant."""
    user = make_user(
        user_id="usr_admin",
        role=UserRole.tenant_admin,
        workspace_ids=[],
    )
    app.dependency_overrides[get_current_user] = lambda: user
    return user


def _state(
    *,
    student_id: str = "stu_a",
    workspace_id: str = "wsp_a",
    xp_total: int = 250,
    level: int = 2,
    streak_days: int = 4,
    longest_streak_days: int = 8,
    last_active_date: str | None = "2026-05-23",
    questions_answered: int = 12,
    questions_correct: int = 9,
    flashcards_reviewed: int = 3,
    study_sessions_completed: int = 4,
    revision_sessions_completed: int = 2,
    flashcard_sessions_completed: int = 3,
    badges: list[Badge] | None = None,
    xp_by_topic: dict[str, int] | None = None,
    daily_activity: dict[str, int] | None = None,
    daily_xp: dict[str, int] | None = None,
) -> GamificationState:
    return GamificationState(
        **{"_id": f"gam_{student_id}"},
        tenant_id="ten_test001",
        workspace_id=workspace_id,
        student_id=student_id,
        xp_total=xp_total,
        level=level,
        streak_days=streak_days,
        longest_streak_days=longest_streak_days,
        last_active_date=last_active_date,
        questions_answered=questions_answered,
        questions_correct=questions_correct,
        flashcards_reviewed=flashcards_reviewed,
        study_sessions_completed=study_sessions_completed,
        revision_sessions_completed=revision_sessions_completed,
        flashcard_sessions_completed=flashcard_sessions_completed,
        badges=badges or [],
        xp_by_topic=xp_by_topic or {"Photosynthesis": 250},
        daily_activity=daily_activity or {"2026-05-23": 5},
        daily_xp=daily_xp or {"2026-05-23": 42},
    )


def _workspace(leaderboard_visible: bool = True) -> dict:
    return Workspace(
        **{"_id": "wsp_a"},
        tenant_id="ten_test001",
        name="Demo Class",
        description="",
        settings=WorkspaceSettings(leaderboard_visible=leaderboard_visible),
        created_by="usr_admin",
    ).model_dump(by_alias=True)


# ── Profile endpoint ────────────────────────────────────────────────────────


def test_profile_returns_full_view_with_progress_hints(client, student):
    """Profile endpoint adds level-progress fields the wire model
    pre-computes for the UI."""
    state = _state(xp_total=250, level=2)
    with patch(
        "app.api.gamification.gamification_service.get_state",
        AsyncMock(return_value=state),
    ):
        response = client.get(
            "/api/v1/workspaces/wsp_a/users/stu_a/gamification",
        )

    assert response.status_code == 200
    body = response.json()
    assert body["xp_total"] == 250
    assert body["level"] == 2
    # Level 2 starts at 100 XP; xp_into_level = 250 - 100 = 150.
    assert body["xp_into_level"] == 150
    # Level 3 starts at 400 XP; xp_for_next_level = 400 - 100 = 300.
    assert body["xp_for_next_level"] == 300
    assert body["xp_by_topic"] == {"Photosynthesis": 250}
    assert body["daily_activity"] == {"2026-05-23": 5}
    assert body["daily_xp"] == {"2026-05-23": 42}
    assert body["study_sessions_completed"] == 4
    assert body["revision_sessions_completed"] == 2
    assert body["flashcard_sessions_completed"] == 3


def test_profile_student_cannot_read_other_students(client, student):
    """Student → student access on someone else's profile is 403."""
    response = client.get(
        "/api/v1/workspaces/wsp_a/users/stu_other/gamification",
    )
    assert response.status_code == 403


def test_profile_workspace_admin_can_read_any_member(client):
    """A workspace admin in wsp_a can read stu_a's profile."""
    admin_user = make_user(
        user_id="usr_admin_a",
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: admin_user

    state = _state()
    with patch(
        "app.api.gamification.gamification_service.get_state",
        AsyncMock(return_value=state),
    ):
        response = client.get(
            "/api/v1/workspaces/wsp_a/users/stu_a/gamification",
        )
    assert response.status_code == 200


def test_profile_tenant_admin_bypasses_workspace_membership(client, admin):
    """Tenant admin doesn't need to be a member — they see everything."""
    state = _state(workspace_id="wsp_other")
    with patch(
        "app.api.gamification.gamification_service.get_state",
        AsyncMock(return_value=state),
    ):
        response = client.get(
            "/api/v1/workspaces/wsp_other/users/stu_a/gamification",
        )
    assert response.status_code == 200


# ── Streak endpoint ─────────────────────────────────────────────────────────


def test_streak_returns_compact_summary(client, student):
    state = _state(
        streak_days=7,
        longest_streak_days=12,
        last_active_date="2026-05-23",
    )
    with patch(
        "app.api.gamification.gamification_service.get_state",
        AsyncMock(return_value=state),
    ):
        response = client.get(
            "/api/v1/workspaces/wsp_a/users/stu_a/streak",
        )
    body = response.json()
    assert body["streak_days"] == 7
    assert body["longest_streak_days"] == 12
    assert body["last_active_date"] == "2026-05-23"
    # ``active_today`` depends on wall-clock today; just verify the
    # field is present and a bool.
    assert isinstance(body["active_today"], bool)


# ── Badges endpoint ─────────────────────────────────────────────────────────


def test_badges_returns_earned_plus_available(client, student):
    earned = Badge(
        badge_id="first_steps",
        name="First Steps",
        description="Answer your first question.",
        icon="spa_rounded",
        earned_at="2026-05-22T10:00:00+00:00",
    )
    state = _state(badges=[earned])
    with patch(
        "app.api.gamification.gamification_service.get_state",
        AsyncMock(return_value=state),
    ):
        response = client.get(
            "/api/v1/workspaces/wsp_a/users/stu_a/badges",
        )
    body = response.json()
    assert body["earned_count"] == 1
    assert body["total_count"] == len(BADGES)
    earned_ids = {b["badge_id"] for b in body["earned"]}
    available_ids = {b["badge_id"] for b in body["available"]}
    assert "first_steps" in earned_ids
    assert "first_steps" not in available_ids
    # Sanity: every other catalog entry is in either earned or available.
    catalog_ids = {b.id for b in BADGES}
    assert earned_ids | available_ids == catalog_ids


# ── Leaderboard endpoint ────────────────────────────────────────────────────


def test_leaderboard_sorts_by_xp_desc_with_stable_tiebreak(client, student):
    """Two students at 100 XP must sort by student_id alphabetically so
    repeated calls return the same ranks."""
    a = _state(student_id="stu_a", xp_total=100, level=2)
    b = _state(student_id="stu_b", xp_total=100, level=2)
    c = _state(student_id="stu_c", xp_total=500, level=3)
    workspace = _workspace(leaderboard_visible=True)

    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(return_value=workspace)
    users_col = MagicMock()
    # Async iterator over user docs for display-name lookup.
    users_col.find = MagicMock(
        return_value=_async_iter(
            [
                {"_id": "stu_a", "display_name": "Aki"},
                {"_id": "stu_b", "display_name": "Bea"},
                {"_id": "stu_c", "display_name": "Cris"},
            ]
        )
    )

    def _factory(_tid, collection):
        from app.core.database import USERS, WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        if collection == USERS:
            return users_col
        raise AssertionError(collection)

    with (
        patch("app.api.gamification.get_collection", side_effect=_factory),
        patch(
            "app.api.gamification.gamification_service.list_workspace_states",
            AsyncMock(return_value=[a, b, c]),
        ),
    ):
        response = client.get("/api/v1/workspaces/wsp_a/leaderboard")

    body = response.json()
    assert body["visible"] is True
    ranks_in_order = [e["student_id"] for e in body["entries"]]
    # Cris first (500 XP), then Aki + Bea tied at 100 — alphabetical
    # tiebreak puts Aki before Bea.
    assert ranks_in_order == ["stu_c", "stu_a", "stu_b"]
    # current_user_rank reflects the calling student.
    assert body["current_user_rank"] == 2  # Aki is rank 2.


def test_leaderboard_hidden_for_students_when_workspace_setting_off(client, student):
    """``leaderboard_visible=False`` ⇒ students get visible=False + empty."""
    workspace = _workspace(leaderboard_visible=False)
    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(return_value=workspace)

    def _factory(_tid, collection):
        from app.core.database import WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        return MagicMock()

    with patch("app.api.gamification.get_collection", side_effect=_factory):
        response = client.get("/api/v1/workspaces/wsp_a/leaderboard")

    body = response.json()
    assert body["visible"] is False
    assert body["entries"] == []


def test_leaderboard_visible_to_admins_even_when_setting_off(client, admin):
    """Admins always see the leaderboard so they can monitor engagement.

    Workspace setting toggles only gate the student view.
    """
    workspace = _workspace(leaderboard_visible=False)
    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(return_value=workspace)
    users_col = MagicMock()
    users_col.find = MagicMock(return_value=_async_iter([{"_id": "stu_a", "display_name": "Aki"}]))

    def _factory(_tid, collection):
        from app.core.database import USERS, WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        if collection == USERS:
            return users_col
        raise AssertionError(collection)

    with (
        patch("app.api.gamification.get_collection", side_effect=_factory),
        patch(
            "app.api.gamification.gamification_service.list_workspace_states",
            AsyncMock(return_value=[_state()]),
        ),
    ):
        response = client.get("/api/v1/workspaces/wsp_a/leaderboard")

    body = response.json()
    assert body["visible"] is True
    assert len(body["entries"]) == 1


def test_leaderboard_non_member_student_gets_403(client):
    user = make_user(
        user_id="stu_outsider",
        role=UserRole.student,
        workspace_ids=["wsp_other"],
    )
    app.dependency_overrides[get_current_user] = lambda: user
    response = client.get("/api/v1/workspaces/wsp_a/leaderboard")
    assert response.status_code == 403


# ── Helpers ────────────────────────────────────────────────────────────────


def _async_iter(items):
    """Return an object yielding ``items`` under ``async for``."""

    class _Iter:
        def __init__(self, xs):
            self._xs = iter(xs)

        def __aiter__(self):
            return self

        async def __anext__(self):
            try:
                return next(self._xs)
            except StopIteration as exc:
                raise StopAsyncIteration from exc

    return _Iter(items)
