"""Unit tests for the gamification engine (Sprint 5.1, 5.13).

Pins the XP rule, the level curve, the streak math, the weekly reset,
the daily-activity pruning, and the I/O contract (upsert + zero-state
init). Numeric assertions pin the constants in ``gamification.py`` —
when you tune the XP awards or the streak cap, these break loudly.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock, patch

import pytest

from app.models.flashcard import FlashcardRating
from app.models.gamification import Badge, GamificationState
from app.models.question import DifficultyLevel
from app.services import gamification as gamification_service
from app.services.gamification import (
    DAILY_ACTIVITY_RETENTION_DAYS,
    WRONG_ANSWER_PENALTY_XP,
    _apply_streak,
    _apply_weekly_reset,
    _bump_daily_activity,
    _bump_daily_xp,
    _iso_week_start,
    compute_question_xp,
    level_for_xp,
    record_flashcard_rating,
    record_question_attempt,
    xp_for_next_level,
    xp_into_level,
)

# ── Pure XP rule ────────────────────────────────────────────────────────────


def test_compute_xp_wrong_answer_applies_penalty():
    """Every wrong study or revision answer deducts exactly 1 XP."""
    xp = compute_question_xp(
        is_correct=False,
        difficulty=DifficultyLevel.advanced,
        streak_days=5,
    )
    assert xp == -1


def test_compute_xp_wrong_answer_penalty_is_negative():
    assert WRONG_ANSWER_PENALTY_XP == -1


def test_compute_xp_correct_advanced_at_zero_streak():
    """1 XP for advanced correct."""
    xp = compute_question_xp(
        is_correct=True,
        difficulty=DifficultyLevel.advanced,
        streak_days=0,
    )
    assert xp == 1


def test_compute_xp_streak_bonus_is_capped():
    xp_long = compute_question_xp(
        is_correct=True,
        difficulty=DifficultyLevel.beginner,
        streak_days=200,
    )
    assert xp_long == 1


def test_compute_xp_streak_bonus_scales_below_cap():
    low = compute_question_xp(
        is_correct=True,
        difficulty=DifficultyLevel.beginner,
        streak_days=3,
    )
    assert low == 1


# ── Level curve ─────────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("xp", "expected_level"),
    [
        (0, 1),
        (50, 1),
        (99, 1),
        (100, 2),
        (399, 2),
        (400, 3),
        (900, 4),
        (1600, 5),
        (2500, 6),
        (10_000, 11),
    ],
)
def test_level_for_xp_thresholds(xp: int, expected_level: int):
    """``floor(sqrt(xp/100)) + 1`` — pin the canonical thresholds."""
    assert level_for_xp(xp) == expected_level


def test_xp_into_level_at_floor_is_zero():
    """Exactly at a level threshold, you've earned 0 XP into that level."""
    assert xp_into_level(400) == 0
    assert xp_into_level(900) == 0


def test_xp_into_level_plus_remaining_equals_next_floor_minus_floor():
    """``xp_into_level`` + remaining-to-next = full span of the current level."""
    xp = 550
    assert xp_into_level(xp) + (xp_for_next_level(xp) - xp_into_level(xp)) == \
        xp_for_next_level(xp)


def test_xp_for_next_level_always_positive():
    """The progress bar denominator must never be zero."""
    for xp in (0, 100, 999, 9_999):
        assert xp_for_next_level(xp) > 0


# ── Streak math ─────────────────────────────────────────────────────────────


def _state() -> GamificationState:
    """Construct a zero gamification state for streak tests."""
    return GamificationState(
        **{"_id": "gam_t"},
        tenant_id="ten_a",
        workspace_id="wsp_a",
        student_id="stu_a",
    )


def test_streak_first_ever_event_starts_at_one():
    state = _state()
    extended = _apply_streak(state, today=date(2026, 5, 23))
    assert extended is True
    assert state.streak_days == 1
    assert state.longest_streak_days == 1
    assert state.last_active_date == "2026-05-23"


def test_streak_same_day_event_unchanged():
    state = _state()
    state.streak_days = 4
    state.longest_streak_days = 4
    state.last_active_date = "2026-05-23"
    extended = _apply_streak(state, today=date(2026, 5, 23))
    assert extended is False
    assert state.streak_days == 4


