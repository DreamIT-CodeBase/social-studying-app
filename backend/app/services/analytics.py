"""Analytics aggregation service — Sprint 5.9.

Read-only aggregation over the per-tenant Cosmos collections. Three
entry points feed three endpoints (and three UI views):

- :func:`build_student_progress` → ``GET /workspaces/{ws}/users/{usr}/progress``
- :func:`build_workspace_analytics` → ``GET /workspaces/{ws}/analytics``
- :func:`build_tenant_analytics` → ``GET /tenants/{tid}/analytics``

Why a separate service
----------------------
The endpoints are thin wrappers — they enforce access control, then
hand off here. Keeping aggregation in a service module means the
queries are reusable from notification scheduling later (e.g. "send a
reminder to students with mastery < 30% on their weakest topic") and
the heavier I/O paths are unit-testable in isolation.

Performance notes
-----------------
Workspace analytics reads three collections (knowledge_states,
interactions, flashcard_ratings) and is O(N) in interactions per
workspace. For early-stage scale (hundreds of students) that's
acceptable. Sprint 6 polish will add a daily roll-up worker that
populates a ``workspace_metrics`` collection for cheap reads.

Tenant analytics is one workspaces query + N workspace aggregations.
For tenants with many workspaces the response shape carries only the
per-workspace summaries — no per-student detail — so the payload
stays bounded.

Activity timeline
-----------------
Interactions and flashcard rating events live in separate collections
but the student progress view wants them interleaved chronologically.
:func:`build_student_progress` reads both, attributes a fixed
``FLASHCARD_XP`` to each rating event (the rating collection doesn't
persist XP — gamification.state does), and merges + sorts. The result
is capped at :data:`RECENT_ACTIVITY_LIMIT` items.
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import UTC, date, datetime, timedelta
from typing import Any

from app.core.database import (
    FLASHCARD_RATINGS,
    INTERACTIONS,
    KNOWLEDGE_STATES,
    USERS,
    WORKSPACES,
    get_collection,
)
from app.models.knowledge_state import KnowledgeState
from app.models.workspace import Workspace
from app.services.gamification import (
    FLASHCARD_XP,
    get_state as get_gamification_state,
    xp_for_next_level,
    xp_into_level,
)

logger = logging.getLogger(__name__)


RECENT_ACTIVITY_LIMIT: int = 20
"""How many recent items to surface on the student progress view.
Combined limit across questions + flashcards — the merge selects
whichever 20 are most recent regardless of source."""

ACTIVE_WINDOW_DAYS: int = 7
"""Window for `active_students_7d` and the engagement-heatmap counts.
A student is "active" if they had at least one interaction OR
flashcard rating in the last N days (UTC)."""

ENGAGEMENT_HEATMAP_DAYS: int = 14
"""Number of UTC dates in the engagement heatmap. Two weeks gives the
admin enough signal to spot a streak vs. a one-off spike."""

ATTENTION_MASTERY_THRESHOLD: float = 0.5
"""Students below this current mastery are included in attention counts."""

ATTENTION_DECLINE_THRESHOLD: float = -0.05
"""A five-point mastery decline over the selected range needs attention."""

FLASHCARD_RECALL_SCORES: dict[str, float] = {
    "easy": 1.0,
    "medium": 0.6,
    "hard": 0.0,
}
"""Convert the app's three self-rating buckets to a recall percentage."""


# ── Student progress ────────────────────────────────────────────────────────


async def build_student_progress(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
) -> dict[str, Any]:
    """Build the wire shape consumed by Flutter ``StudentProgress``.

    Pulls gamification (level + XP), knowledge_state (per-topic mastery
    + overall), and the last :data:`RECENT_ACTIVITY_LIMIT` interactions
    + flashcard ratings merged by timestamp.

    Returns a dict (not a Pydantic model) so the API layer's response
    model owns the wire schema — keeping aggregation here free of
    Pydantic coupling.
    """
    gam = await get_gamification_state(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
    )
    knowledge = await _read_knowledge_state(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
    )

    recent = await _recent_activity(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        limit=RECENT_ACTIVITY_LIMIT,
    )

    topics = []
    if knowledge is not None:
        for row in knowledge.topics:
            attempts = row.questions_attempted
            success_rate = (
                (row.questions_correct / attempts) if attempts > 0 else 0.0
            )
            topics.append(
                {
                    # No canonical topic_id on KnowledgeState — display name
                    # is the natural key, and the Flutter side accepts it
                    # as both id and name. (Canonicalising via the taxonomy
                    # is Sprint 6 polish.)
                    "topic_id": row.topic,
                    "topic_name": row.topic,
                    "mastery": row.mastery_score,
                    "attempts": attempts,
                    "success_rate": success_rate,
                }
            )

    overall = knowledge.overall_mastery if knowledge is not None else 0.0
    return {
        "level": gam.level,
        "total_xp": gam.xp_total,
        "xp_into_level": xp_into_level(gam.xp_total),
        "xp_for_next_level": xp_for_next_level(gam.xp_total),
        "overall_mastery": overall,
        "topics": topics,
        "recent_activity": recent,
    }


