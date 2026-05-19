"""Learning Path Engine Layer 1 — adaptive topic selection (Sprint 3.3).

Given a student's precomputed knowledge state, their recent interactions,
and the workspace's canonical taxonomy (with parent edges from
Sprint 2.7's dep inference), pick the next topic to drill.

Why a weighted priority score and not BKT/IRT
--------------------------------------------
Per the Search Before Building ethos: classic adaptive-learning literature
(Bayesian Knowledge Tracing, Item Response Theory) requires lots of
historical attempts to fit per-skill priors. The cold-start case — a
brand-new student with zero interactions — is the dominant one for a
30-day MVP. A weighted priority score is the canonical Layer-1 baseline:
it degrades gracefully to "pick the lowest-complexity root topic" on a
cold start, and accumulates signal as the student answers.

Score components
----------------
For each topic, we compute a weighted sum of:

- ``mastery_deficit`` — ``1 - mastery_score``. The dominant signal once
  the student has interactions. Less-mastered = higher priority.
- ``recency_factor`` — penalises topics seen recently. A topic answered
  within the last ``recency_short_window`` interactions gets the full
  recency penalty; the penalty smoothly decays beyond that.
- ``prereq_readiness`` — parent-topic mastery. Topics with no parent
  (roots) always get full readiness. Topics whose parent is unmastered
  get a deduction so the student isn't drilled on advanced material
  before the foundation is there. NOT a hard gate — the score still
  ranks them, just lower.
- ``variety_factor`` — flat -1 if the topic appears in the most-recent
  ``variety_window`` interactions, 0 otherwise. Smooths alternation so
  the student doesn't see the same topic three turns in a row.
- ``curriculum_priority`` — admin-supplied boost (default 0). Admin UI
  in Sprint 4 will wire this up; today it's a no-op so the signature
  stays stable.

Output
------
:class:`TopicSelection` returns the selected topic, the full ranked
candidate list with per-component breakdowns, and a human-readable
``rationale``. The rationale string is the seam Sprint 4's admin
"why did the engine pick this?" tooltip will read.

Edge cases
----------
- Empty taxonomy → :class:`NoTopicsAvailable`. The caller (Sprint 3.9's
  ``/questions/next`` endpoint) maps this to a 409 with admin guidance.
- Student with zero interactions → all mastery = 0, all recency = 0.
  Ranking reduces to prereq_readiness + (negative) complexity tiebreak,
  so roots come first.
- Workspace not found → :class:`WorkspaceNotFound`.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from app.core.database import WORKSPACES, get_collection
from app.mcp_tools import invoke
from app.mcp_tools.retrieve_student_context import (
    RetrieveStudentContextInput,
    RetrieveStudentContextOutput,
)
from app.models.workspace import CanonicalTopic, Workspace

logger = logging.getLogger(__name__)


# ── Errors ──────────────────────────────────────────────────────────────────


class NoTopicsAvailable(RuntimeError):
    """The workspace has no canonical topics yet — nothing to select.

    Caller should suggest the admin upload more material. Sprint 3.9
    maps this to HTTP 409 with a clear message.
    """


class WorkspaceNotFound(RuntimeError):
    """Workspace id doesn't resolve to a row in the tenant's database."""


# ── Configuration ───────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class SelectionWeights:
    """Tunable weights for the score components.

    Defaults reflect the v1 calibration: mastery dominates, recency and
    variety provide smoothing, prereq is a soft nudge, curriculum is
    inactive until Sprint 4 wires admin priorities.

    Why these numbers
    -----------------
    - ``mastery=1.0`` baselines the others; everything's a fraction of
      this signal's authority.
    - ``recency=0.5`` is loud enough to break ties between two equally
      under-mastered topics in favour of the one the student hasn't
      just seen.
    - ``variety=0.3`` is roughly half of recency — a flat-band penalty
      that bumps a "haven't seen for 3 turns" topic above a "saw 2 turns
      ago" topic.
    - ``prereq=0.3`` keeps unmastered-parent topics IN the candidate
      pool (we don't block) but lower than their unblocked siblings.
    - ``curriculum=1.0`` makes admin priorities authoritative ONCE they
      ship — admin opinion should outrank pure recency / variety. Set
      to 0 today because no admin priorities exist yet.
    """

    mastery: float = 1.0
    recency: float = 0.5
    prereq: float = 0.3
    variety: float = 0.3
    curriculum: float = 1.0


@dataclass(frozen=True, slots=True)
class SelectionConfig:
    """Tunable thresholds + windows that aren't weights.

    Separated from weights so weight-only experiments don't have to
    repeat the bucket constants.
    """

    # Recency: a topic seen in the last N interactions gets the full
    # penalty; the penalty linearly tapers to 0 across the next N.
    recency_short_window: int = 3
    recency_long_window: int = 10
    # Variety penalty fires if the topic appears in the last N interactions.
    variety_window: int = 3
    # Parent-mastery threshold below which a child topic is "blocked"
    # (just down-weighted, not removed). Tuned for K-12 where 70% is the
    # rough "I get the basics" line.
    prereq_mastery_floor: float = 0.7
    # How many candidates to return (besides the selected one) for
    # observability. None = return all.
    candidates_limit: int | None = None


# ── Outputs ─────────────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class TopicScore:
    """Computed priority for one topic, with per-component breakdown.

    The breakdown is what Sprint 4's admin UI surfaces in tooltips and
    what makes the engine debuggable when the selection looks weird.
    """

    topic_id: str
    topic_name: str
    score: float
    components: dict[str, float]
    complexity_level: float | None  # secondary tiebreak signal


@dataclass(frozen=True, slots=True)
class TopicSelection:
    """Result of :func:`select_next_topic`."""

    selected: TopicScore
    candidates: list[TopicScore]  # includes the selected one, ranked desc
    rationale: str  # human-readable, suitable for admin tooltip


# ── Public entry point ──────────────────────────────────────────────────────


async def select_next_topic(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    weights: SelectionWeights | None = None,
    config: SelectionConfig | None = None,
    curriculum_priorities: dict[str, float] | None = None,
) -> TopicSelection:
    """Pick the next topic to drill for ``student_id`` in ``workspace_id``.

    Args:
        tenant_id: routes the Cosmos reads.
        workspace_id: workspace whose canonical taxonomy + student state
            we score against.
        student_id: target student.
        weights: optional override for the score-component weights.
        config: optional override for thresholds + windows.
        curriculum_priorities: optional map of ``topic_id -> bump``.
            Bumps are signed floats; positive = admin wants more of this
            topic, negative = less. ``None`` = no admin signal (today's
            default).

    Returns:
        :class:`TopicSelection` with the selected topic, ranked candidates,
        and a rationale string.

    Raises:
        WorkspaceNotFound: workspace_id doesn't resolve.
        NoTopicsAvailable: workspace has zero canonical topics.
    """
    weights = weights or SelectionWeights()
    config = config or SelectionConfig()
    curriculum_priorities = curriculum_priorities or {}

    workspace = await _read_workspace(tenant_id, workspace_id)
    topics = workspace.taxonomy.topics
    if not topics:
        raise NoTopicsAvailable(
            f"Workspace {workspace_id} has no canonical topics yet — "
            "upload material before requesting questions."
        )

    context_result = await invoke(
        "retrieve_student_context",
        RetrieveStudentContextInput(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student_id,
        ),
    )
    assert isinstance(context_result, RetrieveStudentContextOutput)

    scored = _score_all_topics(
        topics=topics,
        context=context_result,
        weights=weights,
        config=config,
        curriculum_priorities=curriculum_priorities,
    )

    # Stable sort: by score desc, then by complexity asc (prefer simpler
    # foundational topics on ties), then by name (deterministic across
    # runs — crucial so the same student-state always picks the same
    # topic).
    scored.sort(
        key=lambda s: (-s.score, s.complexity_level or 0.0, s.topic_name.casefold())
    )

    selected = scored[0]
    candidates = (
        scored[: 1 + config.candidates_limit]
        if config.candidates_limit is not None
        else scored
    )
    rationale = _build_rationale(selected, context_result)

    logger.info(
        "Learning path selected topic=%s score=%.3f student=%s workspace=%s "
        "candidates=%d (rationale: %s)",
        selected.topic_name,
        selected.score,
        student_id,
        workspace_id,
        len(candidates),
        rationale,
    )

    return TopicSelection(
        selected=selected,
        candidates=candidates,
        rationale=rationale,
    )


# ── Scoring ─────────────────────────────────────────────────────────────────


def _score_all_topics(
    *,
    topics: list[CanonicalTopic],
    context: RetrieveStudentContextOutput,
    weights: SelectionWeights,
    config: SelectionConfig,
    curriculum_priorities: dict[str, float],
) -> list[TopicScore]:
    """Compute the priority score for every topic in the taxonomy.

    Pulled out so the v1 algorithm is one function call and the public
    entry stays focused on data wrangling + return shape.
    """
    # Build a name → mastery lookup. Student-side topics are keyed by
    # display name (the question's ``topic`` string); canonical topics
    # use ``name`` + ``aliases``. Case-fold both sides so spelling
    # variance ("Photosynthesis" vs "photosynthesis") doesn't break the
    # join.
    mastery_by_name: dict[str, _TopicMasteryProjection] = {}
    for m in context.topic_mastery:
        mastery_by_name[m.topic.casefold()] = _TopicMasteryProjection(
            mastery_score=m.mastery_score,
            last_seen_at=m.last_seen_at,
        )

    # Build the parent lookup (id → CanonicalTopic) once. Used to compute
    # prereq readiness for every child topic.
    by_id = {t.id: t for t in topics}

    # Build a recent-topics list (most-recent-first) for variety + recency.
    recent_topics: list[str] = [
        ix.topic.casefold() for ix in context.recent_interactions
    ]

    scored: list[TopicScore] = []
    for t in topics:
        mastery_proj = mastery_by_name.get(t.name.casefold())
        for alias in t.aliases:
            if mastery_proj is None:
                mastery_proj = mastery_by_name.get(alias.casefold())
            if mastery_proj is not None:
                break
        mastery_score = mastery_proj.mastery_score if mastery_proj else 0.0
        mastery_deficit = 1.0 - mastery_score

        recency_pos = _recency_position(t, recent_topics)
        recency_factor = _recency_factor(recency_pos, config)

        prereq_readiness = _prereq_readiness(
            topic=t,
            by_id=by_id,
            mastery_by_name=mastery_by_name,
            floor=config.prereq_mastery_floor,
        )

        variety_factor = _variety_factor(t, recent_topics, config.variety_window)

        curriculum_bump = curriculum_priorities.get(t.id, 0.0)

        components = {
            "mastery_deficit": mastery_deficit,
            "recency_factor": recency_factor,
            "prereq_readiness": prereq_readiness,
            "variety_factor": variety_factor,
            "curriculum_priority": curriculum_bump,
        }
        score = (
            weights.mastery * mastery_deficit
            + weights.recency * recency_factor
            + weights.prereq * prereq_readiness
            + weights.variety * variety_factor
            + weights.curriculum * curriculum_bump
        )

        scored.append(
            TopicScore(
                topic_id=t.id,
                topic_name=t.name,
                score=score,
                components=components,
                complexity_level=t.complexity_level,
            )
        )
    return scored


@dataclass(frozen=True, slots=True)
class _TopicMasteryProjection:
    """Local-only slim view of a topic's mastery for the scoring loop.

    Kept private — callers should use :class:`TopicSelection` for output.
    """

    mastery_score: float
    last_seen_at: str | None


def _recency_position(
    topic: CanonicalTopic,
    recent_topics: list[str],
) -> int | None:
    """Return the 0-indexed position of the topic in the recent list.

    0 = most recent interaction. Matches by name OR alias (case-folded).
    Returns ``None`` if the student hasn't seen this topic in the
    lookback window.
    """
    haystack = {topic.name.casefold()}
    haystack.update(a.casefold() for a in topic.aliases)
    for idx, name in enumerate(recent_topics):
        if name in haystack:
            return idx
    return None


def _recency_factor(position: int | None, config: SelectionConfig) -> float:
    """Map a recency position to a penalty in ``[-1.0, 0.0]``.

    - ``None`` (not seen) → 0.0 (no penalty, no boost)
    - ``< short_window`` → -1.0 (full penalty — just saw this)
    - ``< long_window``  → linear taper from -1.0 to 0.0
    - ``>= long_window`` → 0.0 (no penalty)
    """
    if position is None:
        return 0.0
    if position < config.recency_short_window:
        return -1.0
    if position < config.recency_long_window:
        # Linear taper. At position = short_window we want -1.0; at
        # long_window we want 0.0.
        span = max(1, config.recency_long_window - config.recency_short_window)
        steps_past = position - config.recency_short_window
        return -1.0 + steps_past / span
    return 0.0


def _prereq_readiness(
    *,
    topic: CanonicalTopic,
    by_id: dict[str, CanonicalTopic],
    mastery_by_name: dict[str, _TopicMasteryProjection],
    floor: float,
) -> float:
    """Score how "ready" a topic is given its parent's mastery.

    Returns:
        - ``1.0`` if the topic has no parent (it's a root).
        - The parent's mastery score, if known.
        - ``1.0`` if the parent_id points at a topic we can't find (broken
          edge — shouldn't happen post-2.7 sanitize, but defensively don't
          punish the child for a stale edge).
        - ``-1.0`` when the parent's mastery is below ``floor`` (visible
          deduction; still ranks but loud about being premature).

    The discontinuity at ``floor`` is intentional: parents below the
    floor look indistinguishably "not ready" to a kid; we don't want
    the engine to pretend partial credit unlocks the child.
    """
    if topic.parent_id is None:
        return 1.0
    parent = by_id.get(topic.parent_id)
    if parent is None:
        return 1.0
    proj = mastery_by_name.get(parent.name.casefold())
    if proj is None:
        for alias in parent.aliases:
            proj = mastery_by_name.get(alias.casefold())
            if proj is not None:
                break
    parent_mastery = proj.mastery_score if proj else 0.0
    if parent_mastery < floor:
        return -1.0
    return parent_mastery


def _variety_factor(
    topic: CanonicalTopic,
    recent_topics: list[str],
    window: int,
) -> float:
    """Flat -1 if the topic appears in the last ``window`` interactions.

    Separate from recency_factor on purpose: recency tapers smoothly
    across a longer horizon; variety is a sharp short-horizon nudge so
    the engine doesn't ping-pong on two topics.
    """
    haystack = {topic.name.casefold()}
    haystack.update(a.casefold() for a in topic.aliases)
    head = recent_topics[:window]
    return -1.0 if any(name in haystack for name in head) else 0.0


# ── Rationale ───────────────────────────────────────────────────────────────


def _build_rationale(
    selected: TopicScore,
    context: RetrieveStudentContextOutput,
) -> str:
    """Render a short, admin-readable explanation of the selection.

    Picks the 2-3 highest-magnitude components and surfaces those, plus
    a cold-start hint when the student has no interactions.
    """
    if not context.recent_interactions and context.overall_mastery == 0.0:
        # Cold start — the only signal that mattered is structural
        # (prereq readiness + complexity).
        return (
            f"Cold start (no prior interactions): selected "
            f"{selected.topic_name!r} as the lowest-complexity root topic."
        )

    parts = []
    deficit = selected.components.get("mastery_deficit", 0.0)
    if deficit > 0.5:
        parts.append(f"low mastery ({1 - deficit:.0%})")
    elif deficit > 0.2:
        parts.append(f"partial mastery ({1 - deficit:.0%})")
    else:
        parts.append(f"well-mastered ({1 - deficit:.0%}) but next-best")

    recency = selected.components.get("recency_factor", 0.0)
    if recency < -0.1:
        parts.append("hasn't recovered from a recent attempt")
    elif recency == 0.0:
        parts.append("not seen recently")

    prereq = selected.components.get("prereq_readiness", 1.0)
    if prereq >= 0.99:
        parts.append("root topic / prereqs clear")
    elif prereq < 0:
        parts.append("note: parent topic not yet at mastery floor")

    return (
        f"Selected {selected.topic_name!r} — score={selected.score:.2f} "
        f"({', '.join(parts)})"
    )


# ── Cosmos read ─────────────────────────────────────────────────────────────


async def _read_workspace(tenant_id: str, workspace_id: str) -> Workspace:
    col = get_collection(tenant_id, WORKSPACES)
    raw = await col.find_one({"_id": workspace_id})
    if raw is None:
        raise WorkspaceNotFound(
            f"Workspace {workspace_id} not found in tenant {tenant_id}"
        )
    return Workspace.model_validate(raw)
