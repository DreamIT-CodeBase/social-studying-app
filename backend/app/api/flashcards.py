"""Flashcard endpoints — Sprint 3.12.

Two endpoints:

- ``POST /workspaces/{ws}/flashcards/next``: generate + persist + serve
  the next flashcard for the calling student.
- ``POST /workspaces/{ws}/flashcards/{fc_id}/rate``: record a student's
  self-rating (easy / medium / hard).

Smaller surface than the question pipeline — flashcards skip:
- Difficulty calibration (the student self-rates, no system grading)
- Answer evaluation (no canonical "correct" answer)
- Knowledge state updates (Sprint 5/6 SRS reads rating events directly)

Same shape elsewhere:
- Learning Path Engine drives topic selection (3.3)
- retrieve_content provides grounding (3.5)
- Content Safety + structural checks gate output (3.8 pattern, inlined)
- 3-attempt retry across candidate topics, 503 with Retry-After on
  exhaustion (3.9 pattern)
"""

from __future__ import annotations

import logging
import random
from dataclasses import dataclass
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends
from pydantic import BaseModel, Field

from app.core.auth import get_current_user
from app.core.database import (
    FLASHCARD_RATINGS,
    FLASHCARDS,
    INTERACTIONS,
    QUESTION_QUEUE,
    WORKSPACES,
    get_collection,
)
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ServiceUnavailableError,
)
from app.mcp_tools import invoke  # noqa: F401 - kept for route test/extension patch seam
from app.models.base import utc_now
from app.models.flashcard import (
    Flashcard,
    FlashcardForStudent,
    FlashcardRatingBadgeUnlock,
    FlashcardRatingEvent,
    FlashcardRatingResponse,
    FlashcardRatingSubmission,
    FlashcardStatus,
)
from app.models.question import Question
from app.models.user import User
from app.models.workspace import Workspace
from app.services import content_safety, flashcard_generation
from app.services import gamification as gamification_service
from app.services import notifications as notification_service
from app.services.flashcard_generation import (
    FlashcardShapeError,
    GeneratedFlashcard,
    InsufficientFlashcardSource,
)
from app.services.learning_path import (  # noqa: F401 - kept for compatibility patch seam
    select_next_topic,
)


class NextFlashcardRequest(BaseModel):
    topics: list[str] | None = Field(
        default=None, description="Optional selected topic IDs/names to filter flashcards."
    )
    mastery: float | None = Field(
        default=None,
        ge=0.0,
        le=1.0,
        description="Student's current overall mastery (0–1). Used to bias difficulty.",
    )


def _resolve_descendants(workspace: Workspace, selected_topic_ids: list[str]) -> list[str]:
    # Build maps
    topics_map = {t.id: t for t in workspace.taxonomy.topics}
    parent_to_children = {}
    for t in workspace.taxonomy.topics:
        if t.parent_id:
            parent_to_children.setdefault(t.parent_id, []).append(t.id)

    resolved_ids = set()
    for start_id in selected_topic_ids:
        # If it's a topic name (not starting with tpc_), we find its ID first
        start_id_resolved = start_id
        if not start_id.startswith("tpc_"):
            for t in workspace.taxonomy.topics:
                if t.name.casefold() == start_id.casefold():
                    start_id_resolved = t.id
                    break

        if start_id_resolved not in topics_map:
            continue

        resolved_ids.add(start_id_resolved)
        queue = [start_id_resolved]
        while queue:
            curr = queue.pop(0)
            children = parent_to_children.get(curr, [])
            for child in children:
                if child not in resolved_ids:
                    resolved_ids.add(child)
                    queue.append(child)

    return [topics_map[tid].name for tid in resolved_ids if tid in topics_map]


logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/workspaces/{workspace_id}/flashcards",
    tags=["flashcards"],
)


def _mastery_tier(mastery: float | None) -> str:
    """Map a 0–1 mastery score to a difficulty tier string.

    Tiers (aligned with the product spec):
    - beginner    mastery < 0.40
    - intermediate 0.40 ≤ mastery < 0.75
    - expert       mastery ≥ 0.75
    """
    if mastery is None or mastery < 0.40:
        return "beginner"
    if mastery < 0.75:
        return "intermediate"
    return "expert"


