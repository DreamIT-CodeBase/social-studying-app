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
from datetime import UTC, datetime, timedelta
from typing import Any

from app.core.database import (
    FLASHCARD_RATINGS,
    INTERACTIONS,
    KNOWLEDGE_STATES,
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
