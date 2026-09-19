"""Unit tests for the retrieve_student_context MCP tool (Sprint 3.6).

The tool joins ``knowledge_states`` (precomputed mastery summary) with a
client-side-sorted tail of the student's ``interactions``. The tests
pin three things the orchestrator depends on:

1. Missing knowledge_state is normal (brand-new student) — output is
   zero mastery, never an error.
2. ``recent_interactions`` is most-recent-first (the sort is client-side
   because Cosmos rejects ``cursor.sort`` without an index).
3. ``seen_question_ids`` is a deduplicated, order-preserving projection
   of the recent interactions.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.core.database import INTERACTIONS, KNOWLEDGE_STATES
from app.mcp_tools.retrieve_student_context import (
    RetrieveStudentContextInput,
    retrieve_student_context,
)
from app.models.knowledge_state import KnowledgeState, TopicMastery

# ── Helpers ─────────────────────────────────────────────────────────────────


def _state(
    *,
    topics: list[TopicMastery] | None = None,
    overall: float = 0.4,
) -> dict:
    """Build a knowledge_state document for the fake collection."""
    return KnowledgeState(
        **{"_id": "ks_test001"},
        tenant_id="ten_a",
        workspace_id="wsp_a",
        student_id="stu_a",
        topics=topics or [],
        overall_mastery=overall,
        last_recalculated_at="2026-05-01T00:00:00+00:00",
    ).model_dump(by_alias=True)


def _interaction(
    *,
    question_id: str,
    topic: str,
    answered_at: str,
    is_correct: bool = True,
) -> dict:
    return {
        "_id": f"ix_{question_id}",
        "tenant_id": "ten_a",
        "workspace_id": "wsp_a",
        "student_id": "stu_a",
        "question_id": question_id,
        "topic": topic,
        "is_correct": is_correct,
        "answer_given": "redacted",
        "time_spent_seconds": 10,
        "xp_earned": 5,
        "answered_at": answered_at,
        "created_at": answered_at,
        "updated_at": answered_at,
        "deleted_at": None,
    }


def _route(states: dict | None, interactions: list[dict]):
    """Return a get_collection mock that routes to per-collection fakes.

    Each collection has minimal motor-like API: ``find_one`` for the
    state read, ``find().to_list()`` for the interactions read.
    """
    ks_col = MagicMock()

    async def _find_one(_filter):
        if states is None:
            return None
        return states

    ks_col.find_one = _find_one

    class _Cursor:
        def __init__(self, items: list[dict]):
            self._items = items

        async def to_list(self, length=None):
            return list(self._items)

    ix_col = MagicMock()
    ix_col.find = MagicMock(return_value=_Cursor(interactions))

    def _factory(_tenant_id, collection):
        if collection == KNOWLEDGE_STATES:
            return ks_col
        if collection == INTERACTIONS:
            return ix_col
        raise AssertionError(f"unexpected collection: {collection}")

    return _factory


# ── Tests ───────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_happy_path_projects_state_and_recent_interactions():
    state = _state(
        topics=[
            TopicMastery(
                topic="Photosynthesis",
                mastery_score=0.6,
                questions_attempted=4,
                questions_correct=3,
                last_seen_at="2026-05-01T00:00:00+00:00",
            ),
            TopicMastery(
                topic="Mitosis",
                mastery_score=0.3,
                questions_attempted=2,
                questions_correct=0,
                last_seen_at="2026-04-30T00:00:00+00:00",
            ),
        ],
        overall=0.45,
    )
    # Out of order — verify the client-side sort puts the most recent first.
    interactions = [
        _interaction(
            question_id="qst_1",
            topic="Photosynthesis",
            answered_at="2026-05-01T10:00:00+00:00",
        ),
        _interaction(
            question_id="qst_3",
            topic="Mitosis",
            answered_at="2026-05-03T10:00:00+00:00",
            is_correct=False,
        ),
        _interaction(
            question_id="qst_2",
            topic="Photosynthesis",
            answered_at="2026-05-02T10:00:00+00:00",
        ),
    ]

    factory = _route(state, interactions)
    with patch(
        "app.mcp_tools.retrieve_student_context.get_collection",
        side_effect=factory,
    ):
        result = await retrieve_student_context(
            RetrieveStudentContextInput(
                tenant_id="ten_a",
                workspace_id="wsp_a",
                student_id="stu_a",
                recent_interaction_limit=10,
            )
        )

    assert result.student_id == "stu_a"
    assert result.overall_mastery == 0.45
    assert result.last_recalculated_at == "2026-05-01T00:00:00+00:00"

    # Topic projection — accuracy is derived, not stored.
    by_topic = {t.topic: t for t in result.topic_mastery}
    assert by_topic["Photosynthesis"].accuracy == pytest.approx(0.75)
    assert by_topic["Mitosis"].accuracy == pytest.approx(0.0)

    # Most-recent-first ordering.
    assert [i.question_id for i in result.recent_interactions] == [
        "qst_3",
        "qst_2",
        "qst_1",
    ]
    # Order-preserving dedup of question ids.
    assert result.seen_question_ids == ["qst_3", "qst_2", "qst_1"]


@pytest.mark.asyncio
async def test_missing_knowledge_state_returns_zero_mastery_not_error():
    """Brand-new students have no precomputed state until 3.11 writes
    the first one. Treat as zero mastery; never raise.
    """
    interactions = [
        _interaction(
            question_id="qst_new",
            topic="Algebra",
            answered_at="2026-05-04T10:00:00+00:00",
        )
    ]
    factory = _route(None, interactions)
    with patch(
        "app.mcp_tools.retrieve_student_context.get_collection",
        side_effect=factory,
    ):
        result = await retrieve_student_context(
            RetrieveStudentContextInput(
                tenant_id="ten_a",
                workspace_id="wsp_a",
                student_id="stu_new",
                recent_interaction_limit=5,
            )
        )

    assert result.overall_mastery == 0.0
    assert result.topic_mastery == []
    assert result.last_recalculated_at is None
    # Recent interactions still surface even without precomputed state.
    assert [i.question_id for i in result.recent_interactions] == ["qst_new"]
    assert result.seen_question_ids == ["qst_new"]


@pytest.mark.asyncio
async def test_no_interactions_yet_returns_empty_lists():
    state = _state(topics=[])
    factory = _route(state, [])
    with patch(
        "app.mcp_tools.retrieve_student_context.get_collection",
        side_effect=factory,
    ):
        result = await retrieve_student_context(
            RetrieveStudentContextInput(
                tenant_id="ten_a",
                workspace_id="wsp_a",
                student_id="stu_a",
            )
        )

    assert result.recent_interactions == []
    assert result.seen_question_ids == []


@pytest.mark.asyncio
async def test_recent_interaction_limit_caps_the_tail():
    """Sort happens BEFORE the cap, so we always get the most recent N
    even if the over-read returns older rows first.
    """
    # 5 interactions, oldest-first in the fake. limit=2 should yield the
    # two MOST RECENT ones.
    interactions = [
        _interaction(
            question_id=f"qst_{i}",
            topic="Topic",
            answered_at=f"2026-05-0{i + 1}T00:00:00+00:00",
        )
        for i in range(5)
    ]
    factory = _route(_state(), interactions)
    with patch(
        "app.mcp_tools.retrieve_student_context.get_collection",
        side_effect=factory,
    ):
        result = await retrieve_student_context(
            RetrieveStudentContextInput(
                tenant_id="ten_a",
                workspace_id="wsp_a",
                student_id="stu_a",
                recent_interaction_limit=2,
            )
        )

    assert [i.question_id for i in result.recent_interactions] == ["qst_4", "qst_3"]


@pytest.mark.asyncio
async def test_duplicate_question_ids_deduped_in_seen_list_but_kept_in_interactions():
    """A student answering the same question twice produces two
    interactions but one entry in ``seen_question_ids`` — that's the
    prompt-side contract Sprint 3.7 will rely on for repeat suppression.
    """
    interactions = [
        _interaction(
            question_id="qst_repeat",
            topic="Photosynthesis",
            answered_at="2026-05-02T00:00:00+00:00",
        ),
        _interaction(
            question_id="qst_repeat",
            topic="Photosynthesis",
            answered_at="2026-05-01T00:00:00+00:00",
            is_correct=False,
        ),
        _interaction(
            question_id="qst_other",
            topic="Mitosis",
            answered_at="2026-05-03T00:00:00+00:00",
        ),
    ]
    factory = _route(_state(), interactions)
    with patch(
        "app.mcp_tools.retrieve_student_context.get_collection",
        side_effect=factory,
    ):
        result = await retrieve_student_context(
            RetrieveStudentContextInput(
                tenant_id="ten_a",
                workspace_id="wsp_a",
                student_id="stu_a",
            )
        )

    assert len(result.recent_interactions) == 3
    assert result.seen_question_ids == ["qst_other", "qst_repeat"]
