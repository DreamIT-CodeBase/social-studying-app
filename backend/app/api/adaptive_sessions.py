"""Prepare-once adaptive study, revision, and flashcard sessions."""

from __future__ import annotations

import logging
from collections.abc import Iterable
from uuid import uuid4

from fastapi import APIRouter, Depends

from app.api.questions import _record_interaction
from app.core.auth import get_current_user
from app.core.database import (
    ADAPTIVE_SESSIONS,
    FLASHCARD_RATINGS,
    FLASHCARDS,
    GAMIFICATION,
    INTERACTIONS,
    KNOWLEDGE_STATES,
    QUESTION_QUEUE,
    get_collection,
)
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ServiceUnavailableError,
)
from app.models.adaptive_session import (
    AdaptiveAnswerEvaluation,
    AdaptiveLevel,
    AdaptiveSessionMode,
    AdaptiveSessionPlan,
    AdaptiveSessionSummary,
    CompleteAdaptiveSessionRequest,
    EvaluateAdaptiveAnswerRequest,
    PrepareAdaptiveSessionRequest,
    PreparedFlashcard,
    PreparedOption,
    PreparedQuestion,
    SessionAchievementUnlock,
    SessionCompletionReason,
)
from app.models.base import utc_now
from app.models.flashcard import Flashcard, FlashcardRatingEvent, FlashcardStatus
from app.models.question import AnswerSubmission, DifficultyLevel, Question, QuestionStatus
from app.models.user import User, UserRole
from app.services import answer_evaluation, question_pipeline
from app.services import gamification as gamification_service
from app.services import knowledge_state as knowledge_state_service

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/workspaces/{workspace_id}/adaptive-sessions",
    tags=["adaptive-sessions"],
)

_QUESTION_RANGES = {
    AdaptiveLevel.beginner: (5, 7),
    AdaptiveLevel.intermediate: (12, 15),
    AdaptiveLevel.expert: (20, 25),
}
_FLASHCARD_RANGES = {
    AdaptiveLevel.beginner: (3, 4),
    AdaptiveLevel.intermediate: (10, 13),
    AdaptiveLevel.expert: (18, 25),
}
_DURATION_MINUTES = {
    AdaptiveLevel.beginner: 15,
    AdaptiveLevel.intermediate: 25,
    AdaptiveLevel.expert: 30,
}
_COMPLETION_BONUSES = {
    AdaptiveSessionMode.study: 8,
    AdaptiveSessionMode.revision: 5,
    AdaptiveSessionMode.flashcard: 5,
}


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    if user.role == UserRole.tenant_admin:
        return
    if workspace_id not in {m.workspace_id for m in user.workspace_memberships}:
        raise ForbiddenError("You are not a member of this workspace")


def _level_for_mastery(score: float) -> AdaptiveLevel:
    if score < 0.40:
        return AdaptiveLevel.beginner
    if score <= 0.75:
        return AdaptiveLevel.intermediate
    return AdaptiveLevel.expert


def _adaptive_count(score: float, level: AdaptiveLevel, bounds: tuple[int, int]) -> int:
    low, high = bounds
    if level == AdaptiveLevel.beginner:
        position = score / 0.40
    elif level == AdaptiveLevel.intermediate:
        position = (score - 0.40) / 0.35
    else:
        position = (score - 0.75) / 0.25
    position = max(0.0, min(1.0, position))
    return low + round((high - low) * position)


