"""Unit tests for the difficulty calibrator (Sprint 3.4).

The calibrator is a pure function — every test is deterministic and
runs in microseconds. Hard-coded numbers reflect the v1 calibration:
re-tune the curves in difficulty.py and the affected tests will fail
loudly, which is the intended forcing function for keeping calibration
shifts deliberate.

What's pinned here
------------------
- The mastery → difficulty map at boundary and mid-zone mastery values.
- predict_success_probability is monotonic in mastery for every level.
- predict_success_probability is monotonic-decreasing across difficulties
  at any fixed mastery (advanced is always harder than beginner).
- Step hints walk one notch and drop silently at the rails.
- in_target_zone flag agrees with TARGET_SUCCESS_LOW/HIGH.
- Rationale string surfaces the step-hint outcome (dropped vs applied).
"""

from __future__ import annotations

import pytest

from app.models.question import DifficultyLevel
from app.services.difficulty import (
    TARGET_SUCCESS_HIGH,
    TARGET_SUCCESS_LOW,
    TARGET_SUCCESS_MID,
    StepHint,
    calibrate_difficulty,
    is_in_target_zone,
    predict_success_probability,
)

# ── predict_success_probability ─────────────────────────────────────────────


@pytest.mark.parametrize("difficulty", list(DifficultyLevel))
def test_predict_success_is_monotonic_nondecreasing_in_mastery(difficulty):
    """Higher mastery must never lower predicted success at a fixed
    difficulty. This is the basic sanity property — break it and the
    learning loop is fighting the student.
    """
    last = -1.0
    for m in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
        p = predict_success_probability(mastery=m, difficulty=difficulty)
        assert p >= last
        last = p


@pytest.mark.parametrize("mastery", [0.0, 0.25, 0.5, 0.75, 1.0])
def test_predict_success_is_monotonic_nonincreasing_across_difficulties(mastery):
    """At any fixed mastery, advanced must never predict higher success
    than intermediate, and intermediate never higher than beginner.
    Otherwise 'advanced' isn't actually advanced.
    """
    pb = predict_success_probability(mastery=mastery, difficulty=DifficultyLevel.beginner)
    pi = predict_success_probability(
        mastery=mastery, difficulty=DifficultyLevel.intermediate
    )
    pa = predict_success_probability(mastery=mastery, difficulty=DifficultyLevel.advanced)
    assert pb >= pi >= pa


def test_predict_success_clamps_negative_mastery_to_floor():
    """A student profile with a stray -0.1 mastery (corrupted state)
    should not produce a negative probability — clamp to 0.0 mastery,
    which yields the intercept.
    """
    assert predict_success_probability(
        mastery=-0.5, difficulty=DifficultyLevel.beginner
    ) == predict_success_probability(
        mastery=0.0, difficulty=DifficultyLevel.beginner
    )


def test_predict_success_clamps_above_one_mastery_to_ceiling():
    assert predict_success_probability(
        mastery=1.5, difficulty=DifficultyLevel.advanced
    ) == predict_success_probability(
        mastery=1.0, difficulty=DifficultyLevel.advanced
    )


def test_predict_success_pins_v1_calibration_endpoints():
    """If anyone tunes the curves, these snapshots break. Update the
    numbers AND the docstring math at the same time.
    """
    # beginner: intercept 0.55, slope 0.35
    assert predict_success_probability(
        mastery=0.0, difficulty=DifficultyLevel.beginner
    ) == pytest.approx(0.55)
    assert predict_success_probability(
        mastery=1.0, difficulty=DifficultyLevel.beginner
    ) == pytest.approx(0.90)
    # intermediate: 0.40, slope 0.50
    assert predict_success_probability(
        mastery=0.0, difficulty=DifficultyLevel.intermediate
    ) == pytest.approx(0.40)
    assert predict_success_probability(
        mastery=1.0, difficulty=DifficultyLevel.intermediate
    ) == pytest.approx(0.90)
    # advanced: 0.20, slope 0.60
    assert predict_success_probability(
        mastery=0.0, difficulty=DifficultyLevel.advanced
    ) == pytest.approx(0.20)
    assert predict_success_probability(
        mastery=1.0, difficulty=DifficultyLevel.advanced
    ) == pytest.approx(0.80)


# ── is_in_target_zone ───────────────────────────────────────────────────────


def test_is_in_target_zone_inclusive_at_boundaries():
    assert is_in_target_zone(TARGET_SUCCESS_LOW)
    assert is_in_target_zone(TARGET_SUCCESS_HIGH)
    assert is_in_target_zone(TARGET_SUCCESS_MID)
    assert not is_in_target_zone(TARGET_SUCCESS_LOW - 0.001)
    assert not is_in_target_zone(TARGET_SUCCESS_HIGH + 0.001)


# ── calibrate_difficulty: base selection (no step hint) ─────────────────────


def test_cold_start_mastery_zero_selects_beginner():
    """A student with no mastery should get beginner — predicted success
    0.55 there is closer to the 0.725 target than intermediate's 0.40
    or advanced's 0.20.
    """
    cal = calibrate_difficulty(mastery=0.0)
    assert cal.difficulty == DifficultyLevel.beginner
    assert cal.predicted_success == pytest.approx(0.55)
    assert cal.step_applied is None
    # 0.55 isn't in the [0.70, 0.75] band — flag should be False.
    assert cal.in_target_zone is False


