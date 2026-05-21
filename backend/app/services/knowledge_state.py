"""Knowledge state update — Sprint 3.11.

Called by the ``/questions/{id}/answer`` endpoint after an evaluation
result lands. Reads the student's :class:`KnowledgeState` doc (creates
one on first interaction), bumps the per-topic mastery, recomputes
overall mastery, and writes it back.

Why a precomputed summary, not live aggregation
-----------------------------------------------
Per the Cosmos schema docs: ``knowledge_states`` is the precomputed
"what does this student know" summary. Sprint 3.3's Learning Path
Engine reads it on every ``/questions/next`` request. Live-aggregating
from the ``interactions`` collection on each read would be O(N) on
total attempts and would saturate Cosmos under load.

Mastery update rule (v1)
------------------------
Weighted exponential moving average::

    weight = LEARNING_RATE × difficulty_weight(question.difficulty)
    correctness = 1.0 if is_correct else 0.0
    new_mastery = old_mastery + weight × (correctness − old_mastery)
    clamped to [0.0, 1.0]

Difficulty weights — getting an advanced question right matters more
than a beginner one:

    beginner:     0.5
    intermediate: 1.0
    advanced:     1.5

A correct beginner question at mastery 0 moves to ~0.10; a correct
advanced question at mastery 0.5 moves to ~0.65; a wrong advanced
question at mastery 0.7 falls to ~0.49.

Sprint 5 gamification will layer in streak bonuses + per-attempt XP
weighting on top of this; the mastery math stays here.

Idempotency / concurrency
-------------------------
A real implementation would compare-and-swap on a version field to
avoid lost updates if two interactions land at the same time
(double-tap on the answer button). Sprint 3 v1 uses ``replace_one``
without optimistic concurrency — the racing-double-submit window is
a fraction of a second and the worst case is one of two updates
being lost. Sprint 5 polish item.
"""

from __future__ import annotations

import logging
from uuid import uuid4

from app.core.database import KNOWLEDGE_STATES, get_collection
from app.models.base import utc_now
from app.models.knowledge_state import KnowledgeState, TopicMastery
from app.models.question import DifficultyLevel

logger = logging.getLogger(__name__)


# ── Calibration constants ──────────────────────────────────────────────────


LEARNING_RATE: float = 0.2
"""How much each interaction shifts mastery toward the correctness signal.

0.2 = ~5 interactions to climb from 0.0 to 0.7 on consistently correct
answers; about ten to drop back the same way on consistent failure.
Slow enough to filter out the lucky-guess + unlucky-typo noise; fast
enough to feel responsive to the student's effort.
"""


_DIFFICULTY_WEIGHTS: dict[DifficultyLevel, float] = {
    DifficultyLevel.beginner: 0.5,
    DifficultyLevel.intermediate: 1.0,
    DifficultyLevel.advanced: 1.5,
}


# ── Public entry point ──────────────────────────────────────────────────────


async def record_attempt(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    topic: str,
    difficulty: DifficultyLevel,
    is_correct: bool,
    now: str | None = None,
) -> KnowledgeState:
    """Apply one interaction's effect to the student's knowledge state.

    Args:
        tenant_id, workspace_id, student_id: target student.
        topic: display name from the question (will be the key on the
            per-topic mastery row).
        difficulty: drives the difficulty_weight in the mastery update.
        is_correct: from the evaluator.
        now: ISO 8601 UTC timestamp. Tests pass a fixed value for
            determinism; production callers omit it (defaults to
            :func:`utc_now`).

    Returns:
        The persisted :class:`KnowledgeState` after the update — useful
        for the endpoint's response and for logging.

    Persistence: ``replace_one`` upsert by ``(student_id,
    workspace_id)``. Returns the post-update doc model so the caller
    can include mastery deltas in the response.
    """
    timestamp = now or utc_now()

    state = await _read_or_init(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
    )

    mastery_row = _find_or_append_topic(state, topic=topic)
    mastery_row.questions_attempted += 1
    if is_correct:
        mastery_row.questions_correct += 1
    mastery_row.last_seen_at = timestamp
    mastery_row.mastery_score = _apply_update(
        old=mastery_row.mastery_score,
        is_correct=is_correct,
        difficulty=difficulty,
    )

    state.overall_mastery = _recompute_overall(state.topics)
    state.last_recalculated_at = timestamp
    state.touch()

    await _persist(tenant_id=tenant_id, state=state)
    logger.info(
        "Recorded attempt student=%s workspace=%s topic=%s correct=%s "
        "topic_mastery=%.3f overall_mastery=%.3f",
        student_id,
        workspace_id,
        topic,
        is_correct,
        mastery_row.mastery_score,
        state.overall_mastery,
    )
    return state


# ── Mastery math ───────────────────────────────────────────────────────────


def _apply_update(
    *,
    old: float,
    is_correct: bool,
    difficulty: DifficultyLevel,
) -> float:
    """Return the post-attempt mastery score, clamped to [0, 1]."""
    weight = LEARNING_RATE * _DIFFICULTY_WEIGHTS[difficulty]
    correctness = 1.0 if is_correct else 0.0
    delta = weight * (correctness - old)
    return max(0.0, min(1.0, old + delta))


def _recompute_overall(topics: list[TopicMastery]) -> float:
    """Mean of per-topic mastery scores.

    Zero topics = zero overall mastery. Sprint 5 polish may switch to
    a weighted mean (e.g. by questions_attempted) so a single
    well-practised topic doesn't dwarf untouched ones, but the v1
    rule keeps the LPE's cold-start math symmetric.
    """
    if not topics:
        return 0.0
    return sum(t.mastery_score for t in topics) / len(topics)


# ── Topic lookup ───────────────────────────────────────────────────────────


def _find_or_append_topic(state: KnowledgeState, *, topic: str) -> TopicMastery:
    """Find the ``TopicMastery`` row for ``topic``, creating it on first hit.

    Matching is case-insensitive — student-side topic naming may differ
    from the canonical taxonomy on case alone, and we'd rather merge
    the rows than dual-track them. The newly-appended row stores the
    name in its canonical (incoming) casing.
    """
    target = topic.casefold()
    for row in state.topics:
        if row.topic.casefold() == target:
            return row
    new_row = TopicMastery(topic=topic, mastery_score=0.0)
    state.topics.append(new_row)
    return new_row


# ── Cosmos I/O ─────────────────────────────────────────────────────────────


async def _read_or_init(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
) -> KnowledgeState:
    """Read the existing knowledge_state doc, or build a fresh one.

    Filter is keyed on the natural composite (student_id, workspace_id)
    rather than ``_id`` — the document id is opaque-but-stable
    (``ks_<uuid>``) so the first-ever read has no id to compose. We
    generate an id when initialising and the upsert in :func:`_persist`
    treats it as authoritative.
    """
    col = get_collection(tenant_id, KNOWLEDGE_STATES)
    raw = await col.find_one(
        {
            "student_id": student_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    if raw is None:
        return KnowledgeState(
            **{"_id": f"ks_{uuid4().hex}"},
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student_id,
        )
    return KnowledgeState.model_validate(raw)


async def _persist(*, tenant_id: str, state: KnowledgeState) -> None:
    """Upsert the state doc.

    Replace-by-id covers both the "first interaction" (insert) and the
    "subsequent" (update) paths. Sprint 5 polish: add optimistic
    concurrency on a ``version`` field so racing double-submits don't
    silently lose one update.
    """
    col = get_collection(tenant_id, KNOWLEDGE_STATES)
    await col.replace_one(
        {"_id": state.id},
        state.model_dump(by_alias=True),
        upsert=True,
    )
