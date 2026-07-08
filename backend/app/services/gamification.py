"""Gamification engine — Sprint 5.1.

Single writer for the ``gamification`` Cosmos collection. The answer
and flashcard endpoints call into here after persisting their
interaction; the engine bumps XP, streak, level, per-topic XP, daily
activity, and unlocks badges — then upserts the
:class:`GamificationState` doc.

Why a single writer
-------------------
The state is denormalised so the leaderboard and profile views read
one document instead of aggregating over interactions. That only
holds up if every counter has exactly one mutation path. Two writers
(say, an interaction worker and the answer endpoint) would race on
the same counters; the moment they diverge from interactions the
denormalisation is a lie. Sprint 5 keeps the answer endpoint as the
sole writer and the engine is the function it calls.

XP model
--------
Question XP::

    correct_xp = 7           # on correct answer
    incorrect_xp = -1        # on wrong attempt (penalty)
    streak_bonus = +2 XP     # awarded when streak extends to a new day

So a correct answer on a new streak day earns 9 XP.
A wrong answer deducts 1 XP (floor at 0 so total never goes negative).

Flashcard XP::

    flat = 5

Self-rated, no grading signal — keep the reward modest so flashcards
don't outpace the question loop. Streak bonus does NOT apply to
flashcards (the loop already rewards engagement; doubling it would
incentivise farming).

Level model
-----------
``level = floor(sqrt(xp_total / 100)) + 1``. Cumulative XP for level n
is ``(n - 1)^2 * 100`` — predictable squared curve, easy to surface as
a progress bar (the UI computes the next-level threshold the same way).

Streak model
------------
Streak day = UTC calendar day. The engine compares today's ISO date
against the persisted ``last_active_date``:

- today == last_active_date → no streak change (multiple events same day)
- today == last_active_date + 1d → streak += 1
- otherwise → streak = 1 (today still counts as a day-1 streak)

Weekly XP (``xp_this_week``) resets when today crosses past
``week_starts_at + 7 days``. ``week_starts_at`` is the Monday of the
current ISO week (UTC).

Idempotency
-----------
Like :mod:`knowledge_state`, persistence is ``replace_one`` upsert by
``_id`` without optimistic concurrency — racing double-submits within
sub-second windows may lose one update. Sprint 5/6 polish item.
"""

from __future__ import annotations

import logging
import math
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, timedelta
from uuid import uuid4

from app.core.database import GAMIFICATION, get_collection
from app.models.base import utc_now
from app.models.flashcard import FlashcardRating
from app.models.gamification import Badge, GamificationState
from app.models.question import DifficultyLevel
from app.services import badges as badges_module

logger = logging.getLogger(__name__)


# ── XP constants ────────────────────────────────────────────────────────────


ATTEMPT_XP: int = 10
"""XP awarded just for submitting an answer. Encourages attempts."""

CORRECT_BONUS_XP: dict[DifficultyLevel, int] = {
    DifficultyLevel.beginner: 5,
    DifficultyLevel.intermediate: 10,
    DifficultyLevel.advanced: 20,
}
"""Difficulty-weighted bonus added on a correct answer."""

WRONG_ANSWER_PENALTY_XP: int = -7
"""XP deducted when the student answers incorrectly. On wrong answers,
attempt XP and streak bonus are not awarded, and only this penalty is
applied. The returned value is negative; the caller floors total XP at 0."""

STREAK_BONUS_CAP: int = 10
"""Maximum streak-day XP applied to a single submission. Streak XP =
``min(streak_days, STREAK_BONUS_CAP)``. Caps the late-streak runaway —
a 200-day streak doesn't trivialise the level curve."""

FLASHCARD_XP: int = 5
"""Flat XP for any flashcard rating event. No difficulty signal, no
streak bonus — keep flashcards modest so the question loop stays the
core reward path."""

DAILY_ACTIVITY_RETENTION_DAYS: int = 30
"""How many days of ``daily_activity`` to keep on the doc. Older
entries are pruned every write so the doc stays bounded."""


# ── Engine output ───────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class GamificationDelta:
    """What happened on this single event, plus the post-event state.

    The answer / flashcard endpoints use this both to write back the
    final ``xp_earned`` (incl. streak bonus) on the interaction record
    and to surface celebration cues to the UI (level-up modal, badge
    unlock toast).
    """

    xp_earned: int
    """Total XP awarded for this event (attempt + correct + streak)."""

    new_level: int
    """The student's level after this event."""

    leveled_up: bool
    """True iff ``new_level`` is strictly greater than the pre-event
    level. The 5.5 celebration UI fires on this flag."""

    streak_days: int
    """Streak length after this event."""

    streak_extended: bool
    """True iff today's event extended the streak (vs. same-day or
    first-day-after-reset). Drives the streak flame pulse animation."""

    badges_unlocked: list[Badge] = field(default_factory=list)
    """Newly-earned badges, in catalog order. Already appended to
    :attr:`state.badges` before this dataclass is returned."""

    state: GamificationState | None = None
    """The persisted post-event state. ``None`` only in pure-function
    unit tests that exercise the dataclass shape."""


