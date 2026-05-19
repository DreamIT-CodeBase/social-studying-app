"""Difficulty calibration — Sprint 3.4.

Given a student's mastery on a topic (0.0–1.0) plus an optional step hint
from the answer-evaluation loop, pick a question difficulty whose
predicted success probability lands in the 70–75% "desirable difficulty"
zone (Bjork & Bjork 2011: deliberately effortful retrieval produces the
best long-term learning).

Why a piecewise linear model and not IRT
----------------------------------------
Item Response Theory predicts success via a logistic curve over a
latent (ability - difficulty) gap, fit from thousands of attempts per
item. We don't have that data on day 1, and a fancier model would only
appear more accurate. A piecewise linear mapping with three discrete
difficulty bands hits the target zone smoothly across mastery and is
trivially explainable in admin tooltips.

Calibration
-----------
For each difficulty level, predicted success rises linearly with
mastery. Slopes and intercepts are calibrated so each level's
"in target zone" band falls at a distinct, monotonically-increasing
mastery:

    beginner:     0.55 + 0.35 × mastery   (target zone: mastery ∈ [0.43, 0.57])
    intermediate: 0.40 + 0.50 × mastery   (target zone: mastery ∈ [0.60, 0.70])
    advanced:     0.20 + 0.60 × mastery   (target zone: mastery ∈ [0.83, 0.92])

Selection: pick the difficulty whose predicted success is closest to
the midpoint of the target zone (0.725). Ties (which only happen at
the exact boundary mastery) are broken by complexity ascending — prefer
the easier option so the student gets a win first.

Step hints
----------
The answer-evaluation worker (Sprint 3.10) accumulates short-horizon
signals (e.g. "got the last 3 right at this difficulty"). On those
signals, it passes ``StepHint.up`` / ``StepHint.down`` here to override
the base selection by one notch. This is the standard ratchet behavior
that lets the system respond faster than mastery_score recalculation
would allow.

A step hint at the rail (up at advanced, down at beginner) is a no-op
and is reported back through the rationale string.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from enum import StrEnum

from app.models.question import DifficultyLevel

logger = logging.getLogger(__name__)


# ── Target zone ──────────────────────────────────────────────────────────────

# The "desirable difficulty" band, from Bjork's spacing/effortful-retrieval
# work. Hard-coded rather than configurable today — Sprint 4's admin UI
# may surface a slider for this; if so, lift to ``WorkspaceSettings``.
TARGET_SUCCESS_LOW: float = 0.70
TARGET_SUCCESS_HIGH: float = 0.75
TARGET_SUCCESS_MID: float = (TARGET_SUCCESS_LOW + TARGET_SUCCESS_HIGH) / 2  # 0.725


# Order from easiest to hardest. Step hints walk along this list.
_DIFFICULTY_LADDER: tuple[DifficultyLevel, ...] = (
    DifficultyLevel.beginner,
    DifficultyLevel.intermediate,
    DifficultyLevel.advanced,
)


# ── Calibration table ───────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class _LinearCurve:
    """Predicted success = ``intercept + slope * mastery``.

    Slopes + intercepts are fixed at v1 calibration. Re-tuning here
    moves the in-target-zone bands; every test pinning a specific
    selection should break loudly so the calibration shift is deliberate.
    """

    intercept: float
    slope: float

    def predict(self, mastery: float) -> float:
        return self.intercept + self.slope * mastery


_CURVES: dict[DifficultyLevel, _LinearCurve] = {
    DifficultyLevel.beginner: _LinearCurve(intercept=0.55, slope=0.35),
    DifficultyLevel.intermediate: _LinearCurve(intercept=0.40, slope=0.50),
    DifficultyLevel.advanced: _LinearCurve(intercept=0.20, slope=0.60),
}


# ── Hint enum ───────────────────────────────────────────────────────────────


class StepHint(StrEnum):
    """One-notch nudge that overrides the base calibration.

    Emitted by the answer-evaluation worker when a short-horizon signal
    (streak of right/wrong) warrants a faster ratchet than the mastery
    recalculation would produce.
    """

    up = "up"
    down = "down"


# ── Output ──────────────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class DifficultyCalibration:
    """Result of :func:`calibrate_difficulty`."""

    difficulty: DifficultyLevel
    predicted_success: float
    in_target_zone: bool
    candidates: dict[DifficultyLevel, float]
    rationale: str
    step_applied: StepHint | None = None  # None if the hint hit the rail or was unset


# ── Pure prediction ─────────────────────────────────────────────────────────


def predict_success_probability(
    *,
    mastery: float,
    difficulty: DifficultyLevel,
) -> float:
    """Return predicted success probability for ``(mastery, difficulty)``.

    Mastery is clamped to ``[0.0, 1.0]`` — a student profile that drifts
    outside the band (which shouldn't happen post-validation, but be
    defensive) collapses to the rail rather than emitting an out-of-range
    probability.

    Raises:
        ValueError: if ``difficulty`` is not a recognized DifficultyLevel.
            Adding a new level requires extending ``_CURVES`` — failing
            loud forces the calibration update.
    """
    if difficulty not in _CURVES:
        raise ValueError(
            f"Unknown difficulty {difficulty!r}; calibration table only "
            f"covers {list(_CURVES)}"
        )
    bounded = max(0.0, min(1.0, mastery))
    return _CURVES[difficulty].predict(bounded)


def is_in_target_zone(success_probability: float) -> bool:
    """True iff ``success_probability`` is within the desirable-difficulty band."""
    return TARGET_SUCCESS_LOW <= success_probability <= TARGET_SUCCESS_HIGH


# ── Calibration ─────────────────────────────────────────────────────────────


def calibrate_difficulty(
    *,
    mastery: float,
    step_hint: StepHint | None = None,
) -> DifficultyCalibration:
    """Pick the best difficulty for a student's current mastery on a topic.

    Selection algorithm:
        1. Predict success for each difficulty at the given mastery.
        2. Pick the difficulty whose prediction is closest to the
           target-zone midpoint (0.725). Ties go to the easier option
           (rare — happens only at exact boundary mastery).
        3. If ``step_hint`` is provided, move one notch on the
           difficulty ladder in that direction. A hint at the rail
           (``up`` at advanced, ``down`` at beginner) is dropped and
           reported as ``step_applied=None``.

    Args:
        mastery: student's mastery on the topic, 0.0–1.0. Out-of-range
            inputs are clamped, not rejected.
        step_hint: optional one-notch ratchet from the answer-eval loop.

    Returns:
        :class:`DifficultyCalibration` with the chosen level, its
        predicted success, an in_target_zone flag, the full candidate
        dict for observability, and a rationale string.

    Predicted success is recomputed AFTER any step hint is applied, so
    ``in_target_zone`` reflects the actually-selected difficulty.
    """
    bounded = max(0.0, min(1.0, mastery))
    candidates: dict[DifficultyLevel, float] = {
        d: _CURVES[d].predict(bounded) for d in _DIFFICULTY_LADDER
    }

    # Closest-to-target selection. Stable sort: by distance asc, then by
    # ladder index asc (lower difficulty wins ties).
    base = min(
        _DIFFICULTY_LADDER,
        key=lambda d: (abs(candidates[d] - TARGET_SUCCESS_MID), _DIFFICULTY_LADDER.index(d)),
    )

    selected, step_applied = _apply_step_hint(base=base, hint=step_hint)
    predicted = candidates[selected]
    rationale = _build_rationale(
        mastery=bounded,
        base=base,
        selected=selected,
        predicted=predicted,
        step_hint=step_hint,
        step_applied=step_applied,
    )

    logger.info(
        "Calibrated difficulty=%s mastery=%.3f predicted_success=%.3f "
        "in_target=%s base=%s step_hint=%s step_applied=%s",
        selected.value,
        bounded,
        predicted,
        is_in_target_zone(predicted),
        base.value,
        step_hint.value if step_hint else None,
        step_applied.value if step_applied else None,
    )

    return DifficultyCalibration(
        difficulty=selected,
        predicted_success=predicted,
        in_target_zone=is_in_target_zone(predicted),
        candidates=candidates,
        rationale=rationale,
        step_applied=step_applied,
    )


# ── Step hint application ───────────────────────────────────────────────────


def _apply_step_hint(
    *,
    base: DifficultyLevel,
    hint: StepHint | None,
) -> tuple[DifficultyLevel, StepHint | None]:
    """Walk one notch along the ladder; report the hint that actually fired.

    Returns ``(selected, step_applied)``. ``step_applied`` is ``None``
    when no hint was given OR when the hint hit the rail (e.g. ``up``
    at ``advanced``) — both cases are no-ops, but reporting them
    distinctly helps callers decide whether to log the dropped hint.
    """
    if hint is None:
        return base, None

    idx = _DIFFICULTY_LADDER.index(base)
    if hint == StepHint.up:
        if idx == len(_DIFFICULTY_LADDER) - 1:
            return base, None  # already at the top rail
        return _DIFFICULTY_LADDER[idx + 1], hint
    if hint == StepHint.down:
        if idx == 0:
            return base, None  # already at the bottom rail
        return _DIFFICULTY_LADDER[idx - 1], hint
    raise ValueError(f"Unknown step hint: {hint!r}")


# ── Rationale ───────────────────────────────────────────────────────────────


def _build_rationale(
    *,
    mastery: float,
    base: DifficultyLevel,
    selected: DifficultyLevel,
    predicted: float,
    step_hint: StepHint | None,
    step_applied: StepHint | None,
) -> str:
    """Render a short, admin-readable explanation of the calibration."""
    in_zone = is_in_target_zone(predicted)
    zone_phrase = (
        "in the 70-75% target zone"
        if in_zone
        else (
            f"closest available to {TARGET_SUCCESS_MID:.0%} target "
            "(zone unreachable at this mastery)"
        )
    )

    if step_hint is None:
        return (
            f"Selected {selected.value} for mastery {mastery:.0%}: "
            f"predicted success {predicted:.0%} ({zone_phrase})."
        )

    if step_applied is None:
        return (
            f"Selected {selected.value} for mastery {mastery:.0%}: "
            f"predicted success {predicted:.0%} ({zone_phrase}). "
            f"Step hint {step_hint.value!r} ignored — already at the rail."
        )

    return (
        f"Selected {selected.value} for mastery {mastery:.0%}: "
        f"predicted success {predicted:.0%} ({zone_phrase}). "
        f"Base calibration was {base.value}; stepped {step_hint.value} one notch."
    )