def test_streak_consecutive_day_extends_by_one():
    state = _state()
    state.streak_days = 4
    state.longest_streak_days = 4
    state.last_active_date = "2026-05-23"
    extended = _apply_streak(state, today=date(2026, 5, 24))
    assert extended is True
    assert state.streak_days == 5
    assert state.longest_streak_days == 5
    assert state.last_active_date == "2026-05-24"


def test_streak_gap_resets_to_one_but_keeps_longest():
    state = _state()
    state.streak_days = 12
    state.longest_streak_days = 12
    state.last_active_date = "2026-05-20"
    extended = _apply_streak(state, today=date(2026, 5, 23))
    # Three-day gap — reset; today still counts as a fresh day-1.
    assert extended is False
    assert state.streak_days == 1
    assert state.longest_streak_days == 12  # not shrunk


def test_streak_malformed_persisted_date_falls_back_to_reset():
    state = _state()
    state.last_active_date = "not-a-date"
    extended = _apply_streak(state, today=date(2026, 5, 23))
    assert extended is True
    assert state.streak_days == 1


# ── Weekly reset ────────────────────────────────────────────────────────────


def test_iso_week_start_returns_monday():
    # 2026-05-23 is a Saturday. Monday of that ISO week is 2026-05-18.
    assert _iso_week_start(date(2026, 5, 23)) == date(2026, 5, 18)
    # Already Monday → same date.
    assert _iso_week_start(date(2026, 5, 18)) == date(2026, 5, 18)


def test_weekly_reset_first_call_seeds_week_starts_at():
    state = _state()
    _apply_weekly_reset(state, today=date(2026, 5, 23))
    assert state.week_starts_at == "2026-05-18"
    assert state.xp_this_week == 0


def test_weekly_reset_same_week_keeps_xp():
    state = _state()
    state.week_starts_at = "2026-05-18"
    state.xp_this_week = 250
    _apply_weekly_reset(state, today=date(2026, 5, 22))  # still that week
    assert state.xp_this_week == 250


def test_weekly_reset_new_week_zeros_xp():
    state = _state()
    state.week_starts_at = "2026-05-18"
    state.xp_this_week = 250
    _apply_weekly_reset(state, today=date(2026, 5, 25))  # next Monday
    assert state.xp_this_week == 0
    assert state.week_starts_at == "2026-05-25"


# ── Daily activity pruning ──────────────────────────────────────────────────


def test_bump_daily_activity_increments_today_counter():
    state = _state()
    _bump_daily_activity(state, today=date(2026, 5, 23))
    _bump_daily_activity(state, today=date(2026, 5, 23))
    assert state.daily_activity == {"2026-05-23": 2}


def test_bump_daily_activity_prunes_oldest_past_retention():
    state = _state()
    # Seed with retention+5 distinct days already.
    for i in range(DAILY_ACTIVITY_RETENTION_DAYS + 5):
        state.daily_activity[f"2026-04-{i + 1:02d}"] = 1
    _bump_daily_activity(state, today=date(2026, 5, 23))
    # Pruned down to the cap.
    assert len(state.daily_activity) == DAILY_ACTIVITY_RETENTION_DAYS
    # Today survives.
    assert "2026-05-23" in state.daily_activity
    # The oldest was dropped.
    assert "2026-04-01" not in state.daily_activity


def test_bump_daily_xp_accumulates_net_xp_for_the_date():
    state = _state()
    _bump_daily_xp(state, today=date(2026, 5, 23), xp_delta=9)
    _bump_daily_xp(state, today=date(2026, 5, 23), xp_delta=-1)
    assert state.daily_xp == {"2026-05-23": 8}


def test_bump_daily_xp_prunes_oldest_past_retention():
    state = _state()
    for i in range(DAILY_ACTIVITY_RETENTION_DAYS + 5):
        state.daily_xp[f"2026-04-{i + 1:02d}"] = i
    _bump_daily_xp(state, today=date(2026, 5, 23), xp_delta=7)
    assert len(state.daily_xp) == DAILY_ACTIVITY_RETENTION_DAYS
    assert state.daily_xp["2026-05-23"] == 7
    assert "2026-04-01" not in state.daily_xp