async def _mastery_assessment(*, tenant_id: str, workspace_id: str, student_id: str) -> float:
    """Compute the proficiency signal solely on the backend.

    The score combines the precomputed knowledge model with the complete
    learning history: XP, time-on-task, right/wrong answers, recent
    improvement, attempted difficulty, completed topics, revisions, session
    accuracy, completion rate, and consistency. Missing history is omitted
    and the remaining weights are normalised for honest cold-start behavior.
    """
    knowledge_raw = await get_collection(tenant_id, KNOWLEDGE_STATES).find_one(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    )
    knowledge = float((knowledge_raw or {}).get("overall_mastery", 0.0))

    interaction_cursor = get_collection(tenant_id, INTERACTIONS).find(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    )
    interactions = await interaction_cursor.to_list(length=500)
    interactions.sort(key=lambda row: row.get("answered_at", ""))

    session_cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "status": {"$in": ["completed", "timed_out", "exited"]},
        }
    )
    sessions = await session_cursor.to_list(length=50)
    sessions.sort(key=lambda row: row.get("completed_at", ""), reverse=True)
    sessions = sessions[:10]

    components: list[tuple[float, float]] = [(knowledge, 0.35)]
    if interactions:
        historical = sum(bool(row.get("is_correct")) for row in interactions) / len(interactions)
        recent_rows = interactions[-10:]
        recent = sum(bool(row.get("is_correct")) for row in recent_rows) / len(recent_rows)
        active_days = {str(row.get("answered_at", ""))[:10] for row in interactions[-100:]}
        improvement = max(0.0, min(1.0, 0.5 + recent - historical))
        average_time = sum(
            max(0, int(row.get("time_spent_seconds", 0))) for row in interactions
        ) / len(interactions)
        time_on_task = min(1.0, average_time / 120.0)
        topic_attempts: dict[str, list[bool]] = {}
        for row in interactions:
            topic_attempts.setdefault(str(row.get("topic", "")), []).append(
                bool(row.get("is_correct"))
            )
        completed_topics = sum(
            len(results) >= 3 and sum(results) / len(results) >= 0.75
            for results in topic_attempts.values()
            if results and results[0] is not None
        )
        topic_completion = completed_topics / max(1, len(topic_attempts))
        components.extend(
            [
                (historical, 0.20),
                (recent, 0.10),
                (min(len(active_days), 7) / 7.0, 0.05),
                (improvement, 0.05),
                (time_on_task, 0.03),
                (topic_completion, 0.03),
            ]
        )
    if sessions:
        scored = [
            float(row["accuracy_percentage"]) / 100.0
            for row in sessions
            if row.get("accuracy_percentage") is not None
        ]
        if scored:
            components.append((sum(scored) / len(scored), 0.10))
        completion = sum(float(row.get("completion_ratio", 0.0)) for row in sessions) / len(
            sessions
        )
        components.append((completion, 0.05))
        revision_count = sum(
            row.get("mode") == AdaptiveSessionMode.revision.value for row in sessions
        )
        revision_ratio = revision_count / len(sessions)
        components.append((revision_ratio, 0.02))

        difficulty_values: list[float] = []
        for session in sessions:
            for question in (session.get("plan") or {}).get("questions", []):
                difficulty_values.append(
                    {"beginner": 0.33, "intermediate": 0.66, "advanced": 1.0}.get(
                        str(question.get("difficulty", "beginner")), 0.33
                    )
                )
        if difficulty_values:
            components.append((sum(difficulty_values) / len(difficulty_values), 0.03))

    gamification_raw = await get_collection(tenant_id, GAMIFICATION).find_one(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    )
    if gamification_raw:
        xp_total = max(0, int(gamification_raw.get("xp_total", 0)))
        components.append((xp_total / (xp_total + 500.0), 0.02))

    weight = sum(item_weight for _, item_weight in components)
    score = sum(value * item_weight for value, item_weight in components) / weight
    return max(0.0, min(1.0, score))


async def _history(
    *, tenant_id: str, workspace_id: str, student_id: str
) -> tuple[list[dict], dict[str, float]]:
    cursor = get_collection(tenant_id, INTERACTIONS).find(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    )
    interactions = await cursor.to_list(length=1000)
    interactions.sort(key=lambda row: row.get("answered_at", ""), reverse=True)
    knowledge = await get_collection(tenant_id, KNOWLEDGE_STATES).find_one(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    )
    weak_topics = {
        str(row.get("topic", "")): float(row.get("mastery_score", 0.0))
        for row in (knowledge or {}).get("topics", [])
    }
    return interactions, weak_topics


def _unique_questions(items: Iterable[Question]) -> list[Question]:
    result: list[Question] = []
    seen: set[str] = set()
    for item in items:
        if item.id not in seen:
            seen.add(item.id)
            result.append(item)
    return result


