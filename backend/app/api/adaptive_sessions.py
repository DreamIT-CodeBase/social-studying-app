"""Prepare-once adaptive study, revision, and flashcard sessions."""

from __future__ import annotations

import asyncio
import hashlib
import logging
import re
import unicodedata
from collections.abc import Iterable
from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends

from app.api import flashcards as flashcards_api
from app.api.questions import _record_interaction
from app.core.auth import get_current_user
from app.core.database import (
    ADAPTIVE_SESSIONS,
    CHUNKS,
    DOCUMENTS,
    FLASHCARD_RATINGS,
    FLASHCARDS,
    GAMIFICATION,
    INTERACTIONS,
    KNOWLEDGE_STATES,
    QUESTION_QUEUE,
    cosmos_retry,
    get_collection,
)
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ServiceUnavailableError,
)
from app.mcp_tools.retrieve_content import (
    RetrieveContentInput,
    RetrievedChunk,
    retrieve_content,
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
from app.models.question import (
    AnswerSubmission,
    DifficultyLevel,
    Question,
    QuestionStatus,
    QuestionType,
)
from app.models.user import User, UserRole
from app.services import (
    answer_evaluation,
    flashcard_generation,
    question_pipeline,
    question_validation,
    study_sources,
)
from app.services import gamification as gamification_service
from app.services import knowledge_state as knowledge_state_service
from app.services.subject_classifier import classify_subject_from_text

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
_MINUTES_PER_ITEM = 2  # kept for XP calculations only — not used for duration
# Per-type time allocations (seconds). These drive the session clock.
_SECONDS_PER_QUESTION_TYPE: dict[str, int] = {
    "mcq": 60,  # 1 minute — answer from options, quick recall
    "true_false": 50,  # 50 seconds — binary choice
    "short_answer": 120,  # 2 minutes — brief written response
    "long_answer": 240,  # 4 minutes — medium/long written answer
    "mathematical": 120,  # 2 minutes — calculation, similar to short answer
}
_DEFAULT_QUESTION_SECONDS = 120  # fallback for unknown types
_SECONDS_PER_FLASHCARD = 30  # 30 seconds per flashcard (flip + rate)
_COMPLETION_BONUSES = {
    AdaptiveSessionMode.study: 8,
    AdaptiveSessionMode.revision: 5,
    AdaptiveSessionMode.flashcard: 5,
}
_MAX_GENERATED_FLASHCARDS_PER_PREPARE = 25

# Self-study is a synthetic single-owner workspace (id ``wsp_self_{user_id}``).
# Each fresh material snapshot grants a bounded number of non-repeating
# sessions per mode; once consumed the learner is told to upload more material.
# Revision is deliberately uncapped — it re-practises previously wrong answers.
_SELF_STUDY_PREFIX = "wsp_self_"
_MAX_SELF_STUDY_SESSIONS = 4
_CAPPED_MODES = frozenset({AdaptiveSessionMode.study, AdaptiveSessionMode.flashcard})
# Background top-up sizes — generated after a session is served so the next
# session reads from a warm pool instead of blocking on generation. Bounded so
# a burst of prepares can't run away with generation cost.
_QUESTION_TOPUP_MIN = 12
_QUESTION_TOPUP_MAX = 25
_FLASHCARD_TOPUP_MIN = 8
_MAX_DAILY_SESSIONS_PER_USER = 8


def _is_self_study(workspace_id: str) -> bool:
    return workspace_id.startswith(_SELF_STUDY_PREFIX)


def _source_snapshot(
    sources: study_sources.CurrentStudySources,
    subject: str | None = None,
    subcategory: str | None = None,
) -> str:
    """Stable short hash of the current ready-document set (optionally scoped to subject and subcategory).

    The session cap and idempotency key are scoped to this snapshot so
    uploading new material grants a fresh batch of sessions while the previous
    snapshot's consumed sessions no longer block the learner.
    """
    raw = "|".join(sorted(sources.document_ids))
    if subject:
        raw = f"{raw}#{subject.strip().casefold()}"
    if subcategory:
        raw = f"{raw}#sub:{subcategory.strip().casefold()}"
    digest = hashlib.sha256(raw.encode("utf-8"))
    return digest.hexdigest()[:16]


def _session_duration_minutes(
    questions: list[PreparedQuestion],
    flashcards: list[PreparedFlashcard],
) -> int:
    """Compute the session time budget from the actual item types and count."""
    total_seconds = sum(
        _SECONDS_PER_QUESTION_TYPE.get(q.question_type, _DEFAULT_QUESTION_SECONDS)
        for q in questions
    )
    total_seconds += len(flashcards) * _SECONDS_PER_FLASHCARD
    # Ensure at least 1 minute and round up to nearest full minute.
    return max(1, -(-total_seconds // 60))  # ceiling division


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


_COMMON_QUESTION_TEMPLATES = (
    "which of the following is the solution to the equation",
    "which of the following is the solution to",
    "which of the following is the value of",
    "which of the following is",
    "what is the solution to the equation",
    "what is the solution to",
    "what is the value of x in the equation",
    "what is the value of x in",
    "what is the value of",
    "what is the value of x",
    "solve for x in the equation",
    "solve for x in",
    "solve the equation",
    "solve for x",
    "find the value of x in the equation",
    "find the value of x in",
    "find the value of x",
    "find the value of",
    "determine the value of x in",
    "determine the value of x",
    "determine the solution to",
    "find the solution to",
    "find x",
    "solve",
)


def _question_fingerprint(body: str) -> str:
    """Return a stable comparison key for a question stem.

    Detects mathematical equations and creates a canonical equation signature
    (e.g. eq:2(x+3)=16, eq:8x=40), and strips conversational question templates
    so reworded question stems or questions with shuffled options for the same
    underlying problem are recognized as duplicates.
    """
    eq_info = question_validation.extract_equation(body)
    if eq_info is not None:
        var_name, lhs, rhs = eq_info
        clean_lhs = re.sub(r"\s+", "", lhs.casefold())
        clean_rhs = re.sub(r"\s+", "", rhs.casefold())
        return f"eq:{clean_lhs}={clean_rhs}"

    normalized = unicodedata.normalize("NFKC", body).casefold()
    normalized = re.sub(r"[^\w\s]", " ", normalized)
    normalized = " ".join(normalized.split())

    for tpl in _COMMON_QUESTION_TEMPLATES:
        if normalized.startswith(tpl):
            stripped = normalized[len(tpl):].strip()
            if stripped:
                return stripped

    return normalized


def _unique_questions(items: Iterable[Question]) -> list[Question]:
    result: list[Question] = []
    seen_ids: set[str] = set()
    seen_bodies: set[str] = set()
    for item in items:
        fingerprint = _question_fingerprint(item.body)
        if item.id in seen_ids or fingerprint in seen_bodies:
            continue
        seen_ids.add(item.id)
        seen_bodies.add(fingerprint)
        result.append(item)
    return result


async def _reserved_questions(
    *, tenant_id: str, workspace_id: str, student_id: str
) -> tuple[set[str], set[str]]:
    """Questions already allocated to unfinished sessions for this learner.

    Preparing a second session before completing the first must not return the
    same questions. Completed sessions are covered by interaction history.
    """
    cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "status": "prepared",
        }
    )
    rows = await cursor.to_list(length=50)
    questions = [
        question for row in rows for question in (row.get("plan") or {}).get("questions", [])
    ]
    ids = {str(question["id"]) for question in questions if question.get("id")}
    fingerprints = {
        _question_fingerprint(str(question["body"]))
        for question in questions
        if question.get("body")
    }
    return ids, fingerprints


def _flashcard_fingerprint(front: str, back: str) -> str:
    """Identify equivalent cards even when they have different record IDs."""
    return f"{_question_fingerprint(front)}|{_question_fingerprint(back)}"


def _unique_flashcards(items: Iterable[PreparedFlashcard]) -> list[PreparedFlashcard]:
    result: list[PreparedFlashcard] = []
    seen_ids: set[str] = set()
    seen_content: set[str] = set()
    for item in items:
        fingerprint = _flashcard_fingerprint(item.front, item.back)
        if item.id in seen_ids or fingerprint in seen_content:
            continue
        seen_ids.add(item.id)
        seen_content.add(fingerprint)
        result.append(item)
    return result


async def _flashcard_history(
    *, tenant_id: str, workspace_id: str, student_id: str
) -> tuple[set[str], set[str], list[str]]:
    rating_cursor = get_collection(tenant_id, FLASHCARD_RATINGS).find(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "deleted_at": None,
        }
    )
    rating_rows = await rating_cursor.to_list(length=5000)
    ids = {str(row["flashcard_id"]) for row in rating_rows if row.get("flashcard_id")}

    # A card counts as seen when it was delivered in a prior session plan, not
    # only when it was rated. This covers sessions the learner exited or let
    # time out after seeing some/all of their prepared cards.
    session_cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "mode": AdaptiveSessionMode.flashcard.value,
            "status": {"$ne": "prepared"},
        }
    )
    session_rows = await session_cursor.to_list(length=500)
    cards = [card for row in session_rows for card in (row.get("plan") or {}).get("flashcards", [])]
    ids.update(str(card["id"]) for card in cards if card.get("id"))
    fingerprints = {
        _flashcard_fingerprint(str(card["front"]), str(card["back"]))
        for card in cards
        if card.get("front") and card.get("back")
    }
    fronts = [str(card["front"]) for card in cards if card.get("front")]
    return ids, fingerprints, fronts