# ── End-to-end (async with fake collection) ─────────────────────────────────


def _fake_collection(*, initial: dict | None = None):
    """Mutable in-memory stand-in for a Cosmos collection.

    Mirrors the helper in ``test_knowledge_state.py``.
    """
    store: dict[str, dict | None] = {"current": initial}
    col = MagicMock()

    async def _find_one(_filter):
        return store["current"]

    async def _replace_one(_filter, doc, upsert=False):
        store["current"] = doc
        return MagicMock(matched_count=1, upserted_id=doc["_id"])

    col.find_one = _find_one
    col.replace_one = _replace_one
    return col, store


def _seed(
    *,
    xp_total: int = 0,
    level: int = 1,
    streak_days: int = 0,
    last_active_date: str | None = None,
    badges: list[Badge] | None = None,
    questions_answered: int = 0,
    questions_correct: int = 0,
    flashcards_reviewed: int = 0,
) -> dict:
    return GamificationState(
        **{"_id": "gam_seed"},
        tenant_id="ten_a",
        workspace_id="wsp_a",
        student_id="stu_a",
        xp_total=xp_total,
        level=level,
        streak_days=streak_days,
        last_active_date=last_active_date,
        badges=badges or [],
        questions_answered=questions_answered,
        questions_correct=questions_correct,
        flashcards_reviewed=flashcards_reviewed,
    ).model_dump(by_alias=True)


@pytest.mark.asyncio
async def test_record_question_attempt_persists_daily_xp_history():
    col, store = _fake_collection(initial=None)
    with patch.object(gamification_service, "get_collection", return_value=col):
        await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
            now="2026-05-23T10:00:00+00:00",
        )

    persisted = store["current"]
    assert persisted is not None
    assert persisted["daily_xp"] == {
        "2026-05-23": persisted["xp_this_week"],
    }


@pytest.mark.asyncio
async def test_record_question_attempt_initializes_state_on_first_event():
    col, store = _fake_collection(initial=None)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
            now="2026-05-23T10:00:00+00:00",
        )

    # +1 action XP and the configurable +5 First Steps achievement.
    # Daily login is deliberately claimed through its own idempotent endpoint.
    assert delta.xp_earned == 6
    assert delta.streak_days == 1
    assert delta.streak_extended is True
    assert delta.leveled_up is False  # level 1 → still 1 below 100 XP
    assert delta.new_level == 1
    # State persisted.
    persisted = store["current"]
    assert persisted is not None
    assert persisted["xp_total"] == 6
    assert persisted["xp_by_topic"]["Photosynthesis"] == 1
    assert persisted["questions_answered"] == 1
    assert persisted["questions_correct"] == 1
    assert persisted["daily_activity"]["2026-05-23"] == 1


@pytest.mark.asyncio
async def test_record_question_attempt_unlocks_first_steps_badge():
    col, _ = _fake_collection(initial=None)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
            now="2026-05-23T10:00:00+00:00",
        )
    unlocked_ids = {b.badge_id for b in delta.badges_unlocked}
    # First-steps fires on the first answered question. Streak-3 doesn't
    # fire (only one day). Sharp-5 doesn't fire (only one correct).
    assert "first_steps" in unlocked_ids
    assert "streak_3" not in unlocked_ids
    assert "sharp_5" not in unlocked_ids


@pytest.mark.asyncio
async def test_record_question_attempt_level_up_flag_fires_on_threshold_cross():
    """At 99 XP (level 1), earning 1 XP lands at 100 XP → level 2."""
    initial = _seed(
        xp_total=99,
        level=1,
        streak_days=1,
        last_active_date="2026-05-23",
    )
    col, store = _fake_collection(initial=initial)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.advanced,
            is_correct=True,
            now="2026-05-23T10:00:00+00:00", # same day, no daily login bonus
        )
    assert delta.leveled_up is True
    assert delta.new_level == 2
    # +1 answer, then First Steps, Rising Star, and Level Up rewards (+5 each).
    assert store["current"]["xp_total"] == 115