async def _prepare_questions(
    *,
    user: User,
    workspace_id: str,
    target: int,
    level: AdaptiveLevel,
    revision: bool,
) -> list[PreparedQuestion]:
    interactions, weak_topics = await _history(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
        student_id=user.id,
    )
    seen_ids = {str(row.get("question_id")) for row in interactions}
    wrong_order = {
        str(row.get("question_id")): index
        for index, row in enumerate(interactions)
        if not row.get("is_correct", False)
    }
    weak_order = {
        topic.casefold(): index
        for index, (topic, _) in enumerate(sorted(weak_topics.items(), key=lambda pair: pair[1]))
    }
    desired_difficulty = {
        AdaptiveLevel.beginner: DifficultyLevel.beginner.value,
        AdaptiveLevel.intermediate: DifficultyLevel.intermediate.value,
        AdaptiveLevel.expert: DifficultyLevel.advanced.value,
    }[level]

    cursor = get_collection(user.tenant_id, QUESTION_QUEUE).find(
        {
            "workspace_id": workspace_id,
            "status": QuestionStatus.approved.value,
            "deleted_at": None,
        }
    )
    raw_questions = await cursor.to_list(length=1000)

    def priority(row: dict) -> tuple[int, int, int, int, str]:
        question_id = str(row.get("_id", ""))
        difficulty_penalty = 0 if row.get("difficulty") == desired_difficulty else 1
        if revision:
            return (
                0 if question_id in wrong_order else 1,
                wrong_order.get(question_id, 10_000),
                weak_order.get(str(row.get("topic", "")).casefold(), 10_000),
                difficulty_penalty,
                question_id,
            )
        return (
            0 if question_id not in seen_ids else 1,
            difficulty_penalty,
            int(row.get("times_served", 0)),
            0,
            question_id,
        )

    raw_questions.sort(key=priority)
    available: list[Question] = []
    for raw in raw_questions:
        try:
            available.append(Question.model_validate(raw))
        except Exception:
            logger.warning("Skipping malformed queued question id=%s", raw.get("_id"))

    selected = _unique_questions(available)[:target]
    missing = target - len(selected)
    if missing > 0:
        try:
            generated = await question_pipeline._generate_and_persist_batch(
                tenant_id=user.tenant_id,
                workspace_id=workspace_id,
                student_id=user.id,
                user_obj=user,
                revision=revision,
                batch_size=missing,
            )
            selected = _unique_questions([*selected, *generated])[:target]
        except Exception:
            logger.exception("Adaptive session batch generation failed")

    if not selected:
        raise ServiceUnavailableError(
            "No approved questions are ready yet. Please try again after "
            "study material finishes processing.",
            headers={"Retry-After": "30"},
        )

    return [
        PreparedQuestion(
            id=question.id,
            topic=question.topic,
            question_type=question.question_type,
            difficulty=question.difficulty,
            body=question.body,
            options=[
                PreparedOption(key=option.key, text=option.text) for option in question.options
            ],
            answer=question.answer,
            explanation=question.explanation,
            grading_hints=question.grading_hints,
        )
        for question in selected
    ]


async def _prepare_flashcards(
    *, user: User, workspace_id: str, target: int
) -> list[PreparedFlashcard]:
    _, weak_topics = await _history(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
        student_id=user.id,
    )
    weak_order = {
        topic.casefold(): index
        for index, (topic, _) in enumerate(sorted(weak_topics.items(), key=lambda pair: pair[1]))
    }
    cursor = get_collection(user.tenant_id, FLASHCARDS).find(
        {
            "workspace_id": workspace_id,
            "status": FlashcardStatus.approved.value,
            "deleted_at": None,
        }
    )
    raw_cards = await cursor.to_list(length=1000)
    raw_cards.sort(
        key=lambda row: (
            weak_order.get(str(row.get("topic", "")).casefold(), 10_000),
            int(row.get("times_served", 0)),
            str(row.get("_id", "")),
        )
    )
    cards: list[PreparedFlashcard] = []
    for raw in raw_cards:
        try:
            card = Flashcard.model_validate(raw)
        except Exception:
            continue
        cards.append(
            PreparedFlashcard(
                id=card.id,
                topic=card.topic,
                front=card.front,
                back=card.back,
                explanation=card.explanation,
            )
        )
        if len(cards) >= target:
            return cards

    # Approved questions are valid source-backed recall cards and let a new
    # learner receive a full flashcard session without a chain of AI calls.
    question_cursor = get_collection(user.tenant_id, QUESTION_QUEUE).find(
        {
            "workspace_id": workspace_id,
            "status": QuestionStatus.approved.value,
            "deleted_at": None,
        }
    )
    question_rows = await question_cursor.to_list(length=1000)
    question_rows.sort(
        key=lambda row: (
            weak_order.get(str(row.get("topic", "")).casefold(), 10_000),
            str(row.get("_id", "")),
        )
    )
    existing_ids = {card.id for card in cards}
    for raw in question_rows:
        try:
            question = Question.model_validate(raw)
        except Exception:
            continue
        derived_id = f"derived_{question.id}"
        if derived_id in existing_ids:
            continue
        cards.append(
            PreparedFlashcard(
                id=derived_id,
                topic=question.topic,
                front=question.body,
                back=question.answer,
                explanation=question.explanation,
            )
        )
        existing_ids.add(derived_id)
        if len(cards) >= target:
            break

    if not cards:
        raise ConflictError(
            "No source-backed flashcards are ready yet. Complete a study session first."
        )
    return cards


