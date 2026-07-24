"""Unit tests for the analytics aggregation service (Sprint 5.9, 5.13).

Pins the wire shape (the Flutter ``StudentProgress`` model is the
source of truth and this service must match it), the aggregation
math (averages, correct rates, topic distribution), the empty-state
behaviour, and the activity merge.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.gamification import GamificationState
from app.models.knowledge_state import KnowledgeState, TopicMastery
from app.models.workspace import Workspace, WorkspaceSettings
from app.services import analytics as analytics_service
from app.services.analytics import (
    ENGAGEMENT_HEATMAP_DAYS,
    RECENT_ACTIVITY_LIMIT,
    build_student_progress,
    build_tenant_analytics,
    build_workspace_analytics,
)
from app.services.gamification import FLASHCARD_XP


def test_learning_trend_replays_real_events_and_carries_forward():
    points = analytics_service._aggregate_learning_trend(
        interactions=[
            {
                "student_id": "stu_a",
                "topic": "Algebra",
                "is_correct": True,
                "answered_at": "2026-07-01T10:00:00+00:00",
            },
            {
                "student_id": "stu_a",
                "topic": "Algebra",
                "is_correct": False,
                "answered_at": "2026-07-03T10:00:00+00:00",
            },
        ],
        ratings=[
            {
                "student_id": "stu_a",
                "topic": "Algebra",
                "rating": "easy",
                "rated_at": "2026-07-03T11:00:00+00:00",
            }
        ],
        student_ids={"stu_a"},
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 4),
        topic=None,
    )

    assert [point["date"] for point in points] == [
        "2026-07-01",
        "2026-07-02",
        "2026-07-03",
        "2026-07-04",
    ]
    assert points[0]["overall_mastery"] == pytest.approx(0.2)
    assert points[1]["overall_mastery"] == pytest.approx(0.2)
    assert points[2]["overall_mastery"] == pytest.approx(0.16)
    assert points[2]["quiz_accuracy"] == pytest.approx(0.5)
    assert points[2]["flashcard_recall"] == pytest.approx(1.0)
    assert points[3]["activity_count"] == 0


def test_learning_trend_filters_student_and_topic():
    points = analytics_service._aggregate_learning_trend(
        interactions=[
            {
                "student_id": "stu_a",
                "topic": "Algebra",
                "is_correct": True,
                "answered_at": "2026-07-01T10:00:00+00:00",
            },
            {
                "student_id": "stu_b",
                "topic": "Algebra",
                "is_correct": False,
                "answered_at": "2026-07-01T10:00:00+00:00",
            },
            {
                "student_id": "stu_a",
                "topic": "Geometry",
                "is_correct": False,
                "answered_at": "2026-07-01T10:00:00+00:00",
            },
        ],
        ratings=[],
        student_ids={"stu_a"},
        start_date=date(2026, 7, 1),
        end_date=date(2026, 7, 1),
        topic="Algebra",
    )

    assert points[0]["activity_count"] == 1
    assert points[0]["overall_mastery"] == pytest.approx(0.2)
    assert points[0]["quiz_accuracy"] == pytest.approx(1.0)


# ── Helpers ─────────────────────────────────────────────────────────────────


def _gamification(
    *,
    xp_total: int = 250,
    level: int = 2,
    student_id: str = "stu_a",
    workspace_id: str = "wsp_a",
) -> GamificationState:
    return GamificationState(
        **{"_id": f"gam_{student_id}"},
        tenant_id="ten_a",
        workspace_id=workspace_id,
        student_id=student_id,
        xp_total=xp_total,
        level=level,
    )


def _knowledge(
    *,
    student_id: str = "stu_a",
    workspace_id: str = "wsp_a",
    topics: list[TopicMastery] | None = None,
    overall: float = 0.5,
) -> KnowledgeState:
    return KnowledgeState(
        **{"_id": f"ks_{student_id}"},
        tenant_id="ten_a",
        workspace_id=workspace_id,
        student_id=student_id,
        topics=topics
        or [
            TopicMastery(
                topic="Photosynthesis",
                mastery_score=0.6,
                questions_attempted=10,
                questions_correct=7,
            )
        ],
        overall_mastery=overall,
    )


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


# ── build_student_progress ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_student_progress_full_snapshot():
    """Joins gamification + knowledge_state + interactions/flashcards
    into the Flutter-contract wire shape.
    """
    gam = _gamification(xp_total=250, level=2)
    knowledge = _knowledge(
        topics=[
            TopicMastery(
                topic="Photosynthesis",
                mastery_score=0.6,
                questions_attempted=10,
                questions_correct=7,
            ),
            TopicMastery(
                topic="Mitosis",
                mastery_score=0.3,
                questions_attempted=5,
                questions_correct=2,
            ),
        ],
        overall=0.45,
    )

    interactions_col = MagicMock()
    interactions_col.find = MagicMock(
        return_value=_async_iter(
            [
                {
                    "topic": "Photosynthesis",
                    "is_correct": True,
                    "xp_earned": 15,
                    "answered_at": "2026-05-23T10:00:00+00:00",
                },
                {
                    "topic": "Mitosis",
                    "is_correct": False,
                    "xp_earned": 10,
                    "answered_at": "2026-05-22T10:00:00+00:00",
                },
            ]
        )
    )
    ratings_col = MagicMock()
    ratings_col.find = MagicMock(
        return_value=_async_iter(
            [
                {
                    "topic": "Photosynthesis",
                    "rated_at": "2026-05-23T11:00:00+00:00",
                }
            ]
        )
    )
    knowledge_col = MagicMock()
    knowledge_col.find_one = AsyncMock(
        return_value=knowledge.model_dump(by_alias=True)
    )

    def _factory(_tid, collection):
        from app.core.database import (
            FLASHCARD_RATINGS,
            INTERACTIONS,
            KNOWLEDGE_STATES,
        )

        if collection == INTERACTIONS:
            return interactions_col
        if collection == FLASHCARD_RATINGS:
            return ratings_col
        if collection == KNOWLEDGE_STATES:
            return knowledge_col
        raise AssertionError(collection)

    with (
        patch("app.services.analytics.get_collection", side_effect=_factory),
        patch(
            "app.services.analytics.get_gamification_state",
            AsyncMock(return_value=gam),
        ),
    ):
        result = await build_student_progress(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    assert result["level"] == 2
    assert result["total_xp"] == 250
    assert result["overall_mastery"] == 0.45
    # Topics ordered as on the knowledge_state.
    assert [t["topic_name"] for t in result["topics"]] == [
        "Photosynthesis",
        "Mitosis",
    ]
    # Success rate computed from attempts/correct.
    assert result["topics"][0]["success_rate"] == pytest.approx(0.7)
    # Recent activity merged + sorted descending.
    recent = result["recent_activity"]
    assert len(recent) == 3
    assert recent[0]["occurred_at"] == "2026-05-23T11:00:00+00:00"
    assert recent[0]["kind"] == "flashcard"
    # Flashcard XP attributed at the fixed constant.
    assert recent[0]["xp_earned"] == FLASHCARD_XP


@pytest.mark.asyncio
async def test_student_progress_zero_state_when_knowledge_missing():
    """A brand-new student has no knowledge_state — service returns a
    zero-mastery, empty-topics snapshot rather than 500'ing.
    """
    gam = _gamification(xp_total=0, level=1)
    knowledge_col = MagicMock()
    knowledge_col.find_one = AsyncMock(return_value=None)

    interactions_col = MagicMock()
    interactions_col.find = MagicMock(return_value=_async_iter([]))
    ratings_col = MagicMock()
    ratings_col.find = MagicMock(return_value=_async_iter([]))

    def _factory(_tid, collection):
        from app.core.database import (
            FLASHCARD_RATINGS,
            INTERACTIONS,
            KNOWLEDGE_STATES,
        )

        if collection == KNOWLEDGE_STATES:
            return knowledge_col
        if collection == INTERACTIONS:
            return interactions_col
        if collection == FLASHCARD_RATINGS:
            return ratings_col
        raise AssertionError(collection)

    with (
        patch("app.services.analytics.get_collection", side_effect=_factory),
        patch(
            "app.services.analytics.get_gamification_state",
            AsyncMock(return_value=gam),
        ),
    ):
        result = await build_student_progress(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    assert result["overall_mastery"] == 0.0
    assert result["topics"] == []
    assert result["recent_activity"] == []
    # Level + XP still come from gamification even with no mastery.
    assert result["level"] == 1
    assert result["total_xp"] == 0


@pytest.mark.asyncio
async def test_student_progress_caps_recent_activity():
    """More than ``RECENT_ACTIVITY_LIMIT`` events ⇒ only the most
    recent N survive after merge."""
    gam = _gamification()
    knowledge_col = MagicMock()
    knowledge_col.find_one = AsyncMock(return_value=None)

    interactions_col = MagicMock()
    interactions_col.find = MagicMock(
        return_value=_async_iter(
            [
                {
                    "topic": "T",
                    "is_correct": True,
                    "xp_earned": 10,
                    "answered_at": f"2026-05-{i:02d}T10:00:00+00:00",
                }
                for i in range(1, RECENT_ACTIVITY_LIMIT + 11)
            ]
        )
    )
    ratings_col = MagicMock()
    ratings_col.find = MagicMock(return_value=_async_iter([]))

    def _factory(_tid, collection):
        from app.core.database import (
            FLASHCARD_RATINGS,
            INTERACTIONS,
            KNOWLEDGE_STATES,
        )

        if collection == KNOWLEDGE_STATES:
            return knowledge_col
        if collection == INTERACTIONS:
            return interactions_col
        if collection == FLASHCARD_RATINGS:
            return ratings_col
        raise AssertionError(collection)

    with (
        patch("app.services.analytics.get_collection", side_effect=_factory),
        patch(
            "app.services.analytics.get_gamification_state",
            AsyncMock(return_value=gam),
        ),
    ):
        result = await build_student_progress(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    assert len(result["recent_activity"]) == RECENT_ACTIVITY_LIMIT


# ── build_workspace_analytics ───────────────────────────────────────────────


@pytest.mark.asyncio
async def test_workspace_analytics_aggregates_across_students():
    """Workspace analytics: avg mastery, attempts per student, topic
    distribution all come from the underlying collection reads.
    """
    states = [
        _knowledge(
            student_id="stu_a",
            topics=[
                TopicMastery(
                    topic="Photosynthesis",
                    mastery_score=0.6,
                    questions_attempted=10,
                    questions_correct=7,
                )
            ],
            overall=0.6,
        ),
        _knowledge(
            student_id="stu_b",
            topics=[
                TopicMastery(
                    topic="Mitosis",
                    mastery_score=0.4,
                    questions_attempted=4,
                    questions_correct=2,
                )
            ],
            overall=0.4,
        ),
    ]
    interactions = [
        {
            "topic": "Photosynthesis",
            "is_correct": True,
            "student_id": "stu_a",
            "answered_at": _recent_iso(0),
        },
        {
            "topic": "Photosynthesis",
            "is_correct": False,
            "student_id": "stu_a",
            "answered_at": _recent_iso(1),
        },
        {
            "topic": "Mitosis",
            "is_correct": True,
            "student_id": "stu_b",
            "answered_at": _recent_iso(2),
        },
    ]
    ratings: list[dict] = []

    knowledge_col = _list_returning_col(states)
    interactions_col = _list_returning_col(interactions)
    ratings_col = _list_returning_col(ratings)

    def _factory(_tid, collection):
        from app.core.database import (
            FLASHCARD_RATINGS,
            INTERACTIONS,
            KNOWLEDGE_STATES,
        )

        if collection == KNOWLEDGE_STATES:
            return knowledge_col
        if collection == INTERACTIONS:
            return interactions_col
        if collection == FLASHCARD_RATINGS:
            return ratings_col
        raise AssertionError(collection)

    with patch("app.services.analytics.get_collection", side_effect=_factory):
        result = await build_workspace_analytics(
            tenant_id="ten_a", workspace_id="wsp_a"
        )

    assert result["total_students"] == 2
    # Mean of 0.6 and 0.4.
    assert result["avg_overall_mastery"] == pytest.approx(0.5)
    # 3 interactions across 2 students.
    assert result["avg_questions_per_student"] == pytest.approx(1.5)
    # 2 correct of 3.
    assert result["avg_correct_rate"] == pytest.approx(2 / 3)
    # Topic distribution alphabetical.
    topics = result["topic_distribution"]
    assert [t["topic"] for t in topics] == ["Mitosis", "Photosynthesis"]
    photo = next(t for t in topics if t["topic"] == "Photosynthesis")
    assert photo["attempts"] == 2
    assert photo["correct_rate"] == pytest.approx(0.5)
    # Both students had recent events → both count as active.
    assert result["active_students_7d"] == 2


@pytest.mark.asyncio
async def test_workspace_analytics_engagement_heatmap_has_full_window():
    """The heatmap returns a contiguous window even when most days are
    empty — UI can plot without a sparse-axis fallback.
    """
    states: list = []
    interactions = [
        {
            "topic": "T",
            "is_correct": True,
            "student_id": "stu_a",
            "answered_at": _recent_iso(2),
        }
    ]
    ratings: list[dict] = []

    knowledge_col = _list_returning_col(states)
    interactions_col = _list_returning_col(interactions)
    ratings_col = _list_returning_col(ratings)

    def _factory(_tid, collection):
        from app.core.database import (
            FLASHCARD_RATINGS,
            INTERACTIONS,
            KNOWLEDGE_STATES,
        )

        if collection == KNOWLEDGE_STATES:
            return knowledge_col
        if collection == INTERACTIONS:
            return interactions_col
        if collection == FLASHCARD_RATINGS:
            return ratings_col
        raise AssertionError(collection)

    with patch("app.services.analytics.get_collection", side_effect=_factory):
        result = await build_workspace_analytics(
            tenant_id="ten_a", workspace_id="wsp_a"
        )
    heatmap = result["engagement_heatmap"]
    assert len(heatmap) == ENGAGEMENT_HEATMAP_DAYS
    # Sum of events should match what we fed in.
    assert sum(cell["events"] for cell in heatmap) == 1
    # Oldest → newest order so the UI plots left-to-right.
    dates = [cell["date"] for cell in heatmap]
    assert dates == sorted(dates)


# ── build_tenant_analytics ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_tenant_analytics_rolls_up_workspace_summaries():
    """Tenant analytics returns one summary row per workspace + tenant
    totals."""
    workspaces = [
        Workspace(
            **{"_id": "wsp_a"},
            tenant_id="ten_a",
            name="Class A",
            description="",
            settings=WorkspaceSettings(),
            created_by="usr_admin",
        ),
        Workspace(
            **{"_id": "wsp_b"},
            tenant_id="ten_a",
            name="Class B",
            description="",
            settings=WorkspaceSettings(),
            created_by="usr_admin",
        ),
    ]
    # Per-workspace state lookups will alternate.
    state_a = [_knowledge(student_id="stu_a", overall=0.6)]
    state_b = [
        _knowledge(student_id="stu_b", overall=0.3),
        _knowledge(student_id="stu_c", overall=0.5),
    ]

    knowledge_responses = iter([state_a, state_b])
    interactions_responses = iter(
        [
            [
                {
                    "topic": "T",
                    "is_correct": True,
                    "student_id": "stu_a",
                    "answered_at": _recent_iso(0),
                }
            ],
            [
                {
                    "topic": "T",
                    "is_correct": False,
                    "student_id": "stu_b",
                    "answered_at": _recent_iso(0),
                }
            ],
        ]
    )
    ratings_responses = iter([[], []])
    workspaces_responses = iter([workspaces])

    def _factory(_tid, collection):
        from app.core.database import (
            FLASHCARD_RATINGS,
            INTERACTIONS,
            KNOWLEDGE_STATES,
            WORKSPACES,
        )

        if collection == WORKSPACES:
            ws = MagicMock()
            ws.find = MagicMock(
                return_value=_async_iter(
                    [w.model_dump(by_alias=True) for w in next(workspaces_responses)]
                )
            )
            return ws
        if collection == KNOWLEDGE_STATES:
            return _list_returning_col(next(knowledge_responses))
        if collection == INTERACTIONS:
            return _list_returning_col(next(interactions_responses))
        if collection == FLASHCARD_RATINGS:
            return _list_returning_col(next(ratings_responses))
        raise AssertionError(collection)

    with patch("app.services.analytics.get_collection", side_effect=_factory):
        result = await build_tenant_analytics(tenant_id="ten_a")

    assert result["total_workspaces"] == 2
    assert result["total_students"] == 3
    # Both workspaces had a recent event from one of their students.
    assert result["active_students_7d"] == 2
    rows = {w["workspace_id"]: w for w in result["workspaces"]}
    assert rows["wsp_a"]["total_students"] == 1
    assert rows["wsp_a"]["total_questions_answered"] == 1
    assert rows["wsp_b"]["total_students"] == 2


# ── Test helpers ───────────────────────────────────────────────────────────


def _list_returning_col(items):
    """Build a MagicMock collection whose ``find()`` returns an async
    iterator over ``items``. ``items`` may be Pydantic models or
    dicts; models are dumped by alias.
    """
    col = MagicMock()
    docs = [
        item.model_dump(by_alias=True) if hasattr(item, "model_dump") else item
        for item in items
    ]
    col.find = MagicMock(return_value=_async_iter(docs))
    return col


def _recent_iso(days_ago: int) -> str:
    """An ISO 8601 timestamp ``days_ago`` UTC days before now."""
    from datetime import UTC, datetime, timedelta

    return (datetime.now(UTC) - timedelta(days=days_ago)).isoformat()