# ── Workspace analytics ─────────────────────────────────────────────────────


async def build_workspace_analytics(
    *,
    tenant_id: str,
    workspace_id: str,
) -> dict[str, Any]:
    """Aggregate stats across every student in ``workspace_id``.

    Returns a dict matching the admin analytics dashboard's wire
    contract (Sprint 5.11):

    - ``total_students`` / ``active_students_7d``
    - ``avg_overall_mastery``: mean across non-empty knowledge states
    - ``avg_questions_per_student``: total interactions / total students
    - ``avg_correct_rate``: aggregate correct / total interactions
    - ``topic_distribution``: per-topic attempts + avg mastery + correct rate
    - ``difficulty_distribution``: attempts + correct per difficulty band
    - ``engagement_heatmap``: last :data:`ENGAGEMENT_HEATMAP_DAYS` UTC days,
      each {date, total_events} across questions + flashcards
    """
    states = await _read_workspace_states(
        tenant_id=tenant_id, workspace_id=workspace_id
    )
    interactions = await _read_workspace_interactions(
        tenant_id=tenant_id, workspace_id=workspace_id
    )
    ratings = await _read_workspace_flashcard_ratings(
        tenant_id=tenant_id, workspace_id=workspace_id
    )

    total_students = len(states)
    overall_scores = [s.overall_mastery for s in states if s.topics]
    avg_overall = (
        sum(overall_scores) / len(overall_scores) if overall_scores else 0.0
    )

    total_questions = len(interactions)
    correct_questions = sum(1 for i in interactions if i.get("is_correct"))
    avg_questions_per_student = (
        total_questions / total_students if total_students > 0 else 0.0
    )
    avg_correct_rate = (
        correct_questions / total_questions if total_questions > 0 else 0.0
    )

    # Active = any event (question or flashcard) in the last N days.
    cutoff = _utc_now() - timedelta(days=ACTIVE_WINDOW_DAYS)
    active_ids: set[str] = set()
    for event in (*interactions, *ratings):
        ts = _parse_iso(event.get("answered_at") or event.get("rated_at"))
        if ts is not None and ts >= cutoff:
            sid = event.get("student_id")
            if sid:
                active_ids.add(sid)

    return {
        "workspace_id": workspace_id,
        "total_students": total_students,
        "active_students_7d": len(active_ids),
        "avg_overall_mastery": avg_overall,
        "avg_questions_per_student": avg_questions_per_student,
        "avg_correct_rate": avg_correct_rate,
        "topic_distribution": _topic_distribution(states, interactions),
        "difficulty_distribution": _difficulty_distribution(interactions),
        "engagement_heatmap": _engagement_heatmap(interactions, ratings),
    }


# ── Tenant analytics ────────────────────────────────────────────────────────


