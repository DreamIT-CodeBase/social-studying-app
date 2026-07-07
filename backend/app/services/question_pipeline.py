from __future__ import annotations

import asyncio
import json
import logging
from uuid import uuid4
from typing import Any
from fastapi import BackgroundTasks

from app.core.database import get_collection, QUESTION_QUEUE, INTERACTIONS
from app.core.redis_client import get_redis
from app.core.exceptions import ServiceUnavailableError, ConflictError, NotFoundError
from app.models.question import Question, QuestionStatus, QuestionForStudent, DifficultyLevel
from app.models.user import User
from app.services import question_generation, question_safety
from app.services.difficulty import calibrate_difficulty
from app.services.learning_path import select_next_topic, NoTopicsAvailable, WorkspaceNotFound
from app.mcp_tools import invoke
from app.mcp_tools.retrieve_content import RetrieveContentInput, RetrieveContentOutput
from app.mcp_tools.retrieve_student_context import RetrieveStudentContextInput, RetrieveStudentContextOutput

logger = logging.getLogger(__name__)

CACHE_KEY_PREFIX = "telemetry:question_cache"
SEEN_KEY_PREFIX = "telemetry:seen_questions"

async def get_next_question(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    user_obj: User,
    revision: bool = False,
    background_tasks: BackgroundTasks,
) -> Question:
    """Retrieve the next question from the queue cache.
    Pops from Redis buffer. Triggers background generation if buffer drops <= 5.
    Falls back to synchronous batch generation if buffer is empty.
    """
    redis = await get_redis()
    cache_key = f"{CACHE_KEY_PREFIX}:{workspace_id}:{student_id}"
    
    # 1. Read buffer from Redis
    cached = await redis.get(cache_key)
    questions = json.loads(cached) if cached else []
    
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
            )
            logger.info("Triggered background question prefetch for student=%s", student_id)
            
        return Question.model_validate(first_q)
        
    # 2. Buffer is empty: run synchronous batch generation
    logger.info("Buffer empty for student=%s, running synchronous batch generation", student_id)
    generated_list = await _generate_and_persist_batch(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        user_obj=user_obj,
        revision=revision,
        batch_size=20,
    )
    
    if not generated_list:
        raise ServiceUnavailableError("Could not generate a study question at this time. Please retry.")
        
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
) -> None:
    """FastAPI background task to pre-populate cache queue."""
    redis = await get_redis()
    cache_key = f"{CACHE_KEY_PREFIX}:{workspace_id}:{student_id}"
    
    # Verify current size before running to avoid duplicate triggers
    cached = await redis.get(cache_key)
    questions = json.loads(cached) if cached else []
    if len(questions) > 5:
        return
        
    logger.info("Starting background prefetch for student=%s", student_id)
    new_questions = await _generate_and_persist_batch(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        user_obj=user_obj,
        revision=revision,
        batch_size=20,
    )
    
    if new_questions:
        questions.extend([q.model_dump(by_alias=True) for q in new_questions])
        await redis.set(cache_key, json.dumps(questions), ex=3600)
        logger.info("Successfully prefetched %d questions for student=%s", len(new_questions), student_id)

