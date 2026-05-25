"""Unit tests for the notification scheduler tick (Sprint 5.7c).

Covers:

* Active-today students get no reminder fired.
* Inactive-today students with a workspace get the study reminder.
* Inactive-today students with ``streak_days >= 1`` ALSO get the
  streak warning.
* Per-day idempotency: a dispatch row already present for today
  suppresses a second fire.
* Students with no workspace are skipped silently.
* Students whose primary workspace was deleted are skipped silently.
* Tenant admins are NOT evaluated (they don't get reminders).
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.gamification import GamificationState
from app.models.notification import DispatchOutcome
from app.models.user import User, UserRole, WorkspaceMembership
from app.models.workspace import Workspace, WorkspaceSettings
from app.services.notifications import DispatchResult
from app.workers import notification_scheduler


# ── Helpers ───────────────────────────────────────────────────────────────


def _student(
    *,
    user_id: str = "stu_a",
    workspace_ids: tuple[str, ...] = ("wsp_a",),
) -> User:
    return User(
        **{"_id": user_id},
        tenant_id="ten_a",
        email=f"{user_id}@example.com",
        display_name=user_id,
        role=UserRole.student,
        workspace_memberships=[
            WorkspaceMembership(
                workspace_id=ws,
                role=UserRole.student,
                joined_at="2026-04-01T00:00:00+00:00",
            )
            for ws in workspace_ids
        ],
    )


def _workspace(
    *,
    workspace_id: str = "wsp_a",
    questions_per_day: int = 3,
) -> Workspace:
    return Workspace(
        **{"_id": workspace_id},
        tenant_id="ten_a",
        name="Demo",
        description="",
        settings=WorkspaceSettings(questions_per_day=questions_per_day),
        created_by="usr_admin",
    )


def _gamification(
    *,
    student_id: str = "stu_a",
    workspace_id: str = "wsp_a",
    last_active_date: str | None = None,
    streak_days: int = 0,
) -> GamificationState:
    return GamificationState(
        **{"_id": f"gam_{student_id}"},
        tenant_id="ten_a",
        workspace_id=workspace_id,
        student_id=student_id,
        streak_days=streak_days,
        last_active_date=last_active_date,
    )


def _patch_module(
    *,
    students: list[User],
    workspaces: dict[str, Workspace],
    gamification: dict[str, GamificationState | None],
    already_sent: set[tuple[str, str]] | None = None,
    sender_results: list[DispatchResult] | None = None,
):
    """Patch the per-function reads + the notification helpers so the
    tick is testable without Cosmos.

    ``already_sent`` is the set of (student_id, type) pairs that
    should be reported as having already been sent today.
    ``sender_results`` is what the dispatch helpers (study reminder,
    streak warning) should return — defaults to a single
    ``logged_only`` result so the rule "fired correctly even without
    a live channel".
    """
    sent = already_sent or set()
    results = sender_results or [DispatchResult(outcome=DispatchOutcome.logged_only)]

    async def _fake_students(tenant_id: str):
        return students

    async def _fake_workspaces(tenant_id: str):
        return workspaces

    async def _fake_gam(*, tenant_id, workspace_id, student_id):
        return gamification.get(student_id)

    async def _fake_already(
        *, tenant_id, user_id, notification_type, today_iso
    ):
        return (user_id, notification_type.value) in sent

    study_mock = AsyncMock(return_value=results)
    streak_mock = AsyncMock(return_value=results)
    # No-op the reprompt path by default — tests that want to
    # exercise it patch ``_fire_unanswered_reprompts`` themselves.
    reprompt_mock = AsyncMock(return_value=(0, 0))

    return [
        patch.object(notification_scheduler, "_read_students", _fake_students),
        patch.object(
            notification_scheduler, "_read_workspaces_by_id", _fake_workspaces
        ),
        patch.object(
            notification_scheduler, "_read_gamification", _fake_gam
        ),
        patch.object(
            notification_scheduler, "_already_sent_today", _fake_already
        ),
        patch.object(
            notification_scheduler,
            "_fire_unanswered_reprompts",
            reprompt_mock,
        ),
        patch(
            "app.workers.notification_scheduler.notification_service.send_study_reminder",
            study_mock,
        ),
        patch(
            "app.workers.notification_scheduler.notification_service.send_streak_warning",
            streak_mock,
        ),
    ], (study_mock, streak_mock)


def _enter(mocks):
    from contextlib import ExitStack

    stack = ExitStack()
    for m in mocks:
        stack.enter_context(m)
    return stack


# ── Tests ─────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_active_today_student_gets_no_reminder():
    today = notification_scheduler.datetime.now(notification_scheduler.UTC).date().isoformat()
    mocks, (study, streak) = _patch_module(
        students=[_student()],
        workspaces={"wsp_a": _workspace()},
        gamification={
            "stu_a": _gamification(last_active_date=today),
        },
    )
    with _enter(mocks):
        summary = await notification_scheduler.run_tick_for_tenant(
            tenant_id="ten_a"
        )

    assert summary.students_evaluated == 1
    assert summary.study_reminders_sent == 0
    assert summary.streak_warnings_sent == 0
    study.assert_not_awaited()
    streak.assert_not_awaited()


@pytest.mark.asyncio
async def test_inactive_today_student_with_no_streak_fires_study_reminder_only():
    mocks, (study, streak) = _patch_module(
        students=[_student()],
        workspaces={"wsp_a": _workspace(questions_per_day=4)},
        gamification={
            "stu_a": _gamification(
                last_active_date="2026-04-01",  # well in the past
                streak_days=0,
            ),
        },
    )
    with _enter(mocks):
        summary = await notification_scheduler.run_tick_for_tenant(
            tenant_id="ten_a"
        )

    assert summary.study_reminders_sent == 1
    assert summary.streak_warnings_sent == 0
    study.assert_awaited_once()
    kwargs = study.await_args.kwargs
    assert kwargs["questions_per_day"] == 4
    streak.assert_not_awaited()


@pytest.mark.asyncio
async def test_inactive_today_student_with_streak_fires_both_pushes():
    mocks, (study, streak) = _patch_module(
        students=[_student()],
        workspaces={"wsp_a": _workspace()},
        gamification={
            "stu_a": _gamification(
                last_active_date="2026-04-01",
                streak_days=7,
            ),
        },
    )
    with _enter(mocks):
        summary = await notification_scheduler.run_tick_for_tenant(
            tenant_id="ten_a"
        )

    assert summary.study_reminders_sent == 1
    assert summary.streak_warnings_sent == 1
    study.assert_awaited_once()
    streak.assert_awaited_once()
    assert streak.await_args.kwargs["streak_days"] == 7


@pytest.mark.asyncio
async def test_already_sent_today_suppresses_second_fire():
    """Per-day idempotency rule — a reminder dispatched earlier today
    short-circuits the next tick's evaluation."""
    mocks, (study, streak) = _patch_module(
        students=[_student()],
        workspaces={"wsp_a": _workspace()},
        gamification={
            "stu_a": _gamification(
                last_active_date="2026-04-01",
                streak_days=3,
            ),
        },
        already_sent={
            ("stu_a", "study_reminder"),
            ("stu_a", "streak_warning"),
        },
    )
    with _enter(mocks):
        summary = await notification_scheduler.run_tick_for_tenant(
            tenant_id="ten_a"
        )
    assert summary.study_reminders_sent == 0
    assert summary.streak_warnings_sent == 0
    study.assert_not_awaited()
    streak.assert_not_awaited()