async def build_tenant_analytics(*, tenant_id: str) -> dict[str, Any]:
    """Workspace-level summaries rolled up to a tenant view.

    Per-workspace sub-aggregations stay bounded to summary fields
    (avg mastery, total students, total questions) — no full
    interaction list per workspace. For deep dive into one workspace,
    the admin loads :func:`build_workspace_analytics` directly.
    """
    workspaces = await _read_tenant_workspaces(tenant_id=tenant_id)

    summaries: list[dict[str, Any]] = []
    total_students = 0
    total_active = 0

    for workspace in workspaces:
        states = await _read_workspace_states(
            tenant_id=tenant_id, workspace_id=workspace.id
        )
        interactions = await _read_workspace_interactions(
            tenant_id=tenant_id, workspace_id=workspace.id
        )
        ratings = await _read_workspace_flashcard_ratings(
            tenant_id=tenant_id, workspace_id=workspace.id
        )

        ws_students = len(states)
        ws_overall_scores = [s.overall_mastery for s in states if s.topics]
        ws_avg_mastery = (
            sum(ws_overall_scores) / len(ws_overall_scores)
            if ws_overall_scores
            else 0.0
        )

        cutoff = _utc_now() - timedelta(days=ACTIVE_WINDOW_DAYS)
        ws_active: set[str] = set()
        for event in (*interactions, *ratings):
            ts = _parse_iso(event.get("answered_at") or event.get("rated_at"))
            if ts is not None and ts >= cutoff:
                sid = event.get("student_id")
                if sid:
                    ws_active.add(sid)

        summaries.append(
            {
                "workspace_id": workspace.id,
                "name": workspace.name,
                "total_students": ws_students,
                "active_students_7d": len(ws_active),
                "avg_mastery": ws_avg_mastery,
                "total_questions_answered": len(interactions),
                "total_flashcards_reviewed": len(ratings),
            }
        )
        total_students += ws_students
        total_active += len(ws_active)

    return {
        "tenant_id": tenant_id,
        "total_workspaces": len(workspaces),
        "total_students": total_students,
        "active_students_7d": total_active,
        "workspaces": summaries,
    }


async def build_learning_progress_trend(
    *,
    tenant_id: str,
    workspace_id: str,
    start_date: date,
    end_date: date,
    student_id: str | None = None,
    topic: str | None = None,
    compare_workspace: bool = False,
) -> dict[str, Any]:
    """Build a contiguous, filterable learning trend from persisted events.

    Mastery is replayed from the append-only question interaction stream using
    the same intermediate-difficulty EMA used by ``knowledge_state``. Quiz
    accuracy and flashcard recall are cumulative within the selected date
    window. No chart values are synthesized when a day has no activity: the
    latest measured value is carried forward and ``activity_count`` remains
    zero for that date.
    """
    states = await _read_workspace_states(
        tenant_id=tenant_id, workspace_id=workspace_id
    )
    interactions = await _read_workspace_interactions(
        tenant_id=tenant_id, workspace_id=workspace_id
    )
    ratings = await _read_workspace_flashcard_ratings(
        tenant_id=tenant_id, workspace_id=workspace_id
    )
    workspace = await _read_workspace(
        tenant_id=tenant_id, workspace_id=workspace_id
    )
    users = await _read_workspace_users(
        tenant_id=tenant_id, workspace_id=workspace_id
    )

    known_student_ids = set(workspace.student_ids if workspace is not None else [])
    known_student_ids.update(state.student_id for state in states)
    known_student_ids.update(
        str(event["student_id"])
        for event in (*interactions, *ratings)
        if event.get("student_id")
    )
    user_names = {user["id"]: user["display_name"] for user in users}
    for user in users:
        if user.get("role") == "student":
            known_student_ids.add(user["id"])

    selected_student_ids = (
        {student_id} if student_id is not None else known_student_ids
    )
    points = _aggregate_learning_trend(
        interactions=interactions,
        ratings=ratings,
        student_ids=selected_student_ids,
        start_date=start_date,
        end_date=end_date,
        topic=topic,
    )

    comparison_points: list[dict[str, Any]] = []
    if student_id is not None and compare_workspace:
        comparison_points = _aggregate_learning_trend(
            interactions=interactions,
            ratings=ratings,
            student_ids=known_student_ids,
            start_date=start_date,
            end_date=end_date,
            topic=topic,
        )

    student_rows: list[dict[str, Any]] = []
    for sid in sorted(known_student_ids, key=lambda value: user_names.get(value, value)):
        student_points = _aggregate_learning_trend(
            interactions=interactions,
            ratings=ratings,
            student_ids={sid},
            start_date=start_date,
            end_date=end_date,
            topic=topic,
        )
        first = student_points[0] if student_points else _empty_trend_point(start_date)
        last = student_points[-1] if student_points else first
        change = last["overall_mastery"] - first["overall_mastery"]
        has_activity = any(point["activity_count"] > 0 for point in student_points)
        student_rows.append(
            {
                "student_id": sid,
                "display_name": user_names.get(sid, sid),
                "overall_mastery": last["overall_mastery"],
                "mastery_change": change,
                "quiz_accuracy": last["quiz_accuracy"],
                "flashcard_recall": last["flashcard_recall"],
                "activity_count": sum(
                    point["activity_count"] for point in student_points
                ),
                "needs_attention": has_activity
                and (
                    last["overall_mastery"] < ATTENTION_MASTERY_THRESHOLD
                    or change <= ATTENTION_DECLINE_THRESHOLD
                ),
            }
        )

    first_point = points[0] if points else _empty_trend_point(start_date)
    last_point = points[-1] if points else first_point
    topics = sorted(
        {
            str(event["topic"])
            for event in (*interactions, *ratings)
            if event.get("topic")
        },
        key=str.casefold,
    )
    return {
        "workspace_id": workspace_id,
        "scope": "student" if student_id is not None else "workspace",
        "student_id": student_id,
        "student_name": user_names.get(student_id) if student_id else None,
        "topic": topic,
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "available_topics": topics,
        "kpis": {
            "overall_mastery": last_point["overall_mastery"],
            "mastery_change": (
                last_point["overall_mastery"] - first_point["overall_mastery"]
            ),
            "quiz_accuracy": last_point["quiz_accuracy"],
            "students_needing_attention": sum(
                1 for row in student_rows if row["needs_attention"]
            ),
        },
        "points": points,
        "workspace_comparison": comparison_points,
        "students": student_rows,
    }