# ── Public entry points ─────────────────────────────────────────────────────


async def record_question_attempt(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    topic: str,
    difficulty: DifficultyLevel,
    is_correct: bool,
    revision: bool = False,
    now: str | None = None,
) -> GamificationDelta:
    """Apply one answer's effect to the student's gamification state.

    Study question: +1 XP
    Revision question: +1 XP
    Login bonus: +2 XP (awarded if streak_extended is True)
    """
    timestamp = now or utc_now()
    today = _today(timestamp)

    state = await _read_or_init(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
    )

    pre_level = state.level
    _apply_weekly_reset(state, today=today)
    streak_extended = _apply_streak(state, today=today)

    xp_earned = compute_question_xp(
        is_correct=is_correct,
        difficulty=difficulty,
        streak_days=state.streak_days,
        revision=revision,
    )

    if streak_extended:
        xp_earned += 2

    # Floor xp_total at 0
    state.xp_total = max(0, state.xp_total + xp_earned)
    state.xp_this_week = max(0, state.xp_this_week + xp_earned)
    state.xp_by_topic[topic] = max(
        0, state.xp_by_topic.get(topic, 0) + xp_earned
    )
    state.questions_answered += 1
    if is_correct:
        state.questions_correct += 1
    state.level = level_for_xp(state.xp_total)
    _bump_daily_activity(state, today=today)

    unlocks = _materialise_unlocks(state, earned_at=timestamp)

    state.touch()
    await _persist(tenant_id=tenant_id, state=state)

    logger.info(
        "Gamification question event student=%s workspace=%s correct=%s "
        "xp=%d streak=%d level=%d unlocks=%s",
        student_id,
        workspace_id,
        is_correct,
        xp_earned,
        state.streak_days,
        state.level,
        [u.badge_id for u in unlocks],
    )

    return GamificationDelta(
        xp_earned=xp_earned,
        new_level=state.level,
        leveled_up=state.level > pre_level,
        streak_days=state.streak_days,
        streak_extended=streak_extended,
        badges_unlocked=unlocks,
        state=state,
    )


async def record_flashcard_rating(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    topic: str,
    rating: FlashcardRating,
    now: str | None = None,
) -> GamificationDelta:
    """Apply one flashcard rating event to the student's gamification state.

    Flashcard review: 0 XP
    Login bonus: +2 XP (awarded if streak_extended is True)
    """
    timestamp = now or utc_now()
    today = _today(timestamp)

    state = await _read_or_init(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
    )

    pre_level = state.level
    _apply_weekly_reset(state, today=today)
    streak_extended = _apply_streak(state, today=today)

    xp_earned = 0
    if streak_extended:
        xp_earned += 2

    state.xp_total += xp_earned
    state.xp_this_week += xp_earned
    state.xp_by_topic[topic] = state.xp_by_topic.get(topic, 0) + xp_earned
    state.flashcards_reviewed += 1
    state.level = level_for_xp(state.xp_total)
    _bump_daily_activity(state, today=today)

    unlocks = _materialise_unlocks(state, earned_at=timestamp)

    state.touch()
    await _persist(tenant_id=tenant_id, state=state)

    logger.info(
        "Gamification flashcard event student=%s workspace=%s rating=%s "
        "xp=%d streak=%d level=%d unlocks=%s",
        student_id,
        workspace_id,
        rating.value,
        xp_earned,
        state.streak_days,
        state.level,
        [u.badge_id for u in unlocks],
    )

    return GamificationDelta(
        xp_earned=xp_earned,
        new_level=state.level,
        leveled_up=state.level > pre_level,
        streak_days=state.streak_days,
        streak_extended=streak_extended,
        badges_unlocked=unlocks,
        state=state,
    )