def test_mid_mastery_selects_beginner_in_zone():
    """At mastery 0.5, beginner predicts exactly 0.725 — the target
    midpoint. That's the strongest possible "in zone" result.
    """
    cal = calibrate_difficulty(mastery=0.5)
    assert cal.difficulty == DifficultyLevel.beginner
    assert cal.predicted_success == pytest.approx(0.725)
    assert cal.in_target_zone is True


def test_high_mid_mastery_selects_intermediate_in_zone():
    """At mastery 0.65, intermediate predicts 0.725 — perfectly on
    target — while beginner predicts 0.7775 (too easy) and advanced
    predicts 0.59 (too hard).
    """
    cal = calibrate_difficulty(mastery=0.65)
    assert cal.difficulty == DifficultyLevel.intermediate
    assert cal.predicted_success == pytest.approx(0.725)
    assert cal.in_target_zone is True


def test_high_mastery_selects_advanced_in_zone():
    """At mastery 0.875, advanced predicts 0.725 — on target.
    Intermediate would predict 0.8375 (too easy), beginner 0.856 (too easy).
    """
    cal = calibrate_difficulty(mastery=0.875)
    assert cal.difficulty == DifficultyLevel.advanced
    assert cal.predicted_success == pytest.approx(0.725)
    assert cal.in_target_zone is True


def test_full_mastery_selects_advanced_closest_to_target():
    """At mastery 1.0 every prediction is above the target. advanced
    (0.80) is closest to 0.725; the rationale should report that the
    target zone is unreachable.
    """
    cal = calibrate_difficulty(mastery=1.0)
    assert cal.difficulty == DifficultyLevel.advanced
    assert cal.predicted_success == pytest.approx(0.80)
    assert cal.in_target_zone is False
    assert "zone unreachable" in cal.rationale


def test_candidates_dict_contains_all_three_levels():
    cal = calibrate_difficulty(mastery=0.5)
    assert set(cal.candidates) == set(DifficultyLevel)
    for prob in cal.candidates.values():
        assert 0.0 <= prob <= 1.0


# ── calibrate_difficulty: step hints ────────────────────────────────────────


def test_step_up_from_beginner_lands_on_intermediate():
    cal = calibrate_difficulty(mastery=0.0, step_hint=StepHint.up)
    assert cal.difficulty == DifficultyLevel.intermediate
    assert cal.step_applied == StepHint.up
    # Predicted success reflects the stepped-up difficulty, NOT the base.
    assert cal.predicted_success == pytest.approx(0.40)
    assert "stepped up one notch" in cal.rationale


def test_step_up_from_intermediate_lands_on_advanced():
    cal = calibrate_difficulty(mastery=0.65, step_hint=StepHint.up)
    assert cal.difficulty == DifficultyLevel.advanced
    assert cal.step_applied == StepHint.up


def test_step_up_at_advanced_is_no_op_and_reported_in_rationale():
    """Step-up at the top rail must NOT roll over to anything else.
    The rationale must surface that the hint was dropped so the
    answer-eval worker can adjust its threshold next time.
    """
    cal = calibrate_difficulty(mastery=0.875, step_hint=StepHint.up)
    # base would already be advanced; step up has nowhere to go.
    assert cal.difficulty == DifficultyLevel.advanced
    assert cal.step_applied is None
    assert "already at the rail" in cal.rationale


def test_step_down_from_advanced_lands_on_intermediate():
    cal = calibrate_difficulty(mastery=0.875, step_hint=StepHint.down)
    assert cal.difficulty == DifficultyLevel.intermediate
    assert cal.step_applied == StepHint.down
    assert "stepped down one notch" in cal.rationale


def test_step_down_at_beginner_is_no_op_and_reported_in_rationale():
    cal = calibrate_difficulty(mastery=0.0, step_hint=StepHint.down)
    assert cal.difficulty == DifficultyLevel.beginner
    assert cal.step_applied is None
    assert "already at the rail" in cal.rationale


def test_step_hint_does_not_change_candidates_dict():
    """Candidates are the per-level predictions at the input mastery —
    they shouldn't shift because of a step hint. The hint only changes
    which level is selected.
    """
    base = calibrate_difficulty(mastery=0.65)
    stepped = calibrate_difficulty(mastery=0.65, step_hint=StepHint.up)
    assert base.candidates == stepped.candidates


# ── Selection determinism ──────────────────────────────────────────────────


def test_selection_is_deterministic_across_repeated_calls():
    for _ in range(5):
        cal = calibrate_difficulty(mastery=0.55)
        assert cal.difficulty == DifficultyLevel.beginner
        assert cal.predicted_success == pytest.approx(0.55 * 0.35 + 0.55)


def test_predict_success_rejects_unknown_difficulty_enum_extension():
    """If someone adds a DifficultyLevel value without updating the
    calibration table, predict_success_probability must fail loud.
    Passing an arbitrary string simulates the gap.
    """
    with pytest.raises(ValueError, match="Unknown difficulty"):
        predict_success_probability(mastery=0.5, difficulty="unknown_level")  # type: ignore[arg-type]