@pytest.mark.asyncio
async def test_student_with_no_workspace_is_skipped_silently():
    mocks, (study, streak) = _patch_module(
        students=[_student(workspace_ids=())],
        workspaces={},
        gamification={},
    )
    with _enter(mocks):
        summary = await notification_scheduler.run_tick_for_tenant(
            tenant_id="ten_a"
        )
    assert summary.students_evaluated == 1
    assert summary.study_reminders_sent == 0
    study.assert_not_awaited()
    streak.assert_not_awaited()


@pytest.mark.asyncio
async def test_student_with_deleted_workspace_is_skipped_silently():
    mocks, (study, _) = _patch_module(
        students=[_student(workspace_ids=("wsp_ghost",))],
        workspaces={},  # the workspace ref is stale
        gamification={"stu_a": _gamification()},
    )
    with _enter(mocks):
        summary = await notification_scheduler.run_tick_for_tenant(
            tenant_id="ten_a"
        )
    assert summary.study_reminders_sent == 0
    study.assert_not_awaited()


# ── 5.12 reprompts ────────────────────────────────────────────────────────


def _async_iter(items):
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


@pytest.mark.asyncio
async def test_reprompt_path_fires_for_due_questions_and_clears_defer():
    """Sprint 5.12 — _fire_unanswered_reprompts fires one push per
    question whose deferred_until has elapsed, then clears the field
    so the same skip isn't re-prompted twice."""
    due_question = {
        "_id": "qst_a",
        "workspace_id": "wsp_a",
        "topic": "Photosynthesis",
        "deferred_for": "stu_a",
        # An ISO 8601 timestamp clearly in the past.
        "deferred_until": "2020-01-01T00:00:00+00:00",
        "deleted_at": None,
    }
    questions_col = MagicMock()
    questions_col.find = MagicMock(return_value=_async_iter([due_question]))
    captured_updates: list[dict] = []

    async def _update_one(_filter, update):
        captured_updates.append(update)
        return MagicMock(modified_count=1)

    questions_col.update_one = _update_one

    def _factory(_tid, collection):
        from app.core.database import QUESTION_QUEUE

        if collection == QUESTION_QUEUE:
            return questions_col
        raise AssertionError(collection)

    reprompt_mock = AsyncMock(
        return_value=[DispatchResult(outcome=DispatchOutcome.logged_only)]
    )
    with patch.object(
        notification_scheduler, "get_collection", side_effect=_factory
    ), patch(
        "app.workers.notification_scheduler.notification_service.send_unanswered_reprompt",
        reprompt_mock,
    ):
        successes, failures = await notification_scheduler._fire_unanswered_reprompts(
            tenant_id="ten_a"
        )

    assert successes == 1
    assert failures == 0
    # send_unanswered_reprompt was called with the question's fields.
    kwargs = reprompt_mock.await_args.kwargs
    assert kwargs["question_id"] == "qst_a"
    assert kwargs["user_id"] == "stu_a"
    assert kwargs["workspace_id"] == "wsp_a"
    assert kwargs["topic"] == "Photosynthesis"
    # And the question's deferred_until was cleared.
    assert captured_updates == [{"$set": {"deferred_until": None}}]


