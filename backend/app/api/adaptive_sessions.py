"""Prepare-once adaptive study, revision, and flashcard sessions."""

from __future__ import annotations

import asyncio
import hashlib
import logging
import random
import re
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
    SessionQuestionAttempt,
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
    study_sources,
)
from app.services import gamification as gamification_service
from app.services import knowledge_state as knowledge_state_service
from app.services.question_deduplication import (
    canonical_question_signature,
    is_candidate_duplicate,
    normalize_question_stem,
)
from app.services.question_variation_generator import generate_runtime_material_variations
from app.services.subject_classifier import (
    canonical_subject,
    classify_subject_from_text,
    is_conflicting_subject,
    is_math_question_body,
    subjects_match,
)

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
# Increased from 50 — 50 sessions is only ~2 days for an active student doing 3 sessions/day.
# 200 sessions per snapshot gives months of headroom before needing to upload new material.
_MAX_SELF_STUDY_SESSIONS = 200
_CAPPED_MODES = frozenset({AdaptiveSessionMode.study, AdaptiveSessionMode.flashcard})
# Background top-up sizes — generated after a session is served so the next
# session reads from a warm pool instead of blocking on generation. Bounded so
# a burst of prepares can't run away with generation cost.
_QUESTION_TOPUP_MIN = 12
_QUESTION_TOPUP_MAX = 25
_FLASHCARD_TOPUP_MIN = 10
_FLASHCARD_TOPUP_MAX = 20
_MAX_DAILY_SESSIONS_PER_USER = 50
_MAX_TOPIC_RECREATIONS = 10


async def _topic_recreation_count(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    subcategory: str | None,
) -> int:
    """Count how many times variations/recreations have been produced for this specific topic."""
    if not subcategory:
        return 0
    subcat_clean = subcategory.strip().casefold()
    try:
        return await cosmos_retry(lambda: get_collection(tenant_id, ADAPTIVE_SESSIONS).count_documents(
            {
                "workspace_id": workspace_id,
                "student_id": student_id,
                "subcategory": subcat_clean,
                "is_recreated": True,
            }
        ))
    except Exception:
        return 0


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
    knowledge_raw = await cosmos_retry(lambda: get_collection(tenant_id, KNOWLEDGE_STATES).find_one(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    ))
    if not knowledge_raw:
        alt_k = await cosmos_retry(lambda: get_collection(tenant_id, KNOWLEDGE_STATES).find_one(
            {"student_id": student_id, "deleted_at": None}
        ))
        if alt_k:
            knowledge_raw = alt_k
    knowledge = float((knowledge_raw or {}).get("overall_mastery", 0.0))

    interaction_cursor = get_collection(tenant_id, INTERACTIONS).find(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    )
    interactions = await cosmos_retry(lambda: interaction_cursor.to_list(length=500))
    if not interactions:
        alt_cursor = get_collection(tenant_id, INTERACTIONS).find(
            {"student_id": student_id, "deleted_at": None}
        )
        alt_interactions = await cosmos_retry(lambda: alt_cursor.to_list(length=500))
        if alt_interactions:
            interactions = alt_interactions
    interactions.sort(key=lambda row: row.get("answered_at", ""))

    session_cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "status": {"$in": ["completed", "timed_out", "exited"]},
        }
    )
    sessions = await cosmos_retry(lambda: session_cursor.to_list(length=50))
    if not sessions:
        alt_sc = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
            {
                "student_id": student_id,
                "status": {"$in": ["completed", "timed_out", "exited"]},
            }
        )
        alt_sessions = await cosmos_retry(lambda: alt_sc.to_list(length=50))
        if alt_sessions:
            sessions = alt_sessions
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

    gamification_raw = await cosmos_retry(lambda: get_collection(tenant_id, GAMIFICATION).find_one(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    ))
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
        {"$or": [{"student_id": student_id}, {"user_id": student_id}], "deleted_at": None}
    )
    interactions = await cosmos_retry(lambda: cursor.to_list(length=3000))
    interactions.sort(key=lambda row: str(row.get("answered_at") or ""), reverse=True)
    knowledge = await cosmos_retry(lambda: get_collection(tenant_id, KNOWLEDGE_STATES).find_one(
        {"workspace_id": workspace_id, "student_id": student_id, "deleted_at": None}
    ))
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

    Detects mathematical equations, calculus expressions, strips cross-subject
    conversational question templates, and returns a canonical fingerprint.
    """
    return canonical_question_signature(body)


def _unique_questions(items: Iterable[Question]) -> list[Question]:
    result: list[Question] = []
    seen_ids: set[str] = set()
    seen_bodies: set[str] = set()
    seen_records: list[tuple[str, str | None]] = []
    for item in items:
        fingerprint = canonical_question_signature(item.body)
        norm_body = normalize_question_stem(item.body)
        if item.id in seen_ids or fingerprint in seen_bodies or norm_body in seen_bodies:
            continue
        if is_candidate_duplicate(item.body, item.answer, seen_records):
            continue
        seen_ids.add(item.id)
        seen_bodies.add(fingerprint)
        seen_bodies.add(norm_body)
        seen_records.append((item.body, item.answer))
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
            "student_id": student_id,
            "status": "prepared",
        }
    )
    rows = await cosmos_retry(lambda: cursor.to_list(length=50))
    questions = [
        question for row in rows for question in (row.get("plan") or {}).get("questions", [])
    ]
    ids = {str(question["id"]) for question in questions if question.get("id")}
    fingerprints = {
        _question_fingerprint(str(question["body"]))
        for question in questions
        if question.get("body")
    }
    fingerprints.update(canonical_question_signature(str(question["body"])) for question in questions if question.get("body"))
    fingerprints.update(normalize_question_stem(str(question["body"])) for question in questions if question.get("body"))
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
            "student_id": student_id,
            "deleted_at": None,
        }
    )
    rating_rows = await cosmos_retry(lambda: rating_cursor.to_list(length=5000))
    ids = {str(row["flashcard_id"]) for row in rating_rows if row.get("flashcard_id")}

    session_cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {"student_id": student_id}
    )
    raw_rows = await cosmos_retry(lambda: session_cursor.to_list(length=5000))
    session_rows = [
        r for r in raw_rows
        if r.get("mode") == AdaptiveSessionMode.flashcard.value and r.get("status") != "prepared"
    ]
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
            "student_id": student_id,
            "status": "prepared",
        }
    )
    raw_rows = await cosmos_retry(lambda: cursor.to_list(length=50))
    rows = [r for r in raw_rows if r.get("mode") == AdaptiveSessionMode.flashcard.value]
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
    of whether the student actually submitted an answer or what the session status is.

    This supplements INTERACTIONS to prevent questions from reappearing across sessions:
    once a question appears in ANY session for a user, it must not repeat.
    """
    cursor = get_collection(tenant_id, ADAPTIVE_SESSIONS).find(
        {"student_id": student_id}
    )
    raw_rows = await cosmos_retry(lambda: cursor.to_list(length=5000))
    valid_modes = {AdaptiveSessionMode.study.value, AdaptiveSessionMode.revision.value}
    rows = [
        row for row in raw_rows
        if not row.get("mode") or row.get("mode") in valid_modes
    ]
    questions = [q for row in rows for q in (row.get("plan") or {}).get("questions", [])]
    ids = {str(q["id"]) for q in questions if q.get("id")}
    fingerprints = {_question_fingerprint(str(q["body"])) for q in questions if q.get("body")}
    fingerprints.update(canonical_question_signature(str(q["body"])) for q in questions if q.get("body"))
    fingerprints.update(normalize_question_stem(str(q["body"])) for q in questions if q.get("body"))
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
        rows = await cosmos_retry(lambda: cursor.to_list(length=200))
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

    doc_subjects: dict[str, str] = {}
    doc_subcats: dict[str, set[str]] = {}
    if current_sources.document_ids:
        doc_col = get_collection(user.tenant_id, DOCUMENTS)
        doc_cursor = doc_col.find(
            {"_id": {"$in": list(current_sources.document_ids)}},
            {"filename": 1, "topic_tags": 1, "category": 1, "subcategory": 1},
        )
        docs_raw = await cosmos_retry(lambda: doc_cursor.to_list(length=100))
        for doc_raw in docs_raw:
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

            s = cat or classify_subject_from_text(f"{fn} {subcat or ''}")
            if not s or s.casefold() == "study":
                for tag_name in tags:
                    ts = classify_subject_from_text(tag_name)
                    if ts and ts.casefold() != "study":
                        s = ts
                        break
            doc_subjects[str(doc_raw["_id"])] = s or ""

    col = get_collection(user.tenant_id, QUESTION_QUEUE)
    q_query: dict[str, Any] = {
        "workspace_id": workspace_id,
        "status": QuestionStatus.approved.value,
        "deleted_at": None,
    }
    if current_sources.document_ids:
        matching_doc_ids = (
            [did for did in current_sources.document_ids if subjects_match(doc_subjects.get(did, ""), subject)]
            if subject
            else list(current_sources.document_ids)
        )
        # If matching documents exist for the requested subject, query ONLY from those documents
        target_doc_ids = matching_doc_ids if matching_doc_ids else list(current_sources.document_ids)
        q_query["document_id"] = {"$in": sorted(target_doc_ids)}

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

    def matches_subject(q: Question) -> bool:
        if not subject:
            return True
        doc_s = doc_subjects.get(q.document_id, "")
        if is_conflicting_subject(doc_s, subject, body=q.body):
            return False
        q_top_subj = classify_subject_from_text(q.topic)
        if is_conflicting_subject(q_top_subj, subject, body=q.body):
            return False
        if is_conflicting_subject(None, subject, body=q.body):
            return False
        if is_math_question_body(q.body) and canonical_subject(subject).casefold() != "mathematics":
            return False

        # Reject if body content clearly classifies to a different core subject
        body_subj = classify_subject_from_text(q.body)
        if is_conflicting_subject(body_subj, subject, body=q.body):
            return False

        if q_top_subj and subjects_match(q_top_subj, subject):
            return True
        if subjects_match(body_subj, subject):
            return True
        if subjects_match(q.topic, subject):
            return True
        return bool(doc_s and subjects_match(doc_s, subject))

    if subject:
        available = [q for q in available if matches_subject(q)]

    # If available questions for this subject/workspace are fewer than target,
    # extract questions from any matching documents that haven't been queued yet
    if len(available) < target and current_sources.document_ids:
        try:
            from app.services.document_question_extractor import (
                extract_and_queue_document_questions,
            )
            for doc_id in current_sources.document_ids:
                doc_s = doc_subjects.get(doc_id, "")
                if not subject or subjects_match(doc_s, subject):
                    doc_has_avail = any(q.document_id == doc_id for q in available)
                    if not doc_has_avail:
                        extracted = await extract_and_queue_document_questions(
                            tenant_id=user.tenant_id,
                            workspace_id=workspace_id,
                            document_id=doc_id,
                        )
                        if extracted:
                            matching_extracted = [q for q in extracted if matches_subject(q)]
                            available.extend(matching_extracted)
        except Exception as e:
            logger.warning("Automated document question extraction encountered error: %s", e)

    def matches_subcat(q: Question) -> bool:
        if not subcategory:
            return True
        # If question topic conflicts with subject, reject immediately
        if subject and is_conflicting_subject(classify_subject_from_text(q.topic), subject, body=q.body):
            return False
        subcat_clean = subcategory.strip().casefold()
        q_top = q.topic.strip().casefold()
        if subcat_clean == q_top or subcat_clean in q_top or q_top in subcat_clean:
            return True
        sub_terms = {
            t for t in re.findall(r"[a-z0-9]+", subcat_clean)
            if len(t) >= 2 and not t.isdigit() and t not in {
                "the", "and", "in", "of", "to", "a", "an", "is", "for", "with", "on", "concepts", "fundamentals", "basics", "study", "class", "unit", "chapter"
            }
        }
        if not sub_terms:
            return True
        q_terms = {t for t in re.findall(r"[a-z0-9]+", q_top) if len(t) >= 2 and not t.isdigit()}
        body_terms = {t for t in re.findall(r"[a-z0-9]+", q.body.casefold()) if len(t) >= 2 and not t.isdigit()}
        # For concise topics (1-2 terms, e.g. 'Laws of Motion' -> 'laws', 'motion'):
        # Require ALL distinctive terms to match in either topic or body
        if len(sub_terms) <= 2:
            return sub_terms.issubset(q_terms) or sub_terms.issubset(body_terms)
        min_overlap = max(2, int(len(sub_terms) * 0.7))
        return len(sub_terms & q_terms) >= min_overlap or len(sub_terms & body_terms) >= min_overlap

    if subcategory:
        available = [q for q in available if matches_subcat(q)]

    if question_type:
        available = [q for q in available if q.question_type == question_type]

    # Gather question bodies and answers for all answered question IDs (INTERACTIONS)
    answered_records: list[tuple[str, str | None]] = [
        (q.body, q.answer) for q in available if q.id in seen_ids
    ]
    available_ids = {q.id for q in available}
    missing_answered_ids = [qid for qid in seen_ids if qid and qid not in session_seen_ids and qid not in available_ids]
    if missing_answered_ids:
        try:
            cursor_ans = col.find({"_id": {"$in": missing_answered_ids[:300]}}, {"body": 1, "answer": 1})
            docs_ans = await cosmos_retry(lambda: cursor_ans.to_list(length=300))
            for da in docs_ans:
                if da.get("_id") in missing_answered_ids and da.get("body"):
                    answered_records.append((str(da["body"]), str(da.get("answer", "")) or None))
        except Exception:
            pass

    historical_seen_records: list[tuple[str, str | None]] = [
        *[(b, None) for b in session_seen_bodies],
        *answered_records,
    ]

    # Combine fingerprints from answer history AND session plan history
    seen_fingerprints = (
        session_seen_fingerprints
        | {canonical_question_signature(b) for b, _ in historical_seen_records}
        | {normalize_question_stem(b) for b, _ in historical_seen_records}
        | {canonical_question_signature(question.body) for question in available if question.id in seen_ids}
    )

    # A normal study session is fresh-only. Previously answered questions,
    # questions delivered in prior session plans, and questions equivalent in
    # any form (canonical equation, template, or semantic duplicate) are not eligible.
    if revision:
        eligible = available
    else:
        eligible = [
            question
            for question in available
            if question.id not in seen_ids
            and question.id not in reserved_ids
            and canonical_question_signature(question.body) not in seen_fingerprints
            and canonical_question_signature(question.body) not in reserved_fingerprints
            and normalize_question_stem(question.body) not in seen_fingerprints
            and not is_candidate_duplicate(question.body, question.answer, historical_seen_records)
        ]

    selected = _unique_questions(eligible)[:target]
    missing = target - len(selected)
    should_generate = missing > 0 and (
        bool(current_sources.document_ids) or subcategory or question_type or _is_self_study(workspace_id)
    )
    if should_generate:
        # Optimized timeouts: LLM batch calls take 3-10s; 25s is ample and prevents timeout errors
        gen_timeout = 25.0 if (_is_self_study(workspace_id) or question_type) else (20.0 if current_sources.document_ids else 8.0)
        gen_batch = missing
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
                    extra_seen_bodies=[b for b, _ in historical_seen_records],
                ),
                timeout=gen_timeout,
            )
            if not revision:
                # Filter strictly for historical uniqueness AND topic purity — reject duplicates in any form
                generated = [
                    question
                    for question in generated
                    if question.document_id in current_sources.document_ids
                    and (not subject or matches_subject(question))
                    and (not subcategory or matches_subcat(question))
                    and question.id not in seen_ids
                    and question.id not in reserved_ids
                    and canonical_question_signature(question.body) not in seen_fingerprints
                    and canonical_question_signature(question.body) not in reserved_fingerprints
                    and canonical_question_signature(question.body) not in session_seen_fingerprints
                    and normalize_question_stem(question.body) not in seen_fingerprints
                    and not is_candidate_duplicate(question.body, question.answer, historical_seen_records)
                    and not is_candidate_duplicate(question.body, question.answer, [(q.body, q.answer) for q in selected])
                    and (not question_type or question.question_type == question_type)
                ]
            else:
                if subject:
                    generated = [q for q in generated if matches_subject(q)]
                if question_type:
                    generated = [q for q in generated if q.question_type == question_type]
                if subcategory:
                    generated = [q for q in generated if matches_subcat(q)]
            selected = _unique_questions([*selected, *generated])[:target]
            # If after generation we still have missing slots, do a swift top-up generation pass
            if len(selected) < target and not revision and current_sources.document_ids:
                try:
                    topup_needed = target - len(selected)
                    topup_generated = await asyncio.wait_for(
                        question_pipeline._generate_and_persist_batch(
                            tenant_id=user.tenant_id,
                            workspace_id=workspace_id,
                            student_id=user.id,
                            user_obj=user,
                            revision=revision,
                            subject=subject,
                            target_topic=subcategory,
                            target_type=question_type,
                            batch_size=max(topup_needed + 2, 5),
                            extra_seen_bodies=[*[b for b, _ in historical_seen_records], *(q.body for q in selected)],
                        ),
                        timeout=12.0,
                    )
                    topup_clean = [
                        q for q in topup_generated
                        if q.document_id in current_sources.document_ids
                        and (not subject or matches_subject(q))
                        and (not subcategory or matches_subcat(q))
                        and q.id not in seen_ids
                        and q.id not in reserved_ids
                        and canonical_question_signature(q.body) not in seen_fingerprints
                        and canonical_question_signature(q.body) not in session_seen_fingerprints
                        and normalize_question_stem(q.body) not in seen_fingerprints
                        and not is_candidate_duplicate(q.body, q.answer, historical_seen_records)
                        and not is_candidate_duplicate(q.body, q.answer, [(x.body, x.answer) for x in selected])
                        and (not question_type or q.question_type == question_type)
                    ]
                    selected = _unique_questions([*selected, *topup_clean])[:target]
                except Exception:
                    logger.debug("Top-up question generation skipped")
        except TimeoutError:
            logger.info("Synchronous question generation timed out; serving fast available questions")
        except Exception:
            logger.exception("Adaptive session batch generation failed")

    # Strict topic purity safeguard: ensure NO question outside the subcategory leaks in
    if subcategory:
        selected = [q for q in selected if matches_subcat(q)]

    # If fresh questions and generation could not fill the session target,
    # recycle previously answered questions ONLY in revision mode.
    # A fresh study session (revision=False) must never recycle old questions.
    if revision and len(selected) < target and available:
        selected_ids = {q.id for q in selected}
        selected_fps = {canonical_question_signature(q.body) for q in selected}
        recycled = [
            q for q in available
            if q.id not in selected_ids and canonical_question_signature(q.body) not in selected_fps
            and (not question_type or q.question_type == question_type)
        ]
        needed = target - len(selected)
        selected.extend(recycled[:needed])

    # RUNTIME MATERIAL VARIATION SYNTHESIS:
    # When not enough fresh questions remain (e.g. all original static items in the document
    # have been completed across prior sessions), NEVER stop session generation and NEVER leak
    # generic out-of-document fallback questions (calculus, quadratic discriminant, etc.)!
    # Instead, synthesize mathematically valid, modified variations of past study material
    # in real time.
    if len(selected) < target and not revision and (current_sources.document_ids or available or historical_seen_records):
        needed = target - len(selected)
        matching_doc_ids = [
            did for did in current_sources.document_ids
            if not subject or subjects_match(doc_subjects.get(did, ""), subject)
        ]
        doc_id = matching_doc_ids[0] if matching_doc_ids else (
            None if subject else (list(current_sources.document_ids)[0] if current_sources.document_ids else "doc_runtime_material")
        )
        if doc_id:
            current_seen_sigs = (
                seen_fingerprints
                | session_seen_fingerprints
                | {canonical_question_signature(q.body) for q in selected}
                | {normalize_question_stem(q.body) for q in selected}
            )
            eff_subj = subject or doc_subjects.get(doc_id, "") or (classify_subject_from_text(subcategory) if subcategory else "") or "study"
            try:
                variations = await generate_runtime_material_variations(
                    tenant_id=user.tenant_id,
                    workspace_id=workspace_id,
                    document_id=doc_id,
                    subject=eff_subj,
                    subcategory=subcategory,
                    seed_questions=available,
                    historical_seen_bodies=[b for b, _ in historical_seen_records],
                    seen_signatures=current_seen_sigs,
                    count=needed,
                    target_type=question_type,
                )
                if subject:
                    variations = [q for q in variations if matches_subject(q)]
                if subcategory:
                    variations = [q for q in variations if matches_subcat(q)]
                if question_type:
                    variations = [q for q in variations if q.question_type == question_type]
                selected.extend(variations)
            except Exception as var_exc:
                logger.exception("Runtime material variation generation failed: %s", var_exc)

    if not selected:
        if revision and available:
            selected = [q for q in available if not question_type or q.question_type == question_type][:target]
        elif current_sources.document_ids or available or historical_seen_records:
            matching_doc_ids = [
                did for did in current_sources.document_ids
                if not subject or subjects_match(doc_subjects.get(did, ""), subject)
            ]
            doc_id = matching_doc_ids[0] if matching_doc_ids else (
                None if subject else (list(current_sources.document_ids)[0] if current_sources.document_ids else "doc_runtime_material")
            )
            if doc_id:
                eff_subj = subject or doc_subjects.get(doc_id, "") or (classify_subject_from_text(subcategory) if subcategory else "") or "study"
                try:
                    variations = await generate_runtime_material_variations(
                        tenant_id=user.tenant_id,
                        workspace_id=workspace_id,
                        document_id=doc_id,
                        subject=eff_subj,
                        subcategory=subcategory,
                        seed_questions=available,
                        historical_seen_bodies=[b for b, _ in historical_seen_records],
                        seen_signatures=seen_fingerprints | session_seen_fingerprints,
                        count=target,
                        target_type=question_type,
                    )
                    if subject:
                        variations = [q for q in variations if matches_subject(q)]
                    if subcategory:
                        variations = [q for q in variations if matches_subcat(q)]
                    if question_type:
                        variations = [q for q in variations if q.question_type == question_type]
                    selected = variations[:target]
                except Exception as var_exc:
                    logger.exception("Direct runtime variation generation failed: %s", var_exc)

        # Emergency extraction retry if document questions were not available yet
        if not selected and current_sources.document_ids:
            try:
                from app.services.document_question_extractor import (
                    extract_and_queue_document_questions,
                )
                for doc_id in current_sources.document_ids:
                    doc_s = doc_subjects.get(doc_id, "")
                    if not subject or subjects_match(doc_s, subject):
                        extracted = await extract_and_queue_document_questions(
                            tenant_id=user.tenant_id,
                            workspace_id=workspace_id,
                            document_id=doc_id,
                        )
                        if extracted:
                            if subject:
                                extracted = [q for q in extracted if matches_subject(q)]
                            if subcategory:
                                extracted = [q for q in extracted if matches_subcat(q)]
                            if question_type:
                                extracted = [q for q in extracted if q.question_type == question_type]
                            selected = extracted[:target]
                            if selected:
                                break
            except Exception as ex:
                logger.warning("Emergency document extraction retry failed: %s", ex)

        # Emergency LLM generation pass on document chunks if still empty
        if not selected and current_sources.document_ids:
            try:
                emergency_gen = await question_pipeline._generate_and_persist_batch(
                    tenant_id=user.tenant_id,
                    workspace_id=workspace_id,
                    student_id=user.id,
                    user_obj=user,
                    revision=revision,
                    subject=subject or (list(doc_subjects.values())[0] if doc_subjects else None),
                    target_topic=subcategory,
                    target_type=question_type,
                    batch_size=target,
                    allow_repeats=True,
                )
                if emergency_gen:
                    selected = [
                        q for q in emergency_gen
                        if (not subject or matches_subject(q))
                        and (not question_type or q.question_type == question_type)
                    ][:target]
            except Exception as ex:
                logger.warning("Emergency LLM batch generation failed: %s", ex)

        if not selected:
            # Guaranteed fallback is ONLY permitted for cold-start workspaces with zero documents and zero history
            fb_plan = _build_guaranteed_fallback_plan(
                workspace_id=workspace_id,
                user_id=user.id,
                tenant_id=user.tenant_id,
                mode=AdaptiveSessionMode.study if not revision else AdaptiveSessionMode.revision,
                level=level,
                mastery=0.0,
                subject=subject or eff_subj,
                subcategory=subcategory,
                question_type=question_type,
            )
            filtered_fallback = [
                q for q in fb_plan.questions
                if q.id not in seen_ids
                and canonical_question_signature(q.body) not in seen_fingerprints
                and canonical_question_signature(q.body) not in session_seen_fingerprints
                and normalize_question_stem(q.body) not in seen_fingerprints
                and (not question_type or q.question_type == question_type)
                and (not subject or matches_subject(q))
            ]
            selected = (filtered_fallback if filtered_fallback else fb_plan.questions)[:target]

    # Strict question type safeguard: guarantee 100% format purity
    eff_qtype_str = None
    if question_type:
        eff_qtype_str = (
            question_type.value if hasattr(question_type, "value") else str(question_type)
        ).lower()
        selected = [
            q for q in selected
            if (q.question_type.value if hasattr(q.question_type, "value") else str(q.question_type)).lower() == eff_qtype_str
        ]

    prepared_results: list[PreparedQuestion] = []
    for question in selected:
        if isinstance(question, PreparedQuestion):
            if question.options and len(question.options) >= 2:
                shuffled_opts = list(question.options)
                random.shuffle(shuffled_opts)
                keys = ["A", "B", "C", "D"][:len(shuffled_opts)]
                correct_text = None
                for opt in question.options:
                    if opt.key.strip().upper() == str(question.answer).strip().upper():
                        correct_text = opt.text.strip().lower()
                        break
                new_opts = []
                new_ans = "A"
                for i, opt in enumerate(shuffled_opts):
                    k = keys[i]
                    new_opts.append(PreparedOption(key=k, text=opt.text))
                    if correct_text is not None and opt.text.strip().lower() == correct_text:
                        new_ans = k
                prepared_results.append(
                    PreparedQuestion(
                        id=question.id,
                        topic=question.topic,
                        question_type=question.question_type,
                        difficulty=question.difficulty,
                        body=question.body,
                        options=new_opts,
                        answer=new_ans,
                        explanation=question.explanation,
                        grading_hints=question.grading_hints,
                    )
                )
            else:
                prepared_results.append(question)
        else:
            prepared_results.append(_prepare_question_with_shuffled_options(question))

    return prepared_results[:target]


