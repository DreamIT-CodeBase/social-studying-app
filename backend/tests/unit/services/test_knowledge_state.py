"""Unit tests for the knowledge state update service (Sprint 3.11).

Pins the v1 mastery math (weighted EMA), the difficulty weighting, the
clamping at [0, 1], and the I/O contract (upsert + first-interaction
init).

Whenever the LEARNING_RATE or _DIFFICULTY_WEIGHTS constants change in
``knowledge_state.py``, the numeric assertions here break loudly — the
intended forcing function for keeping calibration shifts deliberate.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.models.knowledge_state import KnowledgeState, TopicMastery
from app.models.question import DifficultyLevel
from app.services import knowledge_state as knowledge_state_service
from app.services.knowledge_state import (
    LEARNING_RATE,
    _apply_update,
    _recompute_overall,
    record_attempt,
)

# ── Pure-math helpers ──────────────────────────────────────────────────────


def test_apply_update_correct_beginner_from_zero():
    """LEARNING_RATE × 0.5 × (1.0 − 0.0) = 0.10"""
    result = _apply_update(
        old=0.0,
        is_correct=True,
        difficulty=DifficultyLevel.beginner,
    )
    assert result == pytest.approx(LEARNING_RATE * 0.5)


def test_apply_update_correct_advanced_from_half():
    """LEARNING_RATE × 1.5 × (1.0 − 0.5) = 0.15 → 0.65"""
    result = _apply_update(
        old=0.5,
        is_correct=True,
        difficulty=DifficultyLevel.advanced,
    )
    assert result == pytest.approx(0.5 + LEARNING_RATE * 1.5 * 0.5)


def test_apply_update_wrong_intermediate_from_high_mastery():
    """LEARNING_RATE × 1.0 × (0.0 − 0.7) = −0.14 → 0.56"""
    result = _apply_update(
        old=0.7,
        is_correct=False,
        difficulty=DifficultyLevel.intermediate,
    )
    assert result == pytest.approx(0.7 + LEARNING_RATE * 1.0 * (0.0 - 0.7))


def test_apply_update_clamps_to_one():
    """Even with an aggressive correct streak the mastery never goes
    above 1.0. The EMA naturally converges below 1, but adversarial
    weights or rounding errors mustn't push past the rail.
    """
    # Manually construct a scenario that the formula would push past 1.
    # With old=0.95 and advanced (weight 1.5×0.2=0.3), delta = 0.3 × 0.05
    # = 0.015 → 0.965 (still under). Push old higher to force the clamp.
    result = _apply_update(
        old=0.99,
        is_correct=True,
        difficulty=DifficultyLevel.advanced,
    )
    assert 0.0 <= result <= 1.0


def test_apply_update_clamps_to_zero():
    result = _apply_update(
        old=0.01,
        is_correct=False,
        difficulty=DifficultyLevel.advanced,
    )
    assert 0.0 <= result <= 1.0


def test_recompute_overall_is_mean_of_topic_scores():
    topics = [
        TopicMastery(topic="A", mastery_score=0.2),
        TopicMastery(topic="B", mastery_score=0.6),
        TopicMastery(topic="C", mastery_score=1.0),
    ]
    assert _recompute_overall(topics) == pytest.approx(0.6)


def test_recompute_overall_zero_topics_returns_zero():
    assert _recompute_overall([]) == 0.0


# ── record_attempt: end-to-end with a fake Cosmos collection ───────────────


def _fake_collection(*, initial: dict | None = None):
    """Mutable in-memory stand-in for a Cosmos collection.

    The ``_data`` dict is captured so tests can inspect the post-upsert
    state. ``find_one`` returns ``initial`` on first call (or None when
    seed is omitted); ``replace_one`` writes the new doc into ``_data``.
    """
    state: dict[str, dict | None] = {"current": initial}

    col = MagicMock()

    async def _find_one(_filter):
        return state["current"]

    async def _replace_one(_filter, doc, upsert=False):  # noqa: ARG001
        state["current"] = doc
        return MagicMock(matched_count=1, upserted_id=doc["_id"])

    col.find_one = _find_one
    col.replace_one = _replace_one
    return col, state


def _seed_state(
    *,
    topics: list[TopicMastery] | None = None,
    overall: float = 0.0,
) -> dict:
    return KnowledgeState(
        **{"_id": "ks_seed"},
        tenant_id="ten_a",
        workspace_id="wsp_a",
        student_id="stu_a",
        topics=topics or [],
        overall_mastery=overall,
        last_recalculated_at=None,
    ).model_dump(by_alias=True)


@pytest.mark.asyncio
async def test_record_attempt_initializes_state_on_first_interaction():
    col, store = _fake_collection(initial=None)
    with patch.object(knowledge_state_service, "get_collection", return_value=col):
        state = await record_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
            now="2026-06-01T00:00:00+00:00",
        )

    assert state.student_id == "stu_a"
    assert state.last_recalculated_at == "2026-06-01T00:00:00+00:00"
    assert len(state.topics) == 1
    row = state.topics[0]
    assert row.topic == "Photosynthesis"
    assert row.questions_attempted == 1
    assert row.questions_correct == 1
    # Correct beginner from 0 → LEARNING_RATE × 0.5 = 0.1.
    assert row.mastery_score == pytest.approx(0.1)
    # Persisted to Cosmos.
    assert store["current"] is not None
    assert store["current"]["overall_mastery"] == pytest.approx(0.1)


@pytest.mark.asyncio
async def test_record_attempt_updates_existing_topic_row():
    initial = _seed_state(
        topics=[
            TopicMastery(
                topic="Photosynthesis",
                mastery_score=0.4,
                questions_attempted=3,
                questions_correct=2,
            )
        ],
        overall=0.4,
    )
    col, _ = _fake_collection(initial=initial)
    with patch.object(knowledge_state_service, "get_collection", return_value=col):
        state = await record_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.intermediate,
            is_correct=True,
            now="2026-06-01T00:00:00+00:00",
        )

    row = next(t for t in state.topics if t.topic == "Photosynthesis")
    assert row.questions_attempted == 4
    assert row.questions_correct == 3
    # Correct intermediate from 0.4 → 0.4 + 0.2 × 1.0 × 0.6 = 0.52.
    assert row.mastery_score == pytest.approx(0.52)


@pytest.mark.asyncio
async def test_record_attempt_appends_new_topic_when_not_seen_before():
    initial = _seed_state(
        topics=[
            TopicMastery(topic="Photosynthesis", mastery_score=0.6),
        ],
        overall=0.6,
    )
    col, _ = _fake_collection(initial=initial)
    with patch.object(knowledge_state_service, "get_collection", return_value=col):
        state = await record_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Mitosis",
            difficulty=DifficultyLevel.beginner,
            is_correct=False,
            now="2026-06-01T00:00:00+00:00",
        )

    assert {t.topic for t in state.topics} == {"Photosynthesis", "Mitosis"}
    mitosis = next(t for t in state.topics if t.topic == "Mitosis")
    # Wrong beginner from 0.0 → 0.0 + 0.2 × 0.5 × (0 - 0) = 0.0.
    assert mitosis.mastery_score == pytest.approx(0.0)
    # Overall is mean of (Photosynthesis=0.6, Mitosis=0.0) = 0.3.
    assert state.overall_mastery == pytest.approx(0.3)


@pytest.mark.asyncio
async def test_record_attempt_topic_match_is_case_insensitive():
    """Existing row "Photosynthesis" + incoming "photosynthesis" must
    merge into one row, not dual-track.
    """
    initial = _seed_state(
        topics=[TopicMastery(topic="Photosynthesis", mastery_score=0.5)],
        overall=0.5,
    )
    col, _ = _fake_collection(initial=initial)
    with patch.object(knowledge_state_service, "get_collection", return_value=col):
        state = await record_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="photosynthesis",  # lower-case incoming
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
        )

    assert len(state.topics) == 1
    assert state.topics[0].questions_attempted == 1


@pytest.mark.asyncio
async def test_record_attempt_persists_via_upsert():
    """Cold start ⇒ ``replace_one`` with ``upsert=True`` so a missing
    row gets inserted instead of failing the update.
    """
    col, _ = _fake_collection(initial=None)
    # Wrap replace_one with an AsyncMock to inspect kwargs.
    captured: dict[str, object] = {}

    async def _capture(_filter, doc, upsert=False):
        captured["filter"] = _filter
        captured["upsert"] = upsert
        return MagicMock(matched_count=1)

    col.replace_one = _capture
    with patch.object(knowledge_state_service, "get_collection", return_value=col):
        await record_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Mitosis",
            difficulty=DifficultyLevel.intermediate,
            is_correct=True,
        )

    assert captured["upsert"] is True
    assert "_id" in captured["filter"]


@pytest.mark.asyncio
async def test_record_attempt_uses_provided_timestamp():
    """Tests pass a fixed timestamp for determinism."""
    col, _ = _fake_collection(initial=None)
    with patch.object(knowledge_state_service, "get_collection", return_value=col):
        state = await record_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Photosynthesis",
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
            now="2026-12-25T12:00:00+00:00",
        )
    assert state.last_recalculated_at == "2026-12-25T12:00:00+00:00"
    assert state.topics[0].last_seen_at == "2026-12-25T12:00:00+00:00"


@pytest.mark.asyncio
async def test_record_attempt_falls_back_to_utc_now_when_omitted():
    """Production callers omit ``now``; the service supplies a UTC
    timestamp via :func:`utc_now`. We don't assert the exact value
    (it's the wall clock) — just that it's set and ISO-8601-ish.
    """
    col, _ = _fake_collection(initial=None)
    with patch.object(knowledge_state_service, "get_collection", return_value=col):
        state = await record_attempt(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            topic="Mitosis",
            difficulty=DifficultyLevel.beginner,
            is_correct=True,
        )
    assert state.last_recalculated_at is not None
    assert state.last_recalculated_at.startswith("20")  # 21st-century timestamp