@pytest.mark.asyncio
async def test_reprompt_skips_questions_with_missing_owner_but_clears_field():
    """Stale state: ``deferred_until`` is set but ``deferred_for`` is
    null. The push can't fire (nowhere to send) but the field is
    cleared so the row doesn't accumulate stale entries."""
    stale_question = {
        "_id": "qst_stale",
        "workspace_id": "wsp_a",
        "topic": "Photosynthesis",
        "deferred_for": None,
        "deferred_until": "2020-01-01T00:00:00+00:00",
        "deleted_at": None,
    }
    questions_col = MagicMock()
    questions_col.find = MagicMock(return_value=_async_iter([stale_question]))
    captured_updates: list[dict] = []

    async def _update_one(_filter, update):
        captured_updates.append(update)
        return MagicMock(modified_count=1)

    questions_col.update_one = _update_one

    def _factory(_tid, collection):
        from app.core.database import QUESTION_QUEUE

        if collection == QUESTION_QUEUE:
            return questions_col
        raise AssertionError(collection)

    reprompt_mock = AsyncMock()
    with patch.object(
        notification_scheduler, "get_collection", side_effect=_factory
    ), patch(
        "app.workers.notification_scheduler.notification_service.send_unanswered_reprompt",
        reprompt_mock,
    ):
        successes, failures = await notification_scheduler._fire_unanswered_reprompts(
            tenant_id="ten_a"
        )

    assert successes == 0
    assert failures == 0
    reprompt_mock.assert_not_awaited()
    # Field is still cleared.
    assert captured_updates == [{"$set": {"deferred_until": None}}]


@pytest.mark.asyncio
async def test_dispatch_failures_count_against_summary():
    failing = DispatchResult(
        outcome=DispatchOutcome.failed, failure_reason="http 410"
    )
    mocks, _ = _patch_module(
        students=[_student()],
        workspaces={"wsp_a": _workspace()},
        gamification={
            "stu_a": _gamification(
                last_active_date="2026-04-01", streak_days=2
            ),
        },
        sender_results=[failing, failing],
    )
    with _enter(mocks):
        summary = await notification_scheduler.run_tick_for_tenant(
            tenant_id="ten_a"
        )
    # 2 failures per send_* call, fired twice (reminder + warning) = 4.
    assert summary.failures == 4
    assert summary.study_reminders_sent == 0
    assert summary.streak_warnings_sent == 0