async def _generate_and_persist_batch(
    tenant_id: str,
    workspace_id: str,
    student_id: str,
    user_obj: User,
    revision: bool = False,
    batch_size: int = 20,
) -> list[Question]:
    """Generate 20-30 questions in parallel using asyncio.gather across top candidate topics.
    Filter out duplicate questions using a temporary Redis set.
    """
    redis = await get_redis()
    seen_key = f"{SEEN_KEY_PREFIX}:{workspace_id}:{student_id}"
    
    # Fetch student context and seen/queued question bodies
    # For simplicity, fetch the context once
    context = await _fetch_student_context(tenant_id, workspace_id, student_id)
    all_seen_bodies = await _fetch_all_seen_and_queued_bodies(tenant_id, workspace_id, student_id)
    
    # Get seen bodies from Redis temporary set to prevent repetition within current session
    redis_seen = await redis.smembers(seen_key) or []
    local_seen_normalized = {s.strip().lower().rstrip("?.!") for s in redis_seen}
    db_seen_normalized = {s.strip().lower().rstrip("?.!") for s in all_seen_bodies}
    combined_seen = local_seen_normalized.union(db_seen_normalized)
    
    # Retrieve top topic candidates from Learning Path Engine
    try:
        selection = await select_next_topic(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            student_id=student_id,
        )
    except NoTopicsAvailable as exc:
        raise ConflictError(
            "This workspace has no topics yet. Ask an admin to upload "
            "study material before requesting questions."
        ) from exc
    except WorkspaceNotFound as exc:
        raise NotFoundError("Workspace", workspace_id) from exc
    except Exception as e:
        logger.warning("LPE topic selection failed: %s", e)
        return []
        
    candidates = selection.candidates[:5] # use top 5 topics for diverse parallel generation
    if not candidates:
        return []
        
    # Determine generation batch size per topic
    items_per_topic = (batch_size // len(candidates)) + 1
    
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
            )
        )
        
    batches = await asyncio.gather(*tasks, return_exceptions=True)
    
    persisted_questions: list[Question] = []
    col = get_collection(tenant_id, QUESTION_QUEUE)
    
    for batch in batches:
        if isinstance(batch, Exception):
            logger.warning("Batch generation task encountered error: %s", batch)
            continue
            
        for gq, topic_name in batch:
            # 1. Duplicate check: Question text stem similarity & exact normalization match
            norm_body = gq.body.strip().lower().rstrip("?.!")
            if norm_body in combined_seen:
                continue # duplicate detected, skip
                
            combined_seen.add(norm_body)
            await redis.sadd(seen_key, norm_body) # store in temporary Redis memory
            
            # 2. Moderation safety check
            review = await question_safety.review_question(gq)
            if review.verdict != question_safety.ReviewVerdict.approved:
                continue
                
            # 3. Create model and save to db
            question_obj = Question(
                **{"_id": f"qst_{uuid4().hex}"},
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id="batch_source",
                topic=topic_name,
                question_type=gq.question_type,
                difficulty=gq.difficulty,
                body=gq.body,
                options=gq.options,
                answer=gq.answer,
                explanation=gq.explanation,
                grading_hints=gq.grading_hints,
                prompt_version="question_batch_v1",
                status=QuestionStatus.approved,
            )
            await col.insert_one(question_obj.model_dump(by_alias=True))
            persisted_questions.append(question_obj)
            
    return persisted_questions

async def _generate_topic_batch(
    tenant_id: str,
    workspace_id: str,
    candidate: Any,
    context: RetrieveStudentContextOutput,
    seen_bodies: list[str],
    count: int,
) -> list[tuple[Any, str]]:
    """Retrieve chunks for topic and trigger batch question generator."""
    mastery = 0.5
    for topic_view in context.topic_mastery:
        if topic_view.topic.casefold() == candidate.topic_name.casefold():
            mastery = topic_view.mastery_score
            break
            
    calibration = calibrate_difficulty(mastery=mastery)
    difficulty = calibration.difficulty
    
    try:
        retrieved = await invoke(
            "retrieve_content",
            RetrieveContentInput(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                topic_ids=[candidate.topic_id],
                query_text=candidate.topic_name,
                top_k=3,
            ),
        )
        assert isinstance(retrieved, RetrieveContentOutput)
        if not retrieved.chunks:
            return []
            
        gqs = await question_generation.generate_batch_questions(
            topic=candidate.topic_name,
            difficulty=difficulty,
            count=count,
            grounding_chunks=retrieved.chunks,
            seen_question_bodies=seen_bodies[:30],
        )
        return [(gq, candidate.topic_name) for gq in gqs]
    except Exception as e:
        logger.warning("Topic batch generation failed for %s: %s", candidate.topic_name, e)
        return []

# Helper utilities matching original queries in questions.py

async def _fetch_student_context(tenant_id: str, workspace_id: str, student_id: str) -> RetrieveStudentContextOutput:
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

async def _fetch_all_seen_and_queued_bodies(tenant_id: str, workspace_id: str, student_id: str) -> list[str]:
    col_q = get_collection(tenant_id, QUESTION_QUEUE)
    col_i = get_collection(tenant_id, INTERACTIONS)
    
    # 1. Fetch all question IDs from student's interactions in this workspace
    cursor_i = col_i.find({"workspace_id": workspace_id, "student_id": student_id}, {"question_id": 1})
    interacted_ids = [doc["question_id"] async for doc in cursor_i if doc.get("question_id")]
    
    # 2. Fetch all question bodies from the queue for this workspace
    cursor_q = col_q.find({
        "workspace_id": workspace_id,
        "deleted_at": None
    }, {"body": 1})
    bodies = [doc["body"] async for doc in cursor_q if doc.get("body")]
    
    # 3. Fetch bodies of old answered questions that might not be in the current workspace active queue
    if interacted_ids:
        cursor_q2 = col_q.find({
            "_id": {"$in": interacted_ids}
        }, {"body": 1})
        bodies.extend([doc["body"] async for doc in cursor_q2 if doc.get("body")])
        
    return list(set(bodies))
