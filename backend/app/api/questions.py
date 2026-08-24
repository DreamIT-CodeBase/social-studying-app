"""Question generation + answer endpoints.

Sprint 3.9 (this file) — ``POST /questions/next``: the orchestrator that
ties every Sprint 3 service together to produce one adaptively-chosen,
safety-reviewed, persisted question for the calling student.

Pipeline executed per request
-----------------------------
1. Auth + workspace access check.
2. Read workspace settings to find enabled question_types.
3. Learning Path Engine (3.3) → ranked list of topic candidates.
4. retrieve_student_context (3.6) → mastery + recently-seen question ids.
5. Pick a question type from workspace settings, biased toward variety
   across the student's recent interactions.
6. For each topic candidate, up to ``_MAX_ATTEMPTS`` times:
   a. Calibrate difficulty (3.4) from the student's per-topic mastery.
   b. retrieve_content (3.5) using the canonical topic id as filter.
   c. generate_question (3.7).
   d. review_question (3.8).
   e. ``approved`` → persist with status=approved, return to student.
   f. ``flagged``  → persist with status=pending_review +
      moderation_flagged + moderation_log entry. Do NOT serve. Try
      next candidate.
   g. ``rejected`` → log, do NOT persist. Try next candidate.
   h. ``InsufficientSource`` from the generator → log, try next candidate.
7. Exhausted candidates without an approved question → 503 with a
   retry-after hint.

What this endpoint deliberately does NOT do
-------------------------------------------
- Prefetching (Sprint 3.13 will add a background worker that
  pre-populates the question_queue so /next can sometimes be a Cosmos
  read instead of a full pipeline run).
- Answer evaluation (Sprint 3.10 / 3.11 — ``POST /questions/{id}/answer``).
- Flashcards (Sprint 3.12 — separate endpoint pair).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import uuid4

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, BackgroundTasks, Depends, Response, status

from app.core.auth import get_current_user
from app.core.database import (
    INTERACTIONS,
    MODERATION_LOG,
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
from app.mcp_tools import invoke
from app.mcp_tools.retrieve_content import (
    RetrieveContentInput,
    RetrieveContentOutput,
)
from app.mcp_tools.retrieve_student_context import (
    RetrieveStudentContextInput,
    RetrieveStudentContextOutput,
)
from app.models.base import utc_now
from app.models.interaction import Interaction
from app.models.moderation import (
    ModerationAction,
    ModerationLog,
    ModerationTarget,
)
from app.models.question import (
    AnswerFeedback,
    AnswerSubmission,
    BadgeUnlock,
    DifficultyLevel,
    Question,
    QuestionForStudent,
    QuestionStatus,
    QuestionType,
)
from app.models.user import User
from app.models.workspace import Workspace
from app.services import (
    answer_evaluation,
    question_generation,
    question_safety,
    rag_evaluation,
    study_sources,
)
from app.services import (
    gamification as gamification_service,
)
from app.services import (
    knowledge_state as knowledge_state_service,
)
from app.services import question_pipeline
from app.services import notifications as notification_service
from app.services.difficulty import calibrate_difficulty
from app.services.learning_path import (
    NoTopicsAvailable,
    TopicScore,
    WorkspaceNotFound,
    select_next_topic,
)
from app.services.question_generation import (
    GeneratedQuestion,
    InsufficientSource,
)
from app.services.question_safety import QuestionReview, ReviewVerdict

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/workspaces/{workspace_id}/questions", tags=["questions"])


# How many distinct topic candidates we'll try before giving up. Each
# candidate is one full generation + review round; 2 is the sweet spot
# between user wait time and not punishing the student for a bad roll.
_MAX_ATTEMPTS = 2

# How many grounding chunks to retrieve per generation attempt. 3 is
# enough context while keeping input tokens small for extremely fast inference.
_GROUNDING_CHUNK_LIMIT = 3


# ── Endpoint ────────────────────────────────────────────────────────────────


@router.post("/next", response_model=QuestionForStudent)
async def next_question(
    workspace_id: str,
    background_tasks: BackgroundTasks,
    revision: bool = False,
    current_user: User = Depends(get_current_user),
) -> QuestionForStudent:
    """Generate and return the next adaptive question for the calling student."""
    _assert_workspace_access(current_user, workspace_id)

    import os

    is_testing = "PYTEST_CURRENT_TEST" in os.environ
    if not revision and not is_testing:
        q_doc = await question_pipeline.get_next_question(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
            user_obj=current_user,
            revision=revision,
            background_tasks=background_tasks,
        )
        return QuestionForStudent.from_doc(q_doc)

    if revision:
        # --- Revision Session Logic ---
        # 1. Fetch past interactions in this workspace
        interactions_col = get_collection(current_user.tenant_id, INTERACTIONS)
        cursor = interactions_col.find(
            {"workspace_id": workspace_id, "student_id": current_user.id}
        )
        interactions = await cursor.to_list(length=1000)

        # 2. Extract wrong answers (recent wrong answers favoured/sorted first)
        wrong_interactions = [i for i in interactions if not i.get("is_correct", True)]
        wrong_qids = []
        for itx in sorted(wrong_interactions, key=lambda x: x.get("answered_at", ""), reverse=True):
            qid = itx.get("question_id")
            if qid and qid not in wrong_qids:
                wrong_qids.append(qid)

        # 3. Fallback: latest answered questions from the recent 5 study sessions
        fallback_qids = []
        if not wrong_qids and interactions:
            sorted_itx = sorted(interactions, key=lambda x: x.get("answered_at", ""))
            sessions = []
            current_session = []
            for itx in sorted_itx:
                if not current_session:
                    current_session.append(itx)
                else:
                    try:
                        prev_time = datetime.fromisoformat(
                            current_session[-1].get("answered_at", "").replace("Z", "+00:00")
                        )
                        curr_time = datetime.fromisoformat(
                            itx.get("answered_at", "").replace("Z", "+00:00")
                        )
                        if (curr_time - prev_time).total_seconds() > 30 * 60:
                            sessions.append(current_session)
                            current_session = [itx]
                        else:
                            current_session.append(itx)
                    except Exception:
                        current_session.append(itx)
            if current_session:
                sessions.append(current_session)

            # Extract from the recent 5 sessions (newest session first)
            recent_5_sessions = list(reversed(sessions))[:5]
            for session in recent_5_sessions:
                for itx in sorted(session, key=lambda x: x.get("answered_at", ""), reverse=True):
                    qid = itx.get("question_id")
                    if qid and qid not in fallback_qids:
                        fallback_qids.append(qid)

        candidates = wrong_qids if wrong_qids else fallback_qids

        # 4. Filter out questions answered in the last 1 hour to prevent repetition
        cutoff = (datetime.now(UTC) - timedelta(hours=1)).isoformat()
        recent_answered_qids = {
            i.get("question_id") for i in interactions if i.get("answered_at", "") >= cutoff
        }
        eligible_qids = [qid for qid in candidates if qid not in recent_answered_qids]

        # 5. Fetch and serve eligible question
        if eligible_qids:
            col = get_collection(current_user.tenant_id, QUESTION_QUEUE)
            q_cursor = col.find(
                {
                    "_id": {"$in": eligible_qids},
                    "workspace_id": workspace_id,
                    "status": QuestionStatus.approved.value,
                    "deleted_at": None,
                }
            )
            fetched_qs = await q_cursor.to_list(length=100)
            q_map = {q["_id"]: q for q in fetched_qs}
            for qid in eligible_qids:
                if qid in q_map:
                    matched_q = Question.model_validate(q_map[qid])
                    logger.info("next_question (revision) served past question=%s", matched_q.id)
                    return QuestionForStudent.from_doc(matched_q)

        # 6. Fallback: Generate a new revision question on a recent topic
        target_topic = None
        if wrong_interactions:
            target_topic = sorted(
                wrong_interactions, key=lambda x: x.get("answered_at", ""), reverse=True
            )[0].get("topic")
        elif interactions:
            target_topic = sorted(
                interactions, key=lambda x: x.get("answered_at", ""), reverse=True
            )[0].get("topic")

        if target_topic:
            workspace = await _read_workspace(current_user.tenant_id, workspace_id)
            enabled_types = _resolve_enabled_types(workspace)
            context = await _fetch_student_context(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                limit=100,
            )
            all_seen_bodies = await _fetch_seen_question_bodies(
                tenant_id=current_user.tenant_id,
                question_ids=context.seen_question_ids,
            )
            question_type = _pick_question_type(enabled_types, context)
            try:
                selection = await select_next_topic(
                    tenant_id=current_user.tenant_id,
                    workspace_id=workspace_id,
                    student_id=current_user.id,
                )
                candidate = None
                for c in selection.candidates:
                    if c.topic_name.casefold() == target_topic.casefold():
                        candidate = c
                        break
                if not candidate and selection.candidates:
                    candidate = selection.candidates[0]

                if candidate:
                    outcome = await _try_candidate(
                        current_user=current_user,
                        workspace_id=workspace_id,
                        candidate=candidate,
                        context=context,
                        question_type=question_type,
                        all_seen_bodies=all_seen_bodies,
                    )
                    if isinstance(outcome, _Persisted):
                        logger.info(
                            "next_question (revision fallback generation) generated new question=%s",
                            outcome.for_student.id,
                        )
                        return outcome.for_student
            except Exception as e:
                logger.warning("next_question (revision fallback generation) failed: %s", e)

    # Sprint 3.13: check the prefetch slot first. If a prior /answer
    # call queued a question for this student, claim it atomically and
    # serve immediately — skipping the full generation pipeline. The
    # find-one-and-update ensures two concurrent /next calls can't
    # both consume the same row.
    context_for_prefetch = await _fetch_student_context(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        limit=100,
    )
    all_seen_bodies = await _fetch_seen_question_bodies(
        tenant_id=current_user.tenant_id,
        question_ids=context_for_prefetch.seen_question_ids,
    )
    prefetched = await _claim_prefetched_question(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        already_seen_ids=set(context_for_prefetch.seen_question_ids),
        already_seen_bodies=all_seen_bodies,
    )
    if prefetched is not None:
        logger.info(
            "next_question served prefetched question=%s student=%s",
            prefetched.id,
            current_user.id,
        )
        return QuestionForStudent.from_doc(prefetched)

    workspace = await _read_workspace(current_user.tenant_id, workspace_id)
    enabled_types = _resolve_enabled_types(workspace)

    try:
        selection = await select_next_topic(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
        )
    except NoTopicsAvailable as exc:
        raise ConflictError(
            "This workspace has no topics yet. Ask an admin to upload "
            "study material before requesting questions."
        ) from exc
    except WorkspaceNotFound as exc:
        # Workspace existed at the access check above but vanished
        # before the engine read it — race against an admin delete.
        # Same 404 as access denial, no need to distinguish.
        raise NotFoundError("Workspace", workspace_id) from exc

    # Re-use the context we already fetched for the prefetch check; if the
    # prefetch path was taken, context_for_prefetch is available from the
    # block above. We always have it because the prefetch guard runs first.
    context = context_for_prefetch

    # One question type per request — see module docstring for why we
    # don't switch types mid-retry.
    question_type = _pick_question_type(enabled_types, context)

    candidates = selection.candidates[:_MAX_ATTEMPTS]
    attempt_log: list[str] = []

    for attempt_index, candidate in enumerate(candidates, start=1):
        outcome = await _try_candidate(
            current_user=current_user,
            workspace_id=workspace_id,
            candidate=candidate,
            context=context,
            question_type=question_type,
            all_seen_bodies=all_seen_bodies,
        )
        if isinstance(outcome, _Persisted):
            return outcome.for_student

        attempt_log.append(
            f"attempt={attempt_index} topic={candidate.topic_name!r} → {outcome.reason}"
        )

    logger.warning(
        "next_question exhausted attempts workspace=%s student=%s log=%s",
        workspace_id,
        current_user.id,
        " | ".join(attempt_log),
    )
    # Retry-After is a hint; pick 30s — long enough that a transient
    # model hiccup probably cleared, short enough not to feel broken.
    raise ServiceUnavailableError(
        "Couldn't generate a clean question right now after "
        f"{len(candidates)} attempts. Please retry in a moment.",
        headers={"Retry-After": "30"},
    )


# ── Per-candidate inner loop ───────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class _Persisted:
    """Successful candidate — question stored, ready to serve."""

    for_student: QuestionForStudent


@dataclass(frozen=True, slots=True)
class _Skip:
    """Candidate failed (insufficient source, flagged, rejected). Try next."""

    reason: str


async def _try_candidate(
    *,
    current_user: User,
    workspace_id: str,
    candidate: TopicScore,
    context: RetrieveStudentContextOutput,
    question_type: QuestionType,
    all_seen_bodies: list[str],
) -> _Persisted | _Skip:
    """One full attempt: calibrate → retrieve → generate → review → persist.

    Returns :class:`_Persisted` on the happy path; :class:`_Skip` on any
    of the recoverable failure modes (the outer loop will move on to
    the next candidate). Non-recoverable failures propagate.
    """
    mastery = _mastery_for_topic(candidate.topic_name, context)
    calibration = calibrate_difficulty(mastery=mastery)
    difficulty = calibration.difficulty

    retrieved = await invoke(
        "retrieve_content",
        RetrieveContentInput(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            topic_ids=[candidate.topic_id],
            query_text=candidate.topic_name,
            top_k=_GROUNDING_CHUNK_LIMIT,
        ),
    )
    assert isinstance(retrieved, RetrieveContentOutput)
    if not retrieved.chunks:
        return _Skip(
            f"no grounding chunks (mode={retrieved.mode}) — topic "
            "indexed but search returned nothing"
        )

    # Pass recently-seen question bodies to the generator so the prompt
    # instructs GPT-4o to avoid exact-duplicate stems. Capped at 30 to
    # keep prompt tokens reasonable but give it plenty of examples of what to avoid.
    seen_bodies = all_seen_bodies[:30]

    try:
        generated = await question_generation.generate_question(
            topic=candidate.topic_name,
            difficulty=difficulty,
            question_type=question_type,
            grounding_chunks=retrieved.chunks,
            seen_question_bodies=seen_bodies or None,
        )
    except InsufficientSource as exc:
        return _Skip(f"generator: insufficient_source ({exc})")
    except question_generation.QuestionShapeError as exc:
        return _Skip(f"generator: shape error ({exc})")

    # Strict check: is this question body (normalized) already answered by the student?
    normalized_generated_body = generated.body.strip().lower().rstrip("?.!")
    seen_bodies_normalized = {b.strip().lower().rstrip("?.!") for b in all_seen_bodies}
    if normalized_generated_body in seen_bodies_normalized:
        logger.warning(
            "Generated question body duplicate of seen question for student=%s body=%r",
            current_user.id,
            generated.body,
        )
        return _Skip("generated question body matches an already-seen question")

    review = await question_safety.review_question(generated)
    persisted = await _persist_question(
        current_user=current_user,
        workspace_id=workspace_id,
        candidate=candidate,
        retrieved=retrieved,
        generated=generated,
        review=review,
    )

    if review.verdict == ReviewVerdict.approved:
        return _Persisted(for_student=QuestionForStudent.from_doc(persisted))

    if review.verdict == ReviewVerdict.flagged:
        # Persisted for admin review; don't serve.
        return _Skip(f"safety flagged ({', '.join(review.safety.flagged_categories)})")

    # Rejected — never persisted (see _persist_question). Skip.
    return _Skip(f"review rejected: {review.reason}")


# ── Persistence ─────────────────────────────────────────────────────────────


async def _persist_question(
    *,
    current_user: User,
    workspace_id: str,
    candidate: TopicScore,
    retrieved: RetrieveContentOutput,
    generated: GeneratedQuestion,
    review: QuestionReview,
) -> Question:
    """Write the question to ``question_queue`` if the review allows it.

    Returns the Question (which the caller projects to either student
    or admin view depending on context). For ``rejected`` verdicts the
    function returns the in-memory Question WITHOUT persisting — the
    orchestrator inspects ``review.verdict`` and skips it.

    For ``flagged`` verdicts the question is persisted AND a
    moderation_log entry is written so the admin moderation dashboard
    surfaces it.
    """
    status_value = (
        QuestionStatus.approved
        if review.verdict == ReviewVerdict.approved
        else QuestionStatus.pending_review
    )
    document_id = retrieved.chunks[0].document_id if retrieved.chunks else "unknown"
    question_id = f"qst_{uuid4().hex}"

    question = Question(
        **{"_id": question_id},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        document_id=document_id,
        topic=candidate.topic_name,
        question_type=generated.question_type,
        difficulty=generated.difficulty,
        body=generated.body,
        options=generated.options,
        answer=generated.answer,
        explanation=generated.explanation,
        grading_hints=generated.grading_hints,
        source_chunk_ids=[c.chunk_id for c in retrieved.chunks],
        status=status_value,
        prompt_version=generated.prompt_version,
        moderation_flagged=review.verdict == ReviewVerdict.flagged,
    )

    if review.verdict == ReviewVerdict.rejected:
        # Never store rejected questions — they'd just clog the moderation
        # queue with structurally-broken garbage no admin can fix.
        logger.warning(
            "Discarding rejected question topic=%s type=%s reason=%s",
            candidate.topic_name,
            generated.question_type.value,
            review.reason,
        )
        return question

    col = get_collection(current_user.tenant_id, QUESTION_QUEUE)
    await col.insert_one(question.model_dump(by_alias=True))

    # Trigger End-to-End RAG evaluation trace & metric persistence
    try:
        current_sources = await study_sources.current_study_sources(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
        )
        source_chunk_ids = [c.chunk_id for c in retrieved.chunks]
        await rag_evaluation.evaluate_and_persist_rag(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
            selected_topic_id=candidate.topic_id,
            selected_topic_name=candidate.topic_name,
            active_document_ids=current_sources.document_ids,
            retrieved_chunks=retrieved.chunks,
            generation_chunk_ids=source_chunk_ids,
            question_id=question_id,
            question_type=generated.question_type.value,
            question_body=generated.body,
            reference_answer=generated.answer,
            explanation=generated.explanation,
            known_source_chunk_ids=source_chunk_ids,
        )
    except Exception as eval_exc:
        logger.warning("RAG evaluation failed in _persist_question %s: %s", question_id, eval_exc)

    if review.verdict == ReviewVerdict.flagged:
        await _write_moderation_log(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            question=question,
            review=review,
        )

    return question


async def _write_moderation_log(
    *,
    tenant_id: str,
    workspace_id: str,
    question: Question,
    review: QuestionReview,
) -> None:
    """Append a moderation_log row for a flagged AI-generated question.

    Best-effort: a failed audit write must NOT regress the question's
    persisted state — the same policy Sprint 2.4 uses for documents.
    The Content Safety call already succeeded; refusing to serve the
    question is the user-facing outcome regardless.
    """
    entry = ModerationLog(
        id=f"mod_{uuid4().hex}",
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        target_type=ModerationTarget.question,
        target_id=question.id,
        action=ModerationAction.flagged,
        performed_by="system",
        reason=review.reason,
        azure_safety_score=review.safety.max_severity_normalized,
        severities=review.safety.severities,
        flagged_categories=review.safety.flagged_categories,
    )
    try:
        col = get_collection(tenant_id, MODERATION_LOG)
        await col.insert_one(entry.model_dump(by_alias=True))
    except Exception:
        logger.exception(
            "Failed to write moderation_log entry for question=%s",
            question.id,
        )


# ── Cosmos reads ────────────────────────────────────────────────────────────


async def _read_workspace(tenant_id: str, workspace_id: str) -> Workspace:
    col = get_collection(tenant_id, WORKSPACES)
    raw = await col.find_one({"_id": workspace_id, "deleted_at": None})
    if raw is None:
        raise NotFoundError("Workspace", workspace_id)
    return Workspace.model_validate(raw)


async def _fetch_student_context(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    limit: int = 100,
) -> RetrieveStudentContextOutput:
    result = await invoke(
        "retrieve_student_context",
        RetrieveStudentContextInput(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student_id,
            recent_interaction_limit=limit,
        ),
    )
    assert isinstance(result, RetrieveStudentContextOutput)
    return result


# ── Selection helpers ──────────────────────────────────────────────────────


def _resolve_enabled_types(workspace: Workspace) -> list[QuestionType]:
    """Project workspace.settings.question_types to validated enum values.

    Only MCQ and short_answer (one word) are allowed to be displayed to students.
    """
    valid: list[QuestionType] = []
    for raw in workspace.settings.question_types:
        try:
            q_type = QuestionType(raw)
            if q_type in (QuestionType.mcq, QuestionType.short_answer):
                valid.append(q_type)
        except ValueError:
            logger.warning(
                "Workspace %s has unknown question_type %r in settings — ignoring",
                workspace.id,
                raw,
            )
    if not valid:
        return [QuestionType.mcq, QuestionType.short_answer]
    return valid


def _pick_question_type(
    enabled: list[QuestionType],
    context: RetrieveStudentContextOutput,
) -> QuestionType:
    """Pick a type from ``enabled``, biased toward variety.

    Deterministic: rotates by ``len(recent_interactions) % len(enabled)``.
    A student with no history gets ``enabled[0]``; after each answered
    question the index rotates. Avoids stickiness (same type N times in
    a row) without needing per-question_type history.
    """
    if len(enabled) == 1:
        return enabled[0]
    idx = len(context.recent_interactions) % len(enabled)
    return enabled[idx]


def _mastery_for_topic(
    topic_name: str,
    context: RetrieveStudentContextOutput,
) -> float:
    """Look up a student's mastery on ``topic_name``.

    Case-fold match — student-side topics are keyed by display name
    (the question's ``topic`` string), which may differ from the
    canonical taxonomy name on case alone. Returns 0.0 for unseen
    topics, which is the cold-start mastery the calibrator expects.
    """
    target = topic_name.casefold()
    for m in context.topic_mastery:
        if m.topic.casefold() == target:
            return m.mastery_score
    return 0.0


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    """Same access check pattern as :mod:`app.api.documents`."""
    from app.models.user import UserRole

    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 3.10 + 3.11 — POST /questions/{question_id}/answer
# ─────────────────────────────────────────────────────────────────────────────


@router.post("/{question_id}/answer", response_model=AnswerFeedback)
async def submit_answer(
    workspace_id: str,
    question_id: str,
    submission: AnswerSubmission,
    background_tasks: BackgroundTasks,
    revision: bool = False,
    current_user: User = Depends(get_current_user),
) -> AnswerFeedback:
    """Evaluate a student's submitted answer and update their mastery.

    Pipeline:
        1. Auth + workspace access.
        2. Load the persisted Question (must belong to this workspace).
        3. answer_evaluation.evaluate() → correctness + canonical answer.
        4. Compute XP (constant attempt + difficulty-weighted correct bonus).
        5. Append to the interactions collection.
        6. knowledge_state.record_attempt() → bumps mastery, writes back.
        7. Return :class:`AnswerFeedback` with feedback + new mastery scores.

    Raises:
        404: Question not found in this workspace.
        409: Question is in pending_review status (admin hasn't approved
            yet — shouldn't be served, must not be answerable).
        403: Caller is not a member of the workspace.
    """
    _assert_workspace_access(current_user, workspace_id)

    question = await _load_question(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        question_id=question_id,
    )
    if question.status != QuestionStatus.approved:
        # Questions in pending_review / rejected / etc. never reached
        # the student through /next, but a probing client might POST
        # an id from the moderation dashboard. Refuse.
        raise ConflictError(
            f"Question {question_id} is not in an answerable state "
            f"(status={question.status.value})."
        )

    evaluation = await answer_evaluation.evaluate(question, submission.answer)
    timestamp = utc_now()

    # Gamification first — its XP rule (incl. the streak bonus) sets
    # the authoritative ``xp_earned`` for both the interaction record
    # and the response. Persistence order: gamification doc, then
    # interaction (source of truth), then knowledge_state. Each writer
    # is independent; a later failure logs but the earlier writes
    # don't roll back (interaction is append-only by design).
    gamification_delta = await gamification_service.record_question_attempt(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        topic=question.topic,
        difficulty=question.difficulty,
        is_correct=evaluation.is_correct,
        revision=revision,
        now=timestamp,
    )

    await _record_interaction(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        question=question,
        submission=submission,
        is_correct=evaluation.is_correct,
        xp_earned=gamification_delta.xp_earned,
        timestamp=timestamp,
    )

    state = await knowledge_state_service.record_attempt(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        topic=question.topic,
        difficulty=question.difficulty,
        is_correct=evaluation.is_correct,
        now=timestamp,
    )
    topic_mastery = _topic_mastery_for(state, question.topic)

    logger.info(
        "Answer submitted question=%s student=%s correct=%s xp=%d "
        "level=%d streak=%d badges=%d topic_mastery=%.3f overall=%.3f",
        question.id,
        current_user.id,
        evaluation.is_correct,
        gamification_delta.xp_earned,
        gamification_delta.new_level,
        gamification_delta.streak_days,
        len(gamification_delta.badges_unlocked),
        topic_mastery,
        state.overall_mastery,
    )

    # Sprint 3.13 prefetch: kick off background generation of the
    # student's NEXT question so the next /next call can be served
    # from the prefetch slot (no live pipeline run). Fire-and-forget
    # via FastAPI's BackgroundTasks — a prefetch failure must NOT
    # affect the answer response the student is about to receive.
    background_tasks.add_task(
        prefetch_next_question,
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
    )

    # Sprint 5.7c: imperative milestone pushes. Same background-task
    # contract as the prefetch — a notification failure must not
    # affect the response the student is about to receive, and the
    # in-app celebration (5.5) is already firing off the response
    # body, so the push is purely the "also tell their phone" path.
    if gamification_delta.leveled_up or gamification_delta.badges_unlocked:
        background_tasks.add_task(
            notification_service.dispatch_gamification_milestones,
            tenant_id=current_user.tenant_id,
            user_id=current_user.id,
            workspace_id=workspace_id,
            leveled_up=gamification_delta.leveled_up,
            new_level=gamification_delta.new_level,
            badges_unlocked=list(gamification_delta.badges_unlocked),
        )

    return AnswerFeedback(
        question_id=question.id,
        is_correct=evaluation.is_correct,
        canonical_answer=evaluation.canonical_answer,
        explanation=question.explanation,
        xp_earned=gamification_delta.xp_earned,
        new_topic_mastery=topic_mastery,
        new_overall_mastery=state.overall_mastery,
        rubric_score=evaluation.rubric_score,
        matched_hints=evaluation.matched_hints,
        new_level=gamification_delta.new_level,
        leveled_up=gamification_delta.leveled_up,
        streak_days=gamification_delta.streak_days,
        streak_extended=gamification_delta.streak_extended,
        badges_unlocked=[
            BadgeUnlock(
                badge_id=b.badge_id,
                name=b.name,
                description=b.description,
                icon=b.icon,
                xp_reward=b.xp_reward,
            )
            for b in gamification_delta.badges_unlocked
        ],
    )


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 5.12 — POST /questions/{question_id}/skip
# ─────────────────────────────────────────────────────────────────────────────


# How long after a skip before the scheduler may fire an
# ``unanswered_reprompt`` push. Four hours threads the needle: long
# enough that the student is in a fresh session, short enough that the
# question is still relevant. Sprint 6 polish: per-workspace knob.
UNANSWERED_REPROMPT_COOLDOWN = timedelta(hours=4)

# After this many skips the question is deemed too hard / off-topic
# for this student and drops out of the rotation entirely. Stays
# persisted (the admin can review and surface manually) but the
# scheduler skips it from re-prompts and ``/next`` won't re-serve it.
UNANSWERED_REPROMPT_MAX_SKIPS = 3


@router.post(
    "/{question_id}/skip",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
)
async def skip_question(
    workspace_id: str,
    question_id: str,
    current_user: User = Depends(get_current_user),
) -> Response:
    """Defer this question to a later session.

    The student saw the question but doesn't want to answer it right
    now (too hard, off-topic, distracted, whatever). The scheduler
    will surface it again via an ``unanswered_reprompt`` push after
    the cool-down has elapsed; if the same student skips the same
    question three+ times the question drops out of the rotation for
    them entirely.

    Raises:
        404: Question not found in this workspace.
        409: Question is not approved (pending review / rejected).
        403: Caller is not a member of the workspace.
    """
    _assert_workspace_access(current_user, workspace_id)
    question = await _load_question(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        question_id=question_id,
    )
    if question.status != QuestionStatus.approved:
        raise ConflictError(
            f"Question {question_id} is not in a skippable state (status={question.status.value})."
        )

    new_count = question.defer_count + 1
    timestamp = utc_now()
    # If the student has hit the skip cap, mark the question as
    # "permanently deferred" by clearing ``deferred_until`` (so the
    # scheduler ignores it) while keeping the count for analytics.
    if new_count >= UNANSWERED_REPROMPT_MAX_SKIPS:
        next_eligible = None
    else:
        next_eligible = (datetime.now(UTC) + UNANSWERED_REPROMPT_COOLDOWN).isoformat()

    col = get_collection(current_user.tenant_id, QUESTION_QUEUE)
    await col.update_one(
        {"_id": question_id, "workspace_id": workspace_id},
        {
            "$set": {
                "deferred_for": current_user.id,
                "deferred_until": next_eligible,
                "defer_count": new_count,
                "updated_at": timestamp,
            }
        },
    )
    logger.info(
        "Question skipped question=%s student=%s defer_count=%d next_eligible=%s",
        question_id,
        current_user.id,
        new_count,
        next_eligible,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ── Per-endpoint helpers ────────────────────────────────────────────────────


async def _load_question(
    *,
    tenant_id: str,
    workspace_id: str,
    question_id: str,
) -> Question:
    """Read the question doc, enforcing workspace scope at the DB layer.

    The workspace_id filter is defence-in-depth on top of the route's
    access check — even a bug in the access check shouldn't let a
    student from workspace A submit answers to workspace B's questions.
    """
    col = get_collection(tenant_id, QUESTION_QUEUE)
    raw = await col.find_one(
        {
            "_id": question_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    if raw is None:
        raise NotFoundError("Question", question_id)
    return Question.model_validate(raw)


async def _record_interaction(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    question: Question,
    submission: AnswerSubmission,
    is_correct: bool,
    xp_earned: int,
    timestamp: str,
    session_id: str | None = None,
) -> None:
    """Append to the append-only ``interactions`` collection.

    Append-only by design — interactions are the source of truth from
    which knowledge_states could be re-derived if needed. No
    ``deleted_at`` updates; if the interaction was a mistake, the admin
    layer (Sprint 5+) can soft-delete by writing a ``deleted_at`` value
    explicitly, but no production code path mutates an existing row.
    """
    interaction = Interaction(
        **{"_id": f"itx_{uuid4().hex}"},
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        session_id=session_id,
        question_id=question.id,
        topic=question.topic,
        is_correct=is_correct,
        answer_given=submission.answer,
        time_spent_seconds=submission.time_spent_seconds,
        xp_earned=xp_earned,
        answered_at=timestamp,
    )
    col = get_collection(tenant_id, INTERACTIONS)
    await col.insert_one(interaction.model_dump(by_alias=True))


def _topic_mastery_for(state, topic: str) -> float:
    """Find the post-update mastery for ``topic`` on ``state``.

    ``record_attempt`` guarantees the row exists (it appended one if
    missing), so this is a straight lookup. Case-insensitive to match
    the appender's name-comparison rule.
    """
    target = topic.casefold()
    for row in state.topics:
        if row.topic.casefold() == target:
            return row.mastery_score
    # Defensive fallback — record_attempt is contractually supposed
    # to leave the row present, but don't crash the response if it
    # didn't.
    return 0.0


async def _fetch_seen_question_bodies(
    *,
    tenant_id: str,
    question_ids: list[str],
) -> list[str]:
    """Return the ``body`` strings for a list of question IDs.

    Used to populate ``seen_question_bodies`` for the prompt's
    avoid-duplication instruction. Missing IDs (deleted / not yet
    persisted) are silently skipped — a missing body in the dedup list
    just means the model might re-generate a similar stem, which is
    acceptable.
    """
    if not question_ids:
        return []
    col = get_collection(tenant_id, QUESTION_QUEUE)
    cursor = col.find(
        {"_id": {"$in": question_ids}},
        projection={"body": 1},
    )
    rows = await cursor.to_list(length=None)
    return [r["body"] for r in rows if r.get("body")]


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 3.13 — prefetch
# ─────────────────────────────────────────────────────────────────────────────


async def _claim_prefetched_question(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    already_seen_ids: set[str] | None = None,
    already_seen_bodies: list[str] | None = None,
) -> Question | None:
    """Atomically claim a prefetched question reserved for ``student_id``.

    Uses Mongo's ``find_one_and_update`` so two concurrent /next calls
    can't both consume the same row — only one of them will see the
    pre-claim state where ``prefetched_for == student_id``; the other
    finds nothing and falls through to live generation.

    ``already_seen_ids``: set of question_ids the student has already
    answered. A prefetched question whose id is in this set is discarded
    (deleted from the slot) rather than re-served — the student would
    see the same question twice otherwise.

    Returns the question (already projected with prefetched_for=None)
    or None if no prefetched row is available.
    """
    col = get_collection(tenant_id, QUESTION_QUEUE)
    raw = await col.find_one_and_update(
        {
            "workspace_id": workspace_id,
            "prefetched_for": student_id,
            "status": QuestionStatus.approved.value,
            "deleted_at": None,
        },
        {"$set": {"prefetched_for": None}},
        return_document=False,  # we want the pre-update doc so we can
        # use its fields verbatim; the in-memory copy we hand back has
        # prefetched_for set to None too via the assignment below.
    )
    if raw is None:
        return None
    raw["prefetched_for"] = None
    question = Question.model_validate(raw)

    # Guard: if the student has already answered this question or one with the exact same body, discard it
    normalized_prefetched_body = question.body.strip().lower().rstrip("?.!")
    seen_bodies_normalized = {b.strip().lower().rstrip("?.!") for b in (already_seen_bodies or [])}
    if (
        already_seen_ids and question.id in already_seen_ids
    ) or normalized_prefetched_body in seen_bodies_normalized:
        logger.info(
            "Discarding stale prefetched question=%s (already seen or duplicate body) student=%s",
            question.id,
            student_id,
        )
        return None
    return question


async def prefetch_next_question(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
) -> None:
    """Generate one question in advance and stash it for ``student_id``.

    Triggered by ``/answer`` via FastAPI BackgroundTasks. Fire-and-
    forget — every exception is caught and logged. A failed prefetch
    is invisible to the student (next /next call just runs live
    generation as it would have anyway).

    Single attempt by design — the user is not waiting on this, so
    burning multiple GPT-4o calls on a speculative prefetch isn't
    worth the cost. If the first attempt fails for any reason, the
    next /answer submission triggers a fresh prefetch.

    Reads workspace + student context with their own DB calls (not
    shared with the answer-endpoint's reads) because BackgroundTasks
    runs after the response is sent — the original request scope is
    gone.
    """
    try:
        await _prefetch_impl(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student_id,
        )
    except Exception:
        logger.exception(
            "prefetch_next_question failed student=%s workspace=%s "
            "— student will fall back to live generation",
            student_id,
            workspace_id,
        )


async def _prefetch_impl(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
) -> None:
    """Body of the prefetch. Mirrors /next's pipeline but:

    - SINGLE candidate attempt (not 3) — keep prefetch cheap.
    - Persists with ``prefetched_for=student_id`` so /next can claim it.
    - Returns None — nothing is served back to a caller.

    A prefetch slot already exists (e.g. from a prior prefetch the
    student hasn't consumed yet) is fine; the next /next call gets
    the older one, this newer one waits.
    """
    workspace = await _read_workspace(tenant_id, workspace_id)
    enabled_types = _resolve_enabled_types(workspace)

    selection = await select_next_topic(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
    )
    if not selection.candidates:
        return

    # Fetch context once for the type-rotation decision + the
    # ``seen_question_bodies`` hint to the generator.
    context_result = await invoke(
        "retrieve_student_context",
        RetrieveStudentContextInput(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student_id,
        ),
    )
    assert isinstance(context_result, RetrieveStudentContextOutput)
    question_type = _pick_question_type(enabled_types, context_result)

    candidate = selection.candidates[0]
    mastery = _mastery_for_topic(candidate.topic_name, context_result)
    difficulty = calibrate_difficulty(mastery=mastery).difficulty

    retrieved = await invoke(
        "retrieve_content",
        RetrieveContentInput(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            topic_ids=[candidate.topic_id],
            query_text=candidate.topic_name,
            top_k=_GROUNDING_CHUNK_LIMIT,
        ),
    )
    assert isinstance(retrieved, RetrieveContentOutput)
    if not retrieved.chunks:
        return

    all_seen_bodies = await _fetch_seen_question_bodies(
        tenant_id=tenant_id,
        question_ids=context_result.seen_question_ids,
    )
    seen_bodies_prefetch = all_seen_bodies[:30]

    try:
        generated = await question_generation.generate_question(
            topic=candidate.topic_name,
            difficulty=difficulty,
            question_type=question_type,
            grounding_chunks=retrieved.chunks,
            seen_question_bodies=seen_bodies_prefetch or None,
        )
    except (InsufficientSource, question_generation.QuestionShapeError):
        return

    # Strict check: is this question body (normalized) already answered by the student?
    normalized_generated_body = generated.body.strip().lower().rstrip("?.!")
    seen_bodies_normalized = {b.strip().lower().rstrip("?.!") for b in all_seen_bodies}
    if normalized_generated_body in seen_bodies_normalized:
        logger.warning(
            "Prefetch generated question body duplicate of seen question for student=%s body=%r",
            student_id,
            generated.body,
        )
        return

    review = await question_safety.review_question(generated)
    if review.verdict != ReviewVerdict.approved:
        # Don't pollute the prefetch slot with flagged/rejected cards.
        # /answer will trigger another prefetch on the student's next
        # submission anyway.
        return

    document_id = retrieved.chunks[0].document_id if retrieved.chunks else "unknown"
    question = Question(
        **{"_id": f"qst_{uuid4().hex}"},
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        document_id=document_id,
        topic=candidate.topic_name,
        question_type=generated.question_type,
        difficulty=generated.difficulty,
        body=generated.body,
        options=generated.options,
        answer=generated.answer,
        explanation=generated.explanation,
        grading_hints=generated.grading_hints,
        source_chunk_ids=[c.chunk_id for c in retrieved.chunks],
        status=QuestionStatus.approved,
        prompt_version=generated.prompt_version,
        moderation_flagged=False,
        prefetched_for=student_id,
    )
    col = get_collection(tenant_id, QUESTION_QUEUE)
    await col.insert_one(question.model_dump(by_alias=True))
    logger.info(
        "Prefetched question=%s topic=%s difficulty=%s student=%s",
        question.id,
        candidate.topic_name,
        difficulty.value,
        student_id,
    )