# Mirrors the question orchestrator's retry budget — same UX
# trade-off (~3-6s total wait vs. tolerating one bad GPT-4o roll).
_MAX_ATTEMPTS = 3
_GROUNDING_CHUNK_LIMIT = 5
# Sanity floor / ceiling for the structural check on generated cards.
_MIN_FRONT_CHARS = 3
_MAX_FRONT_CHARS = 300
_MIN_BACK_CHARS = 3
_MAX_BACK_CHARS = 500


# ── POST /flashcards/next ───────────────────────────────────────────────────


@router.post("/next", response_model=FlashcardForStudent)
async def next_flashcard(
    workspace_id: str,
    request_data: NextFlashcardRequest | None = None,
    current_user: User = Depends(get_current_user),
) -> FlashcardForStudent:
    """Generate and return a flashcard for the calling student.

    Returns the FULL flashcard (front + back + explanation) — unlike
    /questions/next which withholds the answer. Flashcards are
    self-rated, so revealing the back is the whole point.

    Raises:
        404: Workspace not found (or caller has no access).
        409: Workspace has no canonical topics yet.
        503: All retry attempts produced unservable results.
    """
    _assert_workspace_access(current_user, workspace_id)
    workspace = await _read_workspace(current_user.tenant_id, workspace_id)

    if not workspace.taxonomy or not workspace.taxonomy.topics:
        raise ConflictError(
            "This workspace has no topics yet. Ask an admin to upload "
            "study material before requesting flashcards."
        )

    # 1. Fetch correct interactions
    interactions_col = get_collection(current_user.tenant_id, INTERACTIONS)
    query = {
        "workspace_id": workspace_id,
        "student_id": current_user.id,
        "is_correct": True,
    }

    # 2. Apply topic filters (including child descendants)
    if request_data and request_data.topics:
        allowed_names = _resolve_descendants(workspace, request_data.topics)
        if not allowed_names:
            raise ConflictError("None of the selected topics exist in this workspace.")
        query["topic"] = {"$in": allowed_names}

    cursor = interactions_col.find(query)
    interactions = await cursor.to_list(length=5000)

    if not interactions:
        raise ConflictError(
            "You haven't answered any questions correctly yet! "
            "Go to the Study tab and answer questions correctly to unlock flashcards."
        )

    # Determine mastery tier for difficulty calibration
    mastery = request_data.mastery if request_data else None
    mastery_tier = _mastery_tier(mastery)

    # Sort descending by answered_at (newest first)
    interactions.sort(key=lambda x: x.get("answered_at", ""), reverse=True)

    # 3. Apply recency gradient — decay varies by tier:
    #    - BEGINNER : high decay (0.95) → strong preference for recent,
    #      simpler interactions so the student reinforces recent learning.
    #    - INTERMEDIATE: moderate decay (0.80) → balanced mix.
    #    - EXPERT   : low decay (0.60) → flattened weights → older,
    #      harder material resurfaces more often.
    decay_by_tier = {"beginner": 0.95, "intermediate": 0.80, "expert": 0.60}
    decay = decay_by_tier[mastery_tier]

    # Candidate pool size grows with mastery to increase variety.
    pool_by_tier = {"beginner": 3, "intermediate": 5, "expert": 8}
    pool_size = pool_by_tier[mastery_tier]

    candidates: list[dict] = []
    available_indices = list(range(len(interactions)))

    for _ in range(min(pool_size, len(interactions))):
        current_weights = [decay**idx for idx in available_indices]
        curr_total = sum(current_weights)
        if curr_total <= 0:
            break
        r = random.uniform(0, curr_total)
        cumulative = 0.0
        chosen_idx_in_list = 0
        for i, w in enumerate(current_weights):
            cumulative += w
            if r <= cumulative:
                chosen_idx_in_list = i
                break
        chosen_real_idx = available_indices.pop(chosen_idx_in_list)
        candidates.append(interactions[chosen_real_idx])

    attempt_log: list[str] = []

    for attempt_index, candidate_interaction in enumerate(candidates, start=1):
        question_id = candidate_interaction.get("question_id")
        topic_name = candidate_interaction.get("topic")
        if not question_id or not topic_name:
            continue

        q_col = get_collection(current_user.tenant_id, QUESTION_QUEUE)
        q_doc_raw = await q_col.find_one({"_id": question_id})
        if not q_doc_raw:
            attempt_log.append(
                f"attempt={attempt_index} question={question_id} → question not found"
            )
            continue

        question_doc = Question.model_validate(q_doc_raw)

        outcome = await _try_candidate(
            current_user=current_user,
            workspace_id=workspace_id,
            topic_name=topic_name,
            question_doc=question_doc,
            mastery_tier=mastery_tier,
        )
        if isinstance(outcome, _Persisted):
            return outcome.for_student
        attempt_log.append(f"attempt={attempt_index} topic={topic_name!r} → {outcome.reason}")

    logger.warning(
        "next_flashcard exhausted attempts workspace=%s student=%s log=%s",
        workspace_id,
        current_user.id,
        " | ".join(attempt_log),
    )
    raise ServiceUnavailableError(
        "Couldn't generate a clean flashcard right now after "
        f"{len(candidates)} attempts. Please retry in a moment.",
        headers={"Retry-After": "30"},
    )