@pytest.mark.asyncio
async def test_record_question_attempt_streak_does_not_extend_same_day():
    initial = _seed(
        streak_days=3,
        last_active_date="2026-05-23",
    )
    col, _ = _fake_collection(initial=initial)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
            now="2026-05-23T18:00:00+00:00",
        )
    assert delta.streak_days == 3
    assert delta.streak_extended is False


@pytest.mark.asyncio
async def test_record_question_attempt_extends_streak_next_day():
    initial = _seed(
        streak_days=6,
        last_active_date="2026-05-22",
    )
    col, store = _fake_collection(initial=initial)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=False,
            now="2026-05-23T10:00:00+00:00",
        )
    assert delta.streak_days == 7
    assert delta.streak_extended is True
    # Crossing into a 7-day streak should unlock the "Dedicated" badge.
    assert "streak_7" in {b.badge_id for b in delta.badges_unlocked}
    assert store["current"]["streak_days"] == 7


@pytest.mark.asyncio
async def test_record_flashcard_rating_is_flat_xp_and_separate_counter():
    col, store = _fake_collection(initial=None)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_flashcard_rating(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            rating=FlashcardRating.medium,
            now="2026-05-23T10:00:00+00:00",
        )
    # Legacy medium remains neutral; the first-card achievement awards +5 XP.
    assert delta.xp_earned == 5
    # Doesn't touch the question counters.
    persisted = store["current"]
    assert persisted["questions_answered"] == 0
    assert persisted["questions_correct"] == 0
    assert persisted["flashcards_reviewed"] == 1
    # Streak bonus does not apply to flashcards.
    assert delta.streak_days == 1


@pytest.mark.asyncio
async def test_record_question_attempt_does_not_reunlock_existing_badge():
    initial = _seed(
        xp_total=120,
        level=2,
        questions_answered=1,
        questions_correct=1,
        badges=[
            Badge(
                badge_id="first_steps",
                name="First Steps",
                description="Answer your first question.",
                icon="spa_rounded",
                earned_at="2026-05-22T10:00:00+00:00",
            )
        ],
    )
    col, _ = _fake_collection(initial=initial)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=False,
            now="2026-05-23T10:00:00+00:00",
        )
    assert "first_steps" not in {b.badge_id for b in delta.badges_unlocked}


@pytest.mark.asyncio
async def test_record_question_attempt_persists_via_upsert():
    """Cold start ⇒ ``replace_one`` with ``upsert=True``."""
    col, _ = _fake_collection(initial=None)
    captured: dict[str, object] = {}

    async def _capture(_filter, doc, upsert=False):
        captured["upsert"] = upsert
        captured["filter"] = _filter
        return MagicMock(matched_count=1)

    col.replace_one = _capture
    with patch.object(gamification_service, "get_collection", return_value=col):
        await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
        )
    assert captured["upsert"] is True
    assert "_id" in captured["filter"]


@pytest.mark.asyncio
async def test_wrong_answer_deducts_xp_from_total():
    """A wrong answer deducts 1 XP; a fresh First Steps badge adds 5 XP."""
    initial = _seed(xp_total=50, level=1, streak_days=1, last_active_date="2026-05-23")
    col, store = _fake_collection(initial=initial)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_question_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=False,
            now="2026-05-23T18:00:00+00:00",
        )
    assert delta.xp_earned == 4
    assert store["current"]["xp_total"] == 54


@pytest.mark.asyncio
async def test_record_session_completion_awards_correct_xp():
    col, store = _fake_collection(initial=None)
    from app.services.gamification import record_session_completion

    # 1. Study completion (+8) and its first-session achievement (+8).
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_session_completion(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            session_type="study",
            now="2026-05-23T10:00:00+00:00",
        )
    assert delta.xp_earned == 16
    assert store["current"]["xp_total"] == 16

    # 2. Revision session completion on same day (streak_extended = False)
    with patch.object(gamification_service, "get_collection", return_value=col):
        delta = await record_session_completion(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            session_type="revision",
            now="2026-05-23T12:00:00+00:00",
        )
    # +5 XP revision session; daily login remains a separate event.
    assert delta.xp_earned == 5
    assert store["current"]["xp_total"] == 21