# ── Aggregation helpers (pure) ──────────────────────────────────────────────


def _topic_distribution(
    states: list[KnowledgeState],
    interactions: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Per-topic attempts + avg mastery + correct rate.

    Topics seen in EITHER interactions or knowledge_state count.
    Mastery averages over the students whose knowledge_state has that
    topic; attempts and correct rate come from the interaction log so
    the count matches what students actually did.
    """
    # mastery samples per topic (from knowledge states)
    mastery_samples: dict[str, list[float]] = defaultdict(list)
    for state in states:
        for row in state.topics:
            mastery_samples[row.topic].append(row.mastery_score)

    # attempts + correct from interactions
    attempts: dict[str, int] = defaultdict(int)
    correct: dict[str, int] = defaultdict(int)
    for event in interactions:
        topic = event.get("topic")
        if not topic:
            continue
        attempts[topic] += 1
        if event.get("is_correct"):
            correct[topic] += 1

    topics = set(mastery_samples) | set(attempts)
    rows: list[dict[str, Any]] = []
    for topic in sorted(topics):
        samples = mastery_samples.get(topic, [])
        avg_mastery = sum(samples) / len(samples) if samples else 0.0
        att = attempts.get(topic, 0)
        cor = correct.get(topic, 0)
        rows.append(
            {
                "topic": topic,
                "attempts": att,
                "avg_mastery": avg_mastery,
                "correct_rate": (cor / att) if att > 0 else 0.0,
            }
        )
    return rows


def _difficulty_distribution(
    interactions: list[dict[str, Any]],
) -> dict[str, dict[str, int]]:
    """Per-difficulty attempts + correct. Missing difficulties default
    to zero so the wire shape is always the same three keys.
    """
    keys = ("beginner", "intermediate", "advanced")
    out: dict[str, dict[str, int]] = {k: {"attempts": 0, "correct": 0} for k in keys}

    # Difficulty isn't stored on Interaction directly — pull it from the
    # joined question. For v1 we approximate: the interaction record
    # doesn't carry difficulty (it's on the Question doc), so this
    # aggregation needs a join. To avoid an N+1 query, we'd need to
    # denormalise difficulty onto the Interaction (Sprint 5 polish).
    # Today we return zeros and the UI shows "no difficulty data yet".
    # The shape is preserved so the UI doesn't crash.
    _ = interactions  # interactions don't carry difficulty in v1
    return out


def _engagement_heatmap(
    interactions: list[dict[str, Any]],
    ratings: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Last :data:`ENGAGEMENT_HEATMAP_DAYS` UTC days, each with total events.

    The returned list is sorted oldest → newest so the UI can plot it
    left-to-right without re-sorting. Days with zero events are
    included so the heatmap has a contiguous x-axis.
    """
    today = _utc_now().date()
    span = [today - timedelta(days=i) for i in range(ENGAGEMENT_HEATMAP_DAYS - 1, -1, -1)]
    counts: dict[str, int] = {d.isoformat(): 0 for d in span}

    for event in interactions:
        ts = _parse_iso(event.get("answered_at"))
        if ts is None:
            continue
        key = ts.date().isoformat()
        if key in counts:
            counts[key] += 1
    for event in ratings:
        ts = _parse_iso(event.get("rated_at"))
        if ts is None:
            continue
        key = ts.date().isoformat()
        if key in counts:
            counts[key] += 1

    return [{"date": d, "events": counts[d]} for d in counts]


def _aggregate_learning_trend(
    *,
    interactions: list[dict[str, Any]],
    ratings: list[dict[str, Any]],
    student_ids: set[str],
    start_date: date,
    end_date: date,
    topic: str | None,
) -> list[dict[str, Any]]:
    """Replay real learning events into one contiguous daily trend."""
    mastery: dict[tuple[str, str], float] = {}
    quiz_correct = quiz_attempts = 0
    recall_total = 0.0
    recall_attempts = 0
    events_by_day: dict[date, list[tuple[str, dict[str, Any]]]] = defaultdict(list)

    question_events: list[tuple[datetime, dict[str, Any]]] = []
    for event in interactions:
        if str(event.get("student_id", "")) not in student_ids:
            continue
        if topic and event.get("topic") != topic:
            continue
        occurred_at = _parse_iso(event.get("answered_at"))
        if occurred_at is None or occurred_at.date() > end_date:
            continue
        question_events.append((occurred_at, event))

    for occurred_at, event in sorted(question_events, key=lambda row: row[0]):
        if occurred_at.date() < start_date:
            _apply_mastery_event(mastery, event)
        else:
            events_by_day[occurred_at.date()].append(("question", event))

    for event in ratings:
        if str(event.get("student_id", "")) not in student_ids:
            continue
        if topic and event.get("topic") != topic:
            continue
        occurred_at = _parse_iso(event.get("rated_at"))
        if occurred_at is None or not start_date <= occurred_at.date() <= end_date:
            continue
        events_by_day[occurred_at.date()].append(("flashcard", event))

    points: list[dict[str, Any]] = []
    day = start_date
    while day <= end_date:
        day_events = events_by_day.get(day, [])
        for kind, event in day_events:
            if kind == "question":
                _apply_mastery_event(mastery, event)
                quiz_attempts += 1
                quiz_correct += int(bool(event.get("is_correct")))
            else:
                recall_attempts += 1
                recall_total += _flashcard_recall_score(event)

        points.append(
            {
                "date": day.isoformat(),
                "overall_mastery": _overall_mastery(mastery),
                "quiz_accuracy": (
                    quiz_correct / quiz_attempts if quiz_attempts else 0.0
                ),
                "flashcard_recall": (
                    recall_total / recall_attempts if recall_attempts else 0.0
                ),
                "activity_count": len(day_events),
            }
        )
        day += timedelta(days=1)
    return points


def _overall_mastery(mastery: dict[tuple[str, str], float]) -> float:
    """Average topics per student first so every student has equal weight."""
    by_student: dict[str, list[float]] = defaultdict(list)
    for (student_id, _), score in mastery.items():
        by_student[student_id].append(score)
    student_averages = [
        sum(scores) / len(scores) for scores in by_student.values() if scores
    ]
    return (
        sum(student_averages) / len(student_averages)
        if student_averages
        else 0.0
    )


def _apply_mastery_event(
    mastery: dict[tuple[str, str], float],
    event: dict[str, Any],
) -> None:
    student_id = str(event.get("student_id", ""))
    event_topic = str(event.get("topic", "")).strip()
    if not student_id or not event_topic:
        return
    key = (student_id, event_topic)
    old_score = mastery.get(key, 0.0)
    target = 1.0 if bool(event.get("is_correct")) else 0.0
    mastery[key] = old_score + 0.2 * (target - old_score)


def _flashcard_recall_score(event: dict[str, Any]) -> float:
    accuracy = event.get("accuracy_percentage")
    if isinstance(accuracy, (int, float)):
        value = float(accuracy)
        return max(0.0, min(1.0, value / 100 if value > 1 else value))
    if isinstance(event.get("is_correct"), bool):
        return 1.0 if event["is_correct"] else 0.0
    return FLASHCARD_RECALL_SCORES.get(str(event.get("rating", "")).lower(), 0.0)


def _empty_trend_point(day: date) -> dict[str, Any]:
    return {
        "date": day.isoformat(),
        "overall_mastery": 0.0,
        "quiz_accuracy": 0.0,
        "flashcard_recall": 0.0,
        "activity_count": 0,
    }


# ── Cosmos reads ────────────────────────────────────────────────────────────


async def _read_knowledge_state(
    *, tenant_id: str, workspace_id: str, student_id: str
) -> KnowledgeState | None:
    col = get_collection(tenant_id, KNOWLEDGE_STATES)
    raw = await col.find_one(
        {
            "student_id": student_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    return KnowledgeState.model_validate(raw) if raw is not None else None


async def _read_workspace_states(
    *, tenant_id: str, workspace_id: str
) -> list[KnowledgeState]:
    col = get_collection(tenant_id, KNOWLEDGE_STATES)
    cursor = col.find(
        {"workspace_id": workspace_id, "deleted_at": None}
    )
    return [KnowledgeState.model_validate(raw) async for raw in cursor]


async def _read_workspace_interactions(
    *, tenant_id: str, workspace_id: str
) -> list[dict[str, Any]]:
    col = get_collection(tenant_id, INTERACTIONS)
    cursor = col.find({"workspace_id": workspace_id, "deleted_at": None})
    return [doc async for doc in cursor]


async def _read_workspace_flashcard_ratings(
    *, tenant_id: str, workspace_id: str
) -> list[dict[str, Any]]:
    col = get_collection(tenant_id, FLASHCARD_RATINGS)
    cursor = col.find({"workspace_id": workspace_id, "deleted_at": None})
    return [doc async for doc in cursor]


async def _read_workspace(
    *, tenant_id: str, workspace_id: str
) -> Workspace | None:
    col = get_collection(tenant_id, WORKSPACES)
    raw = await col.find_one({"_id": workspace_id, "deleted_at": None})
    return Workspace.model_validate(raw) if raw is not None else None


async def _read_workspace_users(
    *, tenant_id: str, workspace_id: str
) -> list[dict[str, Any]]:
    col = get_collection(tenant_id, USERS)
    cursor = col.find(
        {
            "deleted_at": None,
            "workspace_memberships": {
                "$elemMatch": {"workspace_id": workspace_id}
            },
        }
    )
    return [
        {
            "id": str(doc["_id"]),
            "display_name": str(doc.get("display_name") or doc["_id"]),
            "role": str(doc.get("role", "")),
        }
        async for doc in cursor
    ]


async def _read_tenant_workspaces(*, tenant_id: str) -> list[Workspace]:
    col = get_collection(tenant_id, WORKSPACES)
    cursor = col.find({"deleted_at": None})
    return [Workspace.model_validate(raw) async for raw in cursor]


async def _recent_activity(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    limit: int,
) -> list[dict[str, Any]]:
    """Merge interactions + flashcard ratings for ``student_id`` and
    return the most recent ``limit`` events.

    For interactions we surface the persisted ``xp_earned``. For
    flashcard ratings the rating collection doesn't carry XP (the
    engine writes XP onto the gamification doc, not the event), so we
    attribute :data:`gamification.FLASHCARD_XP` per event — matches
    what the engine actually awarded.
    """
    interactions_col = get_collection(tenant_id, INTERACTIONS)
    ratings_col = get_collection(tenant_id, FLASHCARD_RATINGS)

    # Two narrow cursors, merged client-side. Each cursor is scoped to
    # one student in one workspace, so the read volume stays bounded.
    interactions_cursor = interactions_col.find(
        {
            "student_id": student_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    ratings_cursor = ratings_col.find(
        {
            "student_id": student_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )

    merged: list[dict[str, Any]] = []
    async for doc in interactions_cursor:
        merged.append(
            {
                "kind": "question",
                "topic": doc.get("topic", ""),
                "is_correct": doc.get("is_correct"),
                "xp_earned": doc.get("xp_earned", 0),
                "occurred_at": doc.get("answered_at", ""),
            }
        )
    async for doc in ratings_cursor:
        merged.append(
            {
                "kind": "flashcard",
                "topic": doc.get("topic", ""),
                "is_correct": None,
                "xp_earned": FLASHCARD_XP,
                "occurred_at": doc.get("rated_at", ""),
            }
        )

    # Descending by occurred_at. ISO 8601 sorts lexicographically.
    merged.sort(key=lambda e: e["occurred_at"], reverse=True)
    return merged[:limit]


# ── Time helpers ────────────────────────────────────────────────────────────


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _parse_iso(value: Any) -> datetime | None:
    """Parse an ISO-8601 string into a UTC-aware datetime. Returns
    ``None`` on anything malformed — analytics never crashes on bad
    data; the offending event is silently skipped.
    """
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)