async def _reserved_flashcards(
    *, tenant_id: str, workspace_id: str, student_id: str
) -> tuple[set[str], set[str]]:
    """Cards allocated to another unfinished flashcard session."""
    cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "mode": AdaptiveSessionMode.flashcard.value,
            "status": "prepared",
        }
    )
    rows = await cursor.to_list(length=50)
    cards = [card for row in rows for card in (row.get("plan") or {}).get("flashcards", [])]
    ids = {str(card["id"]) for card in cards if card.get("id")}
    fingerprints = {
        _flashcard_fingerprint(str(card["front"]), str(card["back"]))
        for card in cards
        if card.get("front") and card.get("back")
    }
    return ids, fingerprints


async def _question_session_history(
    *, tenant_id: str, workspace_id: str, student_id: str
) -> tuple[set[str], set[str], list[str]]:
    """Return IDs, body fingerprints, and raw bodies of every question already delivered
    to this student in any past adaptive session (study or revision), regardless
    of whether the student actually submitted an answer.

    This supplements the INTERACTIONS collection (which only records answered
    questions) to prevent questions from reappearing after a student exits or
    times out without answering.
    """
    cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "mode": {"$in": [AdaptiveSessionMode.study.value, AdaptiveSessionMode.revision.value]},
        }
    )
    rows = await cursor.to_list(length=500)
    questions = [q for row in rows for q in (row.get("plan") or {}).get("questions", [])]
    ids = {str(q["id"]) for q in questions if q.get("id")}
    fingerprints = {_question_fingerprint(str(q["body"])) for q in questions if q.get("body")}
    bodies = [str(q["body"]) for q in questions if q.get("body")]
    return ids, fingerprints, bodies


async def _current_grounding_chunks(
    *,
    tenant_id: str,
    workspace_id: str,
    topic: str,
    current_document_ids: frozenset[str],
) -> list[RetrievedChunk]:
    """Retrieve grounding only from the current ready source snapshot.

    Search can briefly lag a newly indexed document or rank an older scrape
    first. The Cosmos fallback keeps session preparation source-backed while
    guaranteeing that superseded document versions are never used.
    """
    chunks: list[RetrievedChunk] = []
    try:
        retrieved = await retrieve_content(
            RetrieveContentInput(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                query_text=topic,
                top_k=50,
            )
        )
        chunks.extend(
            chunk for chunk in retrieved.chunks if chunk.document_id in current_document_ids
        )
    except Exception:
        logger.exception(
            "Flashcard source retrieval failed workspace=%s topic=%s",
            workspace_id,
            topic,
        )

    seen_chunk_ids = {chunk.chunk_id for chunk in chunks}
    if len(chunks) < 5:
        cursor = get_collection(tenant_id, CHUNKS).find(
            {
                "workspace_id": workspace_id,
                "document_id": {"$in": sorted(current_document_ids)},
                "deleted_at": None,
            }
        )
        rows = await cursor.to_list(length=200)
        topic_terms = set(re.findall(r"[a-z0-9]+", topic.casefold()))
        rows.sort(
            key=lambda row: (
                -len(
                    topic_terms & set(re.findall(r"[a-z0-9]+", str(row.get("text", "")).casefold()))
                ),
                str(row.get("document_id", "")),
                int(row.get("chunk_index", 0)),
            )
        )
        for row in rows:
            chunk_id = str(row.get("_id", ""))
            document_id = str(row.get("document_id", ""))
            text = str(row.get("text", "")).strip()
            if (
                not chunk_id
                or chunk_id in seen_chunk_ids
                or document_id not in current_document_ids
                or not text
            ):
                continue
            chunks.append(
                RetrievedChunk(
                    chunk_id=chunk_id,
                    chunk_index=int(row.get("chunk_index", 0)),
                    document_id=document_id,
                    text=text,
                    topic_ids=[str(value) for value in row.get("topic_ids") or []],
                    score=0.0,
                )
            )
            seen_chunk_ids.add(chunk_id)
            if len(chunks) >= 5:
                break
    return chunks[:5]


