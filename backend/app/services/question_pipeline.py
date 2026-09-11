from __future__ import annotations

import asyncio
import json
import logging
import re
from collections.abc import Sequence
from typing import Any
from uuid import uuid4

from fastapi import BackgroundTasks

from app.core.database import (
    CHUNKS,
    DOCUMENTS,
    INTERACTIONS,
    QUESTION_QUEUE,
    cosmos_retry,
    get_collection,
)
from app.core.exceptions import ServiceUnavailableError
from app.core.redis_client import get_redis
from app.mcp_tools import invoke
from app.mcp_tools.retrieve_content import (
    RetrieveContentInput,
    RetrieveContentOutput,
    RetrievedChunk,
)
from app.mcp_tools.retrieve_student_context import (
    RetrieveStudentContextInput,
    RetrieveStudentContextOutput,
)
from app.models.question import Question, QuestionStatus, QuestionType
from app.models.user import User
from app.services import (
    question_generation,
    question_safety,
    question_validation,
    rag_evaluation,
    study_sources,
)
from app.services.difficulty import calibrate_difficulty
from app.services.learning_path import (
    TopicScore,
    select_next_topic,
)
from app.services.subject_classifier import classify_subject_from_text

logger = logging.getLogger(__name__)

CACHE_KEY_PREFIX = "telemetry:question_cache"
SEEN_KEY_PREFIX = "telemetry:seen_questions"


async def invalidate_workspace_cache(*, workspace_id: str) -> int:
    """Remove every student's generated-question buffers for a workspace."""
    redis = await get_redis()
    keys: list[str] = []
    for prefix in (CACHE_KEY_PREFIX, SEEN_KEY_PREFIX):
        async for key in redis.scan_iter(match=f"{prefix}:{workspace_id}:*"):
            keys.append(str(key))
    if keys:
        await redis.delete(*keys)
    logger.info("Invalidated %d question cache keys for workspace=%s", len(keys), workspace_id)
    return len(keys)


async def get_next_question(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    user_obj: User,
    revision: bool = False,
    subject: str | None = None,
    background_tasks: BackgroundTasks,
) -> Question:
    """Retrieve the next question from the queue cache.
    Pops from Redis buffer. Triggers background generation if buffer drops <= 5.
    Falls back to synchronous batch generation if buffer is empty.
    """
    redis = await get_redis()
    cache_suffix = f":{subject.strip().casefold()}" if subject else ""
    cache_key = f"{CACHE_KEY_PREFIX}:{workspace_id}:{student_id}{cache_suffix}"

    # 1. Read buffer from Redis
    cached = await redis.get(cache_key)
    questions = json.loads(cached) if cached else []

    current_sources = await study_sources.current_study_sources(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
    )
    current_document_ids = current_sources.document_ids
    # Cached rows predate the current source snapshot and may outlive a
    # document deletion. Never serve a row unless its real source is active.
    questions = [
        question
        for question in questions
        if str(question.get("document_id", "")) in current_document_ids
        and (
            not subject
            or classify_subject_from_text(str(question.get("topic", ""))).casefold()
            == subject.casefold()
        )
    ]

    if questions:
        # Pop first item
        first_q = questions.pop(0)
        await redis.set(cache_key, json.dumps(questions), ex=3600)

        # Trigger background prefetch if only <= 5 remain
        if len(questions) <= 5:
            background_tasks.add_task(
                prefetch_batch_background,
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                student_id=student_id,
                user_obj=user_obj,
                revision=revision,
                subject=subject,
            )
            logger.info("Triggered background question prefetch for student=%s subject=%s", student_id, subject)

        return Question.model_validate(first_q)

    # 2. Buffer is empty: run synchronous batch generation
    logger.info("Buffer empty for student=%s subject=%s, running synchronous batch generation", student_id, subject)
    generated_list = await _generate_and_persist_batch(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        user_obj=user_obj,
        revision=revision,
        subject=subject,
        batch_size=20,
    )

    if not generated_list:
        raise ServiceUnavailableError(
            "Could not generate a study question at this time. Please retry."
        )

    first_q = generated_list.pop(0)

    # Save the remaining generated questions to cache
    if generated_list:
        q_dicts = [q.model_dump(by_alias=True) for q in generated_list]
        await redis.set(cache_key, json.dumps(q_dicts), ex=3600)

    return first_q