async def record_session_completion(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    session_type: str,
    now: str | None = None,
) -> GamificationDelta:
    """Award XP for completing a study, revision, or flashcard session.

    Study session: +8 XP
    Revision session: +5 XP
    Flashcard session: +5 XP
    Login bonus: +2 XP (awarded if streak_extended is True)
    """
    timestamp = now or utc_now()
    today = _today(timestamp)

    state = await _read_or_init(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
    )

    pre_level = state.level
    _apply_weekly_reset(state, today=today)
    streak_extended = _apply_streak(state, today=today)

    # Calculate XP earned
    if session_type == "study":
        xp_earned = 8
    elif session_type == "revision":
        xp_earned = 5
    elif session_type == "flashcard":
        xp_earned = 5
    else:
        xp_earned = 0

    if streak_extended:
        xp_earned += 2

    state.xp_total = max(0, state.xp_total + xp_earned)
    state.xp_this_week = max(0, state.xp_this_week + xp_earned)
    state.level = level_for_xp(state.xp_total)
    _bump_daily_activity(state, today=today)

    unlocks = _materialise_unlocks(state, earned_at=timestamp)

    state.touch()
    await _persist(tenant_id=tenant_id, state=state)

    logger.info(
        "Gamification session complete event student=%s workspace=%s type=%s "
        "xp=%d streak=%d level=%d unlocks=%s",
        student_id,
        workspace_id,
        session_type,
        xp_earned,
        state.streak_days,
        state.level,
        [u.badge_id for u in unlocks],
    )

    return GamificationDelta(
        xp_earned=xp_earned,
        new_level=state.level,
        leveled_up=state.level > pre_level,
        streak_days=state.streak_days,
        streak_extended=streak_extended,
        badges_unlocked=unlocks,
        state=state,
    )


async def get_state(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
) -> GamificationState:
    """Read the student's gamification state, creating a zero-state on
    first read.

    The API layer (5.2) calls this to render the profile and badges
    views without forcing the student to answer a question first.
    Zero-states are NOT persisted — the engine only writes when an
    event lands.
    """
    return await _read_or_init(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
    )