# ── POST /flashcards/{flashcard_id}/rate ───────────────────────────────────


@router.post(
    "/{flashcard_id}/rate",
    response_model=FlashcardRatingResponse,
)
async def rate_flashcard(
    workspace_id: str,
    flashcard_id: str,
    submission: FlashcardRatingSubmission,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
) -> FlashcardRatingResponse:
    """Record a student's self-rating for a flashcard.

    Validates that the flashcard exists in this workspace and is in
    an approvable state. Persists the rating to the
    ``flashcard_ratings`` append-only collection. Returns the stored
    rating + timestamp.

    Raises:
        404: Flashcard not found in this workspace.
        409: Flashcard is in pending_review / rejected / flagged state.
        403: Caller is not a member of the workspace.
    """
    _assert_workspace_access(current_user, workspace_id)

    flashcard = await _load_flashcard(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        flashcard_id=flashcard_id,
    )
    if flashcard.status != FlashcardStatus.approved:
        raise ConflictError(
            f"Flashcard {flashcard_id} is not in an answerable state "
            f"(status={flashcard.status.value})."
        )

    timestamp = utc_now()
    event = FlashcardRatingEvent(
        **{"_id": f"rat_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        flashcard_id=flashcard_id,
        topic=flashcard.topic,
        rating=submission.rating,
        rated_at=timestamp,
        selected_option=submission.selected_option,
        is_correct=submission.is_correct,
        response_time_ms=submission.response_time_ms,
        session_progress=submission.session_progress,
        accuracy_percentage=submission.accuracy_percentage,
    )
    col = get_collection(current_user.tenant_id, FLASHCARD_RATINGS)
    await col.insert_one(event.model_dump(by_alias=True))

    # Gamification: bump XP / streak / flashcards_reviewed and pick up
    # any badge unlocks. Mirrors the answer endpoint — rating event is
    # the source of truth (append-only), gamification is the summary.
    delta = await gamification_service.record_flashcard_rating(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        topic=flashcard.topic,
        rating=submission.rating,
        now=timestamp,
    )

    logger.info(
        "Flashcard rated flashcard=%s student=%s rating=%s xp=%d level=%d streak=%d badges=%d",
        flashcard_id,
        current_user.id,
        submission.rating.value,
        delta.xp_earned,
        delta.new_level,
        delta.streak_days,
        len(delta.badges_unlocked),
    )

    # Sprint 5.7c — same milestone push fan-out as the answer endpoint.
    if delta.leveled_up or delta.badges_unlocked:
        background_tasks.add_task(
            notification_service.dispatch_gamification_milestones,
            tenant_id=current_user.tenant_id,
            user_id=current_user.id,
            workspace_id=workspace_id,
            leveled_up=delta.leveled_up,
            new_level=delta.new_level,
            badges_unlocked=list(delta.badges_unlocked),
        )

    return FlashcardRatingResponse(
        flashcard_id=flashcard_id,
        rating=submission.rating,
        rated_at=timestamp,
        xp_earned=delta.xp_earned,
        new_level=delta.new_level,
        leveled_up=delta.leveled_up,
        streak_days=delta.streak_days,
        streak_extended=delta.streak_extended,
        badges_unlocked=[
            FlashcardRatingBadgeUnlock(
                badge_id=b.badge_id,
                name=b.name,
                description=b.description,
                icon=b.icon,
                xp_reward=b.xp_reward,
            )
            for b in delta.badges_unlocked
        ],
    )


# ── Inner per-candidate loop (Sprint 3.9 pattern) ──────────────────────────


@dataclass(frozen=True, slots=True)
class _Persisted:
    for_student: FlashcardForStudent


@dataclass(frozen=True, slots=True)
class _Skip:
    reason: str


async def _try_candidate(
    *,
    current_user: User,
    workspace_id: str,
    topic_name: str,
    question_doc: Question,
    mastery_tier: str = "beginner",
) -> _Persisted | _Skip:
    from app.mcp_tools.retrieve_content import RetrievedChunk

    # Format question details into a single chunk text
    question_text = f"Question: {question_doc.body}\n"
    if question_doc.options:
        question_text += "Options:\n"
        for opt in question_doc.options:
            question_text += f"- {opt.key}: {opt.text}\n"
    question_text += f"Correct Answer: {question_doc.answer}\n"
    if question_doc.explanation:
        question_text += f"Explanation: {question_doc.explanation}\n"

    chunk = RetrievedChunk(
        chunk_id="chk_q_" + question_doc.id,
        chunk_index=0,
        document_id=question_doc.document_id,
        text=question_text,
        topic_ids=[],
        score=1.0,
    )

    # First check if we already have an approved flashcard for this topic in the workspace
    fc_col = get_collection(current_user.tenant_id, FLASHCARDS)
    existing_fc = await fc_col.find_one(
        {
            "workspace_id": workspace_id,
            "topic": topic_name,
            "status": FlashcardStatus.approved.value,
            "deleted_at": None,
        }
    )
    if existing_fc:
        logger.info(
            "Serving existing approved flashcard for topic=%s workspace=%s",
            topic_name,
            workspace_id,
        )
        return _Persisted(
            for_student=FlashcardForStudent.from_doc(Flashcard.model_validate(existing_fc))
        )

    # Personal workspaces should open immediately on mobile. The source
    # question has already passed generation, moderation, and answer grading,
    # so it is safe to turn it directly into a grounded recall card instead of
    # blocking the request on another AI generation + safety-review cycle.
    if workspace_id.startswith("wsp_self_"):
        answer = question_doc.answer
        for option in question_doc.options:
            if option.key.casefold() == answer.casefold():
                answer = option.text
                break
        generated = GeneratedFlashcard(
            front=question_doc.body,
            back=answer,
            explanation=question_doc.explanation,
            prompt_version="question-derived-v1",
        )
        persisted = await _persist_flashcard(
            current_user=current_user,
            workspace_id=workspace_id,
            topic_name=topic_name,
            question_doc=question_doc,
            generated=generated,
            verdict=_FlashcardVerdict(
                status=FlashcardStatus.approved,
                reason="Derived from an approved answered question.",
            ),
        )
        logger.info(
            "Served fast question-derived flashcard topic=%s workspace=%s",
            topic_name,
            workspace_id,
        )
        return _Persisted(for_student=FlashcardForStudent.from_doc(persisted))

    seen_card_fronts = await _get_seen_card_fronts(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        topic_name=topic_name,
    )

    try:
        generated = await flashcard_generation.generate_flashcard(
            topic=topic_name,
            grounding_chunks=[chunk],
            seen_card_fronts=seen_card_fronts,
            mastery_tier=mastery_tier,
        )
    except InsufficientFlashcardSource as exc:
        return _Skip(f"generator: insufficient_source ({exc})")
    except FlashcardShapeError as exc:
        return _Skip(f"generator: shape error ({exc})")

    verdict = await _review(generated)
    persisted = await _persist_flashcard(
        current_user=current_user,
        workspace_id=workspace_id,
        topic_name=topic_name,
        question_doc=question_doc,
        generated=generated,
        verdict=verdict,
    )

    if verdict.status == FlashcardStatus.approved:
        return _Persisted(for_student=FlashcardForStudent.from_doc(persisted))
    if verdict.status == FlashcardStatus.flagged:
        # Persisted for admin review; don't serve.
        return _Skip(f"safety flagged ({verdict.reason})")
    # Rejected — not persisted (see _persist_flashcard).
    return _Skip(f"review rejected: {verdict.reason}")


# How many past ratings to look back when building the seen-fronts list.
# 30 covers a realistic session length without blowing the prompt context.
_SEEN_FRONTS_LOOKBACK = 30


async def _get_seen_card_fronts(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    topic_name: str,
) -> list[str]:
    """Return front texts of flashcards this student has already seen for a topic.

    Queries the ratings collection (append-only, one row per swipe) for the
    most recent ``_SEEN_FRONTS_LOOKBACK`` events, then joins to the flashcards
    collection to retrieve the front text. Returns an empty list on any error
    so a DB hiccup degrades gracefully to the old (no-dedup) behaviour.
    """
    try:
        ratings_col = get_collection(tenant_id, FLASHCARD_RATINGS)
        cursor = ratings_col.find(
            {
                "workspace_id": workspace_id,
                "student_id": student_id,
                "topic": topic_name,
            },
            {"flashcard_id": 1},
        ).limit(_SEEN_FRONTS_LOOKBACK)
        rating_docs = await cursor.to_list(_SEEN_FRONTS_LOOKBACK)
        if not rating_docs:
            return []

        seen_ids = [r["flashcard_id"] for r in rating_docs]
        fc_col = get_collection(tenant_id, FLASHCARDS)
        fc_cursor = fc_col.find({"_id": {"$in": seen_ids}}, {"front": 1})
        fc_docs = await fc_cursor.to_list(len(seen_ids))
        return [d["front"] for d in fc_docs if d.get("front")]
    except Exception:
        logger.warning(
            "Failed to fetch seen card fronts for student=%s topic=%r — "
            "falling back to no deduplication.",
            student_id,
            topic_name,
            exc_info=True,
        )
        return []


# ── Output safety (inline) ─────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class _FlashcardVerdict:
    """Outcome of the safety + structural review."""

    status: FlashcardStatus
    reason: str
    safety: content_safety.SafetyVerdict | None = None


async def _review(generated: GeneratedFlashcard) -> _FlashcardVerdict:
    """Run Content Safety + slim structural checks on a generated card.

    Inlined rather than abstracted into a shared service today: the
    flashcard rules are short, the question safety reviewer's shape
    doesn't fit (different types, different leakage patterns), and
    Sprint 5 polish may add SRS-aware ranking that wants to live next
    to the rest of the flashcard logic anyway. Extract if a third
    consumer appears.
    """
    # Structural: cheap, fail-fast.
    structural = _structural_check(generated)
    if structural is not None:
        return _FlashcardVerdict(
            status=FlashcardStatus.rejected,
            reason=f"structural: {structural}",
        )

    # Content safety on the combined text.
    combined = "\n\n".join(s for s in (generated.front, generated.back, generated.explanation) if s)
    safety = await content_safety.analyze_extracted_text(combined)
    if safety.flagged:
        return _FlashcardVerdict(
            status=FlashcardStatus.flagged,
            reason=(
                "Content Safety flagged "
                f"{', '.join(safety.flagged_categories)} "
                f"(max severity {max(safety.severities.values())}/6)."
            ),
            safety=safety,
        )

    return _FlashcardVerdict(
        status=FlashcardStatus.approved,
        reason="Approved.",
    )


def _structural_check(generated: GeneratedFlashcard) -> str | None:
    """Return a failure reason or None when the card passes.

    The two checks worth doing:
    1. Length sanity — a runaway front (model hallucinated the second
       question on the same line) is unrecoverable.
    2. Front ≠ back — a flashcard whose front equals its back is
       useless and reflects a prompt-following failure.
    """
    front = generated.front
    back = generated.back
    if not (_MIN_FRONT_CHARS <= len(front) <= _MAX_FRONT_CHARS):
        return f"front length {len(front)} outside [{_MIN_FRONT_CHARS},{_MAX_FRONT_CHARS}]"
    if not (_MIN_BACK_CHARS <= len(back) <= _MAX_BACK_CHARS):
        return f"back length {len(back)} outside [{_MIN_BACK_CHARS},{_MAX_BACK_CHARS}]"
    if front.strip().casefold() == back.strip().casefold():
        return "front equals back (no recall value)"
    return None


# ── Persistence ─────────────────────────────────────────────────────────────


async def _persist_flashcard(
    *,
    current_user: User,
    workspace_id: str,
    topic_name: str,
    question_doc: Question,
    generated: GeneratedFlashcard,
    verdict: _FlashcardVerdict,
) -> Flashcard:
    """Persist a generated card grounded by a question record."""
    return await _persist_grounded_flashcard(
        current_user=current_user,
        workspace_id=workspace_id,
        topic_name=topic_name,
        document_id=question_doc.document_id,
        source_chunk_ids=question_doc.source_chunk_ids,
        generated=generated,
        verdict=verdict,
    )


async def _persist_grounded_flashcard(
    *,
    current_user: User,
    workspace_id: str,
    topic_name: str,
    document_id: str,
    source_chunk_ids: list[str],
    generated: GeneratedFlashcard,
    verdict: _FlashcardVerdict,
) -> Flashcard:
    """Write the flashcard to Cosmos if the verdict allows.

    Rejected verdicts are NOT persisted — same policy as question
    rejection in Sprint 3.9. Flagged ones get stored with
    moderation_flagged=True for the admin moderation dashboard.
    """
    flashcard = Flashcard(
        **{"_id": f"fc_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        document_id=document_id,
        topic=topic_name,
        front=generated.front,
        back=generated.back,
        explanation=generated.explanation,
        source_chunk_ids=source_chunk_ids,
        status=verdict.status,
        prompt_version=generated.prompt_version,
        moderation_flagged=verdict.status == FlashcardStatus.flagged,
    )

    if verdict.status == FlashcardStatus.rejected:
        logger.warning(
            "Discarding rejected flashcard topic=%s reason=%s",
            topic_name,
            verdict.reason,
        )
        return flashcard

    col = get_collection(current_user.tenant_id, FLASHCARDS)
    await col.insert_one(flashcard.model_dump(by_alias=True))

    if verdict.status == FlashcardStatus.flagged:
        from app.core.database import MODERATION_LOG
        from app.models.moderation import ModerationAction, ModerationLog, ModerationTarget

        entry = ModerationLog(
            **{"_id": f"mod_{uuid4().hex}"},
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            target_type=ModerationTarget.flashcard,
            target_id=flashcard.id,
            action=ModerationAction.flagged,
            performed_by="system",
            reason=verdict.reason,
            azure_safety_score=verdict.safety.max_severity_normalized if verdict.safety else None,
            severities=verdict.safety.severities if verdict.safety else {},
            flagged_categories=verdict.safety.flagged_categories if verdict.safety else [],
        )
        try:
            mod_col = get_collection(current_user.tenant_id, MODERATION_LOG)
            await mod_col.insert_one(entry.model_dump(by_alias=True))
        except Exception:
            logger.exception(
                "Failed to write moderation_log entry for flashcard=%s",
                flashcard.id,
            )

    return flashcard


# ── Cosmos reads ────────────────────────────────────────────────────────────


async def _read_workspace(tenant_id: str, workspace_id: str) -> Workspace:
    col = get_collection(tenant_id, WORKSPACES)
    raw = await col.find_one({"_id": workspace_id, "deleted_at": None})
    if raw is None:
        raise NotFoundError("Workspace", workspace_id)
    return Workspace.model_validate(raw)


async def _load_flashcard(
    *,
    tenant_id: str,
    workspace_id: str,
    flashcard_id: str,
) -> Flashcard:
    """Read flashcard, enforcing workspace scope at the DB filter layer.

    Same defence-in-depth as the question loader: the workspace_id
    filter prevents a student from workspace A rating a flashcard from
    workspace B even if the route's access check were buggy.
    """
    col = get_collection(tenant_id, FLASHCARDS)
    raw = await col.find_one(
        {
            "_id": flashcard_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    if raw is None:
        raise NotFoundError("Flashcard", flashcard_id)
    return Flashcard.model_validate(raw)


# ── Auth helper ─────────────────────────────────────────────────────────────


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    """Mirror :mod:`app.api.documents` and :mod:`app.api.questions`."""
    from app.models.user import UserRole

    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")