@router.post("/prepare", response_model=AdaptiveSessionPlan)
async def prepare_adaptive_session(
    workspace_id: str,
    request: PrepareAdaptiveSessionRequest,
    current_user: User = Depends(get_current_user),
) -> AdaptiveSessionPlan:
    _assert_workspace_access(current_user, workspace_id)
    mastery = await _mastery_assessment(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
    )
    level = _level_for_mastery(mastery)
    ranges = (
        _FLASHCARD_RANGES if request.mode == AdaptiveSessionMode.flashcard else _QUESTION_RANGES
    )
    target = _adaptive_count(mastery, level, ranges[level])

    questions: list[PreparedQuestion] = []
    flashcards: list[PreparedFlashcard] = []
    if request.mode == AdaptiveSessionMode.flashcard:
        flashcards = await _prepare_flashcards(
            user=current_user, workspace_id=workspace_id, target=target
        )
        item_count = len(flashcards)
        xp_min = -item_count + _COMPLETION_BONUSES[request.mode]
        xp_max = item_count + _COMPLETION_BONUSES[request.mode]
    else:
        questions = await _prepare_questions(
            user=current_user,
            workspace_id=workspace_id,
            target=target,
            level=level,
            revision=request.mode == AdaptiveSessionMode.revision,
        )
        item_count = len(questions)
        xp_min = -item_count + _COMPLETION_BONUSES[request.mode]
        xp_max = item_count + _COMPLETION_BONUSES[request.mode]

    session_id = f"ses_{uuid4().hex}"
    plan = AdaptiveSessionPlan(
        session_id=session_id,
        mode=request.mode,
        level=level,
        mastery_score=mastery,
        duration_minutes=_DURATION_MINUTES[level],
        item_count=item_count,
        estimated_xp_min=xp_min,
        estimated_xp_max=xp_max,
        questions=questions,
        flashcards=flashcards,
    )
    now = utc_now()
    await get_collection(current_user.tenant_id, ADAPTIVE_SESSIONS).insert_one(
        {
            "_id": session_id,
            "tenant_id": current_user.tenant_id,
            "workspace_id": workspace_id,
            "student_id": current_user.id,
            "mode": request.mode.value,
            "level": level.value,
            "mastery_before": mastery,
            "planned_count": item_count,
            "status": "prepared",
            "plan": plan.model_dump(mode="json"),
            "created_at": now,
            "updated_at": now,
        }
    )
    return plan


def _question_from_snapshot(
    *, tenant_id: str, workspace_id: str, snapshot: PreparedQuestion
) -> Question:
    return Question(
        **{"_id": snapshot.id},
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        document_id="adaptive_session_snapshot",
        topic=snapshot.topic,
        question_type=snapshot.question_type,
        difficulty=snapshot.difficulty,
        body=snapshot.body,
        options=[
            {"key": option.key, "text": option.text, "is_correct": option.key == snapshot.answer}
            for option in snapshot.options
        ],
        answer=snapshot.answer,
        explanation=snapshot.explanation,
        grading_hints=snapshot.grading_hints,
        status=QuestionStatus.approved,
    )


@router.post(
    "/{session_id}/evaluate",
    response_model=AdaptiveAnswerEvaluation,
)
async def evaluate_adaptive_answer(
    workspace_id: str,
    session_id: str,
    request: EvaluateAdaptiveAnswerRequest,
    current_user: User = Depends(get_current_user),
) -> AdaptiveAnswerEvaluation:
    """Semantically grade one prepared answer without recording progress.

    The completion endpoint remains authoritative and re-evaluates submitted
    attempts before applying XP and mastery changes.
    """
    _assert_workspace_access(current_user, workspace_id)
    raw = await get_collection(current_user.tenant_id, ADAPTIVE_SESSIONS).find_one(
        {
            "_id": session_id,
            "workspace_id": workspace_id,
            "student_id": current_user.id,
            "status": "prepared",
        }
    )
    if raw is None:
        raise NotFoundError("Adaptive session", session_id)

    plan = AdaptiveSessionPlan.model_validate(raw["plan"])
    snapshot = next(
        (question for question in plan.questions if question.id == request.question_id),
        None,
    )
    if snapshot is None:
        raise ConflictError("The submitted question does not belong to this session.")

    question = _question_from_snapshot(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        snapshot=snapshot,
    )
    result = await answer_evaluation.evaluate(question, request.answer)
    return AdaptiveAnswerEvaluation(
        is_correct=result.is_correct,
        canonical_answer=result.canonical_answer,
        rubric_score=result.rubric_score,
        matched_hints=result.matched_hints,
    )