async def list_workspace_states(
    *,
    tenant_id: str,
    workspace_id: str,
) -> list[GamificationState]:
    """Read every gamification doc in a workspace.

    Used by the leaderboard endpoint (5.2). Returns in insertion order
    — sorting / ranking is the caller's job so the same read can power
    weekly, all-time, or topic-restricted views.
    """
    col = get_collection(tenant_id, GAMIFICATION)
    cursor = col.find(
        {
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    return [GamificationState.model_validate(raw) async for raw in cursor]


# ── XP / level helpers (pure) ───────────────────────────────────────────────


def compute_question_xp(
    *,
    is_correct: bool,
    difficulty: DifficultyLevel,
    streak_days: int,
    revision: bool = False,
) -> int:
    """Award 7 XP for a correct answer, deduct 1 XP for an incorrect attempt."""
    return 7 if is_correct else -1


def level_for_xp(xp_total: int) -> int:
    """Squared-curve level. ``level = floor(sqrt(xp/100)) + 1``.

    Cumulative XP needed for level ``n`` is ``(n-1)^2 * 100``. So:
    100 XP → 2, 400 XP → 3, 900 XP → 4, 1600 XP → 5, 10000 XP → 11.
    Predictable enough that the UI can render a progress bar without
    a server roundtrip.
    """
    if xp_total <= 0:
        return 1
    return math.floor(math.sqrt(xp_total / 100.0)) + 1


def xp_into_level(xp_total: int) -> int:
    """XP earned past the start of the current level.

    Used by the level progress bar — together with
    :func:`xp_for_next_level` it gives a 0..1 fraction.
    """
    current_level = level_for_xp(xp_total)
    floor_xp = (current_level - 1) ** 2 * 100
    return max(xp_total - floor_xp, 0)


def xp_for_next_level(xp_total: int) -> int:
    """XP needed to advance one more level. Always > 0."""
    current_level = level_for_xp(xp_total)
    next_floor = current_level**2 * 100
    floor_xp = (current_level - 1) ** 2 * 100
    return max(next_floor - floor_xp, 1)


# ── Streak / weekly helpers (pure) ──────────────────────────────────────────


def _today(now: str) -> date:
    """Parse an ISO 8601 timestamp into a UTC date.

    Accepts both ``"2026-05-23T..."`` from :func:`utc_now` and bare
    ``"2026-05-23"`` strings (tests). Falls back to today() if parsing
    fails — never raise on a malformed persisted timestamp, that would
    take down the answer endpoint.
    """
    try:
        if "T" in now:
            return datetime.fromisoformat(now).astimezone(UTC).date()
        return date.fromisoformat(now)
    except ValueError:
        logger.warning("Could not parse timestamp %r for streak; using today", now)
        return datetime.now(UTC).date()


def _apply_streak(state: GamificationState, *, today: date) -> bool:
    """Update streak fields on ``state`` in-place. Returns ``True`` iff
    the streak grew (i.e. ``last_active_date`` was yesterday).

    Three cases:
    - first ever event → streak = 1 (counts as extension)
    - same day as last event → no change (returns False)
    - exactly one day later → streak += 1 (returns True)
    - any other gap → streak = 1 (returns False — a reset isn't an
      extension; the UI shouldn't celebrate breaking a streak)
    """
    last_iso = state.last_active_date
    if last_iso is None:
        state.streak_days = 1
        state.longest_streak_days = max(state.longest_streak_days, 1)
        state.last_active_date = today.isoformat()
        return True

    try:
        last = date.fromisoformat(last_iso)
    except ValueError:
        logger.warning("Could not parse last_active_date %r; resetting streak", last_iso)
        state.streak_days = 1
        state.longest_streak_days = max(state.longest_streak_days, 1)
        state.last_active_date = today.isoformat()
        return True

    if today == last:
        return False
    if today == last + timedelta(days=1):
        state.streak_days += 1
        state.longest_streak_days = max(state.longest_streak_days, state.streak_days)
        state.last_active_date = today.isoformat()
        return True

    # Gap of two or more days — reset. Today still counts as day 1.
    state.streak_days = 1
    state.last_active_date = today.isoformat()
    # Note: don't shrink longest_streak_days.
    return False


def _apply_weekly_reset(state: GamificationState, *, today: date) -> None:
    """Reset ``xp_this_week`` when today crosses a new ISO week boundary.

    ``week_starts_at`` is stored as the Monday of the previous event's
    ISO week. On each call we compute this event's week start; if it's
    moved forward we zero ``xp_this_week`` and update the field.
    """
    this_week_start = _iso_week_start(today)
    stored = state.week_starts_at
    if stored is None:
        state.week_starts_at = this_week_start.isoformat()
        return
    try:
        stored_start = date.fromisoformat(stored)
    except ValueError:
        state.xp_this_week = 0
        state.week_starts_at = this_week_start.isoformat()
        return

    if this_week_start > stored_start:
        state.xp_this_week = 0
        state.week_starts_at = this_week_start.isoformat()


def _iso_week_start(d: date) -> date:
    """Monday (00:00 UTC) of the ISO week containing ``d``."""
    return d - timedelta(days=d.weekday())


def _bump_daily_activity(state: GamificationState, *, today: date) -> None:
    """Increment today's activity counter and prune old entries.

    Keeps the doc bounded at :data:`DAILY_ACTIVITY_RETENTION_DAYS`
    entries — pruning the oldest first. Pruning is by date string sort
    (ISO is lexicographic), not by date math, so a wrong-clock entry
    can't poison the sort.
    """
    key = today.isoformat()
    state.daily_activity[key] = state.daily_activity.get(key, 0) + 1
    if len(state.daily_activity) > DAILY_ACTIVITY_RETENTION_DAYS:
        for stale_key in sorted(state.daily_activity)[
            : len(state.daily_activity) - DAILY_ACTIVITY_RETENTION_DAYS
        ]:
            state.daily_activity.pop(stale_key, None)


# ── Badge unlocking ─────────────────────────────────────────────────────────


def _materialise_unlocks(
    state: GamificationState, *, earned_at: str
) -> list[Badge]:
    """Evaluate the catalog, append fresh unlocks to ``state.badges``,
    return them.

    The returned :class:`Badge` records carry the catalog's
    name/description/icon — the engine writes them once at unlock
    time so renaming a badge in the catalog later doesn't retroactively
    rewrite already-earned records.
    """
    unlocks: list[Badge] = []
    for definition in badges_module.evaluate_badges(state):
        badge = Badge(
            badge_id=definition.id,
            name=definition.name,
            description=definition.description,
            icon=definition.icon,
            earned_at=earned_at,
        )
        state.badges.append(badge)
        unlocks.append(badge)
    return unlocks


# ── Cosmos I/O ──────────────────────────────────────────────────────────────


async def _read_or_init(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
) -> GamificationState:
    """Read the existing gamification doc, or build a fresh zero-state.

    Filter is keyed on (student_id, workspace_id) — the document id is
    opaque (``gam_<uuid>``), generated on first persistence.
    """
    col = get_collection(tenant_id, GAMIFICATION)
    raw = await col.find_one(
        {
            "student_id": student_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    if raw is None:
        return GamificationState(
            **{"_id": f"gam_{uuid4().hex}"},
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student_id,
        )
    return GamificationState.model_validate(raw)


async def _persist(*, tenant_id: str, state: GamificationState) -> None:
    """Upsert by ``_id``. Mirrors :mod:`knowledge_state`."""
    col = get_collection(tenant_id, GAMIFICATION)
    await col.replace_one(
        {"_id": state.id},
        state.model_dump(by_alias=True),
        upsert=True,
    )
