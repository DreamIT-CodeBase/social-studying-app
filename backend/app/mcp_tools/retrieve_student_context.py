"""MCP tool: retrieve_student_context — Sprint 3.6.

Pulls the precomputed knowledge-state summary + a tail of recent
interactions for one student in one workspace. Used by the Learning
Path Engine (Sprint 3.3) to score topic selection and by the question
generator (Sprint 3.7) to avoid serving recently-seen questions.

Why precomputed + tail, not live aggregation
--------------------------------------------
``knowledge_states.{student_id}`` is the precomputed mastery summary,
updated async by Sprint 3.11's state-update step. We read it once,
not aggregate across interactions on every request. The recent-tail
join is bounded (default 20 rows) and only used for variety / repeat
suppression, not mastery computation.

The interactions read sorts client-side — see
[[first-real-azure-run-findings]] for why Cosmos MongoDB rejects
``cursor.sort`` without an explicit index.
"""

from __future__ import annotations

import logging
from typing import Any

from pydantic import BaseModel, Field

from app.core.database import INTERACTIONS, KNOWLEDGE_STATES, get_collection
from app.mcp_tools import register_tool
from app.models.interaction import Interaction
from app.models.knowledge_state import KnowledgeState

logger = logging.getLogger(__name__)


# ── Input ────────────────────────────────────────────────────────────────────


class RetrieveStudentContextInput(BaseModel):
    """Parameters for :func:`retrieve_student_context`."""

    tenant_id: str = Field(..., min_length=1)
    workspace_id: str = Field(..., min_length=1)
    student_id: str = Field(..., min_length=1)
    recent_interaction_limit: int = Field(
        default=20,
        ge=1,
        le=100,
        description=(
            "How many recent interactions to return. Used by the Learning "
            "Path Engine for variety scoring and by question generation "
            "to dedupe recently-served question_ids."
        ),
    )


# ── Output ───────────────────────────────────────────────────────────────────


class TopicMasteryView(BaseModel):
    """Per-topic mastery row, projected from the KnowledgeState document.

    ``accuracy`` is derived (``questions_correct / questions_attempted``)
    rather than stored — keeps the projection consistent regardless of
    when the underlying state was last recomputed.
    """

    topic: str
    mastery_score: float = Field(ge=0.0, le=1.0)
    accuracy: float = Field(ge=0.0, le=1.0)
    questions_attempted: int = Field(ge=0)
    questions_correct: int = Field(ge=0)
    last_seen_at: str | None = None


class InteractionSummary(BaseModel):
    """One recent interaction. Slim projection — no answer_given to keep
    payloads small and avoid leaking PII into prompts.
    """

    question_id: str
    topic: str
    is_correct: bool
    answered_at: str


class RetrieveStudentContextOutput(BaseModel):
    """Result of :func:`retrieve_student_context`."""

    student_id: str
    workspace_id: str
    overall_mastery: float = Field(ge=0.0, le=1.0)
    last_recalculated_at: str | None = None
    topic_mastery: list[TopicMasteryView]
    recent_interactions: list[InteractionSummary] = Field(
        description="Most-recent-first, capped at ``recent_interaction_limit``.",
    )
    seen_question_ids: list[str] = Field(
        description=(
            "Unique question ids extracted from ``recent_interactions``. "
            "Convenience for the prompt step's repeat-suppression logic — "
            "saves the caller from re-deriving."
        ),
    )


# ── Handler ──────────────────────────────────────────────────────────────────


@register_tool(
    name="retrieve_student_context",
    description=(
        "Return a student's precomputed knowledge state plus their last "
        "N interactions in a workspace. Used by the Learning Path Engine "
        "for topic selection and by question generation to suppress "
        "recently-served questions."
    ),
    input_model=RetrieveStudentContextInput,
    output_model=RetrieveStudentContextOutput,
)
async def retrieve_student_context(
    params: RetrieveStudentContextInput,
) -> RetrieveStudentContextOutput:
    """Fetch knowledge state + recent interactions and project for the caller."""
    state = await _read_knowledge_state(
        tenant_id=params.tenant_id,
        workspace_id=params.workspace_id,
        student_id=params.student_id,
    )

    interactions = await _read_recent_interactions(
        tenant_id=params.tenant_id,
        workspace_id=params.workspace_id,
        student_id=params.student_id,
        limit=params.recent_interaction_limit,
    )

    seen_ids: list[str] = []
    seen_set: set[str] = set()
    summaries: list[InteractionSummary] = []
    for ix in interactions:
        summaries.append(
            InteractionSummary(
                question_id=ix.question_id,
                topic=ix.topic,
                is_correct=ix.is_correct,
                answered_at=ix.answered_at,
            )
        )
        if ix.question_id not in seen_set:
            seen_set.add(ix.question_id)
            seen_ids.append(ix.question_id)

    topic_views = [
        TopicMasteryView(
            topic=t.topic,
            mastery_score=t.mastery_score,
            accuracy=t.accuracy,
            questions_attempted=t.questions_attempted,
            questions_correct=t.questions_correct,
            last_seen_at=t.last_seen_at,
        )
        for t in (state.topics if state else [])
    ]

    return RetrieveStudentContextOutput(
        student_id=params.student_id,
        workspace_id=params.workspace_id,
        overall_mastery=state.overall_mastery if state else 0.0,
        last_recalculated_at=state.last_recalculated_at if state else None,
        topic_mastery=topic_views,
        recent_interactions=summaries,
        seen_question_ids=seen_ids,
    )


# ── Cosmos reads ────────────────────────────────────────────────────────────


async def _read_knowledge_state(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
) -> KnowledgeState | None:
    """Load the student's knowledge_state doc, or None if no interactions yet.

    Missing doc is a normal state — a brand-new student has no precomputed
    mastery row until Sprint 3.11 writes the first one. Caller treats None
    as "all zeroes".
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
        return None
    return KnowledgeState.model_validate(raw)


async def _read_recent_interactions(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    limit: int,
) -> list[Interaction]:
    """Load the most recent ``limit`` interactions for a student in a workspace.

    Sort runs CLIENT-SIDE — Cosmos MongoDB API rejects ``cursor.sort()``
    unless an explicit index exists on the sort field. See
    chunk_storage.find_for_document for the same pattern.

    We over-read in the sense that we pull every row matching the filter
    and then take the tail. Practical concern only once a student has
    thousands of interactions; well past the MVP shape.
    """
    col = get_collection(tenant_id, INTERACTIONS)
    cursor = col.find(
        {
            "student_id": student_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    rows: list[dict[str, Any]] = await cursor.to_list(length=None)
    rows.sort(key=lambda r: r.get("answered_at") or "", reverse=True)
    return [Interaction.model_validate(r) for r in rows[:limit]]