def _prepare_question_with_shuffled_options(question: Question) -> PreparedQuestion:
    """Prepare a question with deduplicated, shuffled options for MCQ questions."""
    raw_type = (
        question.question_type.value
        if hasattr(question.question_type, "value")
        else str(question.question_type)
    )
    options = list(question.options or [])
    answer = question.answer

    if raw_type == "mcq" and options:
        # Identify canonical correct option text
        correct_text: str | None = None
        for opt in options:
            if opt.is_correct or opt.key.strip().upper() == str(answer).strip().upper():
                correct_text = opt.text.strip().lower()
                break

        # Deduplicate option texts
        seen_texts: set[str] = set()
        deduped_opts = []
        for opt in options:
            norm = opt.text.strip().lower()
            if norm in seen_texts:
                continue
            seen_texts.add(norm)
            deduped_opts.append(opt)

        if len(deduped_opts) >= 2:
            options = deduped_opts

        shuffled = list(options)
        random.shuffle(shuffled)

        assigned_keys = ["A", "B", "C", "D"][:len(shuffled)]
        new_prepared_opts: list[PreparedOption] = []
        new_answer = "A"

        for i, opt in enumerate(shuffled):
            key = assigned_keys[i] if i < len(assigned_keys) else chr(ord("A") + i)
            new_prepared_opts.append(PreparedOption(key=key, text=opt.text))
            if (correct_text is not None and opt.text.strip().lower() == correct_text) or (
                correct_text is None and opt.is_correct
            ):
                new_answer = key

        return PreparedQuestion(
            id=question.id,
            topic=question.topic,
            question_type=question.question_type,
            difficulty=(
                question.difficulty.value
                if hasattr(question.difficulty, "value")
                else str(question.difficulty)
            ),
            body=question.body,
            options=new_prepared_opts,
            answer=new_answer,
            explanation=question.explanation,
            grading_hints=question.grading_hints,
        )

    return PreparedQuestion(
        id=question.id,
        topic=question.topic,
        question_type=question.question_type,
        difficulty=(
            question.difficulty.value
            if hasattr(question.difficulty, "value")
            else str(question.difficulty)
        ),
        body=question.body,
        options=[
            PreparedOption(key=option.key, text=option.text) for option in options
        ],
        answer=question.answer,
        explanation=question.explanation,
        grading_hints=question.grading_hints,
    )


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
            if subjects_match(classify_subject_from_text(t), subject)
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
        docs_raw = await cosmos_retry(lambda: doc_cursor.to_list(length=100))
        for doc_raw in docs_raw:
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

            s = cat or classify_subject_from_text(f"{fn} {subcat or ''}")
            if not s or s.casefold() == "study":
                for tag_name in tags:
                    ts = classify_subject_from_text(tag_name)
                    if ts and ts.casefold() != "study":
                        s = ts
                        break
            doc_subjects[str(doc_raw["_id"])] = s or ""

        if subject:
            def matches_card_subject(c: PreparedFlashcard) -> bool:
                card_text = f"{c.front} {c.back}"
                doc_s = doc_subjects.get(card_doc_ids.get(c.id, ""), "")
                if is_conflicting_subject(doc_s, subject, body=card_text):
                    return False
                c_top_s = classify_subject_from_text(c.topic)
                if is_conflicting_subject(c_top_s, subject, body=card_text):
                    return False
                if is_math_question_body(card_text) and canonical_subject(subject).casefold() != "mathematics":
                    return False
                if doc_s and subjects_match(doc_s, subject):
                    return True
                if c_top_s and subjects_match(c_top_s, subject):
                    return True
                if subjects_match(classify_subject_from_text(card_text), subject):
                    return True
                return bool(subjects_match(c.topic, subject))

            available_cards = [c for c in available_cards if matches_card_subject(c)]

        if subcategory:
            subcat_clean = subcategory.strip().casefold()
            sub_terms = {
                t for t in re.findall(r"[a-z0-9]+", subcat_clean)
                if len(t) >= 2 and not t.isdigit() and t not in {"the", "and", "in", "of", "to", "a", "an", "is", "for", "with", "on", "concepts", "fundamentals", "basics", "study"}
            }

            def matches_card_subcat(c: PreparedFlashcard) -> bool:
                c_top = c.topic.strip().casefold()
                if subcat_clean == c_top or subcat_clean in c_top or c_top in subcat_clean:
                    return True
                if not sub_terms:
                    return True
                c_terms = {t for t in re.findall(r"[a-z0-9]+", c_top) if len(t) >= 2 and not t.isdigit()}
                body_terms = {t for t in re.findall(r"[a-z0-9]+", (c.front + " " + c.back).casefold()) if len(t) >= 2 and not t.isdigit()}
                if len(sub_terms & c_terms) >= max(1, len(sub_terms) // 2):
                    return True
                return len(sub_terms & body_terms) >= max(1, len(sub_terms) // 2)

            available_cards = [c for c in available_cards if matches_card_subcat(c)]

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
    unseen_cards = _unique_flashcards(
        card
        for card in available_cards
        if card.id not in seen_ids
        and card.id not in reserved_ids
        and _flashcard_fingerprint(card.front, card.back) not in seen_fingerprints
        and _flashcard_fingerprint(card.front, card.back) not in reserved_fingerprints
    )

    if len(unseen_cards) >= target:
        return unseen_cards[:target]

    cards = list(unseen_cards)

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
                not subjects_match(classify_subject_from_text(question.topic), subject)
                and not subjects_match(doc_subjects.get(question.document_id, ""), subject)
            ):
                continue
        if subcategory:
            subcat_clean = subcategory.strip().casefold()
            sub_terms = set(re.findall(r"[a-z0-9]+", subcat_clean)) - {"the", "and", "in", "of", "to", "a", "an", "is", "for"}
            q_top = question.topic.strip().casefold()
            q_terms = set(re.findall(r"[a-z0-9]+", q_top)) - {"the", "and", "in", "of", "to", "a", "an", "is", "for"}
            body_terms = set(re.findall(r"[a-z0-9]+", question.body.casefold()))
            is_subcat_match = (
                subcat_clean in q_top
                or q_top in subcat_clean
                or bool(sub_terms and len(sub_terms & q_terms) >= max(1, len(sub_terms) // 2))
                or bool(sub_terms and len(sub_terms & body_terms) >= max(1, len(sub_terms) // 2))
            )
            if not is_subcat_match:
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
        fb_plan = _build_guaranteed_fallback_plan(
            workspace_id=workspace_id,
            user_id=user.id,
            tenant_id=user.tenant_id,
            mode=AdaptiveSessionMode.flashcard,
            level=level,
            mastery=0.0,
            subject=subject or (list(doc_subjects.values())[0] if doc_subjects else None),
            subcategory=subcategory,
            target=target,
        )
        return fb_plan.flashcards[:target]

    return selected[:target]


def _shuffle_prepared_mcq_options(q: PreparedQuestion) -> PreparedQuestion:
    """Shuffle options and re-assign keys for prepared MCQ questions."""
    raw_type = (
        q.question_type.value
        if hasattr(q.question_type, "value")
        else str(q.question_type)
    )
    if raw_type != "mcq" or not q.options:
        return q

    # 1. Identify canonical correct text
    correct_text: str | None = None
    for opt in q.options:
        if opt.key.strip().upper() == str(q.answer).strip().upper():
            correct_text = opt.text.strip().lower()
            break

    # 2. Deduplicate options by normalized text
    seen_texts: set[str] = set()
    unique_opts: list[PreparedOption] = []
    for opt in q.options:
        norm = opt.text.strip().lower()
        if norm in seen_texts:
            continue
        seen_texts.add(norm)
        unique_opts.append(opt)

    if len(unique_opts) < 2:
        unique_opts = list(q.options)

    shuffled = list(unique_opts)
    random.shuffle(shuffled)

    assigned_keys = ["A", "B", "C", "D"][:len(shuffled)]
    new_opts: list[PreparedOption] = []
    new_answer = "A"

    for i, opt in enumerate(shuffled):
        key = assigned_keys[i] if i < len(assigned_keys) else chr(ord("A") + i)
        new_opts.append(PreparedOption(key=key, text=opt.text))
        if correct_text is not None and opt.text.strip().lower() == correct_text:
            new_answer = key

    return PreparedQuestion(
        id=q.id,
        topic=q.topic,
        question_type=q.question_type,
        difficulty=q.difficulty,
        body=q.body,
        options=new_opts,
        answer=new_answer,
        explanation=q.explanation,
        grading_hints=q.grading_hints,
    )


_EXTRA_MATH_FLASHCARDS = [
    ("Slope-Intercept Form", "What is the slope-intercept form of a linear equation?", "y = mx + b, where m is the slope and b is the y-intercept.", "m represents rate of change and b represents where the line crosses the y-axis."),
    ("Pythagorean Theorem", "What is the Pythagorean theorem formula for right triangles?", "a² + b² = c², where c is the hypotenuse.", "Applies to right-angled Euclidean triangles."),
    ("Quadratic Formula", "State the quadratic formula used to solve ax² + bx + c = 0.", "x = (-b ± √(b² - 4ac)) / (2a)", "The discriminant b² - 4ac indicates the number of real roots."),
    ("Distributive Property", "What is the distributive property of multiplication over addition?", "a(b + c) = ab + ac", "Distributing multiplies the outer term by each term inside parentheses."),
    ("Product of Powers Rule", "What is the product rule for exponents with the same base (xᵃ · xᵇ)?", "xᵃ · xᵇ = xᵃ⁺ᵇ", "When multiplying powers with the same base, add their exponents."),
    ("Quotient of Powers Rule", "What is the quotient rule for exponents (xᵃ / xᵇ)?", "xᵃ / xᵇ = xᵃ⁻ᵇ (for x ≠ 0)", "When dividing powers with the same base, subtract exponents."),
    ("Zero Exponent Rule", "What is the value of any non-zero number raised to the power of 0 (x⁰)?", "1", "Any non-zero real number to the zero power equals 1."),
    ("Negative Exponent Rule", "How is a negative exponent x⁻ⁿ written in positive exponent form?", "x⁻ⁿ = 1 / xⁿ (for x ≠ 0)", "A negative exponent indicates the reciprocal."),
    ("Slope Formula", "What is the formula for the slope (m) between two points (x₁, y₁) and (x₂, y₂)?", "m = (y₂ - y₁) / (x₂ - x₁)", "Slope measures the steepness (rise over run) of a line."),
    ("Perpendicular Lines Slope", "How are the slopes of two perpendicular non-vertical lines related?", "They are negative reciprocals: m₁ · m₂ = -1", "Perpendicular lines intersect at a 90-degree angle."),
    ("Parallel Lines Slope", "How do the slopes of two distinct parallel lines compare?", "They are equal: m₁ = m₂", "Parallel lines never intersect and have identical steepness."),
    ("Midpoint Formula", "What is the midpoint formula for the line segment joining (x₁, y₁) and (x₂, y₂)?", "M = ((x₁ + x₂)/2, (y₁ + y₂)/2)", "The midpoint coordinates are the averages of the endpoints."),
    ("Distance Formula", "What is the distance formula between points (x₁, y₁) and (x₂, y₂)?", "d = √((x₂ - x₁)² + (y₂ - y₁)²)", "Derived directly from the Pythagorean theorem on a coordinate plane."),
    ("Domain of a Function", "In mathematics, what is the domain of a function?", "The complete set of all possible independent input values (x).", "Domain specifies where the function is mathematically defined."),
    ("Range of a Function", "In mathematics, what is the range of a function?", "The complete set of all possible dependent output values (y).", "Range represents the resulting outputs produced by the domain inputs."),
    ("Absolute Value", "What does the absolute value |x| geometrically represent?", "The distance of x from zero on the number line.", "Distance is always non-negative: |x| ≥ 0."),
    ("Linear Inequality Sign Flip", "When solving a linear inequality, when must you reverse the inequality sign?", "When multiplying or dividing both sides by a negative number.", "Multiplying by a negative inverts the order relation on the number line."),
    ("Greatest Common Factor", "What is the Greatest Common Factor (GCF) of two integers?", "The largest integer that divides both numbers without a remainder.", "Useful for simplifying fractions and factoring algebraic expressions."),
    ("Least Common Multiple", "What is the Least Common Multiple (LCM) of two integers?", "The smallest positive integer that is a multiple of both numbers.", "Used to find the common denominator when adding fractions."),
    ("FOIL Method", "What does the acronym FOIL stand for when multiplying two binomials?", "First, Outside, Inside, Last", "Ensures all pairs of terms are multiplied systematically: (a+b)(c+d)."),
    ("Commutative Property", "What does the commutative property of addition state?", "a + b = b + a", "Changing the order of addends does not change their sum."),
    ("Associative Property", "What does the associative property of addition state?", "(a + b) + c = a + (b + c)", "Changing the grouping of terms does not change their sum."),
    ("Direct Variation", "What is the equation for direct variation between y and x?", "y = kx, where k is the constant of variation.", "As x increases, y changes proportionally in the same direction."),
    ("Inverse Variation", "What is the equation for inverse variation between y and x?", "y = k / x, where k is the constant of variation.", "As x increases, y decreases proportionally such that xy = k."),
    ("Vertex Form of Quadratic", "What is the vertex form of a quadratic function?", "y = a(x - h)² + k, where (h, k) is the vertex.", "Reveals the vertex and axis of symmetry x = h directly.")
]


def _generate_fallback_equation_question(
    idx: int,
    target_qtype: str | None,
    subject: str | None = None,
) -> PreparedQuestion:
    a_vals = [2, 3, 4, 5, 6, 7, 8, 9]
    b_vals = [3, 4, 5, 6, 7, 8, 10, 12, 14, 15]
    x_roots = [2, 3, 4, 5, 6, 7, 8, 9]
    a = a_vals[idx % len(a_vals)]
    b = b_vals[(idx // 2) % len(b_vals)]
    root = x_roots[(idx * 3) % len(x_roots)]
    c = a * root + b

    eff_type = target_qtype or ("mcq" if idx % 3 == 0 else ("true_false" if idx % 3 == 1 else "short_answer"))

    if eff_type == "true_false":
        is_true = (idx % 2 == 0)
        claimed_val = root if is_true else root + 2
        return PreparedQuestion(
            id=f"qst_gen_tf_{uuid4().hex[:8]}",
            topic=subject or "Linear Equations in Algebra",
            question_type="true_false",
            difficulty="beginner",
            body=f"In the linear equation {a}x + {b} = {c}, the value of x is {claimed_val}.",
            options=[
                PreparedOption(key="true", text="True"),
                PreparedOption(key="false", text="False"),
            ],
            answer="true" if is_true else "false",
            explanation=f"Subtract {b} from both sides to get {a}x = {c - b}, then divide by {a} to get x = {root}.",
            grading_hints=[],
        )
    elif eff_type == "short_answer":
        return PreparedQuestion(
            id=f"qst_gen_sa_{uuid4().hex[:8]}",
            topic=subject or "Linear Equations in Algebra",
            question_type="short_answer",
            difficulty="beginner",
            body=f"Solve for x in the equation {a}x + {b} = {c}. What is the numerical value of x?",
            options=[],
            answer=str(root),
            explanation=f"Subtract {b} from both sides: {a}x = {c - b}. Divide both sides by {a}: x = {root}.",
            grading_hints=[str(root), f"x = {root}", f"x={root}"],
        )
    elif eff_type == "long_answer":
        return PreparedQuestion(
            id=f"qst_gen_la_{uuid4().hex[:8]}",
            topic=subject or "Linear Equations in Algebra",
            question_type="long_answer",
            difficulty="intermediate",
            body=f"Explain the step-by-step algebraic procedure used to solve {a}x + {b} = {c} for x, explicitly identifying the inverse operations applied.",
            options=[],
            answer=f"First, apply the subtraction property of equality to subtract {b} from both sides, yielding {a}x = {c - b}. Next, use the division property of equality to divide both sides by {a}, which yields x = {root}. Verification: {a}({root}) + {b} = {c}.",
            explanation="Isolating variables requires systematically undoing operations using properties of equality.",
            grading_hints=[f"subtract {b}", f"divide by {a}", f"x = {root}", "inverse operation"],
        )
    else:
        options = [
            PreparedOption(key="A", text=f"x = {root}"),
            PreparedOption(key="B", text=f"x = {root + 1}"),
            PreparedOption(key="C", text=f"x = {max(1, root - 1)}"),
            PreparedOption(key="D", text=f"x = {root + 3}"),
        ]
        return PreparedQuestion(
            id=f"qst_gen_mcq_{uuid4().hex[:8]}",
            topic=subject or "Linear Equations in Algebra",
            question_type="mcq",
            difficulty="beginner",
            body=f"What is the solution for x in {a}x + {b} = {c}?",
            options=options,
            answer="A",
            explanation=f"Subtract {b} from both sides: {a}x = {c - b}. Divide by {a}: x = {root}.",
            grading_hints=[],
        )

_TRIG_FLASHCARDS = [
    (
        "Trigonometric Ratios",
        "In a right triangle, how is sin(θ) defined in terms of side lengths?",
        "Opposite side divided by Hypotenuse (Opposite / Hypotenuse).",
        "sin(θ) = Opposite / Hypotenuse is the primary ratio for acute angles in a right-angled triangle.",
    ),
    (
        "Trigonometric Ratios",
        "In a right triangle, how is cos(θ) defined in terms of side lengths?",
        "Adjacent side divided by Hypotenuse (Adjacent / Hypotenuse).",
        "cos(θ) = Adjacent / Hypotenuse.",
    ),
    (
        "Trigonometric Ratios",
        "In a right triangle, how is tan(θ) defined?",
        "Opposite side divided by Adjacent side (Opposite / Adjacent).",
        "tan(θ) = Opposite / Adjacent, which is also equal to sin(θ) / cos(θ).",
    ),
    (
        "Pythagorean Trigonometric Identity",
        "What is the fundamental Pythagorean trigonometric identity relating sin(θ) and cos(θ)?",
        "sin²(θ) + cos²(θ) = 1",
        "Derived directly from the Pythagorean theorem a² + b² = c² by dividing through by c².",
    ),
    (
        "Special Angle Values",
        "What is the exact value of sin(30°) (or sin(π/6 radians))?",
        "1/2 (or 0.5)",
        "In a 30°-60°-90° special right triangle, the opposite leg is half the length of the hypotenuse.",
    ),
    (
        "Special Angle Values",
        "What is the exact value of cos(60°)?",
        "1/2 (or 0.5)",
        "cos(60°) = sin(30°) = 1/2 due to complementary angle properties.",
    ),
    (
        "Special Angle Values",
        "What is the exact value of tan(45°)?",
        "1",
        "In an isosceles right triangle (45°-45°-90°), opposite and adjacent sides are equal.",
    ),
    (
        "Reciprocal Trigonometric Functions",
        "What is the reciprocal function of cos(θ)?",
        "sec(θ) (secant)",
        "sec(θ) = 1 / cos(θ).",
    ),
    (
        "Reciprocal Trigonometric Functions",
        "What is the reciprocal function of sin(θ)?",
        "csc(θ) (cosecant)",
        "csc(θ) = 1 / sin(θ).",
    ),
    (
        "Trigonometric Identities",
        "State the identity relating tan²(θ) and sec²(θ).",
        "1 + tan²(θ) = sec²(θ)",
        "Dividing sin²(θ) + cos²(θ) = 1 through by cos²(θ) yields 1 + tan²(θ) = sec²(θ).",
    ),
    (
        "Law of Sines",
        "State the Law of Sines for a triangle with sides a, b, c and opposite angles A, B, C.",
        "a / sin(A) = b / sin(B) = c / sin(C)",
        "The Law of Sines equates the ratio of each side length to the sine of its opposite angle.",
    ),
    (
        "Unit Circle Coordinates",
        "On the unit circle with radius 1, what are the coordinates of the point for angle θ?",
        "(cos(θ), sin(θ))",
        "The x-coordinate corresponds to cos(θ) and the y-coordinate corresponds to sin(θ).",
    ),
]


def _generate_fallback_trigonometry_question(
    idx: int,
    target_qtype: str | None,
    subcategory: str | None = None,
) -> PreparedQuestion:
    triplets = [
        (3, 4, 5),
        (5, 12, 13),
        (8, 15, 17),
        (7, 24, 25),
        (9, 40, 41),
    ]
    opp, adj, hyp = triplets[idx % len(triplets)]
    scale = (idx // len(triplets)) + 1
    opp_s, adj_s, hyp_s = opp * scale, adj * scale, hyp * scale

    topic = subcategory or "Trigonometry"
    eff_type = target_qtype or ("mcq" if idx % 3 == 0 else ("true_false" if idx % 3 == 1 else "short_answer"))

    if eff_type == "true_false":
        is_true = (idx % 2 == 0)
        claimed_hyp = hyp_s if is_true else hyp_s + 2
        return PreparedQuestion(
            id=f"qst_trig_gen_tf_{uuid4().hex[:8]}",
            topic=topic,
            question_type="true_false",
            difficulty="beginner",
            body=f"In a right triangle with legs of length {opp_s} and {adj_s}, the length of the hypotenuse is {claimed_hyp}.",
            options=[
                PreparedOption(key="true", text="True"),
                PreparedOption(key="false", text="False"),
            ],
            answer="true" if is_true else "false",
            explanation=f"By the Pythagorean theorem, hypotenuse = √({opp_s}² + {adj_s}²) = √({opp_s**2 + adj_s**2}) = {hyp_s}.",
            grading_hints=[],
        )
    elif eff_type == "short_answer":
        return PreparedQuestion(
            id=f"qst_trig_gen_sa_{uuid4().hex[:8]}",
            topic=topic,
            question_type="short_answer",
            difficulty="beginner",
            body=f"In a right-angled triangle with legs of length {opp_s} and {adj_s}, what is the length of the hypotenuse?",
            options=[],
            answer=str(hyp_s),
            explanation=f"Hypotenuse = √({opp_s}² + {adj_s}²) = √({opp_s**2 + adj_s**2}) = {hyp_s}.",
            grading_hints=[str(hyp_s), f"c = {hyp_s}", f"c={hyp_s}"],
        )
    elif eff_type == "long_answer":
        return PreparedQuestion(
            id=f"qst_trig_gen_la_{uuid4().hex[:8]}",
            topic=topic,
            question_type="long_answer",
            difficulty="intermediate",
            body=f"In a right-angled triangle with opposite side {opp_s} and adjacent side {adj_s}, calculate the hypotenuse and explain how to find sin(θ).",
            options=[],
            answer=f"First, calculate the hypotenuse using the Pythagorean theorem: c = √({opp_s}² + {adj_s}²) = {hyp_s}. Next, sin(θ) = Opposite / Hypotenuse = {opp_s} / {hyp_s} = {opp}/{hyp}.",
            explanation="The Pythagorean theorem yields the hypotenuse, and the sine ratio evaluates opposite over hypotenuse.",
            grading_hints=[f"{hyp_s}", f"{opp}/{hyp}", "opposite / hypotenuse", "Pythagorean theorem"],
        )
    else:
        return PreparedQuestion(
            id=f"qst_trig_gen_mcq_{uuid4().hex[:8]}",
            topic=topic,
            question_type="mcq",
            difficulty="beginner",
            body=f"In a right-angled triangle with opposite side {opp_s} and adjacent side {adj_s}, what is the value of sin(θ)?",
            options=[
                PreparedOption(key="A", text=f"{opp}/{hyp}"),
                PreparedOption(key="B", text=f"{adj}/{hyp}"),
                PreparedOption(key="C", text=f"{opp}/{adj}"),
                PreparedOption(key="D", text=f"{hyp}/{opp}"),
            ],
            answer="A",
            explanation=f"sin(θ) = Opposite / Hypotenuse. With hypotenuse = {hyp_s}, sin(θ) = {opp_s}/{hyp_s} = {opp}/{hyp}.",
            grading_hints=[],
        )


_EXTRA_SCIENCE_FLASHCARDS = [
    ("Scientific Method", "What is the role of an independent variable in an experiment?", "The variable that is deliberately changed or manipulated by the experimenter.", "The independent variable tests the effect on the dependent variable."),
    ("Scientific Method", "What is a control group in a scientific investigation?", "A group that receives no experimental treatment to serve as a baseline for comparison.", "Control groups isolate the effects of the experimental manipulation."),
    ("Cell Biology", "Which organelle is responsible for cellular respiration and ATP generation?", "Mitochondria (mitochondrion).", "Often termed the powerhouse of the cell, it breaks down glucose into usable ATP energy."),
    ("Cell Biology", "Which plant cell organelle conducts photosynthesis?", "Chloroplast.", "Chloroplasts contain chlorophyll pigments that absorb sunlight to synthesize glucose."),
    ("Cell Biology", "What is the primary function of ribosomes in living cells?", "Protein synthesis.", "Ribosomes assemble amino acid chains based on genetic mRNA codes."),
    ("Cell Biology", "What cellular structure regulates what enters and exits the cell?", "The cell membrane (plasma membrane).", "A phospholipid bilayer with selective permeability."),
    ("Molecular Genetics", "What molecule stores hereditary genetic instructions in living organisms?", "DNA (Deoxyribonucleic acid).", "DNA encodes instructions via sequences of adenine, thymine, cytosine, and guanine."),
    ("Molecular Genetics", "What process results in two genetically identical diploid daughter cells?", "Mitosis.", "Mitosis is essential for growth, tissue repair, and asexual reproduction."),
    ("Molecular Genetics", "What process produces four genetically diverse haploid gametes?", "Meiosis.", "Meiosis reduces chromosome number by half for sexual reproduction."),
    ("Atomic Structure", "What does the atomic number of an element represent?", "The number of protons in the nucleus of an atom.", "The atomic number uniquely identifies the chemical element."),
    ("Chemical Bonding", "What type of chemical bond forms when atoms share pairs of electrons?", "A covalent bond.", "Covalent bonding typically occurs between nonmetal atoms sharing valence electrons."),
    ("Chemical Bonding", "What type of chemical bond forms from electrostatic attraction between oppositely charged ions?", "An ionic bond.", "Ionic bonds form when one atom transfers electrons to another, creating ions."),
    ("Conservation of Mass", "State the Law of Conservation of Mass in chemical reactions.", "Mass is neither created nor destroyed; total reactant mass equals total product mass.", "Atoms are rearranged during chemical reactions without altering total mass."),
    ("Acids and Bases", "On the pH scale, how are acidic, neutral, and alkaline solutions identified?", "pH < 7 is acidic, pH = 7 is neutral, and pH > 7 is basic (alkaline).", "pH measures hydrogen ion concentration on a logarithmic scale."),
    ("Newton's Laws", "State Newton's First Law of Motion (Law of Inertia).", "An object at rest stays at rest, and an object in motion stays in motion unless acted upon by a net external force.", "Inertia is the resistance of an object to changes in its velocity."),
    ("Newton's Laws", "State Newton's Second Law of Motion formula.", "F = ma (Net Force = mass × acceleration).", "Acceleration is directly proportional to net force and inversely proportional to mass."),
    ("Newton's Laws", "State Newton's Third Law of Motion.", "For every action, there is an equal and opposite reaction.", "Forces always occur in matched interaction pairs acting on different bodies."),
    ("Energy Transformations", "State the Law of Conservation of Energy.", "Energy cannot be created or destroyed, only transformed from one form to another.", "Total energy in an isolated system remains constant over time."),
    ("Ecology", "In an ecological food chain, what role do producers (autotrophs) serve?", "They produce organic nutrients from inorganic sources like sunlight via photosynthesis.", "Plants and algae form the base trophic level for consumers."),
    ("Earth Science", "What geological theory explains the movement of Earth's lithospheric plates?", "Plate Tectonics.", "Convection currents in the mantle drive the slow movement of continental and oceanic plates."),
]

_SCIENCE_QUESTION_BANKS = [
    {
        "topic": "Cell Biology",
        "mcq": {
            "body": "Which organelle is primarily responsible for synthesizing adenosine triphosphate (ATP) in eukaryotic cells?",
            "options": [
                ("A", "Mitochondria", True),
                ("B", "Endoplasmic reticulum", False),
                ("C", "Golgi apparatus", False),
                ("D", "Lysosome", False),
            ],
            "explanation": "Mitochondria generate the vast majority of cellular ATP via oxidative phosphorylation.",
        },
        "true_false": {
            "body": "Chloroplasts are specialized organelles found in plant cells that convert solar energy into chemical energy through photosynthesis.",
            "answer": "true",
            "explanation": "Chloroplasts contain chlorophyll to absorb light energy and synthesize glucose.",
        },
        "short_answer": {
            "body": "Which cellular organelle is universally responsible for synthesizing proteins from amino acids?",
            "answer": "ribosome",
            "explanation": "Ribosomes translate mRNA transcripts into polypeptide chains.",
            "hints": ["ribosome", "ribosomes"],
        },
        "long_answer": {
            "body": "Explain the role of the cell membrane and how selective permeability protects cell function.",
            "answer": "The phospholipid bilayer forms a semi-permeable barrier regulating the movement of substances into and out of the cell to maintain homeostasis.",
            "explanation": "Selective transport maintains necessary internal concentrations of ions and nutrients.",
            "hints": ["phospholipid bilayer", "selective permeability", "homeostasis", "transport"],
        },
    },
    {
        "topic": "Scientific Method",
        "mcq": {
            "body": "In a controlled scientific experiment, what is the variable that the experimenter deliberately changes to test an effect?",
            "options": [
                ("A", "Independent variable", True),
                ("B", "Dependent variable", False),
                ("C", "Controlled constant", False),
                ("D", "Confounding factor", False),
            ],
            "explanation": "The independent variable is intentionally altered to observe its effect on the dependent variable.",
        },
        "true_false": {
            "body": "A scientific hypothesis must be both testable through empirical observation and capable of being proven false (falsifiable).",
            "answer": "true",
            "explanation": "Scientific hypotheses require empirical testability and falsifiability to qualify as valid scientific inquiries.",
        },
        "short_answer": {
            "body": "In a controlled experiment, what is the term for the baseline group that does not receive the experimental treatment?",
            "answer": "control group",
            "explanation": "The control group serves as a comparison benchmark to isolate the treatment's true effect.",
            "hints": ["control group", "control", "control baseline"],
        },
        "long_answer": {
            "body": "Explain the difference between an independent variable and a dependent variable in a scientific experiment.",
            "answer": "The independent variable is changed or manipulated by the researcher, whereas the dependent variable is measured to observe the response caused by that change.",
            "explanation": "Cause and effect relationships are isolated by manipulating only one variable at a time.",
            "hints": ["independent variable", "dependent variable", "manipulate", "measure", "cause and effect"],
        },
    },
    {
        "topic": "Chemical Foundations",
        "mcq": {
            "body": "Which subatomic particle possesses a positive electrical charge and is located in the nucleus of an atom?",
            "options": [
                ("A", "Proton", True),
                ("B", "Electron", False),
                ("C", "Neutron", False),
                ("D", "Photon", False),
            ],
            "explanation": "Protons have a +1 relative charge and reside within the atomic nucleus, defining the atomic number.",
        },
        "true_false": {
            "body": "In a covalent bond, two atoms share one or more pairs of valence electrons to achieve stable electron configurations.",
            "answer": "true",
            "explanation": "Covalent bonding involves the mutual sharing of valence electrons between atoms.",
        },
        "short_answer": {
            "body": "What term describes a substance with a pH value strictly lower than 7.0 on the pH scale?",
            "answer": "acid",
            "explanation": "A pH below 7 indicates an excess of hydronium ions, defining an acidic solution.",
            "hints": ["acid", "acidic", "an acid"],
        },
        "long_answer": {
            "body": "State the Law of Conservation of Mass and explain its significance in balancing chemical equations.",
            "answer": "Mass cannot be created or destroyed in a chemical reaction; the total number and type of atoms in reactants must equal the total in products.",
            "explanation": "Chemical reactions rearrange atomic bonds without altering total atomic mass.",
            "hints": ["mass cannot be created or destroyed", "reactants equal products", "rearranged atoms"],
        },
    },
    {
        "topic": "Physics & Energy",
        "mcq": {
            "body": "According to Newton's Second Law of Motion, what is the direct mathematical relationship between net force (F), mass (m), and acceleration (a)?",
            "options": [
                ("A", "F = m · a", True),
                ("B", "F = m / a", False),
                ("C", "F = a / m", False),
                ("D", "F = m + a", False),
            ],
            "explanation": "Newton's Second Law states that force equals mass multiplied by acceleration (F = ma).",
        },
        "true_false": {
            "body": "The Law of Conservation of Energy states that energy can be created or destroyed during high-speed physical transformations.",
            "answer": "false",
            "explanation": "Energy cannot be created or destroyed; it can only be converted from one form to another.",
        },
        "short_answer": {
            "body": "What is the scientific term for the tendency of an object to resist any change in its state of motion?",
            "answer": "inertia",
            "explanation": "Inertia is the property of matter described by Newton's First Law of Motion.",
            "hints": ["inertia", "mass inertia"],
        },
        "long_answer": {
            "body": "Explain Newton's Third Law of Motion and provide a real-world example illustrating action and reaction forces.",
            "answer": "For every action force, there is an equal and opposite reaction force acting simultaneously on different objects, such as a rocket pushing exhaust gases downward while the gases push the rocket upward.",
            "explanation": "Forces always occur in matched interaction pairs on interacting objects.",
            "hints": ["equal and opposite", "action and reaction", "rocket", "pairs"],
        },
    },
    {
        "topic": "Genetics & Heredity",
        "mcq": {
            "body": "What helical macromolecule carries the primary genetic code and hereditary instructions in all living cellular organisms?",
            "options": [
                ("A", "Deoxyribonucleic acid (DNA)", True),
                ("B", "Ribonucleic acid (RNA)", False),
                ("C", "Hemoglobin", False),
                ("D", "Adenosine triphosphate (ATP)", False),
            ],
            "explanation": "DNA contains the nucleotide sequences that encode hereditary instructions for cellular development and function.",
        },
        "true_false": {
            "body": "Mitosis produces four genetically unique haploid gamete cells during reproduction.",
            "answer": "false",
            "explanation": "Mitosis produces two genetically identical diploid somatic cells. Meiosis produces four genetically diverse haploid gametes.",
        },
        "short_answer": {
            "body": "What genetic term describes the observable physical traits and characteristics of an organism?",
            "answer": "phenotype",
            "explanation": "Phenotype is the expression of the organism's genotype interacting with its environment.",
            "hints": ["phenotype", "the phenotype"],
        },
        "long_answer": {
            "body": "Distinguish between an organism's genotype and its phenotype with a concrete biological example.",
            "answer": "Genotype refers to the specific genetic allele combination inherited by an organism, whereas phenotype is the observable physical manifestation of those genes.",
            "explanation": "Environmental and genetic factors interact to express phenotypic traits from genotypic data.",
            "hints": ["genotype", "phenotype", "alleles", "observable traits"],
        },
    },
    {
        "topic": "Ecology & Earth Systems",
        "mcq": {
            "body": "In an ecosystem, which organism category converts sunlight into chemical energy to serve as the foundation of the food web?",
            "options": [
                ("A", "Primary producers (autotrophs)", True),
                ("B", "Primary consumers (herbivores)", False),
                ("C", "Secondary consumers (carnivores)", False),
                ("D", "Decomposers (saprotrophs)", False),
            ],
            "explanation": "Autotrophic primary producers like plants and phytoplankton capture radiant energy via photosynthesis.",
        },
        "true_false": {
            "body": "In the water cycle, water vapor cools and condenses to form liquid clouds in the atmosphere.",
            "answer": "true",
            "explanation": "Condensation transitions gaseous water vapor into liquid water droplets or ice crystals forming clouds.",
        },
        "short_answer": {
            "body": "What biological process enables plants to convert sunlight, carbon dioxide, and water into glucose and oxygen?",
            "answer": "photosynthesis",
            "explanation": "Photosynthesis is the foundational autotrophic chemical pathway producing organic carbohydrates and oxygen.",
            "hints": ["photosynthesis", "photo-synthesis"],
        },
        "long_answer": {
            "body": "Explain the role of decomposers in an ecosystem and what would happen to nutrient cycling without them.",
            "answer": "Decomposers break down dead organic matter and waste, releasing essential chemical nutrients back into the soil and ecosystem for primary producers to reabsorb.",
            "explanation": "Without decomposers, organic matter would accumulate and vital nutrients like carbon and nitrogen would remain locked away.",
            "hints": ["decomposers", "nutrient cycling", "break down", "recycle"],
        },
    },
]


def _is_science_subject(subject_or_category: str | None) -> bool:
    if not subject_or_category:
        return False
    s = subject_or_category.strip().lower()
    # Dedicated scientific disciplines must NEVER be grouped into generic science
    if any(d in s for d in ("physics", "phys", "chemistry", "chem", "biology", "bio")):
        return False
    science_keywords = (
        "science", "general science", "life science", "physical science",
        "integrated science", "earth & space science", "earth science",
        "environmental science",
    )
    return any(k in s for k in science_keywords)


def _generate_fallback_science_question(
    idx: int,
    target_qtype: str | None,
    subject: str | None = None,
    subcategory: str | None = None,
) -> PreparedQuestion:
    bank = _SCIENCE_QUESTION_BANKS[idx % len(_SCIENCE_QUESTION_BANKS)]
    topic = subcategory or bank["topic"]
    eff_type = target_qtype or ("mcq" if idx % 3 == 0 else ("true_false" if idx % 3 == 1 else "short_answer"))

    if eff_type == "true_false":
        tf = bank["true_false"]
        return PreparedQuestion(
            id=f"qst_sci_gen_tf_{uuid4().hex[:8]}",
            topic=topic,
            question_type="true_false",
            difficulty="beginner",
            body=tf["body"],
            options=[
                PreparedOption(key="true", text="True"),
                PreparedOption(key="false", text="False"),
            ],
            answer=tf["answer"],
            explanation=tf["explanation"],
            grading_hints=[],
        )
    elif eff_type == "short_answer":
        sa = bank["short_answer"]
        return PreparedQuestion(
            id=f"qst_sci_gen_sa_{uuid4().hex[:8]}",
            topic=topic,
            question_type="short_answer",
            difficulty="beginner",
            body=sa["body"],
            options=[],
            answer=sa["answer"],
            explanation=sa["explanation"],
            grading_hints=sa["hints"],
        )
    elif eff_type == "long_answer":
        la = bank["long_answer"]
        return PreparedQuestion(
            id=f"qst_sci_gen_la_{uuid4().hex[:8]}",
            topic=topic,
            question_type="long_answer",
            difficulty="intermediate",
            body=la["body"],
            options=[],
            answer=la["answer"],
            explanation=la["explanation"],
            grading_hints=la["hints"],
        )
    else:
        mcq = bank["mcq"]
        options = [
            PreparedOption(key=opt[0], text=opt[1])
            for opt in mcq["options"]
        ]
        correct_key = next((opt[0] for opt in mcq["options"] if opt[2]), "A")
        return PreparedQuestion(
            id=f"qst_sci_gen_mcq_{uuid4().hex[:8]}",
            topic=topic,
            question_type="mcq",
            difficulty="beginner",
            body=mcq["body"],
            options=options,
            answer=correct_key,
            explanation=mcq["explanation"],
            grading_hints=[],
        )


def _is_physics_subject(subject_or_category: str | None) -> bool:
    if not subject_or_category:
        return False
    s = subject_or_category.strip().lower()
    physics_keywords = (
        "physics", "phys", "motion", "mechanics", "kinematics", "dynamics",
        "thermodynamics", "optics", "electromagnetism", "gravity", "gravitation",
        "newton", "rotational", "oscillation", "waves", "electrostatics", "force",
    )
    if any(k in s for k in physics_keywords):
        return True
    return canonical_subject(subject_or_category).casefold() == "physics"


def _is_chemistry_subject(subject_or_category: str | None) -> bool:
    if not subject_or_category:
        return False
    s = subject_or_category.strip().lower()
    chem_keywords = (
        "chemistry", "chem", "organic chemistry", "inorganic chemistry",
        "physical chemistry", "periodic table", "stoichiometry", "atomic structure",
        "chemical bonding", "electrochemistry", "equilibrium", "solutions",
    )
    if any(k in s for k in chem_keywords) and not _is_physics_subject(subject_or_category):
        return True
    return canonical_subject(subject_or_category).casefold() == "chemistry"


def _is_biology_subject(subject_or_category: str | None) -> bool:
    if not subject_or_category:
        return False
    s = subject_or_category.strip().lower()
    bio_keywords = (
        "biology", "bio", "cell", "cellular", "genetics", "botany", "zoology",
        "ecosystem", "ecology", "anatomy", "physiology", "reproduction",
        "evolution", "biotechnology", "microbiology",
    )
    if any(k in s for k in bio_keywords) and not _is_physics_subject(subject_or_category):
        return True
    return canonical_subject(subject_or_category).casefold() == "biology"


_PHYSICS_FALLBACK_BANK = [
    {
        "topic": "Newton's Laws of Motion",
        "mcq": {
            "body": "Which property of a physical body causes it to resist any change in its state of rest or uniform motion?",
            "options": [("A", "Friction"), ("B", "Inertia"), ("C", "Gravity"), ("D", "Momentum")],
            "answer": "B",
            "explanation": "Inertia is the inherent tendency of an object to resist changes in its state of motion.",
        },
        "true_false": {
            "body": "Newton's First Law of Motion is also widely known as the Law of Inertia.",
            "answer": "true",
            "explanation": "Newton's First Law states that an object continues in its state of rest or uniform straight-line motion unless acted upon by an external unbalanced force.",
        },
        "short_answer": {
            "body": "The tendency of a body to remain at rest or continue moving with uniform velocity is known as ________.",
            "answer": "inertia",
            "explanation": "Inertia is the property of matter by which it continues in its existing state of rest or uniform motion.",
            "grading_hints": ["inertia"],
        },
        "long_answer": {
            "body": "State Newton's First Law of Motion and explain why passengers lurch forward when a moving bus suddenly brakes.",
            "answer": "Newton's First Law states that an object continues in its state of rest or uniform motion in a straight line unless acted upon by an external net force. When the bus decelerates suddenly, passengers' bodies tend to maintain their forward velocity due to inertia, causing them to pitch forward until an external restraining force acts on them.",
            "explanation": "Inertia resists the instantaneous change in velocity.",
            "grading_hints": ["law of inertia", "external force", "tendency to continue moving", "deceleration"],
        },
    },
    {
        "topic": "Newton's Laws of Motion",
        "mcq": {
            "body": "According to Newton's Second Law of Motion (F = ma), what net force is required to accelerate a 5 kg mass at 4 m/s²?",
            "options": [("A", "20 N"), ("B", "10 N"), ("C", "1.25 N"), ("D", "9 N")],
            "answer": "A",
            "explanation": "F = m * a = 5 kg * 4 m/s² = 20 N.",
        },
        "true_false": {
            "body": "According to Newton's Second Law, acceleration is directly proportional to net force and inversely proportional to mass.",
            "answer": "true",
            "explanation": "a = F_net / m, meaning acceleration scales linearly with force and inversely with mass.",
        },
        "short_answer": {
            "body": "In the equation F = ma, the SI unit of force is the ________.",
            "answer": "newton",
            "explanation": "One Newton is defined as 1 kg·m/s².",
            "grading_hints": ["newton", "newtons", "N"],
        },
        "long_answer": {
            "body": "Explain the relationship between net force, mass, and acceleration as described by Newton's Second Law.",
            "answer": "Newton's Second Law states that the rate of change of linear momentum of a body is directly proportional to the applied force. For constant mass, this simplifies to F = ma, where force equals mass times acceleration.",
            "explanation": "F = ma connects dynamics and kinematics.",
            "grading_hints": ["F = ma", "directly proportional", "inversely proportional", "momentum"],
        },
    },
    {
        "topic": "Newton's Laws of Motion",
        "mcq": {
            "body": "Newton's Third Law states that for every action, there is an equal and opposite reaction. These action-reaction forces:",
            "options": [
                ("A", "Act on the same object and cancel each other out"),
                ("B", "Act on different interacting objects"),
                ("C", "Act in the same direction"),
                ("D", "Differ in magnitude depending on mass"),
            ],
            "answer": "B",
            "explanation": "Action and reaction forces always act on two different interacting bodies, so they never cancel each other out on a single object.",
        },
        "true_false": {
            "body": "Newton's Third Law of Motion implies that forces always occur in matched interaction pairs.",
            "answer": "true",
            "explanation": "Isolated single forces cannot exist in nature; forces always occur in mutual interaction pairs.",
        },
        "short_answer": {
            "body": "The product of an object's mass and its velocity (p = mv) represents linear ________.",
            "answer": "momentum",
            "explanation": "Linear momentum is defined as the product of mass and velocity.",
            "grading_hints": ["momentum", "linear momentum"],
        },
        "long_answer": {
            "body": "Explain how Newton's Third Law applies to rocket propulsion in the vacuum of space.",
            "answer": "A rocket expels high-velocity exhaust gases backward out of its nozzle (action force). By Newton's Third Law, the escaping gas exerts an equal and opposite forward thrust force on the rocket (reaction force), accelerating the rocket forward without needing surrounding air to push against.",
            "explanation": "Rocket engines rely on conservation of momentum and Newton's third law interaction pairs.",
            "grading_hints": ["action force", "reaction force", "thrust", "exhaust gases", "opposite direction"],
        },
    },
    {
        "topic": "Kinetic Energy",
        "mcq": {
            "body": "If the velocity of a moving object is doubled, by what factor does its kinetic energy (KE = ½mv²) increase?",
            "options": [("A", "2 times"), ("B", "4 times"), ("C", "8 times"), ("D", "Remains unchanged")],
            "answer": "B",
            "explanation": "Since kinetic energy depends on the square of velocity (v²), doubling v results in 2² = 4 times the kinetic energy.",
        },
        "true_false": {
            "body": "Work is done on an object only when a force causes a displacement along the direction of that force.",
            "answer": "true",
            "explanation": "W = F * d * cos(theta). If displacement is zero or perpendicular to force, work done is zero.",
        },
        "short_answer": {
            "body": "The rate at which work is performed or energy is transferred per unit time is defined as ________.",
            "answer": "power",
            "explanation": "Power P = W / t, measured in Watts (Joules per second).",
            "grading_hints": ["power"],
        },
        "long_answer": {
            "body": "State the Work-Energy Theorem and explain how it relates the net work done on an object to its motion.",
            "answer": "The Work-Energy Theorem states that the net work done by all forces acting on a particle equals the change in its kinetic energy: W_net = Delta KE = 1/2 m v_f^2 - 1/2 m v_i^2. Positive net work increases speed, while negative net work decreases speed.",
            "explanation": "The theorem connects mechanical work directly to changes in kinetic energy.",
            "grading_hints": ["change in kinetic energy", "net work", "velocity", "W = Delta KE"],
        },
    },
    {
        "topic": "Gravitation",
        "mcq": {
            "body": "According to Newton's Law of Universal Gravitation, what happens to the gravitational attraction between two masses if the distance between them is doubled?",
            "options": [("A", "It doubles"), ("B", "It is halved"), ("C", "It is reduced to one-fourth (1/4)"), ("D", "It is quadrupled")],
            "answer": "C",
            "explanation": "Gravitational force follows an inverse-square law: F is proportional to 1/r², so doubling distance reduces force to 1/4.",
        },
        "true_false": {
            "body": "In a vacuum where aerodynamic drag is absent, all free-falling objects accelerate toward Earth at the exact same rate regardless of their mass.",
            "answer": "true",
            "explanation": "Gravitational acceleration g = GM/r² is independent of the falling object's own mass.",
        },
        "short_answer": {
            "body": "The standard acceleration due to gravity near Earth's surface is approximately ________ m/s² (rounded to one decimal place).",
            "answer": "9.8",
            "explanation": "g = 9.8 m/s² near the surface of the Earth.",
            "grading_hints": ["9.8", "9.81", "9.8 m/s^2"],
        },
        "long_answer": {
            "body": "Distinguish clearly between the mass of an object and its weight on different celestial bodies.",
            "answer": "Mass is an intrinsic measure of the quantity of matter in an object and remains constant anywhere in the universe (measured in kg). Weight is the downward gravitational force acting on that mass (W = mg), which varies directly with the local gravitational field strength g of the planet or celestial body (measured in Newtons).",
            "explanation": "Mass is an invariant scalar quantity, whereas weight is a force dependent on local gravity.",
            "grading_hints": ["mass is constant", "weight is force", "W = mg", "gravitational acceleration", "Newtons vs kilograms"],
        },
    },
]

_CHEMISTRY_FALLBACK_BANK = [
    {
        "topic": "Atomic Structure",
        "mcq": {
            "body": "Which subatomic particle carries a negative electric charge and orbits the atomic nucleus?",
            "options": [("A", "Proton"), ("B", "Electron"), ("C", "Neutron"), ("D", "Positron")],
            "answer": "B",
            "explanation": "Electrons carry a negative elementary charge (-1) and occupy orbitals around the positive nucleus.",
        },
        "true_false": {
            "body": "The atomic number of an element is determined solely by the number of protons in its nucleus.",
            "answer": "true",
            "explanation": "Atomic number Z equals the number of nuclear protons, defining the element's identity.",
        },
        "short_answer": {
            "body": "The dense central core of an atom containing protons and neutrons is called the ________.",
            "answer": "nucleus",
            "explanation": "The atomic nucleus contains essentially all of the atom's mass.",
            "grading_hints": ["nucleus", "atomic nucleus"],
        },
        "long_answer": {
            "body": "Describe the three primary subatomic particles of an atom, including their relative charges and locations.",
            "answer": "Protons have a +1 charge and reside in the nucleus. Neutrons have no charge (neutral) and reside in the nucleus. Electrons have a -1 charge and orbit the nucleus in electron shells.",
            "explanation": "These three particles compose standard atomic architecture.",
            "grading_hints": ["proton", "neutron", "electron", "nucleus", "charges"],
        },
    },
    {
        "topic": "Chemical Bonding",
        "mcq": {
            "body": "A chemical bond formed by the sharing of one or more electron pairs between nonmetal atoms is called a(n):",
            "options": [("A", "Ionic bond"), ("B", "Covalent bond"), ("C", "Metallic bond"), ("D", "Hydrogen bond")],
            "answer": "B",
            "explanation": "Covalent bonding involves the mutual sharing of valence electrons between atoms.",
        },
        "true_false": {
            "body": "Ionic bonds are formed through the electrostatic attraction between oppositely charged ions.",
            "answer": "true",
            "explanation": "Ionic bonds occur when electrons are transferred from a metal to a nonmetal, creating oppositely charged ions.",
        },
        "short_answer": {
            "body": "A positively charged ion formed when an atom loses one or more electrons is called a(n) ________.",
            "answer": "cation",
            "explanation": "Cations are positive ions; anions are negative ions.",
            "grading_hints": ["cation", "cations"],
        },
        "long_answer": {
            "body": "Compare covalent and ionic bonds in terms of electron distribution and properties of the resulting compounds.",
            "answer": "In covalent bonds, electrons are shared between atoms, often forming molecular compounds with lower melting points. In ionic bonds, electrons are transferred completely, creating crystal lattices with high melting points and electrical conductivity when dissolved.",
            "explanation": "Bond type dictates physical and chemical characteristics.",
            "grading_hints": ["sharing vs transfer", "melting points", "lattice", "ions"],
        },
    },
]

_BIOLOGY_FALLBACK_BANK = [
    {
        "topic": "Cell Biology",
        "mcq": {
            "body": "Which cellular organelle is responsible for generating most of the cell's ATP via aerobic cellular respiration?",
            "options": [("A", "Ribosome"), ("B", "Mitochondria"), ("C", "Endoplasmic reticulum"), ("D", "Golgi apparatus")],
            "answer": "B",
            "explanation": "Mitochondria generate ATP through oxidative phosphorylation during cellular respiration.",
        },
        "true_false": {
            "body": "Plant cells contain chloroplasts and a rigid cellulose cell wall, which are absent in animal cells.",
            "answer": "true",
            "explanation": "Chloroplasts for photosynthesis and cellulose walls are characteristic features of plant cells.",
        },
        "short_answer": {
            "body": "The cellular organelle widely referred to as the powerhouse of eukaryotic cells is the ________.",
            "answer": "mitochondria",
            "explanation": "Mitochondria generate ATP from glucose and oxygen.",
            "grading_hints": ["mitochondria", "mitochondrion"],
        },
        "long_answer": {
            "body": "Describe the structural and functional differences between plant cells and animal cells.",
            "answer": "Plant cells have a rigid cellulose cell wall, chloroplasts for photosynthesis, and a large central vacuole for turgor pressure. Animal cells lack cell walls and chloroplasts, and possess smaller, multiple vacuoles and centrioles.",
            "explanation": "These structural adaptations reflect photosynthetic vs heterotrophic lifestyles.",
            "grading_hints": ["cell wall", "chloroplasts", "central vacuole", "photosynthesis"],
        },
    },
    {
        "topic": "Genetics & DNA",
        "mcq": {
            "body": "In a double-stranded DNA molecule, which nitrogenous base forms complementary hydrogen bonds with adenine (A)?",
            "options": [("A", "Guanine (G)"), ("B", "Cytosine (C)"), ("C", "Thymine (T)"), ("D", "Uracil (U)")],
            "answer": "C",
            "explanation": "Adenine pairs with thymine via two hydrogen bonds in DNA (A-T).",
        },
        "true_false": {
            "body": "The double-helix molecular structure of DNA was discovered by James Watson and Francis Crick in 1953.",
            "answer": "true",
            "explanation": "Watson and Crick elucidated the antiparallel double-helix structure using Rosalind Franklin's X-ray data.",
        },
        "short_answer": {
            "body": "The monomer building blocks that polymerize to form DNA and RNA nucleic acids are called ________.",
            "answer": "nucleotides",
            "explanation": "Each nucleotide consists of a nitrogenous base, a pentose sugar, and a phosphate group.",
            "grading_hints": ["nucleotides", "nucleotide"],
        },
        "long_answer": {
            "body": "Explain the Central Dogma of molecular biology.",
            "answer": "The Central Dogma describes the directional flow of genetic information: DNA is transcribed into messenger RNA (mRNA) in the nucleus, and mRNA is then translated into functional polypeptides (proteins) by ribosomes in the cytoplasm.",
            "explanation": "Replication, transcription, and translation define genetic expression.",
            "grading_hints": ["DNA to RNA", "RNA to protein", "transcription", "translation", "ribosomes"],
        },
    },
]


_EXTRA_PHYSICS_FLASHCARDS = [
    ("Newton's Laws of Motion", "What is Newton's First Law of Motion?", "An object remains at rest or in uniform motion unless acted upon by an external net force.", "Known as the Law of Inertia."),
    ("Newton's Laws of Motion", "What is Newton's Third Law of Motion?", "For every action, there is an equal and opposite reaction.", "Action and reaction forces act on different interacting bodies."),
    ("Kinetic Energy", "What is the formula for kinetic energy?", "KE = ½mv²", "Kinetic energy is directly proportional to mass and the square of velocity."),
    ("Work and Energy", "What is the SI unit of work and energy?", "Joule (J = N·m = kg·m²/s²)", "One Joule is the work done by a force of one Newton moving through one meter."),
    ("Gravitation", "What is the standard acceleration due to gravity near Earth's surface?", "g ≈ 9.8 m/s²", "Free-fall acceleration in the absence of air resistance."),
    ("Linear Momentum", "What is the formula for linear momentum?", "p = mv", "Momentum is the product of an object's mass and its velocity."),
]


def _generate_fallback_physics_question(
    idx: int,
    target_qtype: str | None,
    subject: str | None = None,
    subcategory: str | None = None,
) -> PreparedQuestion:
    bank = _PHYSICS_FALLBACK_BANK[idx % len(_PHYSICS_FALLBACK_BANK)]
    topic = subcategory or bank["topic"]
    eff_type = target_qtype or ("mcq" if idx % 3 == 0 else ("true_false" if idx % 3 == 1 else "short_answer"))

    if eff_type == "true_false":
        tf = bank["true_false"]
        return PreparedQuestion(
            id=f"qst_phys_tf_{uuid4().hex[:8]}",
            topic=topic,
            question_type="true_false",
            difficulty="beginner",
            body=tf["body"],
            options=[
                PreparedOption(key="true", text="True"),
                PreparedOption(key="false", text="False"),
            ],
            answer=tf["answer"],
            explanation=tf["explanation"],
            grading_hints=[],
        )
    elif eff_type == "short_answer":
        sa = bank["short_answer"]
        return PreparedQuestion(
            id=f"qst_phys_sa_{uuid4().hex[:8]}",
            topic=topic,
            question_type="short_answer",
            difficulty="beginner",
            body=sa["body"],
            options=[],
            answer=sa["answer"],
            explanation=sa["explanation"],
            grading_hints=sa["grading_hints"],
        )
    elif eff_type == "long_answer":
        la = bank["long_answer"]
        return PreparedQuestion(
            id=f"qst_phys_la_{uuid4().hex[:8]}",
            topic=topic,
            question_type="long_answer",
            difficulty="intermediate",
            body=la["body"],
            options=[],
            answer=la["answer"],
            explanation=la["explanation"],
            grading_hints=la["grading_hints"],
        )
    else:
        mc = bank["mcq"]
        return PreparedQuestion(
            id=f"qst_phys_mc_{uuid4().hex[:8]}",
            topic=topic,
            question_type="mcq",
            difficulty="intermediate" if idx % 2 == 1 else "beginner",
            body=mc["body"],
            options=[PreparedOption(key=k, text=t) for k, t in mc["options"]],
            answer=mc["answer"],
            explanation=mc["explanation"],
            grading_hints=[],
        )


def _generate_fallback_chemistry_question(
    idx: int,
    target_qtype: str | None,
    subject: str | None = None,
    subcategory: str | None = None,
) -> PreparedQuestion:
    bank = _CHEMISTRY_FALLBACK_BANK[idx % len(_CHEMISTRY_FALLBACK_BANK)]
    topic = subcategory or bank["topic"]
    eff_type = target_qtype or ("mcq" if idx % 3 == 0 else ("true_false" if idx % 3 == 1 else "short_answer"))

    if eff_type == "true_false":
        tf = bank["true_false"]
        return PreparedQuestion(
            id=f"qst_chem_tf_{uuid4().hex[:8]}",
            topic=topic,
            question_type="true_false",
            difficulty="beginner",
            body=tf["body"],
            options=[
                PreparedOption(key="true", text="True"),
                PreparedOption(key="false", text="False"),
            ],
            answer=tf["answer"],
            explanation=tf["explanation"],
            grading_hints=[],
        )
    elif eff_type == "short_answer":
        sa = bank["short_answer"]
        return PreparedQuestion(
            id=f"qst_chem_sa_{uuid4().hex[:8]}",
            topic=topic,
            question_type="short_answer",
            difficulty="beginner",
            body=sa["body"],
            options=[],
            answer=sa["answer"],
            explanation=sa["explanation"],
            grading_hints=sa["grading_hints"],
        )
    elif eff_type == "long_answer":
        la = bank["long_answer"]
        return PreparedQuestion(
            id=f"qst_chem_la_{uuid4().hex[:8]}",
            topic=topic,
            question_type="long_answer",
            difficulty="intermediate",
            body=la["body"],
            options=[],
            answer=la["answer"],
            explanation=la["explanation"],
            grading_hints=la["grading_hints"],
        )
    else:
        mc = bank["mcq"]
        return PreparedQuestion(
            id=f"qst_chem_mc_{uuid4().hex[:8]}",
            topic=topic,
            question_type="mcq",
            difficulty="intermediate" if idx % 2 == 1 else "beginner",
            body=mc["body"],
            options=[PreparedOption(key=k, text=t) for k, t in mc["options"]],
            answer=mc["answer"],
            explanation=mc["explanation"],
            grading_hints=[],
        )


def _generate_fallback_biology_question(
    idx: int,
    target_qtype: str | None,
    subject: str | None = None,
    subcategory: str | None = None,
) -> PreparedQuestion:
    bank = _BIOLOGY_FALLBACK_BANK[idx % len(_BIOLOGY_FALLBACK_BANK)]
    topic = subcategory or bank["topic"]
    eff_type = target_qtype or ("mcq" if idx % 3 == 0 else ("true_false" if idx % 3 == 1 else "short_answer"))

    if eff_type == "true_false":
        tf = bank["true_false"]
        return PreparedQuestion(
            id=f"qst_bio_tf_{uuid4().hex[:8]}",
            topic=topic,
            question_type="true_false",
            difficulty="beginner",
            body=tf["body"],
            options=[
                PreparedOption(key="true", text="True"),
                PreparedOption(key="false", text="False"),
            ],
            answer=tf["answer"],
            explanation=tf["explanation"],
            grading_hints=[],
        )
    elif eff_type == "short_answer":
        sa = bank["short_answer"]
        return PreparedQuestion(
            id=f"qst_bio_sa_{uuid4().hex[:8]}",
            topic=topic,
            question_type="short_answer",
            difficulty="beginner",
            body=sa["body"],
            options=[],
            answer=sa["answer"],
            explanation=sa["explanation"],
            grading_hints=sa["grading_hints"],
        )
    elif eff_type == "long_answer":
        la = bank["long_answer"]
        return PreparedQuestion(
            id=f"qst_bio_la_{uuid4().hex[:8]}",
            topic=topic,
            question_type="long_answer",
            difficulty="intermediate",
            body=la["body"],
            options=[],
            answer=la["answer"],
            explanation=la["explanation"],
            grading_hints=la["grading_hints"],
        )
    else:
        mc = bank["mcq"]
        return PreparedQuestion(
            id=f"qst_bio_mc_{uuid4().hex[:8]}",
            topic=topic,
            question_type="mcq",
            difficulty="intermediate" if idx % 2 == 1 else "beginner",
            body=mc["body"],
            options=[PreparedOption(key=k, text=t) for k, t in mc["options"]],
            answer=mc["answer"],
            explanation=mc["explanation"],
            grading_hints=[],
        )


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
    question_type: QuestionType | str | None = None,
    target: int | None = None,
) -> AdaptiveSessionPlan:
    session_id = f"ses_{uuid4().hex}"
    canon = canonical_subject(subject)
    subj = canon.strip().lower() if canon else (subject or "").strip().lower()
    if (not subj or subj == "study") and subcategory:
        subcat_canon = canonical_subject(subcategory) or classify_subject_from_text(subcategory)
        if subcat_canon and subcat_canon.lower() != "study":
            subj = subcat_canon.strip().lower()
    if not subj or subj == "study":
        classified = classify_subject_from_text(subcategory or "") if subcategory else None
        # "general" is a safe neutral default; "mathematics" was wrongly injected
        # for ANY unrecognised subject (e.g. English, Hindi, History).
        subj = classified.strip().lower() if classified else "general"

    if target is None:
        ranges = (
            _FLASHCARD_RANGES if mode == AdaptiveSessionMode.flashcard else _QUESTION_RANGES
        )
        target = _adaptive_count(mastery, level, ranges[level])

    if mode == AdaptiveSessionMode.flashcard:
        if subcategory and "trig" in subcategory.casefold():
            flashcards = []
            while len(flashcards) < target:
                for _topic_name, front_text, back_text, expl_text in _TRIG_FLASHCARDS:
                    flashcards.append(
                        PreparedFlashcard(
                            id=f"fls_trig_{uuid4().hex[:8]}",
                            topic=subcategory.strip(),
                            front=front_text,
                            back=back_text,
                            explanation=expl_text,
                        )
                    )
                    if len(flashcards) >= target:
                        break
        elif subj in ("chemistry", "chem"):
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
        elif subj in ("mathematics", "math", "maths", "algebra", "algebra 1", "geometry", "calculus"):
            flashcards = [
                PreparedFlashcard(
                    id=f"fls_math_{uuid4().hex[:8]}",
                    topic="Linear Equations in Algebra",
                    front="In the linear equation 3x + 7 = 22, what is the value of x?",
                    back="x = 5 (subtract 7 from both sides to get 3x = 15, then divide by 3).",
                    explanation="Isolate the variable by performing inverse operations.",
                ),
                PreparedFlashcard(
                    id=f"fls_math_{uuid4().hex[:8]}",
                    topic="Solving Linear Equations",
                    front="What is the solution to 5x - 12 = 18?",
                    back="x = 6 (add 12 to both sides to get 5x = 30, then divide by 5).",
                    explanation="Add 12 to both sides and divide by 5.",
                ),
                PreparedFlashcard(
                    id=f"fls_math_{uuid4().hex[:8]}",
                    topic="Linear Equations with Parentheses",
                    front="Solve for x: 2(x + 4) = 18.",
                    back="x = 5 (divide by 2 to get x + 4 = 9, then subtract 4).",
                    explanation="Apply the distributive property or divide first.",
                ),
                PreparedFlashcard(
                    id=f"fls_math_{uuid4().hex[:8]}",
                    topic="Variables on Both Sides",
                    front="Solve for x: 7x - 4 = 3x + 16.",
                    back="x = 5 (subtract 3x to get 4x - 4 = 16, add 4 to get 4x = 20, divide by 4).",
                    explanation="Collect variable terms on one side and constant terms on the other.",
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
                    topic="Cell Biology",
                    front="Which organelle is widely known as the powerhouse of eukaryotic cells?",
                    back="Mitochondria (mitochondrion).",
                    explanation="Mitochondria generate the majority of cellular adenosine triphosphate (ATP).",
                ),
                PreparedFlashcard(
                    id=f"fls_bio_{uuid4().hex[:8]}",
                    topic="Cell Biology",
                    front="What is the primary function of ribosomes in living cells?",
                    back="Protein synthesis.",
                    explanation="Ribosomes translate genetic instructions from mRNA into functional protein chains.",
                ),
            ]
        elif _is_science_subject(subj) or subj in ("science", "general science", "life science", "physical science", "integrated science"):
            topic_name = subcategory or (f"{subject} Concepts" if subject else "Science Concepts")
            flashcards = [
                PreparedFlashcard(
                    id=f"fls_sci_{uuid4().hex[:8]}",
                    topic=subcategory or topic_name_card,
                    front=front_text,
                    back=back_text,
                    explanation=expl_text,
                )
                for topic_name_card, front_text, back_text, expl_text in _EXTRA_SCIENCE_FLASHCARDS[:max(4, target)]
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
        if len(flashcards) < target:
            existing_fronts = {f.front.casefold() for f in flashcards}
            if subcategory and "trig" in subcategory.casefold():
                for _topic_name, front_text, back_text, expl_text in _TRIG_FLASHCARDS:
                    if front_text.casefold() not in existing_fronts:
                        flashcards.append(
                            PreparedFlashcard(
                                id=f"fls_trig_ext_{uuid4().hex[:8]}",
                                topic=subcategory.strip(),
                                front=front_text,
                                back=back_text,
                                explanation=expl_text,
                            )
                        )
                        existing_fronts.add(front_text.casefold())
                        if len(flashcards) >= target:
                            break
            elif _is_physics_subject(subj) or _is_physics_subject(subject) or _is_physics_subject(subcategory):
                for topic_name, front_text, back_text, expl_text in _EXTRA_PHYSICS_FLASHCARDS:
                    if front_text.casefold() not in existing_fronts:
                        flashcards.append(
                            PreparedFlashcard(
                                id=f"fls_phys_ext_{uuid4().hex[:8]}",
                                topic=subcategory or topic_name,
                                front=front_text,
                                back=back_text,
                                explanation=expl_text,
                            )
                        )
                        existing_fronts.add(front_text.casefold())
                        if len(flashcards) >= target:
                            break
            elif _is_science_subject(subj) or _is_science_subject(subject) or _is_science_subject(subcategory):
                for topic_name, front_text, back_text, expl_text in _EXTRA_SCIENCE_FLASHCARDS:
                    if front_text.casefold() not in existing_fronts:
                        flashcards.append(
                            PreparedFlashcard(
                                id=f"fls_sci_ext_{uuid4().hex[:8]}",
                                topic=subcategory or topic_name,
                                front=front_text,
                                back=back_text,
                                explanation=expl_text,
                            )
                        )
                        existing_fronts.add(front_text.casefold())
                        if len(flashcards) >= target:
                            break
            else:
                for topic_name, front_text, back_text, expl_text in _EXTRA_MATH_FLASHCARDS:
                    if front_text.casefold() not in existing_fronts:
                        flashcards.append(
                            PreparedFlashcard(
                                id=f"fls_math_ext_{uuid4().hex[:8]}",
                                topic=subcategory or topic_name,
                                front=front_text,
                                back=back_text,
                                explanation=expl_text,
                            )
                        )
                        existing_fronts.add(front_text.casefold())
                        if len(flashcards) >= target:
                            break
        flashcards = flashcards[:target]
        if subcategory:
            for f in flashcards:
                f.topic = subcategory.strip()
        questions = []
        item_count = len(flashcards)
    else:
        # mode == study / revision
        target_qtype = (
            question_type.value
            if hasattr(question_type, "value")
            else (str(question_type).strip().lower() if question_type else None)
        )
        if subcategory and "trig" in subcategory.casefold():
            questions = [
                _generate_fallback_trigonometry_question(idx=i, target_qtype=target_qtype, subcategory=subcategory)
                for i in range(max(target, 8))
            ]
        elif subj in ("physics", "phys") or (subject and canonical_subject(subject).casefold() == "physics"):
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
                    topic="Newton's Laws of Motion",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="According to Newton's Second Law of Motion, what net force is required to accelerate a 5 kg mass at 4 m/s²?",
                    options=[
                        PreparedOption(key="A", text="20 N"),
                        PreparedOption(key="B", text="10 N"),
                        PreparedOption(key="C", text="1.25 N"),
                        PreparedOption(key="D", text="9 N"),
                    ],
                    answer="A",
                    explanation="F = ma = 5 kg × 4 m/s² = 20 N.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Newton's Laws of Motion",
                    question_type="true_false",
                    difficulty="beginner",
                    body="Newton's Third Law states that for every action force, there is an equal and opposite reaction force acting on a different object.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Action and reaction forces are always equal in magnitude, opposite in direction, and act on interacting bodies.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Newton's Laws of Motion",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="According to the laws of motion, the product of an object's mass and its velocity (p = mv) is defined as linear ________.",
                    options=[],
                    answer="momentum",
                    explanation="Linear momentum p = mv is a fundamental conserved quantity in classical mechanics.",
                    grading_hints=["momentum", "linear momentum"],
                ),
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Newton's Laws of Motion",
                    question_type="long_answer",
                    difficulty="intermediate",
                    body="Explain Newton's First Law of Motion and describe what happens to passengers in a bus when the driver suddenly applies brakes.",
                    options=[],
                    answer="Newton's First Law (Law of Inertia) states that an object continues in its state of rest or uniform motion unless acted upon by an external unbalanced force. When brakes are applied, the bus decelerates, but passengers continue moving forward due to inertia.",
                    explanation="Inertia resists the sudden change in state of motion until an external force (seatbelt or friction) decelerates the passenger.",
                    grading_hints=["law of inertia", "external force", "tendency to continue moving", "deceleration"],
                ),
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Kinetic Energy",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="If the speed of a moving object is doubled, what happens to its kinetic energy (KE = ½mv²)?",
                    options=[
                        PreparedOption(key="A", text="It doubles"),
                        PreparedOption(key="B", text="It quadruples (4x)"),
                        PreparedOption(key="C", text="It stays the same"),
                        PreparedOption(key="D", text="It increases by eight times"),
                    ],
                    answer="B",
                    explanation="Kinetic energy is proportional to the square of velocity, so doubling speed quadruples kinetic energy.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Optics & Light",
                    question_type="mcq",
                    difficulty="beginner",
                    body="What phenomenon describes the bending of a light wave as it passes from one medium to another with a different refractive index?",
                    options=[
                        PreparedOption(key="A", text="Reflection"),
                        PreparedOption(key="B", text="Refraction"),
                        PreparedOption(key="C", text="Diffraction"),
                        PreparedOption(key="D", text="Polarization"),
                    ],
                    answer="B",
                    explanation="Refraction is the change in direction of wave propagation due to a change in transmission speed across media.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Thermodynamics",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="Which law of thermodynamics states that energy cannot be created or destroyed, only transformed from one form to another?",
                    options=[
                        PreparedOption(key="A", text="Zeroth Law of Thermodynamics"),
                        PreparedOption(key="B", text="First Law of Thermodynamics"),
                        PreparedOption(key="C", text="Second Law of Thermodynamics"),
                        PreparedOption(key="D", text="Third Law of Thermodynamics"),
                    ],
                    answer="B",
                    explanation="The First Law of Thermodynamics is the law of conservation of energy.",
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
                    topic="Gravitation",
                    question_type="true_false",
                    difficulty="beginner",
                    body="In a vacuum where air resistance is absent, all objects fall toward the Earth with the same gravitational acceleration regardless of mass.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Gravitational acceleration g is independent of the falling object's mass in a vacuum.",
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
                PreparedQuestion(
                    id=f"qst_phys_{uuid4().hex[:8]}",
                    topic="Force and Motion",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="The SI unit of force, named in honor of the physicist who formulated the laws of motion, is the ________.",
                    options=[],
                    answer="newton",
                    explanation="Force is measured in Newtons (N = kg·m/s²).",
                    grading_hints=["newton", "newtons"],
                ),
            ]
            if subcategory and ("motion" in subcategory.casefold() or "law" in subcategory.casefold()):
                for q in questions:
                    q.topic = subcategory.strip()

        elif subj in ("chemistry", "chem"):
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
                PreparedQuestion(
                    id=f"qst_chem_{uuid4().hex[:8]}",
                    topic="Periodic Table",
                    question_type="mcq",
                    difficulty="beginner",
                    body="Elements in the same column (group) of the periodic table generally share similar chemical properties because they have:",
                    options=[
                        PreparedOption(key="A", text="Identical numbers of neutrons"),
                        PreparedOption(key="B", text="The same total atomic mass"),
                        PreparedOption(key="C", text="The same number of valence electrons"),
                        PreparedOption(key="D", text="Identical densities"),
                    ],
                    answer="C",
                    explanation="Elements in the same group possess the same number of valence electrons, leading to similar chemical reactivity.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_chem_{uuid4().hex[:8]}",
                    topic="Chemical Bonding",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="What type of chemical bond is primarily characterized by the electrostatic attraction between oppositely charged ions?",
                    options=[
                        PreparedOption(key="A", text="Covalent bond"),
                        PreparedOption(key="B", text="Ionic bond"),
                        PreparedOption(key="C", text="Hydrogen bond"),
                        PreparedOption(key="D", text="Metallic bond"),
                    ],
                    answer="B",
                    explanation="Ionic bonding arises from electrostatic forces between cations and anions following electron transfer.",
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
                    topic="Conservation of Mass",
                    question_type="true_false",
                    difficulty="beginner",
                    body="According to the law of conservation of mass, total mass in a closed system must remain constant during a chemical reaction.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Mass cannot be created or destroyed in an ordinary chemical process; atoms are simply rearranged.",
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
                    topic="States of Matter",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="The direct phase transition from a solid directly to a gas without passing through the liquid phase is called ________.",
                    options=[],
                    answer="sublimation",
                    explanation="Sublimation is the endothermic transition directly from solid to gaseous state.",
                    grading_hints=["sublimation"],
                ),
            ]
        elif subj in ("mathematics", "math", "maths", "algebra", "algebra 1", "geometry", "calculus"):
            questions = [
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Linear Equations in Algebra",
                    question_type="mcq",
                    difficulty="beginner",
                    body="What is the solution for x in 3x + 7 = 22?",
                    options=[
                        PreparedOption(key="A", text="x = 5"),
                        PreparedOption(key="B", text="x = 4"),
                        PreparedOption(key="C", text="x = 6"),
                        PreparedOption(key="D", text="x = 3"),
                    ],
                    answer="A",
                    explanation="Subtract 7 from both sides: 3x = 15. Divide by 3: x = 5.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Two-Step Equations",
                    question_type="mcq",
                    difficulty="beginner",
                    body="Solve for x: 5x - 15 = 10",
                    options=[
                        PreparedOption(key="A", text="x = 5"),
                        PreparedOption(key="B", text="x = 4"),
                        PreparedOption(key="C", text="x = 3"),
                        PreparedOption(key="D", text="x = 2"),
                    ],
                    answer="A",
                    explanation="Add 15 to both sides: 5x = 25. Divide by 5: x = 5.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Distributive Property Equations",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="Solve for x: 2(x + 4) = 18",
                    options=[
                        PreparedOption(key="A", text="x = 5"),
                        PreparedOption(key="B", text="x = 7"),
                        PreparedOption(key="C", text="x = 9"),
                        PreparedOption(key="D", text="x = 6"),
                    ],
                    answer="A",
                    explanation="2x + 8 = 18 -> 2x = 10 -> x = 5.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Variables on Both Sides",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="Solve for x: 7x - 4 = 3x + 16",
                    options=[
                        PreparedOption(key="A", text="x = 5"),
                        PreparedOption(key="B", text="x = 4"),
                        PreparedOption(key="C", text="x = 6"),
                        PreparedOption(key="D", text="x = 3"),
                    ],
                    answer="A",
                    explanation="Subtract 3x: 4x - 4 = 16. Add 4: 4x = 20. Divide by 4: x = 5.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Linear Systems",
                    question_type="mcq",
                    difficulty="beginner",
                    body="If 2x + y = 10 and y = 4, what is the value of x?",
                    options=[
                        PreparedOption(key="A", text="x = 3"),
                        PreparedOption(key="B", text="x = 2"),
                        PreparedOption(key="C", text="x = 4"),
                        PreparedOption(key="D", text="x = 5"),
                    ],
                    answer="A",
                    explanation="Substitute y = 4: 2x + 4 = 10 -> 2x = 6 -> x = 3.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Equations with Fractions",
                    question_type="mcq",
                    difficulty="beginner",
                    body="Solve for x: x / 3 + 4 = 10",
                    options=[
                        PreparedOption(key="A", text="x = 18"),
                        PreparedOption(key="B", text="x = 14"),
                        PreparedOption(key="C", text="x = 12"),
                        PreparedOption(key="D", text="x = 21"),
                    ],
                    answer="A",
                    explanation="Subtract 4: x / 3 = 6. Multiply by 3: x = 18.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Equations with Negative Coefficients",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="Solve for x: -2x + 8 = -6",
                    options=[
                        PreparedOption(key="A", text="x = 7"),
                        PreparedOption(key="B", text="x = -7"),
                        PreparedOption(key="C", text="x = 1"),
                        PreparedOption(key="D", text="x = -1"),
                    ],
                    answer="A",
                    explanation="-2x = -14 -> x = 7.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Linear Equations in One Variable",
                    question_type="mcq",
                    difficulty="beginner",
                    body="What is the value of x in 4x = 28?",
                    options=[
                        PreparedOption(key="A", text="x = 7"),
                        PreparedOption(key="B", text="x = 6"),
                        PreparedOption(key="C", text="x = 8"),
                        PreparedOption(key="D", text="x = 9"),
                    ],
                    answer="A",
                    explanation="Divide both sides by 4: x = 7.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Algebraic Properties",
                    question_type="true_false",
                    difficulty="beginner",
                    body="In the linear equation 2x + 5 = 15, subtracting 5 from both sides maintains equality and gives 2x = 10.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="The subtraction property of equality allows subtracting the same quantity from both sides.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Inverse Operations",
                    question_type="true_false",
                    difficulty="beginner",
                    body="To isolate x in x / 4 = 3, multiplying both sides by 4 yields the solution x = 12.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Multiplication is the inverse operation of division: 4 * (x / 4) = 4 * 3 -> x = 12.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Linear Equations in Algebra",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="Solve for x: 3x + 6 = 21. What is the value of x?",
                    options=[],
                    answer="5",
                    explanation="Subtract 6: 3x = 15. Divide by 3: x = 5.",
                    grading_hints=["5", "x = 5", "x=5"],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Two-Step Equations",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="Solve for x: 4x - 8 = 12. What is the value of x?",
                    options=[],
                    answer="5",
                    explanation="Add 8: 4x = 20. Divide by 4: x = 5.",
                    grading_hints=["5", "x = 5", "x=5"],
                ),
                PreparedQuestion(
                    id=f"qst_math_{uuid4().hex[:8]}",
                    topic="Linear Equations in Algebra",
                    question_type="long_answer",
                    difficulty="intermediate",
                    body="Explain the step-by-step method used to solve the equation 3x + 7 = 22, specifying the inverse operations applied at each step.",
                    options=[],
                    answer="First, apply the subtraction property of equality to subtract 7 from both sides, yielding 3x = 15. Next, use the division property of equality to divide both sides by 3, which yields x = 5. You can verify by substituting 5 back into 3(5) + 7 = 22.",
                    explanation="Solving linear equations systematically applies inverse operations to isolate the unknown variable.",
                    grading_hints=["subtract 7", "divide by 3", "x = 5", "inverse operations", "isolate"],
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
                    topic="Genetics",
                    question_type="mcq",
                    difficulty="beginner",
                    body="In DNA base pairing, which nucleotide base pairs with adenine (A)?",
                    options=[
                        PreparedOption(key="A", text="Guanine (G)"),
                        PreparedOption(key="B", text="Cytosine (C)"),
                        PreparedOption(key="C", text="Thymine (T)"),
                        PreparedOption(key="D", text="Uracil (U)"),
                    ],
                    answer="C",
                    explanation="Adenine forms two hydrogen bonds with thymine in double-stranded DNA.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_bio_{uuid4().hex[:8]}",
                    topic="Cell Biology",
                    question_type="mcq",
                    difficulty="beginner",
                    body="Which structure regulates what enters and exits a cell, maintaining cellular homeostasis?",
                    options=[
                        PreparedOption(key="A", text="Cell membrane"),
                        PreparedOption(key="B", text="Cytoplasm"),
                        PreparedOption(key="C", text="Nucleolus"),
                        PreparedOption(key="D", text="Ribosome"),
                    ],
                    answer="A",
                    explanation="The selectively permeable phospholipid bilayer membrane regulates transport into and out of the cell.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_bio_{uuid4().hex[:8]}",
                    topic="Ecology & Energy Flow",
                    question_type="mcq",
                    difficulty="intermediate",
                    body="In an ecological pyramid, organisms that produce their own organic food using sunlight are classified as:",
                    options=[
                        PreparedOption(key="A", text="Primary consumers"),
                        PreparedOption(key="B", text="Autotrophs (producers)"),
                        PreparedOption(key="C", text="Decomposers"),
                        PreparedOption(key="D", text="Secondary consumers"),
                    ],
                    answer="B",
                    explanation="Autotrophic producers synthesize organic compounds directly from solar energy and inorganic nutrients.",
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
                PreparedQuestion(
                    id=f"qst_bio_{uuid4().hex[:8]}",
                    topic="Cell Biology",
                    question_type="true_false",
                    difficulty="beginner",
                    body="Ribosomes are the cellular structures responsible for synthesizing proteins from amino acids.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Ribosomes translate messenger RNA (mRNA) sequences into polypeptide protein chains.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_bio_{uuid4().hex[:8]}",
                    topic="Cell Division",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="The type of cell division that produces two genetically identical diploid daughter cells is ________.",
                    options=[],
                    answer="mitosis",
                    explanation="Mitosis produces identical somatic cells for growth and repair.",
                    grading_hints=["mitosis"],
                ),
                PreparedQuestion(
                    id=f"qst_bio_{uuid4().hex[:8]}",
                    topic="Biochemistry",
                    question_type="short_answer",
                    difficulty="beginner",
                    body="Biological catalysts that speed up chemical reactions by lowering activation energy are called ________.",
                    options=[],
                    answer="enzymes",
                    explanation="Enzymes are specialized protein catalysts.",
                    grading_hints=["enzymes", "enzyme"],
                ),
            ]
        elif subj in (
            "english & literature", "english", "english literature", "literature",
            "english language", "hindi", "language arts", "language",
            "core english", "elective english",
        ):
            topic_name = subcategory.strip() if subcategory else "English & Literature"
            questions = [
                PreparedQuestion(
                    id=f"qst_eng_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="mcq",
                    difficulty="beginner",
                    body="Which literary device is used when a writer gives human qualities to a non-human object or idea?",
                    options=[
                        PreparedOption(key="A", text="Personification"),
                        PreparedOption(key="B", text="Simile"),
                        PreparedOption(key="C", text="Alliteration"),
                        PreparedOption(key="D", text="Hyperbole"),
                    ],
                    answer="A",
                    explanation="Personification attributes human traits to inanimate objects or abstract ideas (e.g., 'the wind whispered').",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_eng_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="mcq",
                    difficulty="beginner",
                    body="What is the term for the central message or insight about life that a literary work conveys?",
                    options=[
                        PreparedOption(key="A", text="Theme"),
                        PreparedOption(key="B", text="Plot"),
                        PreparedOption(key="C", text="Setting"),
                        PreparedOption(key="D", text="Dialogue"),
                    ],
                    answer="A",
                    explanation="The theme is the underlying message the author communicates through the story's events and characters.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_eng_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="mcq",
                    difficulty="beginner",
                    body="In a story, the character who opposes the protagonist and creates conflict is called the:",
                    options=[
                        PreparedOption(key="A", text="Antagonist"),
                        PreparedOption(key="B", text="Narrator"),
                        PreparedOption(key="C", text="Foil"),
                        PreparedOption(key="D", text="Protagonist"),
                    ],
                    answer="A",
                    explanation="The antagonist is the character (or force) in direct opposition to the protagonist.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_eng_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="true_false",
                    difficulty="beginner",
                    body="A simile makes a direct comparison between two unlike things using 'like' or 'as'.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Similes use 'like' or 'as' (e.g., 'brave as a lion'), unlike metaphors which state the comparison directly.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_eng_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="true_false",
                    difficulty="beginner",
                    body="First-person narration uses pronouns such as 'I', 'me', and 'we', and tells the story from the narrator's own perspective.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="First-person narrators are characters within the story, offering a subjective, personal point of view.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_eng_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="short_answer",
                    difficulty="beginner",
                    body="The introductory paragraph of an essay that presents the main argument is called the ________.",
                    options=[],
                    answer="introduction",
                    explanation="The introduction sets the context, presents background information, and states the thesis of the essay.",
                    grading_hints=["introduction", "intro", "introductory paragraph"],
                ),
                PreparedQuestion(
                    id=f"qst_eng_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="short_answer",
                    difficulty="intermediate",
                    body="The repetition of the same initial consonant sound in a sequence of words (e.g., 'Peter Piper picked') is called ________.",
                    options=[],
                    answer="alliteration",
                    explanation="Alliteration is a sound device where the same consonant sound is repeated at the start of closely connected words.",
                    grading_hints=["alliteration"],
                ),
            ]
        elif _is_science_subject(subj) or subj in ("science", "general science", "life science", "physical science", "integrated science"):
            questions = [
                _generate_fallback_science_question(
                    idx=i,
                    target_qtype=target_qtype,
                    subject=subject or "Science",
                    subcategory=subcategory,
                )
                for i in range(max(target, 8))
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
                    question_type="mcq",
                    difficulty="beginner",
                    body=f"When analyzing a complex topic in {subject or 'this curriculum'}, which strategy yields the deepest understanding?",
                    options=[
                        PreparedOption(key="A", text="Breaking down components and relating them to foundational rules"),
                        PreparedOption(key="B", text="Memorizing keywords in alphabetical order"),
                        PreparedOption(key="C", text="Skipping challenging sections entirely"),
                        PreparedOption(key="D", text="Reviewing summaries without working through examples"),
                    ],
                    answer="A",
                    explanation=f"Deconstructing complex material into foundational rules enables transferable comprehension in {subject or 'the field'}.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_gen_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="mcq",
                    difficulty="intermediate",
                    body=f"Why is validating answers against source principles critical in {subject or 'academic study'}?",
                    options=[
                        PreparedOption(key="A", text="It ensures factual correctness and eliminates unsupported assumptions"),
                        PreparedOption(key="B", text="It artificially extends the length of a study session"),
                        PreparedOption(key="C", text="It eliminates the need for any conceptual analysis"),
                        PreparedOption(key="D", text="It replaces practical application with passive reading"),
                    ],
                    answer="A",
                    explanation="Rigorous verification confirms that conclusions follow logically from established evidence and definitions.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_gen_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="mcq",
                    difficulty="intermediate",
                    body=f"How do core principles and secondary applications relate to one another in {subject or 'this domain'}?",
                    options=[
                        PreparedOption(key="A", text="Principles establish the foundational rules from which applications derive"),
                        PreparedOption(key="B", text="Applications exist entirely independently of underlying principles"),
                        PreparedOption(key="C", text="Principles only apply to introductory questions and fail in real scenarios"),
                        PreparedOption(key="D", text="Applications contradict and replace foundational theories"),
                    ],
                    answer="A",
                    explanation="Domain concepts form a hierarchy where advanced applications build upon foundational principles.",
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
                PreparedQuestion(
                    id=f"qst_gen_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="true_false",
                    difficulty="beginner",
                    body="Regular active recall and testing strengthens long-term memory retention more effectively than passive re-reading.",
                    options=[
                        PreparedOption(key="true", text="True"),
                        PreparedOption(key="false", text="False"),
                    ],
                    answer="true",
                    explanation="Cognitive science shows retrieval practice produces significantly superior neural consolidation compared to passive review.",
                    grading_hints=[],
                ),
                PreparedQuestion(
                    id=f"qst_gen_{uuid4().hex[:8]}",
                    topic=topic_name,
                    question_type="short_answer",
                    difficulty="beginner",
                    body="The practice of testing yourself on key concepts to strengthen memory retention is known as active ________.",
                    options=[],
                    answer="recall",
                    explanation="Active recall is the process of actively retrieving information from memory.",
                    grading_hints=["recall", "retrieval"],
                ),
            ]

        # Strict question type filtering: if caller requested mcq, never return true_false or short_answer
        if target_qtype:
            filtered_q = [
                q for q in questions
                if (q.question_type.value if hasattr(q.question_type, "value") else str(q.question_type)).lower() == target_qtype
            ]
            if filtered_q:
                questions = filtered_q
            else:
                # If the chosen subject didn't have enough questions of this type,
                # fall back to subject-appropriate questions of this target type so the contract is never violated
                _is_english_subj = subj in (
                    "english & literature", "english", "english literature", "literature",
                    "english language", "hindi", "language arts", "language",
                    "core english", "elective english",
                ) or (subject and canonical_subject(subject).casefold() in (
                    "english & literature", "english",
                ))
                if _is_physics_subject(subj) or _is_physics_subject(subject) or _is_physics_subject(subcategory):
                    questions = [
                        _generate_fallback_physics_question(
                            idx=i,
                            target_qtype=target_qtype,
                            subject=subject or "Physics",
                            subcategory=subcategory,
                        )
                        for i in range(max(target, 6))
                    ]
                elif _is_chemistry_subject(subj) or _is_chemistry_subject(subject) or _is_chemistry_subject(subcategory):
                    questions = [
                        _generate_fallback_chemistry_question(
                            idx=i,
                            target_qtype=target_qtype,
                            subject=subject or "Chemistry",
                            subcategory=subcategory,
                        )
                        for i in range(max(target, 6))
                    ]
                elif _is_biology_subject(subj) or _is_biology_subject(subject) or _is_biology_subject(subcategory):
                    questions = [
                        _generate_fallback_biology_question(
                            idx=i,
                            target_qtype=target_qtype,
                            subject=subject or "Biology",
                            subcategory=subcategory,
                        )
                        for i in range(max(target, 6))
                    ]
                elif _is_english_subj:
                    # English / Language Arts subject: never emit maths algebra questions
                    eng_topic = subcategory.strip() if subcategory else (subject or "English & Literature")
                    eng_type_fb = [
                        PreparedQuestion(
                            id=f"qst_eng_{uuid4().hex[:8]}",
                            topic=eng_topic,
                            question_type="mcq",
                            difficulty="beginner",
                            body="Which literary device is used when a writer gives human qualities to a non-human object?",
                            options=[
                                PreparedOption(key="A", text="Personification"),
                                PreparedOption(key="B", text="Alliteration"),
                                PreparedOption(key="C", text="Hyperbole"),
                                PreparedOption(key="D", text="Metaphor"),
                            ],
                            answer="A",
                            explanation="Personification attributes human traits to inanimate objects (e.g., 'the wind whispered').",
                            grading_hints=[],
                        ),
                        PreparedQuestion(
                            id=f"qst_eng_{uuid4().hex[:8]}",
                            topic=eng_topic,
                            question_type="true_false",
                            difficulty="beginner",
                            body="A simile uses 'like' or 'as' to compare two unlike things.",
                            options=[
                                PreparedOption(key="true", text="True"),
                                PreparedOption(key="false", text="False"),
                            ],
                            answer="true",
                            explanation="Similes use 'like' or 'as' (e.g., 'brave as a lion').",
                            grading_hints=[],
                        ),
                        PreparedQuestion(
                            id=f"qst_eng_{uuid4().hex[:8]}",
                            topic=eng_topic,
                            question_type="short_answer",
                            difficulty="beginner",
                            body="The repetition of the same initial consonant sound in closely connected words is called ________.",
                            options=[],
                            answer="alliteration",
                            explanation="Alliteration is a sound device used in poetry and prose.",
                            grading_hints=["alliteration"],
                        ),
                        PreparedQuestion(
                            id=f"qst_eng_{uuid4().hex[:8]}",
                            topic=eng_topic,
                            question_type="long_answer",
                            difficulty="intermediate",
                            body="Explain the role of characterization in developing the theme of a literary work, with an example.",
                            options=[],
                            answer="Characterization reveals a character's personality through actions, dialogue, and description, which in turn reinforces the theme the author intends to convey.",
                            explanation="Theme and characterization work together to convey the author's message.",
                            grading_hints=["characterization", "theme", "author", "example"],
                        ),
                    ]
                    filtered_eng = [
                        q for q in eng_type_fb
                        if (q.question_type.value if hasattr(q.question_type, "value") else str(q.question_type)).lower() == target_qtype
                    ]
                    questions = filtered_eng if filtered_eng else eng_type_fb
                elif _is_science_subject(subj) or _is_science_subject(subject) or _is_science_subject(subcategory):
                    questions = [
                        _generate_fallback_science_question(
                            idx=i,
                            target_qtype=target_qtype,
                            subject=subject or "Science",
                            subcategory=subcategory,
                        )
                        for i in range(max(target, 6))
                    ]
                else:
                    math_fb = [
                        PreparedQuestion(
                            id=f"qst_math_{uuid4().hex[:8]}",
                            topic="Linear Equations in Algebra",
                            question_type="mcq",
                            difficulty="beginner",
                            body="What is the solution for x in 3x + 7 = 22?",
                            options=[
                                PreparedOption(key="A", text="x = 5"),
                                PreparedOption(key="B", text="x = 4"),
                                PreparedOption(key="C", text="x = 6"),
                                PreparedOption(key="D", text="x = 3"),
                            ],
                            answer="A",
                            explanation="Subtract 7 from both sides: 3x = 15. Divide by 3: x = 5.",
                            grading_hints=[],
                        ),
                        PreparedQuestion(
                            id=f"qst_math_{uuid4().hex[:8]}",
                            topic="Two-Step Equations",
                            question_type="mcq",
                            difficulty="beginner",
                            body="Solve for x: 5x - 15 = 10",
                            options=[
                                PreparedOption(key="A", text="x = 5"),
                                PreparedOption(key="B", text="x = 4"),
                                PreparedOption(key="C", text="x = 3"),
                                PreparedOption(key="D", text="x = 2"),
                            ],
                            answer="A",
                            explanation="Add 15 to both sides: 5x = 25. Divide by 5: x = 5.",
                            grading_hints=[],
                        ),
                        PreparedQuestion(
                            id=f"qst_math_{uuid4().hex[:8]}",
                            topic="Algebraic Properties",
                            question_type="true_false",
                            difficulty="beginner",
                            body="In the linear equation 2x + 5 = 15, subtracting 5 from both sides maintains equality and gives 2x = 10.",
                            options=[
                                PreparedOption(key="true", text="True"),
                                PreparedOption(key="false", text="False"),
                            ],
                            answer="true",
                            explanation="The subtraction property of equality allows subtracting the same quantity from both sides.",
                            grading_hints=[],
                        ),
                        PreparedQuestion(
                            id=f"qst_math_{uuid4().hex[:8]}",
                            topic="Inverse Operations",
                            question_type="true_false",
                            difficulty="beginner",
                            body="To isolate x in x / 4 = 3, multiplying both sides by 4 yields the solution x = 12.",
                            options=[
                                PreparedOption(key="true", text="True"),
                                PreparedOption(key="false", text="False"),
                            ],
                            answer="true",
                            explanation="Multiplication is the inverse operation of division.",
                            grading_hints=[],
                        ),
                        PreparedQuestion(
                            id=f"qst_math_{uuid4().hex[:8]}",
                            topic="Linear Equations in Algebra",
                            question_type="short_answer",
                            difficulty="beginner",
                            body="Solve for x: 3x + 6 = 21. What is the value of x?",
                            options=[],
                            answer="5",
                            explanation="Subtract 6: 3x = 15. Divide by 3: x = 5.",
                            grading_hints=["5", "x = 5", "x=5"],
                        ),
                        PreparedQuestion(
                            id=f"qst_math_{uuid4().hex[:8]}",
                            topic="Linear Equations in Algebra",
                            question_type="long_answer",
                            difficulty="intermediate",
                            body="Explain the systematic method to solve the equation 3x + 7 = 22 and how to verify your solution.",
                            options=[],
                            answer="First subtract 7 from both sides to get 3x = 15. Next divide both sides by 3 to get x = 5. Verify by substituting 5 into 3(5) + 7 = 22.",
                            explanation="Inverse operations isolate the variable in linear equations.",
                            grading_hints=["subtract 7", "divide by 3", "x = 5", "verify"],
                        ),
                    ]
                    filtered_math = [
                        q for q in math_fb
                        if (q.question_type.value if hasattr(q.question_type, "value") else str(q.question_type)).lower() == target_qtype
                    ]
                    if filtered_math:
                        questions = filtered_math
                    else:
                        # Dynamic generic fallback ensuring strict target_qtype compliance
                        questions = [
                            PreparedQuestion(
                                id=f"qst_gen_{uuid4().hex[:8]}",
                                topic=subject or "Core Concepts",
                                question_type=target_qtype,
                                difficulty="intermediate",
                                body=f"Explain the primary principles and structured methodology applied when studying {subject or 'this topic'}.",
                                options=[],
                                answer=f"Understanding {subject or 'this topic'} requires analyzing core definitions, identifying key patterns, and systematically applying foundational principles.",
                                explanation=f"Mastery in {subject or 'this discipline'} develops from structured analysis.",
                                grading_hints=["principles", "methodology", "analysis"],
                            )
                        ]

        if len(questions) < target:
            needed = target - len(questions)
            for idx in range(needed):
                if subcategory and "trig" in subcategory.casefold():
                    questions.append(
                        _generate_fallback_trigonometry_question(
                            idx=idx + len(questions),
                            target_qtype=target_qtype,
                            subcategory=subcategory,
                        )
                    )
                elif _is_physics_subject(subj) or _is_physics_subject(subject) or _is_physics_subject(subcategory):
                    questions.append(
                        _generate_fallback_physics_question(
                            idx=idx + len(questions),
                            target_qtype=target_qtype,
                            subject=subject or "Physics",
                            subcategory=subcategory,
                        )
                    )
                elif _is_chemistry_subject(subj) or _is_chemistry_subject(subject) or _is_chemistry_subject(subcategory):
                    questions.append(
                        _generate_fallback_chemistry_question(
                            idx=idx + len(questions),
                            target_qtype=target_qtype,
                            subject=subject or "Chemistry",
                            subcategory=subcategory,
                        )
                    )
                elif _is_biology_subject(subj) or _is_biology_subject(subject) or _is_biology_subject(subcategory):
                    questions.append(
                        _generate_fallback_biology_question(
                            idx=idx + len(questions),
                            target_qtype=target_qtype,
                            subject=subject or "Biology",
                            subcategory=subcategory,
                        )
                    )
                elif _is_science_subject(subj) or _is_science_subject(subject) or _is_science_subject(subcategory):
                    questions.append(
                        _generate_fallback_science_question(
                            idx=idx + len(questions),
                            target_qtype=target_qtype,
                            subject=subject or "Science",
                            subcategory=subcategory,
                        )
                    )
                elif subj in (
                    "english & literature", "english", "english literature", "literature",
                    "english language", "hindi", "language arts", "language",
                ) or (subject and canonical_subject(subject).casefold() in ("english & literature", "english")):
                    # English subject top-up: never emit equation questions
                    eng_top = subcategory.strip() if subcategory else (subject or "English & Literature")
                    questions.append(
                        PreparedQuestion(
                            id=f"qst_eng_{uuid4().hex[:8]}",
                            topic=eng_top,
                            question_type=target_qtype or "mcq",
                            difficulty="beginner",
                            body="The central idea or message a literary work communicates to its reader is called the ________.",
                            options=[
                                PreparedOption(key="A", text="Theme"),
                                PreparedOption(key="B", text="Plot"),
                                PreparedOption(key="C", text="Setting"),
                                PreparedOption(key="D", text="Conflict"),
                            ] if (target_qtype or "mcq") == "mcq" else [],
                            answer="A" if (target_qtype or "mcq") == "mcq" else "theme",
                            explanation="The theme is the overarching insight the author communicates through narrative events and characters.",
                            grading_hints=["theme"],
                        )
                    )
                else:
                    questions.append(
                        _generate_fallback_equation_question(
                            idx=idx + len(questions),
                            target_qtype=target_qtype,
                            subject=subject,
                        )
                    )
        # Always shuffle MCQ options so the correct answer key is randomized (never always 'A')
        questions = [_shuffle_prepared_mcq_options(q) for q in questions]
        if subcategory:
            for q in questions:
                q.topic = subcategory.strip()
        questions = questions[:target]
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

    Only recent (within 60 seconds) prepared sessions that do NOT contain hardcoded
    fallback questions are reusable for network retries. Older sessions or fallback
    plans are rejected so a fresh, authentic set of questions is prepared.
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
    rows = await cosmos_retry(lambda: cursor.to_list(length=50))
    if not rows:
        return None
    latest = max(rows, key=lambda row: str(row.get("created_at", "")))
    plan = latest.get("plan") or {}
    questions = plan.get("questions") or []
    # If any question in this session is a static fallback question, do NOT reuse!
    if any(str(q.get("id", "")).startswith(("qst_math_", "qst_chem_", "qst_phys_", "qst_bio_", "qst_gen_")) for q in questions):
        return None
    # If the prepared session is older than 60 seconds, do not reuse — prepare fresh session
    created_at = str(latest.get("created_at", ""))
    try:
        created_dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
        if (datetime.now(UTC) - created_dt).total_seconds() > 60:
            return None
    except Exception:
        return None
    return latest


async def _supersede_open_sessions(tenant_id: str, workspace_id: str, student_id: str) -> None:
    """Mark any stale open prepared or processing sessions as superseded so their items count as seen."""
    try:
        col = get_collection(tenant_id, ADAPTIVE_SESSIONS)
        for st in ("prepared", "processing"):
            await cosmos_retry(lambda s=st: col.update_many(
                {
                    "student_id": student_id,
                    "status": s,
                },
                {"$set": {"status": "superseded", "updated_at": utc_now()}},
            ))
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
    return await cosmos_retry(lambda: get_collection(tenant_id, ADAPTIVE_SESSIONS).count_documents(
        {
            "workspace_id": workspace_id,
            "student_id": student_id,
            "mode": mode.value,
            "source_snapshot": snapshot,
            "status": {"$in": ["completed", "in_progress", "timed_out"]},
        }
    ))


async def _daily_session_count(
    *,
    tenant_id: str,
    student_id: str,
) -> int:
    """Count sessions started or prepared by this student today (UTC)."""
    today_start = datetime.now(UTC).strftime("%Y-%m-%dT00:00:00")
    try:
        return await cosmos_retry(lambda: get_collection(tenant_id, ADAPTIVE_SESSIONS).count_documents(
            {
                "student_id": student_id,
                "created_at": {"$gte": today_start},
                "status": {"$in": ["prepared", "in_progress", "completed", "timed_out"]},
            }
        ))
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
    sessions_used: int = 0,
) -> AdaptiveSessionPlan:
    """A zero-item plan telling the learner to upload more study material.

    Returned once every non-repeating session the current material can produce
    has been consumed (the cap, or thin material exhausted early). The client
    renders a call-to-action instead of a runnable session and never posts
    ``complete`` for it, so it is intentionally not persisted.

    ``sessions_used`` is forwarded to the client so the UI can distinguish a
    genuine exhaustion (many sessions completed) from an early failure
    (sessions_used == 0) and show an appropriate message.
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
        sessions_used=sessions_used,
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
    is_recreated = False
    if plan.questions:
        if any(
            q.id.startswith(("qst_var_", "qst_trig_var_", "qst_llm_var_", "qst_trig_gen_"))
            for q in plan.questions
        ):
            is_recreated = True
    elif plan.flashcards:
        if any(
            f.id.startswith(("fls_var_", "fls_trig_var_", "fls_llm_var_", "fls_trig_gen_", "fls_trig_"))
            for f in plan.flashcards
        ):
            is_recreated = True
    subcat_val = (plan.subcategory or "").strip().casefold() or None
    try:
        await cosmos_retry(lambda: get_collection(tenant_id, ADAPTIVE_SESSIONS).insert_one(
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
                "subcategory": subcat_val,
                "is_recreated": is_recreated,
                "created_at": now,
                "updated_at": now,
            }
        ))
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
        # Admin-added workspaces strictly follow the curriculum flow:
        # subject and subcategory filtering only apply in self-study.
        # Format selection (question_type) is supported across all workspaces.
        request.subject = None
        request.subcategory = None
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
    target = _adaptive_count(mastery, level, ranges[level])

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
            any_doc = None
            try:
                doc_col = get_collection(current_user.tenant_id, DOCUMENTS)
                cur = doc_col.find({"workspace_id": workspace_id, "deleted_at": None}).sort("uploaded_at", -1)
                all_ws_docs = await cosmos_retry(lambda: cur.to_list(length=20))
                if request.subject and request.subject.strip().casefold() != "study":
                    for d in all_ws_docs:
                        d_cat = d.get("category") or classify_subject_from_text(d.get("filename", ""))
                        if subjects_match(d_cat, request.subject):
                            any_doc = d
                            break
                if not any_doc and all_ws_docs:
                    any_doc = all_ws_docs[0]
            except Exception as exc:
                logger.debug("Failed to query documents fallback for workspace=%s: %s", workspace_id, exc)
            if any_doc:
                # If document was recently uploaded and is still extracting/chunking/vectorizing, wait for readiness
                doc_status = any_doc.get("status")
                if doc_status in ("pending", "extracting", "text_extracted", "extracting_topics", "topics_extracted", "chunking", "vectorizing"):
                    logger.info("Document %s is in state '%s'; waiting for chunking/vector index readiness...", any_doc.get("_id"), doc_status)
                    for _ in range(24):  # wait up to 36s for complete processing
                        await asyncio.sleep(1.5)
                        refreshed = await cosmos_retry(lambda d_id=any_doc["_id"]: doc_col.find_one({"_id": d_id}))
                        if refreshed and refreshed.get("status") == "ready":
                            any_doc = refreshed
                            sources = await study_sources.current_study_sources(
                                tenant_id=current_user.tenant_id,
                                workspace_id=workspace_id,
                            )
                            break
                        elif refreshed and refreshed.get("status") == "failed":
                            raise ConflictError(f"Document processing failed: {refreshed.get('processing_error', 'Upload failed.')}")
                    else:
                        raise ConflictError(
                            "Your study material is still finalizing search index and embeddings. Please wait a moment and try again."
                        )
                if not sources.document_ids and any_doc.get("status") == "ready":
                    sources = study_sources.CurrentStudySources(
                        document_ids=frozenset({str(any_doc["_id"])}),
                        topic_names=tuple(
                            str(t.get("name", "")) for t in any_doc.get("topic_tags") or [] if isinstance(t, dict)
                        ),
                    )
                if not request.subject or request.subject.strip().casefold() == "study":
                    request.subject = any_doc.get("category") or classify_subject_from_text(any_doc.get("filename", ""))
                if not request.subcategory and any_doc.get("subcategory"):
                    request.subcategory = any_doc.get("subcategory")
            else:
                raise ConflictError(
                    "No study material has been uploaded yet. Please upload study material to begin."
                )
        has_custom_selection = bool(request.subject or request.subcategory or request.question_type)
        if has_custom_selection:
            # When the student explicitly chooses a subject, topic, or format type,
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
            return _build_exhausted_plan(mode=request.mode, level=level, mastery=mastery, subject=request.subject, subcategory=request.subcategory, sessions_used=used)

        if request.subcategory:
            subcat_recreations = await _topic_recreation_count(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                subcategory=request.subcategory,
            )
            if subcat_recreations >= _MAX_TOPIC_RECREATIONS:
                return _build_exhausted_plan(
                    mode=request.mode,
                    level=level,
                    mastery=mastery,
                    subject=request.subject,
                    subcategory=request.subcategory,
                    sessions_used=subcat_recreations,
                )


    # Enforce daily session limit: maximum 50 sessions per user per day (UTC)
    daily_sessions_count = await _daily_session_count(
        tenant_id=current_user.tenant_id,
        student_id=current_user.id,
    )
    if daily_sessions_count >= _MAX_DAILY_SESSIONS_PER_USER:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Daily session limit reached. You can complete up to 50 sessions per day. Please return tomorrow!",
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
        if isinstance(exc, (ForbiddenError, NotFoundError, ConflictError)):
            raise
        logger.exception("Adaptive session prepare error: %s", exc)
        if capped and used > 0:
            return _build_exhausted_plan(
                mode=request.mode,
                level=level,
                mastery=mastery,
                subject=request.subject,
                subcategory=request.subcategory,
                sessions_used=used,
            )
        # Cold-start workspaces or first-time sessions may fall back to guaranteed plan
        plan = _build_guaranteed_fallback_plan(
            workspace_id=workspace_id,
            user_id=current_user.id,
            tenant_id=current_user.tenant_id,
            mode=request.mode,
            level=level,
            mastery=mastery,
            subject=request.subject,
            subcategory=request.subcategory,
            question_type=request.question_type,
            target=target,
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

    if item_count == 0:
        if request.subcategory:
            subcat_recreations = await _topic_recreation_count(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                subcategory=request.subcategory,
            )
            if subcat_recreations >= _MAX_TOPIC_RECREATIONS:
                return _build_exhausted_plan(
                    mode=request.mode,
                    level=level,
                    mastery=mastery,
                    subject=request.subject,
                    subcategory=request.subcategory,
                    sessions_used=subcat_recreations,
                )

        if capped and used > 0:
            return _build_exhausted_plan(
                mode=request.mode,
                level=level,
                mastery=mastery,
                subject=request.subject,
                subcategory=request.subcategory,
                sessions_used=used,
            )
        has_docs = bool(sources and sources.document_ids)
        if has_docs and request.mode != AdaptiveSessionMode.flashcard:
            doc_id = list(sources.document_ids)[0] if (sources and sources.document_ids) else "doc_runtime_material"
            try:
                eff_subj = request.subject or (request.subcategory and classify_subject_from_text(request.subcategory)) or "Science"
                var_questions = await generate_runtime_material_variations(
                    tenant_id=current_user.tenant_id,
                    workspace_id=workspace_id,
                    document_id=doc_id,
                    subject=eff_subj,
                    subcategory=request.subcategory,
                    seed_questions=[],
                    historical_seen_bodies=[],
                    seen_signatures=set(),
                    count=target,
                )
                if var_questions:
                    questions = [_prepare_question_with_shuffled_options(q) for q in var_questions]
                    item_count = len(questions)
            except Exception as var_err:
                logger.warning("Emergency material variation synthesis failed: %s", var_err)
        elif request.mode == AdaptiveSessionMode.flashcard and request.subcategory and "trig" in request.subcategory.casefold():
            var_cards = [
                PreparedFlashcard(
                    id=f"fls_trig_var_{uuid4().hex[:8]}",
                    topic=request.subcategory.strip(),
                    front=front_text,
                    back=back_text,
                    explanation=expl_text,
                )
                for topic_name, front_text, back_text, expl_text in _TRIG_FLASHCARDS
            ]
            flashcards = var_cards[:target]
            item_count = len(flashcards)
        elif request.mode == AdaptiveSessionMode.flashcard and (_is_science_subject(request.subject) or _is_science_subject(request.subcategory)):
            var_cards = [
                PreparedFlashcard(
                    id=f"fls_sci_var_{uuid4().hex[:8]}",
                    topic=request.subcategory.strip() if request.subcategory else topic_name,
                    front=front_text,
                    back=back_text,
                    explanation=expl_text,
                )
                for topic_name, front_text, back_text, expl_text in _EXTRA_SCIENCE_FLASHCARDS
            ]
            flashcards = var_cards[:target]
            item_count = len(flashcards)

        if item_count == 0:
            subcat_recreations = 0
            if request.subcategory:
                subcat_recreations = await _topic_recreation_count(
                    tenant_id=current_user.tenant_id,
                    workspace_id=workspace_id,
                    student_id=current_user.id,
                    subcategory=request.subcategory,
                )
            if used > 0 or subcat_recreations > 0:
                return _build_exhausted_plan(
                    mode=request.mode,
                    level=level,
                    mastery=mastery,
                    subject=request.subject,
                    subcategory=request.subcategory,
                    sessions_used=max(used, subcat_recreations),
                )
            # Cold-start workspace with 0 items: serve guaranteed plan
            logger.info(
                "Item count 0 for workspace=%s; serving guaranteed plan in one go",
                workspace_id,
            )

            plan = _build_guaranteed_fallback_plan(
                workspace_id=workspace_id,
                user_id=current_user.id,
                tenant_id=current_user.tenant_id,
                mode=request.mode,
                level=level,
                mastery=mastery,
                subject=request.subject,
                subcategory=request.subcategory,
                question_type=request.question_type,
                target=target,
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

    if request.mode == AdaptiveSessionMode.flashcard:
        flashcards = flashcards[:target]
        item_count = len(flashcards)
    else:
        questions = questions[:target]
        item_count = len(questions)

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
    raw = await cosmos_retry(lambda: get_collection(current_user.tenant_id, ADAPTIVE_SESSIONS).find_one(
        {
            "_id": session_id,
            "workspace_id": workspace_id,
            "student_id": current_user.id,
            "status": {"$in": ["prepared", "processing"]},
        }
    ))
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
    raw = await cosmos_retry(lambda: sessions.find_one(
        {
            "_id": session_id,
            "workspace_id": workspace_id,
            "student_id": current_user.id,
        }
    ))
    if raw is None:
        raise NotFoundError("Adaptive session", session_id)
    if raw.get("summary") is not None:
        return AdaptiveSessionSummary.model_validate(raw["summary"])

    claim = await cosmos_retry(lambda: sessions.update_one(
        {"_id": session_id, "status": "prepared"},
        {"$set": {"status": "processing", "updated_at": utc_now()}},
    ))
    if claim.matched_count == 0:
        latest = await cosmos_retry(lambda: sessions.find_one({"_id": session_id}))
        if latest and latest.get("summary") is not None:
            return AdaptiveSessionSummary.model_validate(latest["summary"])
        if latest and latest.get("status") == "processing":
            logger.warning("Re-claiming session stuck in processing session_id=%s", session_id)
        else:
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
            await cosmos_retry(lambda ev=event: get_collection(current_user.tenant_id, FLASHCARD_RATINGS).insert_one(
                ev.model_dump(by_alias=True)
            ))
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
        deduped_attempts: list[tuple[SessionQuestionAttempt, Question]] = []
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
            deduped_attempts.append((attempt, question))

        async def _eval_one(q: Question, att: SessionQuestionAttempt) -> bool:
            if att.is_correct is not None:
                return att.is_correct
            try:
                res = await asyncio.wait_for(answer_evaluation.evaluate(q, att.answer), timeout=5.0)
                return bool(res.is_correct)
            except Exception as exc:
                logger.warning("Answer evaluation failed/timed out during session complete: %s", exc)
                return False

        eval_results = await asyncio.gather(*[_eval_one(q, att) for att, q in deduped_attempts]) if deduped_attempts else []

        for (attempt, question), is_correct in zip(deduped_attempts, eval_results, strict=True):
            timestamp = utc_now()
            delta = await gamification_service.record_question_attempt(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                topic=question.topic,
                difficulty=question.difficulty,
                is_correct=is_correct,
                revision=plan.mode == AdaptiveSessionMode.revision,
                now=timestamp,
            )
            action_xp += 1 if is_correct else -1
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
                is_correct=is_correct,
                xp_earned=delta.xp_earned,
                timestamp=timestamp,
            )
            await knowledge_state_service.record_attempt(
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                student_id=current_user.id,
                topic=question.topic,
                difficulty=question.difficulty,
                is_correct=is_correct,
                now=timestamp,
            )
            correct_count += int(is_correct)
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
    await cosmos_retry(lambda: sessions.update_one(
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
    ))
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