async def _current_game_level(*, tenant_id: str, workspace_id: str, student_id: str) -> int:
    raw = await get_collection(tenant_id, GAMIFICATION).find_one(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    )
    return max(1, int((raw or {}).get("level", 1)))


def _performance_message(accuracy: float | None, mode: AdaptiveSessionMode) -> str:
    if mode == AdaptiveSessionMode.flashcard:
        return "Review complete. Your ratings will shape the next session."
    value = accuracy or 0.0
    if value >= 85:
        return "Excellent work — you showed strong command of this material."
    if value >= 65:
        return "Good progress — keep practising the explanations you missed."
    if value >= 40:
        return "You are building momentum. Review the missed concepts once more."
    return "Keep going — revisit the explanations and try a focused revision session."


@router.post("/{session_id}/complete", response_model=AdaptiveSessionSummary)
async def complete_adaptive_session(
    workspace_id: str,
    session_id: str,
    request: CompleteAdaptiveSessionRequest,
    current_user: User = Depends(get_current_user),
) -> AdaptiveSessionSummary:
    _assert_workspace_access(current_user, workspace_id)
    sessions = get_collection(current_user.tenant_id, ADAPTIVE_SESSIONS)
    raw = await sessions.find_one(
        {
            "_id": session_id,
            "workspace_id": workspace_id,
            "student_id": current_user.id,
        }
    )
    if raw is None:
        raise NotFoundError("Adaptive session", session_id)
    if raw.get("summary") is not None:
        return AdaptiveSessionSummary.model_validate(raw["summary"])

    claim = await sessions.update_one(
        {"_id": session_id, "status": "prepared"},
        {"$set": {"status": "processing", "updated_at": utc_now()}},
    )
    if claim.matched_count == 0:
        latest = await sessions.find_one({"_id": session_id})
        if latest and latest.get("summary") is not None:
            return AdaptiveSessionSummary.model_validate(latest["summary"])
        raise ConflictError("This session completion is already being processed.")

    plan = AdaptiveSessionPlan.model_validate(raw["plan"])
    mastery_before = float(raw.get("mastery_before", plan.mastery_score))
    completed_count = 0
    correct_count = 0
    xp_gained = 0
    action_xp = 0
    remembered_count = 0
    needs_review_count = 0
    unlocked_badges: dict[str, object] = {}

    if plan.mode == AdaptiveSessionMode.flashcard:
        card_map = {card.id: card for card in plan.flashcards}
        seen_cards: set[str] = set()
        for attempt in request.flashcard_attempts:
            if attempt.flashcard_id in seen_cards:
                continue
            card = card_map.get(attempt.flashcard_id)
            if card is None:
                raise ConflictError("The submitted flashcard does not belong to this session.")
            seen_cards.add(card.id)
            timestamp = utc_now()
            event = FlashcardRatingEvent(
                **{"_id": f"rat_{uuid4().hex}"},
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                flashcard_id=card.id,
                topic=card.topic,
                rating=attempt.rating,
                rated_at=timestamp,
                response_time_ms=attempt.response_time_ms,
                session_progress=len(seen_cards),
            )
            await get_collection(current_user.tenant_id, FLASHCARD_RATINGS).insert_one(
                event.model_dump(by_alias=True)
            )
            delta = await gamification_service.record_flashcard_rating(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                topic=card.topic,
                rating=attempt.rating,
                now=timestamp,
            )
            remembered = attempt.rating.value == "easy"
            base_xp = 1 if remembered else -1
            action_xp += base_xp
            remembered_count += int(remembered)
            needs_review_count += int(not remembered)
            xp_gained += delta.xp_earned
            for badge in delta.badges_unlocked:
                unlocked_badges[badge.badge_id] = badge
            await knowledge_state_service.record_attempt(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                topic=card.topic,
                difficulty=DifficultyLevel.intermediate,
                is_correct=remembered,
                now=timestamp,
            )
        completed_count = len(seen_cards)
        accuracy: float | None = None
    else:
        question_map = {question.id: question for question in plan.questions}
        seen_questions: set[str] = set()
        for attempt in request.question_attempts:
            if attempt.question_id in seen_questions:
                continue
            snapshot = question_map.get(attempt.question_id)
            if snapshot is None:
                raise ConflictError("The submitted question does not belong to this session.")
            seen_questions.add(snapshot.id)
            question = _question_from_snapshot(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                snapshot=snapshot,
            )
            evaluation = await answer_evaluation.evaluate(question, attempt.answer)
            timestamp = utc_now()
            delta = await gamification_service.record_question_attempt(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                topic=question.topic,
                difficulty=question.difficulty,
                is_correct=evaluation.is_correct,
                revision=plan.mode == AdaptiveSessionMode.revision,
                now=timestamp,
            )
            action_xp += 1 if evaluation.is_correct else -1
            await _record_interaction(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                session_id=session_id,
                question=question,
                submission=AnswerSubmission(
                    answer=attempt.answer,
                    time_spent_seconds=attempt.time_spent_seconds,
                ),
                is_correct=evaluation.is_correct,
                xp_earned=delta.xp_earned,
                timestamp=timestamp,
            )
            await knowledge_state_service.record_attempt(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                topic=question.topic,
                difficulty=question.difficulty,
                is_correct=evaluation.is_correct,
                now=timestamp,
            )
            correct_count += int(evaluation.is_correct)
            xp_gained += delta.xp_earned
            for badge in delta.badges_unlocked:
                unlocked_badges[badge.badge_id] = badge
        completed_count = len(seen_questions)
        accuracy = round(correct_count / completed_count * 100.0, 1) if completed_count else 0.0

    fully_completed = completed_count == plan.item_count
    effective_reason = request.completion_reason
    completion_bonus = 0
    if request.completion_reason == SessionCompletionReason.completed and fully_completed:
        completion_bonus = _COMPLETION_BONUSES[plan.mode]
        completion_delta = await gamification_service.record_session_completion(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
            session_type=plan.mode.value,
            perfect=(accuracy == 100.0),
        )
        xp_gained += completion_delta.xp_earned
        for badge in completion_delta.badges_unlocked:
            unlocked_badges[badge.badge_id] = badge
    elif request.completion_reason == SessionCompletionReason.completed:
        effective_reason = SessionCompletionReason.exited

    achievement_xp = sum(int(getattr(badge, "xp_reward", 0)) for badge in unlocked_badges.values())
    mastery_after = await _mastery_assessment(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
    )
    final_level = _level_for_mastery(mastery_after)
    game_level = await _current_game_level(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
    )
    now = utc_now()
    summary = AdaptiveSessionSummary(
        session_id=session_id,
        mode=plan.mode,
        status=effective_reason,
        planned_count=plan.item_count,
        completed_count=completed_count,
        correct_count=correct_count,
        wrong_count=max(0, completed_count - correct_count)
        if plan.mode != AdaptiveSessionMode.flashcard
        else 0,
        accuracy_percentage=accuracy,
        xp_gained=xp_gained,
        action_xp=action_xp,
        completion_bonus=completion_bonus,
        achievement_xp=achievement_xp,
        remembered_count=remembered_count,
        needs_review_count=needs_review_count,
        achievements_unlocked=[
            SessionAchievementUnlock(
                badge_id=badge.badge_id,
                name=badge.name,
                description=badge.description,
                icon=badge.icon,
                xp_reward=badge.xp_reward,
            )
            for badge in unlocked_badges.values()
        ],
        mastery_before=mastery_before,
        mastery_after=mastery_after,
        level=final_level,
        gamification_level=game_level,
        elapsed_seconds=request.elapsed_seconds,
        performance_message=_performance_message(accuracy, plan.mode),
        completed_at=now,
    )
    completion_ratio = completed_count / plan.item_count if plan.item_count else 0.0
    await sessions.update_one(
        {"_id": session_id},
        {
            "$set": {
                "status": effective_reason.value,
                "summary": summary.model_dump(mode="json"),
                "accuracy_percentage": accuracy,
                "correct_count": correct_count,
                "completed_count": completed_count,
                "completion_ratio": completion_ratio,
                "xp_gained": xp_gained,
                "mastery_after": mastery_after,
                "elapsed_seconds": request.elapsed_seconds,
                "completed_at": now,
                "updated_at": now,
            }
        },
    )
    return summary
