"""Unit tests for the badge catalog and evaluator (Sprint 5.3, 5.13).

Pins:
- Catalog integrity (>= 15 badges, unique ids, every predicate callable)
- Predicate behaviour on zero-state and threshold crossings
- ``evaluate_badges`` filters out already-earned + preserves catalog order
"""

from __future__ import annotations

from app.models.gamification import Badge, GamificationState
from app.services.badges import BADGES, by_id, evaluate_badges

# ── Catalog integrity ──────────────────────────────────────────────────────


def test_catalog_has_at_least_fifteen_badges():
    """Sprint 5.3 requires at least 15 badges for launch."""
    assert len(BADGES) >= 15


def test_catalog_ids_are_unique():
    ids = [b.id for b in BADGES]
    assert len(ids) == len(set(ids))


def test_catalog_predicates_are_safe_on_zero_state():
    """Calling every predicate on a fresh state must not raise.

    Zero-state means questions_answered=0, so any predicate that does
    a division (``perfectionist``) must guard against it.
    """
    zero = _state()
    for definition in BADGES:
        # Must not raise; result type must be a bool.
        result = definition.trigger(zero)
        assert isinstance(result, bool)


def test_by_id_returns_definition_when_known():
    badge = by_id("first_steps")
    assert badge is not None
    assert badge.name == "First Steps"


def test_by_id_returns_none_when_unknown():
    assert by_id("not_a_badge") is None


# ── Predicate spot-checks (one per progression) ────────────────────────────


def test_first_steps_unlocks_at_one_question():
    state = _state(questions_answered=1)
    ids = {b.id for b in evaluate_badges(state)}
    assert "first_steps" in ids


def test_streak_three_does_not_unlock_at_two_days():
    state = _state(streak_days=2)
    ids = {b.id for b in evaluate_badges(state)}
    assert "streak_3" not in ids


def test_streak_three_unlocks_at_three_days():
    state = _state(streak_days=3)
    ids = {b.id for b in evaluate_badges(state)}
    assert "streak_3" in ids


def test_perfectionist_requires_floor_of_fifty_questions():
    """A perfect 1-for-1 doesn't unlock perfectionist — floor matters."""
    state = _state(questions_answered=1, questions_correct=1)
    ids = {b.id for b in evaluate_badges(state)}
    assert "perfectionist" not in ids


def test_perfectionist_unlocks_at_threshold():
    state = _state(questions_answered=50, questions_correct=45)
    ids = {b.id for b in evaluate_badges(state)}
    assert "perfectionist" in ids


def test_level_badge_keys_off_level_field_not_xp():
    """``level_5`` triggers on ``state.level``, not on raw XP. (The
    engine sets ``level`` from XP before evaluating badges, so this
    decoupling lets badge tuning happen without re-deriving XP curves.)
    """
    state = _state(xp_total=1, level=5)
    ids = {b.id for b in evaluate_badges(state)}
    assert "level_5" in ids


# ── Evaluator behaviour ────────────────────────────────────────────────────


def test_evaluate_filters_already_earned():
    """A badge earned previously is not returned even if its predicate
    still holds.
    """
    state = _state(
        questions_answered=10,
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
    ids = {b.id for b in evaluate_badges(state)}
    assert "first_steps" not in ids


def test_evaluate_preserves_catalog_order_on_multi_unlock():
    """Crossing several thresholds at once: unlocks come back in the
    order they appear in ``BADGES`` — deterministic for the UI banner.
    """
    state = _state(
        questions_answered=500,
        questions_correct=450,  # 90% accuracy
        xp_total=10_000,
        flashcards_reviewed=250,
        streak_days=100,
        level=10,
    )
    unlocked_ids = [b.id for b in evaluate_badges(state)]
    catalog_order = [b.id for b in BADGES]
    catalog_positions = [catalog_order.index(i) for i in unlocked_ids]
    # Positions in catalog order must be strictly increasing.
    assert catalog_positions == sorted(catalog_positions)


def test_evaluate_returns_empty_on_zero_state():
    """A brand new student earns no badges until they do something."""
    assert evaluate_badges(_state()) == []


# ── Helpers ────────────────────────────────────────────────────────────────


def _state(**kwargs) -> GamificationState:
    base = {
        "_id": "gam_t",
        "tenant_id": "ten_a",
        "workspace_id": "wsp_a",
        "student_id": "stu_a",
    }
    base.update(kwargs)
    return GamificationState(**base)
