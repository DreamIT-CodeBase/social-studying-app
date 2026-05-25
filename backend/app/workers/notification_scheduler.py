"""Notification scheduler — Sprint 5.7c.

One function: :func:`run_tick_for_tenant`. Walks the tenant's student
roster, evaluates two cron-style rules per student, and dispatches
pushes via :mod:`app.services.notifications`.

Rules
-----
**Study reminder** (``NotificationType.study_reminder``)
    Fires once per UTC day per student. Condition: the student has at
    least one workspace AND has NOT been active today. ``last_active_date``
    from the gamification doc is the source of truth — checking
    interactions live would re-scan the log on every tick.

**Streak warning** (``NotificationType.streak_warning``)
    Fires once per UTC day per student whose ``streak_days >= 1`` and
    who hasn't studied today. Differentiated from the study reminder
    so the UI can render a louder banner. A student in the middle of
    a 30-day streak gets both pushes today — that's intentional, the
    reminder is a soft nudge and the warning is the "act now" follow-
    up.

Why "once per day" via the dispatch log, not a per-user timer
-----------------------------------------------------------
The simplest correctness rule: before firing, scan today's
:class:`NotificationDispatch` rows for this user. If a row of the
same type already exists for today, skip. This makes the tick
idempotent — a cron that fires every hour still only sends one push
per type per day, and a crash mid-tick is recoverable by just
running the next tick.

Production cron cadence
-----------------------
Once per hour is a fine default. Cheap call (~one Cosmos scan per
tenant + per-user point reads), and the per-day idempotency rule
absorbs spurious early/late ticks. The endpoint
``POST /admin/notifications/run-scheduler`` lets an operator dry-run
a tick from the admin console; integration tests invoke
:func:`run_tick_for_tenant` directly.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime

from app.core.database import (
    GAMIFICATION,
    NOTIFICATION_DISPATCHES,
    QUESTION_QUEUE,
    USERS,
    WORKSPACES,
    get_collection,
)
from app.models.base import utc_now
from app.models.gamification import GamificationState
from app.models.notification import NotificationType
from app.models.user import User, UserRole
from app.models.workspace import Workspace
from app.services import notifications as notification_service

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class TickSummary:
    """What one scheduler tick did. Returned to the admin endpoint so
    an operator can sanity-check the dispatch count."""

    students_evaluated: int
    study_reminders_sent: int
    streak_warnings_sent: int
    unanswered_reprompts_sent: int
    failures: int


# ── Entry point ────────────────────────────────────────────────────────────


async def run_tick_for_tenant(*, tenant_id: str) -> TickSummary:
    """Evaluate every student in ``tenant_id`` and fire whichever
    notifications apply.

    Returns a :class:`TickSummary` with per-type counts. The total
    push count is ``study_reminders_sent + streak_warnings_sent``;
    ``failures`` is the count of pushes whose dispatch outcome was
    ``failed`` (transport / 4xx from ANH). A push that lands as
    ``logged_only`` (no ANH creds) counts as a success — the rule
    decided correctly even if the channel is muted.
    """
    today_iso = datetime.now(UTC).date().isoformat()
    students = await _read_students(tenant_id=tenant_id)
    workspaces_by_id = await _read_workspaces_by_id(tenant_id=tenant_id)

    summary_reminders = 0
    summary_warnings = 0
    summary_failures = 0

    for student in students:
        workspace_id = _primary_workspace_id(student)
        if workspace_id is None:
            # Student isn't in any workspace yet — nothing actionable
            # for them. They'll appear once they redeem an invite.
            continue
        workspace = workspaces_by_id.get(workspace_id)
        if workspace is None:
            # Stale membership — workspace was deleted but the
            # student row hasn't been re-keyed. Skip; admin tools
            # will surface this separately.
            continue

        gamification = await _read_gamification(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student.id,
        )
        active_today = (
            gamification is not None
            and gamification.last_active_date == today_iso
        )
        if active_today:
            # No reminder needed; the student has already studied today.
            continue

        # ── Study reminder ─────────────────────────────────────────────
        if not await _already_sent_today(
            tenant_id=tenant_id,
            user_id=student.id,
            notification_type=NotificationType.study_reminder,
            today_iso=today_iso,
        ):
            results = await notification_service.send_study_reminder(
                tenant_id=tenant_id,
                user_id=student.id,
                workspace_id=workspace_id,
                questions_per_day=workspace.settings.questions_per_day,
            )
            summary_reminders += _count_successes(results)
            summary_failures += _count_failures(results)

        # ── Streak warning ─────────────────────────────────────────────
        streak_days = gamification.streak_days if gamification else 0
        if streak_days >= 1 and not await _already_sent_today(
            tenant_id=tenant_id,
            user_id=student.id,
            notification_type=NotificationType.streak_warning,
            today_iso=today_iso,
        ):
            results = await notification_service.send_streak_warning(
                tenant_id=tenant_id,
                user_id=student.id,
                workspace_id=workspace_id,
                streak_days=streak_days,
            )
            summary_warnings += _count_successes(results)
            summary_failures += _count_failures(results)

    # Sprint 5.12 — unanswered reprompt fires. Run after the per-student
    # reminders so a student who hasn't studied today AND has a
    # ready-to-reprompt question gets both pushes — the reminder is the
    # general nudge and the reprompt names the specific question.
    summary_reprompts, reprompt_failures = await _fire_unanswered_reprompts(
        tenant_id=tenant_id
    )
    summary_failures += reprompt_failures

    logger.info(
        "Notification tick tenant=%s students=%d reminders=%d "
        "warnings=%d reprompts=%d failures=%d",
        tenant_id,
        len(students),
        summary_reminders,
        summary_warnings,
        summary_reprompts,
        summary_failures,
    )
    return TickSummary(
        students_evaluated=len(students),
        study_reminders_sent=summary_reminders,
        streak_warnings_sent=summary_warnings,
        unanswered_reprompts_sent=summary_reprompts,
        failures=summary_failures,
    )


async def _fire_unanswered_reprompts(
    *, tenant_id: str
) -> tuple[int, int]:
    """Find every question whose ``deferred_until`` is at or past now,
    fire a reprompt push for it, and clear ``deferred_until`` so the
    student is only nudged once per skip.

    Returns ``(successes, failures)``. Questions whose owning student
    is no longer in the system (deleted user) are still cleared so the
    field doesn't accumulate stale entries forever.
    """
    now_iso = utc_now()
    col = get_collection(tenant_id, QUESTION_QUEUE)
    cursor = col.find(
        {
            # Lexicographic ISO 8601 comparison — strings sort the
            # same as datetimes when they're in canonical form.
            "deferred_until": {"$ne": None, "$lte": now_iso},
            "deleted_at": None,
        }
    )
    successes = 0
    failures = 0
    async for raw in cursor:
        student_id = raw.get("deferred_for")
        if not student_id:
            # Stale state — deferred_until is set but no owning student.
            # Clear it to keep the field honest.
            await col.update_one(
                {"_id": raw["_id"]},
                {"$set": {"deferred_until": None}},
            )
            continue
        results = await notification_service.send_unanswered_reprompt(
            tenant_id=tenant_id,
            user_id=student_id,
            workspace_id=raw.get("workspace_id", ""),
            question_id=raw["_id"],
            topic=raw.get("topic", ""),
        )
        successes += _count_successes(results)
        failures += _count_failures(results)
        await col.update_one(
            {"_id": raw["_id"]},
            {"$set": {"deferred_until": None}},
        )
    return successes, failures


# ── Cosmos reads ───────────────────────────────────────────────────────────


async def _read_students(*, tenant_id: str) -> list[User]:
    """Active students in the tenant. Excludes soft-deleted users and
    admins (who don't get reminders — they're operating the platform,
    not learning on it)."""
    col = get_collection(tenant_id, USERS)
    cursor = col.find(
        {"role": UserRole.student.value, "deleted_at": None}
    )
    return [User.model_validate(raw) async for raw in cursor]


async def _read_workspaces_by_id(
    *, tenant_id: str
) -> dict[str, Workspace]:
    """Bulk-load workspaces so the per-student loop is O(1) lookups
    rather than N point reads."""
    col = get_collection(tenant_id, WORKSPACES)
    cursor = col.find({"deleted_at": None})
    return {
        raw["_id"]: Workspace.model_validate(raw) async for raw in cursor
    }


async def _read_gamification(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
) -> GamificationState | None:
    col = get_collection(tenant_id, GAMIFICATION)
    raw = await col.find_one(
        {
            "student_id": student_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    return GamificationState.model_validate(raw) if raw is not None else None


async def _already_sent_today(
    *,
    tenant_id: str,
    user_id: str,
    notification_type: NotificationType,
    today_iso: str,
) -> bool:
    """True if a dispatch of the given type already exists with
    ``dispatched_at`` starting with today's ISO date.

    ISO 8601 timestamps sort lexicographically, so a ``startsWith``
    predicate is the cheapest way to match "anywhere in this UTC
    day" without a date-truncation expression. Cosmos for MongoDB
    supports ``$regex``-style anchors via plain prefix; we use a tight
    regex to keep the query plan trivial.
    """
    col = get_collection(tenant_id, NOTIFICATION_DISPATCHES)
    existing = await col.find_one(
        {
            "user_id": user_id,
            "notification_type": notification_type.value,
            "dispatched_at": {"$regex": f"^{today_iso}"},
        }
    )
    return existing is not None


# ── Helpers ────────────────────────────────────────────────────────────────


def _primary_workspace_id(user: User) -> str | None:
    """First workspace membership, or None.

    A student in multiple workspaces gets reminders scoped to their
    first one for now. Multi-workspace UX is Sprint 6 polish —
    sending one push per workspace would be noisy, and ranking the
    most-active workspace requires reading every gamification doc per
    tick which isn't worth the cost yet.
    """
    if not user.workspace_memberships:
        return None
    return user.workspace_memberships[0].workspace_id


def _count_successes(results: list) -> int:
    """Tokens that landed as ``sent`` or ``logged_only`` — the rule
    fired correctly either way."""
    from app.models.notification import DispatchOutcome  # local to dodge import order

    return sum(
        1
        for r in results
        if r.outcome in (DispatchOutcome.sent, DispatchOutcome.logged_only)
    )


def _count_failures(results: list) -> int:
    from app.models.notification import DispatchOutcome

    return sum(1 for r in results if r.outcome == DispatchOutcome.failed)