async def prefetch_batch_background(
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    user_obj: User,
    revision: bool = False,
    subject: str | None = None,
) -> None:
    """FastAPI background task to pre-populate cache queue."""
    redis = await get_redis()
    cache_suffix = f":{subject.strip().casefold()}" if subject else ""
    cache_key = f"{CACHE_KEY_PREFIX}:{workspace_id}:{student_id}{cache_suffix}"

    # Verify current size before running to avoid duplicate triggers
    cached = await redis.get(cache_key)
    questions = json.loads(cached) if cached else []
    if len(questions) > 5:
        return

    logger.info("Starting background prefetch for student=%s subject=%s", student_id, subject)
    new_questions = await _generate_and_persist_batch(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        user_obj=user_obj,
        revision=revision,
        subject=subject,
        batch_size=20,
    )

    if new_questions:
        questions.extend([q.model_dump(by_alias=True) for q in new_questions])
        await redis.set(cache_key, json.dumps(questions), ex=3600)
        logger.info(
            "Successfully prefetched %d questions for student=%s", len(new_questions), student_id
        )


async def _generate_and_persist_batch(
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    user_obj: User,
    revision: bool = False,
    subject: str | None = None,
    target_topic: str | None = None,
    target_type: QuestionType | None = None,
    batch_size: int = 20,
    extra_seen_bodies: Sequence[str] | None = None,
) -> list[Question]:
    """Generate questions in parallel across top candidate topics.
    Filter out duplicate questions using temporary Redis set and historical stems.

    When *target_topic* is supplied the LPE topic-selection step is skipped
    entirely and all generation slots are allocated to that single topic.
    This produces fresh, focused questions for the student's explicitly
    chosen subcategory (e.g. "Atomic Structure") without mixing in
    unrelated topics.
    """
    redis = await get_redis()
    seen_key = f"{SEEN_KEY_PREFIX}:{workspace_id}:{student_id}"

    # Fetch student context and seen/queued question bodies
    context = await _fetch_student_context(tenant_id, workspace_id, student_id)
    all_seen_bodies = await _fetch_all_seen_and_queued_bodies(tenant_id, workspace_id, student_id)

    # Get seen bodies from Redis temporary set to prevent repetition within current session
    def _body_fingerprint(s: str) -> str:
        eq_info = question_validation.extract_equation(s)
        if eq_info is not None:
            var_name, lhs, rhs = eq_info
            clean_lhs = re.sub(r"\s+", "", lhs.casefold())
            clean_rhs = re.sub(r"\s+", "", rhs.casefold())
            return f"eq:{clean_lhs}={clean_rhs}"
        return s.strip().lower().rstrip("?.!")

    local_seen_normalized = {_body_fingerprint(s) for s in redis_seen}
    db_seen_normalized = {_body_fingerprint(s) for s in all_seen_bodies}
    extra_normalized = {_body_fingerprint(s) for s in (extra_seen_bodies or []) if s}
    combined_seen = local_seen_normalized.union(db_seen_normalized).union(extra_normalized)

    current_sources = await study_sources.current_study_sources(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
    )
    if not current_sources.document_ids:
        return []

    # ── Fast path: target_topic provided → single-topic generation ──────
    if target_topic:
        candidates = [
            TopicScore(
                topic_id="tpc_target_0",
                topic_name=target_topic.strip(),
                score=1.0,
                components={},
                complexity_level=2.0,
            )
        ]
    else:
        # Retrieve top topic candidates from Learning Path Engine
        try:
            selection = await select_next_topic(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                student_id=student_id,
            )
            candidates = selection.candidates
        except Exception as exc:
            logger.info("LPE topic selection not available (%s), using source topics fallback", exc)
            fallback_topics = list(current_sources.topic_names) or ["Key Concepts"]
            candidates = [
                TopicScore(
                    topic_id=f"tpc_{i}",
                    topic_name=t,
                    score=1.0,
                    components={},
                    complexity_level=1.0,
                )
                for i, t in enumerate(fallback_topics[:10])
            ]

    matching_doc_ids: frozenset[str] | None = None
    if subject or target_topic:
        # Check documents for matching subject or target topic
        doc_col = get_collection(tenant_id, DOCUMENTS)
        matching_docs: list[dict] = []
        matching_ids_set: set[str] = set()
        cursor_doc = doc_col.find({"_id": {"$in": list(current_sources.document_ids)}})
        docs_raw = await cosmos_retry(lambda: cursor_doc.to_list(length=200))
        for doc_raw in docs_raw:
            filename = doc_raw.get("filename", "")
            doc_subj = (doc_raw.get("category") or "").strip() or classify_subject_from_text(filename)
            tags = doc_raw.get("topic_tags") or []
            if subject:
                if not doc_subj or doc_subj.casefold() == "study":
                    for tag in tags:
                        tag_name = tag.get("name") if isinstance(tag, dict) else str(tag)
                        if classify_subject_from_text(tag_name).casefold() == subject.casefold():
                            doc_subj = subject
                            break
                if doc_subj and doc_subj.casefold() == subject.casefold():
                    matching_ids_set.add(str(doc_raw["_id"]))
                    matching_docs.append(doc_raw)

            if target_topic:
                doc_subcat = str(doc_raw.get("subcategory", "")).casefold()
                if target_topic.casefold() in doc_subcat or doc_subcat in target_topic.casefold():
                    matching_ids_set.add(str(doc_raw["_id"]))
                for tag in tags:
                    tag_name = tag.get("name") if isinstance(tag, dict) else str(tag)
                    if target_topic.casefold() in tag_name.casefold() or tag_name.casefold() in target_topic.casefold():
                        matching_ids_set.add(str(doc_raw["_id"]))

        if matching_ids_set:
            matching_doc_ids = frozenset(matching_ids_set)

        if not target_topic and subject:
            # Deeply extract topics directly from the matching subject documents!
            subject_topic_scores: list[TopicScore] = []
            for mdoc in matching_docs:
                for tag in mdoc.get("topic_tags") or []:
                    t_name = tag.get("name") if isinstance(tag, dict) else str(tag)
                    if t_name and t_name.strip() and t_name.strip() not in [c.topic_name for c in subject_topic_scores]:
                        c_level = float(tag.get("complexity_level", 2.0)) if isinstance(tag, dict) else 2.0
                        subject_topic_scores.append(
                            TopicScore(
                                topic_id=f"doc_tpc_{len(subject_topic_scores)}",
                                topic_name=t_name.strip(),
                                score=1.0,
                                components={},
                                complexity_level=c_level,
                            )
                        )

            if subject_topic_scores:
                candidates = subject_topic_scores
            else:
                # Filter candidate topics to those matching the requested subject
                matched_candidates = [
                    c for c in candidates
                    if classify_subject_from_text(c.topic_name).casefold() == subject.casefold()
                ]
                if matched_candidates:
                    candidates = matched_candidates
                else:
                    source_matches = [
                        t for t in current_sources.topic_names
                        if classify_subject_from_text(t).casefold() == subject.casefold()
                    ]
                    if source_matches:
                        candidates = [
                            TopicScore(
                                topic_id=f"tpc_{i}",
                                topic_name=t,
                                score=1.0,
                                components={},
                                complexity_level=1.0,
                            )
                            for i, t in enumerate(source_matches[:5])
                        ]
                    else:
                        candidates = [
                            TopicScore(
                                topic_id="tpc_subject_0",
                                topic_name=f"{subject} Fundamentals",
                                score=1.0,
                                components={},
                                complexity_level=1.0,
                            )
                        ]

    candidates = candidates[:6]

    if not candidates:
        return []

    # Determine generation batch size per topic (with buffer to ensure target is met after filtering)
    effective_batch = max(batch_size + 3, 7) if len(candidates) == 1 else batch_size
    items_per_topic = (effective_batch // len(candidates)) + 1

    # Run concurrent LLM batch generations
    tasks = []
    for candidate in candidates:
        tasks.append(
            _generate_topic_batch(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                candidate=candidate,
                context=context,
                seen_bodies=list(combined_seen),
                count=items_per_topic,
                current_document_ids=current_sources.document_ids,
                matching_doc_ids=matching_doc_ids,
                target_type=target_type,
            )
        )

    batches = await asyncio.gather(*tasks, return_exceptions=True)

    persisted_questions: list[Question] = []
    col = get_collection(tenant_id, QUESTION_QUEUE)

    for batch in batches:
        if isinstance(batch, Exception):
            logger.warning("Batch generation task encountered error: %s", batch)
            continue

        candidate_items = []
        for gq, candidate_obj, document_id, source_chunk_ids, all_retrieved_chunks in batch:
            # 1. Accuracy validation and auto-correction
            clean_gq = question_validation.validate_and_sanitize_question(
                gq,
                grounding_chunks=all_retrieved_chunks,
            )
            if clean_gq is None:
                continue

            # 2. Duplicate check: Question text stem & canonical equation match
            fp = _body_fingerprint(clean_gq.body)
            norm_body = clean_gq.body.strip().lower().rstrip("?.!")
            if fp in combined_seen or norm_body in combined_seen:
                continue  # duplicate detected, skip

            combined_seen.add(fp)
            combined_seen.add(norm_body)
            candidate_items.append(
                (clean_gq, candidate_obj, document_id, source_chunk_ids, all_retrieved_chunks, norm_body)
            )

        if not candidate_items:
            continue

        # 2. Moderation safety checks in parallel
        async def _check_safety(item):
            cand_gq = item[0]
            try:
                review = await question_safety.review_question(cand_gq)
                return review.verdict == question_safety.ReviewVerdict.approved
            except ServiceUnavailableError as exc:
                logger.warning(
                    "Content Safety service unavailable during batch generation: %s. Allowing question.",
                    exc,
                )
                return True
            except Exception as exc:
                logger.warning("Safety review encountered unexpected error: %s", exc)
                return True

        safety_results = await asyncio.gather(*[_check_safety(item) for item in candidate_items])

        for (gq, candidate_obj, document_id, source_chunk_ids, all_retrieved_chunks, norm_body), is_approved in zip(candidate_items, safety_results, strict=True):
            if not is_approved:
                continue

            await redis.sadd(seen_key, norm_body)  # store in temporary Redis memory

            # 3. Create model and save to db
            question_id = f"qst_{uuid4().hex}"
            question_obj = Question(
                **{"_id": question_id},
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                topic=candidate_obj.topic_name,
                question_type=gq.question_type,
                difficulty=gq.difficulty,
                body=gq.body,
                options=gq.options,
                answer=gq.answer,
                explanation=gq.explanation,
                grading_hints=gq.grading_hints,
                source_chunk_ids=source_chunk_ids,
                prompt_version="question_batch_v1",
                status=QuestionStatus.approved,
            )
            await col.insert_one(question_obj.model_dump(by_alias=True))
            persisted_questions.append(question_obj)

            # 4. End-to-end RAG Evaluation (Scope, Groundedness, Facts, Provenance)
            try:
                asyncio.create_task(
                    rag_evaluation.evaluate_and_persist_rag(
                        tenant_id=tenant_id,
                        workspace_id=workspace_id,
                        student_id=student_id,
                        selected_topic_id=candidate_obj.topic_id,
                        selected_topic_name=candidate_obj.topic_name,
                        active_document_ids=current_sources.document_ids,
                        retrieved_chunks=all_retrieved_chunks,
                        generation_chunk_ids=source_chunk_ids,
                        question_id=question_id,
                        question_type=gq.question_type.value,
                        question_body=gq.body,
                        reference_answer=gq.answer,
                        explanation=gq.explanation,
                        known_source_chunk_ids=source_chunk_ids,
                    )
                )
            except Exception as eval_exc:
                logger.warning(
                    "RAG evaluation dispatch failed for batch question %s: %s", question_id, eval_exc
                )

    return persisted_questions


async def _generate_topic_batch(
    tenant_id: str,
    workspace_id: str,
    candidate: Any,
    context: RetrieveStudentContextOutput,
    seen_bodies: list[str],
    count: int,
    current_document_ids: frozenset[str],
    matching_doc_ids: frozenset[str] | None = None,
    target_type: QuestionType | None = None,
) -> list[tuple[Any, Any, str, list[str], list[Any]]]:
    """Retrieve chunks for topic and trigger batch question generator."""
    mastery = 0.5
    for topic_view in context.topic_mastery:
        if topic_view.topic.casefold() == candidate.topic_name.casefold():
            mastery = topic_view.mastery_score
            break

    calibration = calibrate_difficulty(mastery=mastery)
    difficulty = calibration.difficulty

    effective_doc_ids = matching_doc_ids if matching_doc_ids else current_document_ids
    current_chunks: list[RetrievedChunk] = []
    all_retrieved: list[RetrievedChunk] = []
    try:
        topic_ids = [candidate.topic_id] if not candidate.topic_id.startswith("tpc_") and not candidate.topic_id.startswith("doc_tpc_") else []
        retrieved = await invoke(
            "retrieve_content",
            RetrieveContentInput(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                topic_ids=topic_ids,
                query_text=candidate.topic_name,
                top_k=5,
            ),
        )
        if isinstance(retrieved, RetrieveContentOutput):
            all_retrieved = retrieved.chunks
            current_chunks = [
                chunk for chunk in retrieved.chunks if chunk.document_id in effective_doc_ids
            ]
    except Exception as e:
        logger.warning("Search retrieval failed in topic batch for %s: %s", candidate.topic_name, e)

    if not current_chunks:
        try:
            cursor = get_collection(tenant_id, CHUNKS).find(
                {
                    "workspace_id": workspace_id,
                    "document_id": {"$in": sorted(effective_doc_ids)},
                    "deleted_at": None,
                }
            )
            rows = await cosmos_retry(lambda: cursor.to_list(length=20))
            current_chunks = [
                RetrievedChunk(
                    chunk_id=str(r["_id"]),
                    chunk_index=int(r.get("chunk_index", 0)),
                    document_id=str(r.get("document_id", "")),
                    text=str(r.get("text", "")).strip(),
                    topic_ids=[str(v) for v in r.get("topic_ids") or []],
                    score=0.0,
                )
                for r in rows
                if str(r.get("text", "")).strip()
            ][:5]
            if not all_retrieved:
                all_retrieved = current_chunks
        except Exception as e:
            logger.warning("Cosmos chunk fallback failed in topic batch: %s", e)
            return []

    if not current_chunks and matching_doc_ids:
        current_chunks = [
            chunk for chunk in all_retrieved if chunk.document_id in current_document_ids
        ]

    if not current_chunks:
        return []

    try:
        # A question has one purgeable source. Ground it only in chunks from
        # the highest-ranked current document so deleting that source removes
        # every derivative deterministically.
        document_id = current_chunks[0].document_id
        grounding_chunks = [chunk for chunk in current_chunks if chunk.document_id == document_id]
        gqs = await question_generation.generate_batch_questions(
            topic=candidate.topic_name,
            difficulty=difficulty,
            count=count,
            grounding_chunks=grounding_chunks,
            seen_question_bodies=seen_bodies[:50],
            target_type=target_type,
        )
        source_chunk_ids = [chunk.chunk_id for chunk in grounding_chunks]
        return [(gq, candidate, document_id, source_chunk_ids, all_retrieved) for gq in gqs]
    except Exception as e:
        logger.warning("Topic batch generation failed for %s: %s", candidate.topic_name, e)
        return []


# Helper utilities matching original queries in questions.py


async def _fetch_student_context(
    tenant_id: str, workspace_id: str, student_id: str
) -> RetrieveStudentContextOutput:
    res = await invoke(
        "retrieve_student_context",
        RetrieveStudentContextInput(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student_id,
            limit=100,
        ),
    )
    assert isinstance(res, RetrieveStudentContextOutput)
    return res


async def _fetch_all_seen_and_queued_bodies(
    tenant_id: str, workspace_id: str, student_id: str
) -> list[str]:
    """Return bodies of recently-seen and queued questions for deduplication.

    Limited to the 200 most-recent interactions and 300 queue entries to keep
    RU consumption low. A small number of very old questions may slip through
    the dedup filter on busy workspaces, which is an acceptable trade-off vs
    hitting Cosmos TooManyRequests (429) on every session prepare.
    """
    col_q = get_collection(tenant_id, QUESTION_QUEUE)
    col_i = get_collection(tenant_id, INTERACTIONS)

    # 1. Fetch interaction question IDs for this student
    # Cosmos DB requires an explicit index to use .sort("created_at", -1).
    # To avoid a 400 Bad Request, we fetch without sorting and take the last 200,
    # which roughly corresponds to the most recent insertions.
    cursor_i = col_i.find(
        {"workspace_id": workspace_id, "student_id": student_id},
        {"question_id": 1},
    )
    docs_i = await cosmos_retry(lambda: cursor_i.to_list(length=2000))
    interacted_ids = [doc["question_id"] for doc in docs_i if doc.get("question_id")]
    interacted_ids = interacted_ids[-200:]

    # 2. Fetch up to 300 approved question bodies from this workspace
    cursor_q = col_q.find(
        {"workspace_id": workspace_id, "deleted_at": None},
        {"body": 1},
    ).limit(300)
    docs_q = await cosmos_retry(lambda: cursor_q.to_list(length=300))
    bodies: list[str] = [doc["body"] for doc in docs_q if doc.get("body")]

    # 3. Include bodies of answered questions still in the queue
    if interacted_ids:
        cursor_q2 = col_q.find(
            {"_id": {"$in": interacted_ids}}, {"body": 1}
        ).limit(200)
        docs_q2 = await cosmos_retry(lambda: cursor_q2.to_list(length=200))
        bodies.extend([doc["body"] for doc in docs_q2 if doc.get("body")])

    return list(set(bodies))