async def _prepare_questions(
    *,
    user: User,
    workspace_id: str,
    target: int,
    level: AdaptiveLevel,
    revision: bool,
    subject: str | None = None,
    subcategory: str | None = None,
    question_type: QuestionType | None = None,
) -> list[PreparedQuestion]:
    current_sources = await study_sources.current_study_sources(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
    )
    if not current_sources.document_ids:
        raise ConflictError(
            "No ready study material is available for questions. Wait for the latest "
            "source to finish processing, then try again."
        )
    interactions, weak_topics = await _history(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
        student_id=user.id,
    )
    # seen_ids: questions recorded via answer submission (INTERACTIONS)
    seen_ids = {str(row.get("question_id")) for row in interactions}
    # Also add IDs from past session plans that may not have been answered
    # (e.g., student exited or timed out). Fixes Bug 6 — no cross-session repeats.
    session_seen_ids, session_seen_fingerprints, session_seen_bodies = await _question_session_history(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
        student_id=user.id,
    )
    seen_ids |= session_seen_ids
    reserved_ids, reserved_fingerprints = await _reserved_questions(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
        student_id=user.id,
    )

    weak_order = {topic.casefold(): i for i, topic in enumerate(weak_topics)}

    col = get_collection(user.tenant_id, QUESTION_QUEUE)
    q_query: dict[str, Any] = {
        "workspace_id": workspace_id,
        "status": QuestionStatus.approved.value,
        "deleted_at": None,
    }
    if current_sources.document_ids:
        q_query["document_id"] = {"$in": sorted(current_sources.document_ids)}
    cursor = col.find(q_query)
    all_raw = await cosmos_retry(lambda: cursor.to_list(length=600))

    # Weakest topics first, with stable secondary sort by id
    all_raw.sort(
        key=lambda row: (
            weak_order.get(str(row.get("topic", "")).casefold(), 10_000),
            str(row.get("_id", "")),
        )
    )

    available: list[Question] = []
    for raw in all_raw:
        try:
            question = Question.model_validate(raw)
            if question.document_id in current_sources.document_ids:
                available.append(question)
        except Exception:
            logger.warning("Skipping malformed queued question id=%s", raw.get("_id"))

    doc_subjects: dict[str, str] = {}
    doc_subcats: dict[str, set[str]] = {}
    if subject or subcategory:
        doc_col = get_collection(user.tenant_id, DOCUMENTS)
        doc_cursor = doc_col.find(
            {"_id": {"$in": list(current_sources.document_ids)}},
            {"filename": 1, "topic_tags": 1, "category": 1, "subcategory": 1},
        )
        async for doc_raw in doc_cursor:
            fn = doc_raw.get("filename", "")
            cat = doc_raw.get("category")
            subcat = doc_raw.get("subcategory")
            tags: set[str] = set()
            if subcat:
                tags.add(str(subcat).casefold())
            for tag in doc_raw.get("topic_tags") or []:
                tag_name = tag.get("name") if isinstance(tag, dict) else str(tag)
                tags.add(str(tag_name).casefold())
            doc_subcats[str(doc_raw["_id"])] = tags

            s = cat or classify_subject_from_text(fn)
            if not s or s.casefold() == "study":
                for tag_name in tags:
                    ts = classify_subject_from_text(tag_name)
                    if subject and ts.casefold() == subject.casefold():
                        s = subject
                        break
            doc_subjects[str(doc_raw["_id"])] = s or ""

        if subject:
            def matches_subject(q: Question) -> bool:
                return (
                    classify_subject_from_text(q.topic).casefold() == subject.casefold()
                    or doc_subjects.get(q.document_id, "").casefold() == subject.casefold()
                )

            available = [q for q in available if matches_subject(q)]

        if subcategory:
            subcat_clean = subcategory.strip().casefold()
            sub_terms = set(re.findall(r"[a-z0-9]+", subcat_clean))

            def matches_subcat(q: Question) -> bool:
                q_top = q.topic.strip().casefold()
                if subcat_clean in q_top or q_top in subcat_clean:
                    return True
                q_terms = set(re.findall(r"[a-z0-9]+", q_top))
                return bool(sub_terms and len(sub_terms & q_terms) >= max(1, len(sub_terms) // 2))

            available = [q for q in available if matches_subcat(q)]

    if question_type:
        available = [q for q in available if q.question_type == question_type]

    # Combine fingerprints from answer history AND session plan history (Bug 6 fix)
    seen_fingerprints = session_seen_fingerprints | {
        _question_fingerprint(question.body) for question in available if question.id in seen_ids
    }

    # A normal study session is fresh-only. Previously answered questions and
    # questions delivered in prior session plans (even unanswered) and questions
    # allocated to another unfinished session are not eligible.
    if _is_self_study(workspace_id):
        target = 5

    # In self-study workspace, always generate all 5 questions freshly for every session.
    # Revision deliberately retains history so incorrect questions can be re-practiced.
    if revision:
        eligible = available
    else:
        eligible = [
            question
            for question in available
            if question.id not in seen_ids
            and question.id not in reserved_ids
            and _question_fingerprint(question.body) not in seen_fingerprints
            and _question_fingerprint(question.body) not in reserved_fingerprints
        ]
        if not eligible and available and not _is_self_study(workspace_id) and not subcategory and not question_type:
            eligible = available

    selected = _unique_questions(eligible)[:target]
    missing = target - len(selected)
    should_generate = missing > 0 and (subcategory or question_type or len(selected) < 2 or _is_self_study(workspace_id))
    if should_generate:
        # In self-study workspace, grant sufficient generation time (60s) for the
        # LLM to extract from grounding chunks and generate high quality questions freshly.
        gen_timeout = 60.0 if _is_self_study(workspace_id) else (15.0 if (subcategory or question_type) else 5.0)
        gen_batch = missing if _is_self_study(workspace_id) else (min(missing, 3) if (subcategory or question_type) else min(missing, 2))
        try:
            generated = await asyncio.wait_for(
                question_pipeline._generate_and_persist_batch(
                    tenant_id=user.tenant_id,
                    workspace_id=workspace_id,
                    student_id=user.id,
                    user_obj=user,
                    revision=revision,
                    subject=subject,
                    target_topic=subcategory,
                    target_type=question_type,
                    batch_size=gen_batch,
                    extra_seen_bodies=session_seen_bodies,
                ),
                timeout=gen_timeout,
            )
            if not revision:
                # Filter only for integrity and historical uniqueness — do not discard
                # freshly generated items with naive topic text heuristics
                generated = [
                    question
                    for question in generated
                    if question.document_id in current_sources.document_ids
                    and question.id not in seen_ids
                    and question.id not in reserved_ids
                    and _question_fingerprint(question.body) not in seen_fingerprints
                    and _question_fingerprint(question.body) not in reserved_fingerprints
                    and _question_fingerprint(question.body) not in session_seen_fingerprints
                    and (not question_type or question.question_type == question_type)
                ]
            else:
                if question_type:
                    generated = [q for q in generated if q.question_type == question_type]
            selected = _unique_questions([*selected, *generated])[:target]
            if len(selected) < target and not revision:
                try:
                    topup_needed = target - len(selected)
                    topup_generated = await asyncio.wait_for(
                        question_pipeline._generate_and_persist_batch(
                            tenant_id=user.tenant_id,
                            workspace_id=workspace_id,
                            current_sources=current_sources,
                            candidate_topics=[],
                            student_id=user.id,
                            user_obj=user,
                            revision=revision,
                            subject=subject,
                            target_topic=subcategory,
                            target_type=question_type,
                            batch_size=max(topup_needed + 3, 5),
                            extra_seen_bodies=[*session_seen_bodies, *(q.body for q in selected)],
                        ),
                        timeout=15.0,
                    )
                    topup_clean = [
                        q for q in topup_generated
                        if q.document_id in current_sources.document_ids
                        and q.id not in seen_ids
                        and q.id not in reserved_ids
                        and _question_fingerprint(q.body) not in seen_fingerprints
                        and _question_fingerprint(q.body) not in session_seen_fingerprints
                        and (not question_type or q.question_type == question_type)
                    ]
                    selected = _unique_questions([*selected, *topup_clean])[:target]
                except Exception:
                    logger.debug("Top-up question generation skipped")
        except TimeoutError:
            logger.info("Synchronous question generation timed out; serving fast available questions")
        except Exception:
            logger.exception("Adaptive session batch generation failed")

    if not selected:
        if available and not _is_self_study(workspace_id):
            selected = available[:target]
        elif not _is_self_study(workspace_id):
            fb_plan = _build_guaranteed_fallback_plan(
                workspace_id=workspace_id,
                user_id=user.id,
                tenant_id=user.tenant_id,
                mode=AdaptiveSessionMode.study,
                level=level,
                mastery=0.0,
                subject=subject,
                subcategory=subcategory,
            )
            return fb_plan.questions
        else:
            raise ServiceUnavailableError(
                "Your study questions are being prepared from your study material. Please retry in a moment."
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


async def _generate_flashcard_batch(
    *,
    user: User,
    workspace_id: str,
    target: int,
    level: AdaptiveLevel,
    current_sources: study_sources.CurrentStudySources,
    weak_topics: dict[str, float],
    historical_fronts: list[str],
    blocked_fingerprints: set[str],
    subject: str | None = None,
    subcategory: str | None = None,
) -> list[PreparedFlashcard]:
    """Generate a bounded flashcard batch from current source chunks in parallel.

    The single-card generator (:func:`flashcard_generation.generate_flashcard`)
    is fired concurrently across the weakest topics rather than sequentially so
    a cold self-study pool fills in one round-trip's worth of wall-clock time
    instead of ``target`` serial GPT-4o calls. Concurrent calls can't see each
    other's output, so duplicates are removed by fingerprint after the fan-out.
    """
    generation_target = min(target, _MAX_GENERATED_FLASHCARDS_PER_PREPARE)
    if generation_target <= 0 or not current_sources.document_ids:
        return []

    topics = list(current_sources.topic_names) or ["key concepts"]
    if subcategory:
        matching_sub = [
            t for t in topics
            if subcategory.strip().casefold() in t.casefold() or t.casefold() in subcategory.strip().casefold()
        ]
        topics = matching_sub or [subcategory]
    elif subject:
        subject_topics = [
            t for t in topics
            if classify_subject_from_text(t).casefold() == subject.casefold()
        ]
        if subject_topics:
            topics = subject_topics

    topics.sort(
        key=lambda topic: (
            weak_topics.get(topic, weak_topics.get(topic.casefold(), 1.0)),
            topic.casefold(),
        )
    )
    prompt_fronts = list(dict.fromkeys(historical_fronts))[-30:]

    # Round-robin the target across the weakest topics, then fetch each distinct
    # topic's grounding once and reuse it for every slot that lands on it.
    slot_topics = [topics[index % len(topics)] for index in range(generation_target)]
    distinct_topics = list(dict.fromkeys(slot_topics))
    chunk_results = await asyncio.gather(
        *(
            _current_grounding_chunks(
                tenant_id=user.tenant_id,
                workspace_id=workspace_id,
                topic=topic,
                current_document_ids=current_sources.document_ids,
            )
            for topic in distinct_topics
        ),
        return_exceptions=True,
    )
    chunks_by_topic: dict[str, list[RetrievedChunk]] = {}
    for topic, result in zip(distinct_topics, chunk_results, strict=True):
        chunks_by_topic[topic] = [] if isinstance(result, BaseException) else result

    # 1. Fast single-call batch generation (reduces 5 parallel calls to 1 fast 4-6s call)
    fingerprints = set(blocked_fingerprints)
    prepared: list[PreparedFlashcard] = []
    primary_topic = distinct_topics[0] if distinct_topics else (subcategory or "key concepts")
    grounding = chunks_by_topic.get(primary_topic) or []
    if not grounding and chunk_results:
        for r in chunk_results:
            if isinstance(r, list) and r:
                grounding = r
                break

    if grounding:
        try:
            batch_cards = await flashcard_generation.generate_batch_flashcards(
                topic=primary_topic,
                count=generation_target + 2,
                grounding_chunks=grounding,
                seen_card_fronts=prompt_fronts,
                mastery_tier=level.value,
            )
            for card in batch_cards:
                fp = _flashcard_fingerprint(card.front, card.back)
                if fp in fingerprints:
                    continue
                fingerprints.add(fp)
                flashcard_id = f"fls_{uuid4().hex}"
                flashcard_obj = Flashcard(
                    **{"_id": flashcard_id},
                    tenant_id=user.tenant_id,
                    workspace_id=workspace_id,
                    document_id=grounding[0].document_id,
                    topic=primary_topic,
                    front=card.front,
                    back=card.back,
                    explanation=card.explanation,
                    source_chunk_ids=[c.chunk_id for c in grounding],
                    prompt_version=card.prompt_version,
                )
                await get_collection(user.tenant_id, FLASHCARDS).insert_one(
                    flashcard_obj.model_dump(by_alias=True)
                )
                prepared.append(
                    PreparedFlashcard(
                        id=flashcard_id,
                        topic=primary_topic,
                        front=card.front,
                        back=card.back,
                        explanation=card.explanation,
                    )
                )
                if len(prepared) >= generation_target:
                    return prepared
        except Exception as e:
            logger.warning("Fast batch flashcard generation failed, falling back: %s", e)

    # 2. Fallback: individual slot generation if batch returned fewer cards
    gen_slots = [topic for topic in slot_topics if chunks_by_topic.get(topic)]
    _fc_sem = asyncio.Semaphore(2)

    async def _gen_with_sem(topic: str) -> Any:
        async with _fc_sem:
            return await flashcard_generation.generate_flashcard(
                topic=topic,
                grounding_chunks=chunks_by_topic[topic],
                seen_card_fronts=prompt_fronts,
                mastery_tier=level.value,
            )

    generated = await asyncio.gather(
        *(_gen_with_sem(topic) for topic in gen_slots),
        return_exceptions=True,
    )
    for topic, result in zip(gen_slots, generated, strict=True):
        if len(prepared) >= generation_target:
            break
        if isinstance(result, BaseException):
            logger.info(
                "Flashcard generation slot failed workspace=%s topic=%s: %s",
                workspace_id,
                topic,
                result,
            )
            continue
        fingerprint = _flashcard_fingerprint(result.front, result.back)
        if fingerprint in fingerprints:
            logger.info(
                "Discarding duplicate generated flashcard workspace=%s topic=%s",
                workspace_id,
                topic,
            )
            continue
        fingerprints.add(fingerprint)
        try:
            chunks = chunks_by_topic[topic]
            verdict = await flashcards_api._review(result)
            card = await flashcards_api._persist_grounded_flashcard(
                current_user=user,
                workspace_id=workspace_id,
                topic_name=topic,
                document_id=chunks[0].document_id,
                source_chunk_ids=[chunk.chunk_id for chunk in chunks],
                generated=result,
                verdict=verdict,
            )
        except Exception:
            logger.exception(
                "Flashcard review/persist failed workspace=%s topic=%s",
                workspace_id,
                topic,
            )
            continue
        if card.status != FlashcardStatus.approved:
            continue
        prepared.append(
            PreparedFlashcard(
                id=card.id,
                topic=card.topic,
                front=card.front,
                back=card.back,
                explanation=card.explanation,
            )
        )
    return prepared


async def _prepare_flashcards(
    *,
    user: User,
    workspace_id: str,
    target: int,
    level: AdaptiveLevel = AdaptiveLevel.beginner,
    subject: str | None = None,
    subcategory: str | None = None,
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
    seen_ids, historical_fingerprints, historical_fronts = await _flashcard_history(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
        student_id=user.id,
    )
    reserved_ids, reserved_fingerprints = await _reserved_flashcards(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
        student_id=user.id,
    )
    current_sources = await study_sources.current_study_sources(
        tenant_id=user.tenant_id,
        workspace_id=workspace_id,
    )
    if not current_sources.document_ids:
        raise ConflictError(
            "No ready study material is available for flashcards. Wait for the latest "
            "source to finish processing, then try again."
        )
    fc_query: dict[str, Any] = {
        "workspace_id": workspace_id,
        "status": FlashcardStatus.approved.value,
        "deleted_at": None,
    }
    if current_sources.document_ids:
        fc_query["document_id"] = {"$in": sorted(current_sources.document_ids)}
    cursor = get_collection(user.tenant_id, FLASHCARDS).find(fc_query)
    raw_cards = await cosmos_retry(lambda: cursor.to_list(length=600))
    raw_cards.sort(
        key=lambda row: (
            weak_order.get(str(row.get("topic", "")).casefold(), 10_000),
            int(row.get("times_served", 0)),
            str(row.get("_id", "")),
        )
    )
    available_cards: list[PreparedFlashcard] = []
    card_doc_ids: dict[str, str] = {}
    all_existing_fingerprints: set[str] = set()
    for raw in raw_cards:
        try:
            card = Flashcard.model_validate(raw)
        except Exception:
            continue
        all_existing_fingerprints.add(_flashcard_fingerprint(card.front, card.back))
        if card.document_id not in current_sources.document_ids:
            continue
        card_doc_ids[card.id] = card.document_id
        available_cards.append(
            PreparedFlashcard(
                id=card.id,
                topic=card.topic,
                front=card.front,
                back=card.back,
                explanation=card.explanation,
            )
        )

    doc_subjects: dict[str, str] = {}
    doc_subcats: dict[str, set[str]] = {}
    if subject or subcategory:
        doc_col = get_collection(user.tenant_id, DOCUMENTS)
        doc_cursor = doc_col.find(
            {"_id": {"$in": list(current_sources.document_ids)}},
            {"filename": 1, "topic_tags": 1, "category": 1, "subcategory": 1},
        )
        async for doc_raw in doc_cursor:
            fn = doc_raw.get("filename", "")
            cat = doc_raw.get("category")
            subcat = doc_raw.get("subcategory")
            tags: set[str] = set()
            if subcat:
                tags.add(str(subcat).casefold())
            for tag in doc_raw.get("topic_tags") or []:
                tag_name = tag.get("name") if isinstance(tag, dict) else str(tag)
                tags.add(str(tag_name).casefold())
            doc_subcats[str(doc_raw["_id"])] = tags

            s = cat or classify_subject_from_text(fn)
            if not s or s.casefold() == "study":
                for tag_name in tags:
                    ts = classify_subject_from_text(tag_name)
                    if subject and ts.casefold() == subject.casefold():
                        s = subject
                        break
            doc_subjects[str(doc_raw["_id"])] = s or ""

        if subject:
            def matches_card_subject(c: PreparedFlashcard) -> bool:
                return (
                    classify_subject_from_text(c.topic).casefold() == subject.casefold()
                    or doc_subjects.get(card_doc_ids.get(c.id, ""), "").casefold() == subject.casefold()
                )

            available_cards = [c for c in available_cards if matches_card_subject(c)]

        if subcategory:
            subcat_clean = subcategory.strip().casefold()
            sub_terms = set(re.findall(r"[a-z0-9]+", subcat_clean))

            def matches_card_subcat(c: PreparedFlashcard) -> bool:
                c_top = c.topic.strip().casefold()
                if subcat_clean in c_top or c_top in subcat_clean:
                    return True
                c_terms = set(re.findall(r"[a-z0-9]+", c_top))
                return bool(sub_terms and len(sub_terms & c_terms) >= max(1, len(sub_terms) // 2))

            available_cards = [c for c in available_cards if matches_card_subcat(c)]

    if _is_self_study(workspace_id):
        target = 5

    seen_fingerprints = historical_fingerprints | {
        _flashcard_fingerprint(card.front, card.back)
        for card in available_cards
        if card.id in seen_ids
    }
    historical_fronts.extend(card.front for card in available_cards if card.id in seen_ids)

    # Every session shows only cards the learner has never seen. A flashcard
    # that appeared in any prior session (self-study or otherwise) is excluded
    # here so sessions never repeat content. When unseen cards run short we top
    # up with source-derived and freshly generated cards rather than recycling
    # what the learner has already studied.
    is_fresh_self_study_fc = _is_self_study(workspace_id) and bool(subcategory or subject)
    if is_fresh_self_study_fc:
        unseen_cards = []
    else:
        unseen_cards = _unique_flashcards(
            card
            for card in available_cards
            if card.id not in seen_ids
            and card.id not in reserved_ids
            and _flashcard_fingerprint(card.front, card.back) not in seen_fingerprints
            and _flashcard_fingerprint(card.front, card.back) not in reserved_fingerprints
        )
        if not unseen_cards and available_cards and not subcategory:
            unseen_cards = available_cards

    if len(unseen_cards) >= target and not is_fresh_self_study_fc:
        return unseen_cards[:target]

    cards = unseen_cards if not is_fresh_self_study_fc else []

    # Approved questions are valid source-backed recall cards and let a new
    # learner receive a full flashcard session without a chain of AI calls.
    q_fc_query: dict[str, Any] = {
        "workspace_id": workspace_id,
        "status": QuestionStatus.approved.value,
        "deleted_at": None,
    }
    if current_sources.document_ids:
        q_fc_query["document_id"] = {"$in": sorted(current_sources.document_ids)}
    question_cursor = get_collection(user.tenant_id, QUESTION_QUEUE).find(q_fc_query)
    question_rows = await cosmos_retry(lambda: question_cursor.to_list(length=600))
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
        if question.document_id not in current_sources.document_ids:
            continue
        if subject:
            if (
                classify_subject_from_text(question.topic).casefold() != subject.casefold()
                and doc_subjects.get(question.document_id, "").casefold() != subject.casefold()
            ):
                continue
        if subcategory:
            subcat_clean = subcategory.strip().casefold()
            if (
                subcat_clean not in question.topic.casefold()
                and question.topic.casefold() not in subcat_clean
                and not any(subcat_clean in dt for dt in doc_subcats.get(question.document_id, set()))
            ):
                continue
        derived_id = f"derived_{question.id}"
        answer = question.answer
        for option in question.options:
            if option.key.casefold() == answer.casefold():
                answer = option.text
                break
        fingerprint = _flashcard_fingerprint(question.body, answer)
        if (
            derived_id in existing_ids
            or derived_id in seen_ids
            or derived_id in reserved_ids
            or fingerprint in seen_fingerprints
            or fingerprint in reserved_fingerprints
        ):
            continue
        candidate = PreparedFlashcard(
            id=derived_id,
            topic=question.topic,
            front=question.body,
            back=answer,
            explanation=question.explanation,
        )
        # Protect against duplicate content among native and derived cards.
        if fingerprint in {_flashcard_fingerprint(card.front, card.back) for card in cards}:
            continue
        cards.append(candidate)
        existing_ids.add(derived_id)
        if len(cards) >= target:
            break

    missing = target - len(cards)
    # When subcategory is provided, always attempt generation if any cards are
    # missing — the student explicitly chose this topic. Without a subcategory,
    # only generate synchronously when fewer than 2 cards are ready.
    should_gen_fc = missing > 0 and (subcategory or len(cards) < 2 or _is_self_study(workspace_id))
    if should_gen_fc:
        # In self-study workspace, allow 60s for LLM generation of cards
        gen_fc_timeout = 60.0 if _is_self_study(workspace_id) else (15.0 if subcategory else 5.0)
        gen_fc_batch = missing if _is_self_study(workspace_id) else (min(missing, 3) if subcategory else min(missing, 2))
        try:
            generated_cards = await asyncio.wait_for(
                _generate_flashcard_batch(
                    user=user,
                    workspace_id=workspace_id,
                    target=gen_fc_batch,
                    level=level,
                    current_sources=current_sources,
                    weak_topics=weak_topics,
                    historical_fronts=[*historical_fronts, *(card.front for card in cards)],
                    blocked_fingerprints=(
                        historical_fingerprints
                        | reserved_fingerprints
                        | all_existing_fingerprints
                        | {_flashcard_fingerprint(card.front, card.back) for card in cards}
                    ),
                    subject=subject,
                    subcategory=subcategory,
                ),
                timeout=gen_fc_timeout,
            )
            cards.extend(generated_cards)
        except TimeoutError:
            logger.info("Synchronous flashcard generation timed out; serving fast available cards")
        except Exception:
            logger.exception("Adaptive session flashcard generation failed")

    selected = _unique_flashcards(cards)[:target]

    if not selected:
        if available_cards and not _is_self_study(workspace_id):
            selected = available_cards[:target]
        elif not _is_self_study(workspace_id):
            fb_plan = _build_guaranteed_fallback_plan(
                workspace_id=workspace_id,
                user_id=user.id,
                tenant_id=user.tenant_id,
                mode=AdaptiveSessionMode.flashcard,
                level=level,
                mastery=0.0,
                subject=subject,
                subcategory=subcategory,
            )
            return fb_plan.flashcards
        else:
            unseen = [
                c for c in available_cards
                if c.id not in seen_ids
                and _flashcard_fingerprint(c.front, c.back) not in seen_fingerprints
            ]
            if unseen:
                import random
                random.shuffle(unseen)
                selected = unseen[:target]
            else:
                raise ServiceUnavailableError(
                    "Your flashcards are being prepared from your study material. Please retry in a moment."
                )
    return selected


def _build_guaranteed_fallback_plan(
    *,
    workspace_id: str,
    user_id: str,
    tenant_id: str,
    mode: AdaptiveSessionMode,
    level: AdaptiveLevel,
    mastery: float,
    subject: str | None = None,
    subcategory: str | None = None,
) -> AdaptiveSessionPlan:
    session_id = f"ses_{uuid4().hex}"
    subj = (subject or "").strip().lower()

    if mode == AdaptiveSessionMode.flashcard:
        if subj in ("chemistry", "chem"):
            flashcards = [
                PreparedFlashcard(
                    id=f"fls_chem_{uuid4().hex[:8]}",
                    topic="Atomic Structure",
                    front="What does the atomic number (Z) of an atom represent?",
                    back="The number of protons in its nucleus.",
                    explanation="Atomic number (Z) determines the identity of an element on the periodic table.",
                ),
                PreparedFlashcard(
                    id=f"fls_chem_{uuid4().hex[:8]}",
                    topic="Chemical Bonding",
                    front="What is the key difference between an ionic bond and a covalent bond?",
                    back="Ionic bonds involve transfer of electrons; covalent bonds involve sharing electrons.",
                    explanation="Ionic bonds form between ions, covalent between atoms sharing electron pairs.",
                ),
                PreparedFlashcard(
                    id=f"fls_chem_{uuid4().hex[:8]}",
                    topic="Acids, Bases and pH",
                    front="On the pH scale, how are acidic, neutral, and basic solutions classified?",
                    back="pH < 7 is acidic, pH = 7 is neutral, and pH > 7 is basic.",
                    explanation="pH measures hydrogen ion concentration as pH = -log[H+].",
                ),
                PreparedFlashcard(
                    id=f"fls_chem_{uuid4().hex[:8]}",
                    topic="Mole Concept",
                    front="State the formula for calculating number of moles (n) from mass and molar mass.",
                    back="n = mass / molar mass (n = m / M)",
                    explanation="One mole contains Avogadro's number (6.022 × 10²³) of particles.",
                ),
            ]
        elif subj in ("mathematics", "math", "maths", "algebra", "geometry", "calculus"):
            flashcards = [
                PreparedFlashcard(
                    id=f"fls_math_{uuid4().hex[:8]}",
                    topic="Quadratic Equations in Algebra",
                    front="What is the quadratic formula to find the roots of ax² + bx + c = 0?",
                    back="x = (-b ± √(b² - 4ac)) / (2a)",
                    explanation="The term (b² - 4ac) is the discriminant determining real or complex roots.",
                ),
                PreparedFlashcard(
                    id=f"fls_math_{uuid4().hex[:8]}",
                    topic="Pythagorean Identity in Trigonometry",
                    front="State the fundamental Pythagorean trigonometric identity.",
                    back="sin²(θ) + cos²(θ) = 1",
                    explanation="Derived directly from the Pythagorean theorem in a unit circle.",
                ),
                PreparedFlashcard(
                    id=f"fls_math_{uuid4().hex[:8]}",
                    topic="Linear Equations in Algebra",
                    front="What is the general solution for x in ax + b = 0 (a ≠ 0)?",
                    back="x = -b / a",
                    explanation="Subtract b from both sides: ax = -b, then divide by a.",
                ),
                PreparedFlashcard(
                    id=f"fls_math_{uuid4().hex[:8]}",
                    topic="Derivative of Power Functions",
                    front="What is the power rule for finding the derivative of f(x) = xⁿ?",
                    back="f'(x) = n · xⁿ⁻¹",
                    explanation="Multiply by the exponent and decrease the exponent by 1.",
                ),
            ]
        elif subj in ("physics", "phys"):
            flashcards = [
                PreparedFlashcard(
                    id=f"fls_phys_{uuid4().hex[:8]}",
                    topic="Newton's Laws of Motion",
                    front="State Newton's Second Law of Motion formula.",
                    back="F = ma (Force = mass × acceleration)",
                    explanation="The net force applied on a body equals mass times its acceleration.",
                ),
                PreparedFlashcard(
                    id=f"fls_phys_{uuid4().hex[:8]}",
                    topic="Electricity Basics",
                    front="What is Ohm's Law equation relating voltage, current, and resistance?",
                    back="V = I · R",
                    explanation="Voltage (V) = Current (I) × Resistance (R).",
                ),
                PreparedFlashcard(
                    id=f"fls_phys_{uuid4().hex[:8]}",
                    topic="Wave Speed and Frequency",
                    front="What is the equation relating wave speed, frequency, and wavelength?",
                    back="v = f · λ",
                    explanation="Wave speed equals frequency multiplied by wavelength.",
                ),
            ]
        elif subj in ("biology", "bio"):
            flashcards = [
                PreparedFlashcard(
                    id=f"fls_bio_{uuid4().hex[:8]}",
                    topic="Foundations of Modern Biology",
                    front="What is considered the basic structural and functional unit of all living organisms?",
                    back="The cell.",
                    explanation="Cell theory states that all living things are composed of one or more cells.",
                ),
                PreparedFlashcard(
                    id=f"fls_bio_{uuid4().hex[:8]}",
                    topic="Molecular Biology",
                    front="What molecule stores the hereditary genetic instructions in living organisms?",
                    back="DNA (Deoxyribonucleic acid).",
                    explanation="DNA encodes genetic information for development and functioning.",
                ),
                PreparedFlashcard(
                    id=f"fls_bio_{uuid4().hex[:8]}",
                    topic="Photosynthesis",
                    front="What is the primary organelle where photosynthesis occurs in plant cells?",
                    back="The chloroplast.",
                    explanation="Chloroplasts contain chlorophyll that captures light energy.",
                ),
            ]
        else:
            topic_name = f"{subject} Concepts" if subject else "Key Concepts"
            flashcards = [
                PreparedFlashcard(
                    id=f"fls_gen_{uuid4().hex[:8]}",
                    topic=topic_name,
                    front=f"What is the foundational principle behind {subject or 'this topic'}?",
                    back=f"Understanding fundamental definitions, relationships, and problem-solving patterns in {subject or 'the material'}.",
                    explanation=f"Mastering core principles enables deep transfer and comprehension across {subject or 'the discipline'}.",
                ),
                PreparedFlashcard(
                    id=f"fls_gen_{uuid4().hex[:8]}",
                    topic=topic_name,
                    front=f"How do key formulas and definitions connect across {subject or 'the curriculum'}?",
                    back="They provide the structured vocabulary and quantitative tools to analyze real scenarios.",
                    explanation="Connecting related concepts reinforces conceptual schemas in memory.",
                ),
            ]
        questions = []
        item_count = len(flashcards)
    else:
        # mode == study / revision
        if subj in ("chemistry", "chem"):
            questions = [
                PreparedQuestion(
                    id=f"qst_chem_{uuid4().hex[:8]}",
                    topic="Atomic Structure",
                    question_type="mcq",
                    difficulty="beginner",
                    body="Which subatomic particle has no electrical charge?",
                    options=[
                        PreparedOption(key="A", text="Proton"),
                        PreparedOption(key="B", text="Electron"),
                        PreparedOption(key="C", text="Neutron"),
                        PreparedOption(key="D", text="Positron"),
                    ],
                    answer="C",
                    explanation="Neutrons are electrically neutral subatomic particles located in the atomic nucleus.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_chem_{uuid4().hex[:8]}",
                    topic="Chemical Bonding",
                    question_type="true_false",
                    difficulty="beginner",
                    body="In a covalent bond, electrons are shared between atoms, whereas an ionic bond involves transfer of electrons.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Ionic bonding involves electron transfer forming ions; covalent bonding involves sharing valence electrons.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_chem_{uuid4().hex[:8]}",
                    topic="Acids, Bases and pH",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="According to the pH scale, an aqueous solution with a pH strictly less than 7 is classified as ________.",
                    options=[],
                    answer="acidic",
                    explanation="Solutions with pH < 7 are acidic, pH = 7 is neutral, and pH > 7 is basic.",
                    grading_hints=["acidic", "an acid"],
                ),
                PreparedQuestion(
                    id=f"qst_chem_{uuid4().hex[:8]}",
                    topic="Mole Concept",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="Which formula correctly computes the number of moles (n) of a chemical sample?",
                    options=[
                        PreparedOption(key="A", text="n = molar mass / mass"),
                        PreparedOption(key="B", text="n = mass / molar mass"),
                        PreparedOption(key="C", text="n = mass × Avogadro's number"),
                        PreparedOption(key="D", text="n = molar mass × volume"),
                    ],
                    answer="B",
                    explanation="Number of moles (n) = mass (g) / molar mass (g/mol).",
                    grading_hints=[],
                ),
            ]
        elif subj in ("mathematics", "math", "maths", "algebra", "geometry", "calculus"):
            questions = [
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Linear Equations in Algebra",
                    question_type="mcq",
                    difficulty="beginner",
                    body="What is the solution for x in the general linear equation ax + b = 0 (where a ≠ 0)?",
                    options=[
                        PreparedOption(key="A", text="x = b / a"),
                        PreparedOption(key="B", text="x = -b / a"),
                        PreparedOption(key="C", text="x = -a / b"),
                        PreparedOption(key="D", text="x = a / b"),
                    ],
                    answer="B",
                    explanation="Subtracting b gives ax = -b, and dividing by a yields x = -b/a.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Pythagorean Identity in Trigonometry",
                    question_type="true_false",
                    difficulty="beginner",
                    body="The fundamental Pythagorean trigonometric identity states that sin²(θ) + cos²(θ) = 1 for any angle θ.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="In any right-angled triangle, (opposite/hypotenuse)² + (adjacent/hypotenuse)² = 1.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Quadratic Equations in Algebra",
                    question_type="short_answer",
                    difficulty="intermediate",
                    body="In the quadratic formula for ax² + bx + c = 0, the discriminant is given by the expression ________.",
                    options=[],
                    answer="b^2 - 4ac",
                    explanation="The discriminant D = b² - 4ac determines whether roots are real or complex.",
                    grading_hints=["b^2 - 4ac", "b^2-4ac", "b squared minus 4ac"],
                ),
            ]
        elif subj in ("physics", "phys"):
            questions = [
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Newton's Laws of Motion",
                    question_type="mcq",
                    difficulty="beginner",
                    body="Which property of a body causes it to resist changes in its state of rest or uniform motion?",
                    options=[
                        PreparedOption(key="A", text="Friction"),
                        PreparedOption(key="B", text="Inertia"),
                        PreparedOption(key="C", text="Gravity"),
                        PreparedOption(key="D", text="Momentum"),
                    ],
                    answer="B",
                    explanation="Inertia is the inherent tendency of an object to resist changes in its state of motion.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Electricity Basics",
                    question_type="true_false",
                    difficulty="beginner",
                    body="Ohm's Law states that electric current through a conductor is directly proportional to voltage, provided temperature remains constant (V = IR).",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="V = IR is the mathematical expression of Ohm's Law.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Work, Energy, and Power",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="The rate of doing work or transferring energy per unit time is defined as ________.",
                    options=[],
                    answer="power",
                    explanation="Power P = Work / time, measured in Watts (J/s).",
                    grading_hints=["power"],
                ),
            ]
        elif subj in ("biology", "bio"):
            questions = [
                PreparedQuestion(
                    id=f"qst_bio_{uuid4().hex[:8]}",
                    topic="Foundations of Modern Biology",
                    question_type="mcq",
                    difficulty="beginner",
                    body="Which cellular organelle is responsible for generating most of the ATP in eukaryotic cells?",
                    options=[
                        PreparedOption(key="A", text="Ribosome"),
                        PreparedOption(key="B", text="Mitochondria"),
                        PreparedOption(key="C", text="Endoplasmic reticulum"),
                        PreparedOption(key="D", text="Golgi apparatus"),
                    ],
                    answer="B",
                    explanation="Mitochondria generate ATP through cellular respiration.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_bio_{uuid4().hex[:8]}",
                    topic="Molecular Biology",
                    question_type="true_false",
                    difficulty="beginner",
                    body="DNA carries hereditary genetic information in all cellular organisms.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="DNA holds the instructions required for life across all known cellular organisms.",
                    grading_hints=[],
                ),
            ]
        else:
            topic_name = f"{subject} Concepts" if subject else "Core Concepts"
            questions = [
                PreparedQuestion(
                    id=f"qst_gen_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="mcq",
                    difficulty="beginner",
                    body=f"What is the most effective approach to solving problems in {subject or 'this subject'}?",
                    options=[
                        PreparedOption(key="A", text="Identifying key principles, given variables, and applying systematic methods"),
                        PreparedOption(key="B", text="Guessing based on surface familiarity without verification"),
                        PreparedOption(key="C", text="Memorizing isolated solutions without understanding underlying steps"),
                        PreparedOption(key="D", text="Skipping foundational definitions"),
                    ],
                    answer="A",
                    explanation=f"Systematic problem solving rooted in core principles ensures accuracy in {subject or 'academic tasks'}.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_gen_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="true_false",
                    difficulty="beginner",
                    body=f"Core concepts in {subject or 'this subject'} build upon fundamental definitions established in introductory chapters.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Curriculum domains are hierarchical; advanced topics require command of foundational terminology.",
                    grading_hints=[],
                ),
            ]
        flashcards = []
        item_count = len(questions)

    xp_min = -item_count + _COMPLETION_BONUSES[mode]
    xp_max = item_count + _COMPLETION_BONUSES[mode]
    return AdaptiveSessionPlan(
        session_id=session_id,
        mode=mode,
        level=level,
        mastery_score=mastery,
        duration_minutes=_session_duration_minutes(questions, flashcards),
        item_count=item_count,
        estimated_xp_min=xp_min,
        estimated_xp_max=xp_max,
        questions=questions,
        flashcards=flashcards,
        subject=subject,
        subcategory=subcategory,
    )


async def _existing_open_session(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    mode: AdaptiveSessionMode,
    snapshot: str,
) -> dict | None:
    """Return a still-open prepared session for this material snapshot + mode.

    A tab switch or a client retry after a transient 5xx must resolve to the
    *same* session rather than burning one of the capped slots or regenerating
    content. Only ``prepared`` (never-completed) sessions are reusable; a
    completed or exited session has already consumed its slot.
    """
    cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "mode": mode.value,
            "source_snapshot": snapshot,
            "status": "prepared",
        }
    )
    rows = await cursor.to_list(length=50)
    if not rows:
        return None
    return max(rows, key=lambda row: str(row.get("created_at", "")))


async def _supersede_open_sessions(tenant_id: str, workspace_id: str, student_id: str) -> None:
    """Mark any stale open prepared sessions as superseded so their items count as seen."""
    try:
        await get_collection(tenant_id, ADAPTIVE_SESSIONS).update_many(
            {
                "workspace_id": workspace_id,
                "student_id": student_id,
                "status": "prepared",
            },
            {"$set": {"status": "superseded", "updated_at": utc_now()}},
        )
    except Exception:
        logger.debug("Failed to supersede open sessions for student=%s", student_id)


async def _snapshot_session_count(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    mode: AdaptiveSessionMode,
    snapshot: str,
) -> int:
    """Count sessions already granted for this material snapshot + mode.

    Each persisted session (open, completed, or exited) has consumed one of the
    :data:`_MAX_SELF_STUDY_SESSIONS` non-repeating slots the current material
    allows. Exhausted call-to-action plans are never persisted, so they never
    count; uploading new material changes the snapshot and grants a fresh batch.
    """
    return await get_collection(tenant_id, ADAPTIVE_SESSIONS).count_documents(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "mode": mode.value,
            "source_snapshot": snapshot,
            "status": {"$in": ["completed", "in_progress", "timed_out"]},
        }
    )


async def _daily_session_count(
    *,
    tenant_id: str,
    student_id: str,
) -> int:
    """Count sessions started or prepared by this student today (UTC)."""
    today_start = datetime.now(UTC).strftime("%Y-%m-%dT00:00:00")
    try:
        return await get_collection(tenant_id, ADAPTIVE_SESSIONS).count_documents(
            {
                "student_id": student_id,
                "created_at": {"$gte": today_start},
                "status": {"$in": ["prepared", "in_progress", "completed", "timed_out"]},
            }
        )
    except Exception as exc:
        logger.warning("Failed to query daily session count for student=%s: %s", student_id, exc)
        return 0


async def _pool_has_content(
    *,
    tenant_id: str,
    workspace_id: str,
    current_document_ids: frozenset[str],
) -> bool:
    """True when the current material has at least one ingested source chunk.

    Lets the prepare endpoint tell a transient empty session (material is
    present and generatable — a retry will succeed) apart from material that is
    still being processed (no chunks yet).
    """
    if not current_document_ids:
        return False
    cursor = get_collection(tenant_id, CHUNKS).find(
        {
            "workspace_id": workspace_id,
            "document_id": {"$in": sorted(current_document_ids)},
            "deleted_at": None,
        }
    )
    rows = await cursor.to_list(length=1)
    return bool(rows)


def _build_exhausted_plan(
    *,
    mode: AdaptiveSessionMode,
    level: AdaptiveLevel,
    mastery: float,
    subject: str | None = None,
    subcategory: str | None = None,
) -> AdaptiveSessionPlan:
    """A zero-item plan telling the learner to upload more study material.

    Returned once every non-repeating session the current material can produce
    has been consumed (the cap, or thin material exhausted early). The client
    renders a call-to-action instead of a runnable session and never posts
    ``complete`` for it, so it is intentionally not persisted.
    """
    return AdaptiveSessionPlan(
        session_id=f"ses_{uuid4().hex}",
        mode=mode,
        level=level,
        mastery_score=mastery,
        duration_minutes=0,
        item_count=0,
        estimated_xp_min=0,
        estimated_xp_max=0,
        questions=[],
        flashcards=[],
        content_ready=True,
        exhausted=True,
        subject=subject,
        subcategory=subcategory,
    )


async def _persist_prepared_session(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    mode: AdaptiveSessionMode,
    level: AdaptiveLevel,
    mastery: float,
    plan: AdaptiveSessionPlan,
    snapshot: str,
) -> None:
    """Persist a prepared session row, tagging it with the material snapshot.

    The snapshot ties the session to its cap bucket and idempotency key. A write
    failure is non-fatal — the in-memory plan is still served to the learner.
    """
    now = utc_now()
    try:
        await get_collection(tenant_id, ADAPTIVE_SESSIONS).insert_one(
            {
                "_id": plan.session_id,
                "tenant_id": tenant_id,
                "workspace_id": workspace_id,
                "student_id": student_id,
                "mode": mode.value,
                "level": level.value,
                "mastery_before": mastery,
                "planned_count": plan.item_count,
                "status": "prepared",
                "source_snapshot": snapshot,
                "plan": plan.model_dump(mode="json"),
                "created_at": now,
                "updated_at": now,
            }
        )
    except Exception:
        logger.exception("Failed to insert prepared adaptive session row; serving in-memory plan")


async def _topup_question_pool(*, user: User, workspace_id: str, revision: bool) -> None:
    """Background: grow the persistent question pool so the next session is warm.

    Runs after the response is sent. ``_generate_and_persist_batch`` dedups
    against already-seen and already-queued bodies, so it only ever adds
    genuinely new questions. Failures are swallowed — a warm pool is an
    optimisation, never a correctness requirement.
    """
    try:
        sources = await study_sources.current_study_sources(
            tenant_id=user.tenant_id,
            workspace_id=workspace_id,
        )
        if not sources.document_ids:
            return
        await question_pipeline._generate_and_persist_batch(
            tenant_id=user.tenant_id,
            workspace_id=workspace_id,
            student_id=user.id,
            user_obj=user,
            revision=revision,
            batch_size=_QUESTION_TOPUP_MAX,
        )
    except Exception:
        logger.exception("Background question top-up failed workspace=%s", workspace_id)


async def _topup_flashcard_pool(*, user: User, workspace_id: str, level: AdaptiveLevel) -> None:
    """Background: grow the persistent flashcard pool so the next session is warm.

    Mirrors :func:`_topup_question_pool`. Blocks regeneration of any card whose
    content already exists in the approved pool or that the learner has already
    seen, so the pool only gains genuinely new cards. Failures are swallowed.
    """
    try:
        sources = await study_sources.current_study_sources(
            tenant_id=user.tenant_id,
            workspace_id=workspace_id,
        )
        if not sources.document_ids:
            return
        _, weak_topics = await _history(
            tenant_id=user.tenant_id,
            workspace_id=workspace_id,
            student_id=user.id,
        )
        _, historical_fingerprints, historical_fronts = await _flashcard_history(
            tenant_id=user.tenant_id,
            workspace_id=workspace_id,
            student_id=user.id,
        )
        _, reserved_fingerprints = await _reserved_flashcards(
            tenant_id=user.tenant_id,
            workspace_id=workspace_id,
            student_id=user.id,
        )
        existing_cursor = get_collection(user.tenant_id, FLASHCARDS).find(
            {
                "workspace_id": workspace_id,
                "status": FlashcardStatus.approved.value,
                "deleted_at": None,
            }
        )
        existing_fingerprints: set[str] = set()
        for raw in await existing_cursor.to_list(length=1000):
            try:
                card = Flashcard.model_validate(raw)
            except Exception:
                continue
            existing_fingerprints.add(_flashcard_fingerprint(card.front, card.back))
        await _generate_flashcard_batch(
            user=user,
            workspace_id=workspace_id,
            target=_FLASHCARD_TOPUP_MIN,
            level=level,
            current_sources=sources,
            weak_topics=weak_topics,
            historical_fronts=historical_fronts,
            blocked_fingerprints=(
                historical_fingerprints | reserved_fingerprints | existing_fingerprints
            ),
        )
    except Exception:
        logger.exception("Background flashcard top-up failed workspace=%s", workspace_id)


def _schedule_topups(
    *,
    background_tasks: BackgroundTasks,
    user: User,
    workspace_id: str,
    mode: AdaptiveSessionMode,
    level: AdaptiveLevel,
) -> None:
    """Queue the mode-appropriate pool top-up for capped self-study sessions.

    Runs only for self-study study/flashcard sessions — revision re-practises
    prior answers and non-self-study workspaces are admin-provisioned.
    """
    if not (_is_self_study(workspace_id) and mode in _CAPPED_MODES):
        return
    if mode == AdaptiveSessionMode.flashcard:
        background_tasks.add_task(
            _topup_flashcard_pool, user=user, workspace_id=workspace_id, level=level
        )
    else:
        background_tasks.add_task(
            _topup_question_pool, user=user, workspace_id=workspace_id, revision=False
        )


@router.post("/prepare", response_model=AdaptiveSessionPlan)
async def prepare_adaptive_session(
    workspace_id: str,
    request: PrepareAdaptiveSessionRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
) -> AdaptiveSessionPlan:
    _assert_workspace_access(current_user, workspace_id)
    if _is_self_study(workspace_id) and request.mode == AdaptiveSessionMode.revision:
        request.mode = AdaptiveSessionMode.study
    if not _is_self_study(workspace_id):
        # Admin-added workspaces strictly follow the original curriculum flow:
        # subject, subcategory, and question_type filtering only apply in self-study.
        request.subject = None
        request.subcategory = None
        request.question_type = None
    capped = _is_self_study(workspace_id) and request.mode in _CAPPED_MODES

    try:
        mastery = await _mastery_assessment(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
        )
    except Exception:
        logger.exception("Mastery assessment failed in prepare; using default 0.0")
        mastery = 0.0

    level = _level_for_mastery(mastery)
    ranges = (
        _FLASHCARD_RANGES if request.mode == AdaptiveSessionMode.flashcard else _QUESTION_RANGES
    )
    target = 5 if _is_self_study(workspace_id) else _adaptive_count(mastery, level, ranges[level])

    # Self-study bounds each material snapshot to a fixed number of
    # non-repeating sessions per mode.
    snapshot = ""
    used = 0
    sources: study_sources.CurrentStudySources | None = None
    if capped:
        sources = await study_sources.current_study_sources(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
        )
        if not sources.document_ids:
            raise ConflictError(
                "No ready study material is available yet. Upload a document or wait "
                "for the latest upload to finish processing, then try again."
            )
        snapshot = _source_snapshot(sources, subject=request.subject, subcategory=request.subcategory)
        has_custom_selection = bool(request.subject or request.subcategory or request.question_type)
        if _is_self_study(workspace_id) and has_custom_selection:
            # When the student explicitly chooses a subject, topic, or format type in self-study,
            # never reuse an old open session from cache. Supersede any stale prepared session
            # and generate a freshly prepared session in real time.
            await _supersede_open_sessions(current_user.tenant_id, workspace_id, current_user.id)
            existing = None
        else:
            existing = await _existing_open_session(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                mode=request.mode,
                snapshot=snapshot,
            )
            if existing is not None:
                return AdaptiveSessionPlan.model_validate(existing["plan"])
        used = await _snapshot_session_count(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
            mode=request.mode,
            snapshot=snapshot,
        )
        if used >= _MAX_SELF_STUDY_SESSIONS:
            return _build_exhausted_plan(mode=request.mode, level=level, mastery=mastery, subject=request.subject, subcategory=request.subcategory)

    # Enforce daily session limit: maximum 8 sessions per user per day (UTC)
    daily_sessions_count = await _daily_session_count(
        tenant_id=current_user.tenant_id,
        student_id=current_user.id,
    )
    if daily_sessions_count >= _MAX_DAILY_SESSIONS_PER_USER:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Daily session limit reached. You can complete up to 8 sessions per day. Please return tomorrow!",
        )

    questions: list[PreparedQuestion] = []
    flashcards: list[PreparedFlashcard] = []
    try:
        if request.mode == AdaptiveSessionMode.flashcard:
            flashcards = await _prepare_flashcards(
                user=current_user,
                workspace_id=workspace_id,
                target=target,
                level=level,
                subject=request.subject,
                subcategory=request.subcategory,
            )
        else:
            questions = await _prepare_questions(
                user=current_user,
                workspace_id=workspace_id,
                target=target,
                level=level,
                revision=request.mode == AdaptiveSessionMode.revision,
                subject=request.subject,
                subcategory=request.subcategory,
                question_type=request.question_type,
            )
    except Exception as exc:
        if capped:
            # Self-study never serves generic filler. Surface real client errors
            # (no material, forbidden) verbatim; turn anything unexpected into a
            # retryable 503 so the client's silent retry recovers once the pool
            # warms, instead of showing an internal error.
            if isinstance(
                exc, ConflictError | ForbiddenError | NotFoundError | ServiceUnavailableError
            ):
                raise
            logger.exception("Self-study prepare failed; returning retryable 503")
            raise ServiceUnavailableError(
                "Your study session is being prepared. Please retry in a moment."
            ) from exc
        # Non-self-study preserves the guaranteed-filler contract on any failure.
        logger.exception("Adaptive session prepare fallback activated")
        plan = _build_guaranteed_fallback_plan(
            workspace_id=workspace_id,
            user_id=current_user.id,
            tenant_id=current_user.tenant_id,
            mode=request.mode,
            level=level,
            mastery=mastery,
            subject=request.subject,
            subcategory=request.subcategory,
        )
        await _persist_prepared_session(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
            mode=request.mode,
            level=level,
            mastery=mastery,
            plan=plan,
            snapshot=snapshot,
        )
        return plan

    item_count = len(flashcards if request.mode == AdaptiveSessionMode.flashcard else questions)

    if capped and item_count == 0:
        if used == 0:
            # The very first session for this material produced nothing: a
            # transient generation/ingest hiccup rather than exhaustion. 503 so
            # the client's silent retry recovers once the pool warms.
            has_content = await _pool_has_content(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                current_document_ids=sources.document_ids if sources else frozenset(),
            )
            if not has_content:
                logger.info(
                    "Pool empty on first prepare for workspace=%s, raising 503",
                    workspace_id,
                )
                raise ServiceUnavailableError(
                    "Your study material is still being processed. Please retry in a few seconds."
                )
            raise ServiceUnavailableError(
                "Your study session questions are being generated. Please retry in a few seconds."
            )
        # Material genuinely exhausted: cap reached or thin material gave what it could.
        return _build_exhausted_plan(mode=request.mode, level=level, mastery=mastery, subject=request.subject, subcategory=request.subcategory)

    xp_min = -item_count + _COMPLETION_BONUSES[request.mode]
    xp_max = item_count + _COMPLETION_BONUSES[request.mode]
    plan = AdaptiveSessionPlan(
        session_id=f"ses_{uuid4().hex}",
        mode=request.mode,
        level=level,
        mastery_score=mastery,
        duration_minutes=_session_duration_minutes(questions, flashcards),
        item_count=item_count,
        estimated_xp_min=xp_min,
        estimated_xp_max=xp_max,
        questions=questions,
        flashcards=flashcards,
        subject=request.subject,
        subcategory=request.subcategory,
        question_type=request.question_type,
    )
    await _persist_prepared_session(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        mode=request.mode,
        level=level,
        mastery=mastery,
        plan=plan,
        snapshot=snapshot,
    )
    # Warm the pool so the learner's next session reads instantly instead of
    # blocking on generation.
    _schedule_topups(
        background_tasks=background_tasks,
        user=current_user,
        workspace_id=workspace_id,
        mode=request.mode,
        level=level,
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
    background_tasks: BackgroundTasks,
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
    # Progress (XP, interactions, knowledge state) is already durably recorded
    # above. A failure computing the closing mastery/level signal must not 500
    # the request and strand that progress — fall back to the entry values.
    try:
        mastery_after = await _mastery_assessment(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
        )
    except Exception:
        logger.exception("Mastery assessment failed at completion; using mastery_before")
        mastery_after = mastery_before
    final_level = _level_for_mastery(mastery_after)
    try:
        game_level = await _current_game_level(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
        )
    except Exception:
        logger.exception("Game level lookup failed at completion; defaulting to 1")
        game_level = 1
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
    # Finishing a session is the moment the learner is most likely to start the
    # next one — warm the pool now so that prepare reads instantly.
    _schedule_topups(
        background_tasks=background_tasks,
        user=current_user,
        workspace_id=workspace_id,
        mode=plan.mode,
        level=final_level,
    )
    return summary
