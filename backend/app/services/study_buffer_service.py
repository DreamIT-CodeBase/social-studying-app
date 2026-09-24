"""Study Buffer Service — Smart Sliding Question & Flashcard Pre-Warming & Auto-Replenishment.

Provides:
1. Fast-path serving: Users load ready sessions in < 100ms from pre-warmed Cosmos DB buffers.
2. Ingestion pre-fill: Upon document vectorization (`ready`), pre-fills 12–16 questions
   (MCQ, True/False) and 12–16 flashcards per topic in QUESTION_QUEUE and FLASHCARDS.
3. Background auto-replenishment (Conveyor Belt): When remaining unseen items for a topic
   drop to <= 5, silently generates fresh Phase 1 (chunk-grounded) or Phase 2 (LLM variations) items.
4. Zero repetition: Multi-layer deduplication against student history and existing buffer items.
5. Graceful exhaustion: When legitimate concept variations reach the pedagogical limit,
   triggers `_build_exhausted_plan` directing the student to upload more study material.
"""

from __future__ import annotations

import asyncio
import logging
import re
from typing import Any, Sequence
from uuid import uuid4

from app.core.database import (
    CHUNKS,
    DOCUMENTS,
    FLASHCARDS,
    QUESTION_QUEUE,
    cosmos_retry,
    get_collection,
)
from app.models.base import utc_now
from app.models.flashcard import Flashcard, FlashcardStatus
from app.models.question import (
    DifficultyLevel,
    McqOption,
    Question,
    QuestionStatus,
    QuestionType,
)
from app.services import azure_openai
from app.services.question_deduplication import (
    canonical_question_signature,
    is_candidate_duplicate,
    normalize_question_stem,
)
from app.services.subject_classifier import (
    canonical_subject,
    classify_subject_from_text,
    is_conflicting_subject,
    is_math_question_body,
    subjects_match,
)

logger = logging.getLogger(__name__)

# Buffer thresholds
LOW_WATERMARK_THRESHOLD = 5
TARGET_BUFFER_PER_TOPIC = 12
MAX_VARIATION_ROUNDS_PER_TOPIC = 3


def _clean_str(val: Any) -> str:
    return str(val or "").strip()


# ── Ingestion Pre-Fill ───────────────────────────────────────────────────────


async def prefill_document_study_buffers(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
) -> None:
    """Pre-fill question and flashcard buffers in the background when document is ready."""
    try:
        col_docs = get_collection(tenant_id, DOCUMENTS)
        doc = await cosmos_retry(lambda: col_docs.find_one({"_id": document_id, "workspace_id": workspace_id}))
        if not doc:
            logger.warning("Document %s not found for prefill buffer", document_id)
            return

        cat = _clean_str(doc.get("category"))
        subcat = _clean_str(doc.get("subcategory"))
        fn = _clean_str(doc.get("filename"))
        subject = cat or classify_subject_from_text(f"{fn} {subcat}") or "General"
        canonical_subj = canonical_subject(subject)

        # Collect topics
        raw_tags = doc.get("topic_tags") or []
        topics: list[str] = []
        if subcat:
            topics.append(subcat)
        for t in raw_tags:
            t_name = _clean_str(t.get("name") if isinstance(t, dict) else t)
            if t_name and t_name not in topics:
                topics.append(t_name)
        if not topics:
            topics = [f"{canonical_subj} Fundamentals"]

        # Fetch document chunks
        col_chunks = get_collection(tenant_id, CHUNKS)
        cursor = col_chunks.find({"document_id": document_id, "deleted_at": None})
        chunks = await cosmos_retry(lambda: cursor.to_list(length=120))
        if not chunks:
            logger.info("No chunks found for doc=%s; prefill skipped", document_id)
            return

        chunks.sort(key=lambda x: int(x.get("chunk_index", 0)))
        chunk_texts = [_clean_str(c.get("text", "")) for c in chunks if _clean_str(c.get("text", ""))]
        full_text = "\n\n".join(chunk_texts)
        if not full_text:
            return

        # 1. Run direct question extraction if document contains worksheets/problems
        from app.services.document_question_extractor import extract_and_queue_document_questions
        try:
            await extract_and_queue_document_questions(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
            )
        except Exception as ext_err:
            logger.warning("Worksheet direct extraction skipped for doc=%s: %s", document_id, ext_err)

        # 2. Check existing buffered items for this doc
        col_q = get_collection(tenant_id, QUESTION_QUEUE)
        existing_q_count = await cosmos_retry(
            lambda: col_q.count_documents({"document_id": document_id, "deleted_at": None})
        )

        col_fc = get_collection(tenant_id, FLASHCARDS)
        existing_fc_count = await cosmos_retry(
            lambda: col_fc.count_documents({"document_id": document_id, "deleted_at": None})
        )

        # 3. Pre-fill questions if needed
        if existing_q_count < TARGET_BUFFER_PER_TOPIC:
            await _generate_initial_question_buffer(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                canonical_subject_name=canonical_subj,
                topics=topics[:4],
                chunk_texts=chunk_texts,
                chunks=chunks,
            )

        # 4. Pre-fill flashcards if needed
        if existing_fc_count < TARGET_BUFFER_PER_TOPIC:
            await _generate_initial_flashcard_buffer(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                canonical_subject_name=canonical_subj,
                topics=topics[:4],
                chunk_texts=chunk_texts,
                chunks=chunks,
            )

        logger.info(
            "Study buffer pre-fill complete for doc=%s subject=%s topics=%s",
            document_id,
            canonical_subj,
            topics[:4],
        )

    except Exception as exc:
        logger.exception("Pre-filling study buffers failed for doc=%s: %s", document_id, exc)


async def _generate_initial_question_buffer(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    canonical_subject_name: str,
    topics: list[str],
    chunk_texts: list[str],
    chunks: list[dict[str, Any]],
) -> None:
    """Generate 10-14 grounded questions (MCQ + True/False) across topics in a single batched LLM call."""
    chunk_sample = "\n\n".join(chunk_texts[:6])[:7000]
    chunk_ids = [str(c.get("_id")) for c in chunks[:6]]

    system_prompt = (
        f"You are a master {canonical_subject_name} educator. "
        "Your task is to generate 10 to 12 rigorous, 100% grounded study questions strictly based on the text excerpts below. "
        "Questions must span the provided topics. "
        "Strict rules:\n"
        "1. Every question must be fully grounded in the provided text. Do not invent outside concepts.\n"
        "2. Provide 8 Multiple Choice Questions (MCQ) with 4 distinct plausible options, and 2-4 True/False questions.\n"
        "3. Provide clear step-by-step explanations.\n"
        "4. Output strictly valid JSON matching the schema."
    )

    user_prompt = (
        f"Subject: {canonical_subject_name}\n"
        f"Topics: {', '.join(topics)}\n\n"
        f"Study Material Excerpts:\n{chunk_sample}\n\n"
        "Generate 10-12 questions in JSON format:\n"
        "{\n"
        '  "questions": [\n'
        '    {\n'
        '      "topic": "Specific Topic Name from Topics list",\n'
        '      "question_type": "mcq",\n'
        '      "difficulty": "intermediate",\n'
        '      "body": "Clear question text...",\n'
        '      "options": [{"key": "A", "text": "Opt 1"}, {"key": "B", "text": "Opt 2"}, {"key": "C", "text": "Opt 3"}, {"key": "D", "text": "Opt 4"}],\n'
        '      "answer": "A",\n'
        '      "explanation": "Why A is correct..."\n'
        '    }\n'
        "  ]\n"
        "}"
    )

    try:
        resp = await asyncio.wait_for(
            azure_openai.chat_json(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                max_output_tokens=3500,
                temperature=0.2,
            ),
            timeout=35.0,
        )
        raw_list = resp.get("questions") or []
        parsed_questions: list[dict[str, Any]] = []

        seen_sigs: set[str] = set()
        for item in raw_list:
            body = _clean_str(item.get("body"))
            if not body or len(body) < 10:
                continue

            # Subject isolation check
            if is_conflicting_subject(None, canonical_subject_name, body=body):
                continue
            if is_math_question_body(body) and canonical_subject_name.casefold() != "mathematics":
                continue

            sig = canonical_question_signature(body)
            if sig in seen_sigs:
                continue
            seen_sigs.add(sig)

            q_type_str = _clean_str(item.get("question_type")).lower()
            q_type = QuestionType.true_false if "true" in q_type_str else QuestionType.mcq
            topic_val = _clean_str(item.get("topic")) or topics[0]

            ans = _clean_str(item.get("answer")) or "A"
            if q_type == QuestionType.true_false:
                is_t = ans.lower() in ("true", "t", "yes", "1")
                options = [
                    McqOption(key="true", text="True", is_correct=is_t),
                    McqOption(key="false", text="False", is_correct=not is_t),
                ]
                ans = "true" if is_t else "false"
            else:
                raw_opts = item.get("options") or []
                options = [
                    McqOption(
                        key=_clean_str(o.get("key")).upper(),
                        text=_clean_str(o.get("text")),
                        is_correct=(_clean_str(o.get("key")).upper() == ans.upper()),
                    )
                    for o in raw_opts
                    if isinstance(o, dict) and _clean_str(o.get("text"))
                ]
                if len(options) < 2:
                    continue

            q_obj = Question(
                id=f"qst_buf_{uuid4().hex[:12]}",
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                topic=topic_val,
                question_type=q_type,
                difficulty=DifficultyLevel.intermediate,
                body=body,
                options=options,
                answer=ans,
                explanation=_clean_str(item.get("explanation")),
                grading_hints=[],
                status=QuestionStatus.approved,
                source_chunk_ids=chunk_ids[:3],
                prompt_version="study_buffer_v1",
            )
            parsed_questions.append(q_obj.model_dump(by_alias=True))

        if parsed_questions:
            col_q = get_collection(tenant_id, QUESTION_QUEUE)
            await cosmos_retry(lambda: col_q.insert_many(parsed_questions, ordered=False))
            logger.info("Inserted %d buffered questions for doc=%s", len(parsed_questions), document_id)

    except Exception as exc:
        logger.warning("Failed initial question buffer generation for doc=%s: %s", document_id, exc)


async def _generate_initial_flashcard_buffer(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    canonical_subject_name: str,
    topics: list[str],
    chunk_texts: list[str],
    chunks: list[dict[str, Any]],
) -> None:
    """Generate 10-15 grounded flashcards across topics in a single batched LLM call."""
    chunk_sample = "\n\n".join(chunk_texts[:6])[:7000]
    chunk_ids = [str(c.get("_id")) for c in chunks[:6]]

    system_prompt = (
        f"You are a master {canonical_subject_name} educator. "
        "Generate 10 to 14 high-impact flashcards directly grounded in the text excerpts below. "
        "Strict rules:\n"
        "1. Every flashcard must test a core concept, definition, rule, or formula explicitly in the text.\n"
        "2. Front: Clean, clear cue, term, or question prompt.\n"
        "3. Back: Clear, accurate answer or explanation.\n"
        "4. Explanation: 1-2 sentence context or memory aid.\n"
        "5. Output strictly valid JSON matching the schema."
    )

    user_prompt = (
        f"Subject: {canonical_subject_name}\n"
        f"Topics: {', '.join(topics)}\n\n"
        f"Study Material Excerpts:\n{chunk_sample}\n\n"
        "Generate 10-14 flashcards in JSON format:\n"
        "{\n"
        '  "flashcards": [\n'
        '    {\n'
        '      "topic": "Specific Topic Name from Topics list",\n'
        '      "front": "Term or concept prompt...",\n'
        '      "back": "Concise definition or explanation...",\n'
        '      "explanation": "Contextual note..."\n'
        '    }\n'
        "  ]\n"
        "}"
    )

    try:
        resp = await asyncio.wait_for(
            azure_openai.chat_json(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                max_output_tokens=3000,
                temperature=0.2,
            ),
            timeout=35.0,
        )
        raw_list = resp.get("flashcards") or []
        parsed_cards: list[dict[str, Any]] = []

        seen_fronts: set[str] = set()
        for item in raw_list:
            front = _clean_str(item.get("front"))
            back = _clean_str(item.get("back"))
            if not front or not back or len(front) < 3:
                continue

            # Subject isolation check
            if is_conflicting_subject(None, canonical_subject_name, body=f"{front} {back}"):
                continue
            if is_math_question_body(f"{front} {back}") and canonical_subject_name.casefold() != "mathematics":
                continue

            norm_front = front.strip().casefold()
            if norm_front in seen_fronts:
                continue
            seen_fronts.add(norm_front)

            card_topic = _clean_str(item.get("topic")) or topics[0]

            card = Flashcard(
                id=f"fls_buf_{uuid4().hex[:12]}",
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                topic=card_topic,
                front=front,
                back=back,
                explanation=_clean_str(item.get("explanation")),
                status=FlashcardStatus.approved,
                source_chunk_ids=chunk_ids[:3],
                prompt_version="study_buffer_v1",
            )
            parsed_cards.append(card.model_dump(by_alias=True))

        if parsed_cards:
            col_fc = get_collection(tenant_id, FLASHCARDS)
            await cosmos_retry(lambda: col_fc.insert_many(parsed_cards, ordered=False))
            logger.info("Inserted %d buffered flashcards for doc=%s", len(parsed_cards), document_id)

    except Exception as exc:
        logger.warning("Failed initial flashcard buffer generation for doc=%s: %s", document_id, exc)


# ── Buffer Count & Watermark Check ───────────────────────────────────────────


async def get_remaining_study_buffer_count(
    *,
    tenant_id: str,
    workspace_id: str,
    document_ids: Sequence[str],
    subject: str | None,
    topic: str | None,
    is_flashcard: bool,
    seen_ids: set[str],
) -> int:
    """Return count of unused approved questions or flashcards remaining in the buffer."""
    if not document_ids:
        return 0

    col_name = FLASHCARDS if is_flashcard else QUESTION_QUEUE
    col = get_collection(tenant_id, col_name)

    query: dict[str, Any] = {
        "workspace_id": workspace_id,
        "document_id": {"$in": list(document_ids)},
        "status": "approved",
        "deleted_at": None,
    }
    if topic:
        query["topic"] = re.compile(rf"^{re.escape(topic)}$", re.IGNORECASE)

    if seen_ids:
        # Avoid huge $nin query payloads in Cosmos DB
        if len(seen_ids) < 300:
            query["_id"] = {"$nin": list(seen_ids)}

    try:
        count = await cosmos_retry(lambda: col.count_documents(query))
        if len(seen_ids) >= 300:
            # Sift seen IDs locally if seen_ids is large
            cursor = col.find(query, {"_id": 1})
            rows = await cosmos_retry(lambda: cursor.to_list(length=500))
            return sum(1 for r in rows if str(r.get("_id")) not in seen_ids)
        return count
    except Exception as exc:
        logger.warning("Error querying buffer count for ws=%s topic=%s: %s", workspace_id, topic, exc)
        return 0


# ── Background Auto-Replenishment (Conveyor Belt) ───────────────────────────


async def topup_topic_study_buffer(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    subject: str | None,
    topic: str | None,
    is_flashcard: bool,
    seen_ids: set[str],
    seen_bodies_or_fronts: list[str],
    round_limit: int = MAX_VARIATION_ROUNDS_PER_TOPIC,
) -> int:
    """Background task: top up the buffer with fresh Phase 1 chunks or Phase 2 LLM variations."""
    try:
        col_docs = get_collection(tenant_id, DOCUMENTS)
        doc = await cosmos_retry(lambda: col_docs.find_one({"_id": document_id, "workspace_id": workspace_id}))
        if not doc:
            return 0

        eff_subj = subject or _clean_str(doc.get("category")) or "General"
        canonical_subj = canonical_subject(eff_subj)
        eff_topic = topic or _clean_str(doc.get("subcategory")) or f"{canonical_subj} Concepts"

        # Check variation counter for this topic
        topic_var_key = f"var_round_{eff_topic.strip().casefold()}"
        current_round = int(doc.get(topic_var_key, 0))

        if current_round >= round_limit:
            logger.info("Topic '%s' in doc=%s reached max variation limit (%d rounds)", eff_topic, document_id, round_limit)
            return 0

        # Increment round counter
        await cosmos_retry(
            lambda: col_docs.update_one(
                {"_id": document_id},
                {"$inc": {topic_var_key: 1}, "$set": {"updated_at": utc_now()}},
            )
        )

        if is_flashcard:
            return await _replenish_flashcard_variations(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                canonical_subject_name=canonical_subj,
                topic=eff_topic,
                seen_fronts=seen_bodies_or_fronts,
            )
        else:
            return await _replenish_question_variations(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                canonical_subject_name=canonical_subj,
                topic=eff_topic,
                seen_bodies=seen_bodies_or_fronts,
            )

    except Exception as exc:
        logger.exception("Top-up topic study buffer failed for ws=%s topic=%s: %s", workspace_id, topic, exc)
        return 0


async def _replenish_question_variations(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    canonical_subject_name: str,
    topic: str,
    seen_bodies: list[str],
) -> int:
    """Generate 6-8 fresh question variations using LLM concept manipulation."""
    sample_seeds = seen_bodies[-5:] if seen_bodies else []
    seed_block = "\n".join([f"- {s}" for s in sample_seeds]) if sample_seeds else "General concepts."

    system_prompt = (
        f"You are a master {canonical_subject_name} educator. "
        "Generate 6 to 8 fresh, high-quality question variations for the given topic. "
        "Strict rules:\n"
        "1. DO NOT repeat or paraphrase these existing questions:\n"
        f"{seed_block}\n"
        "2. Mutate numbers, change problem framing (e.g. solve for acceleration instead of force), or test inverse principles.\n"
        "3. Provide 5 Multiple Choice Questions (MCQ) and 2-3 True/False questions.\n"
        "4. Include clear step-by-step explanations.\n"
        "5. Output valid JSON matching schema."
    )

    user_prompt = (
        f"Subject: {canonical_subject_name}\n"
        f"Topic: {topic}\n\n"
        "Generate 6-8 fresh non-repeating variations in JSON:\n"
        "{\n"
        '  "questions": [\n'
        '    {\n'
        '      "question_type": "mcq",\n'
        '      "body": "Mutated question text...",\n'
        '      "options": [{"key": "A", "text": "Opt 1"}, {"key": "B", "text": "Opt 2"}, {"key": "C", "text": "Opt 3"}, {"key": "D", "text": "Opt 4"}],\n'
        '      "answer": "A",\n'
        '      "explanation": "Step by step reasoning..."\n'
        '    }\n'
        "  ]\n"
        "}"
    )

    try:
        resp = await asyncio.wait_for(
            azure_openai.chat_json(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                max_output_tokens=3000,
                temperature=0.3,
            ),
            timeout=30.0,
        )
        raw_list = resp.get("questions") or []
        to_insert: list[dict[str, Any]] = []
        seen_sigs = {canonical_question_signature(b) for b in seen_bodies}

        for item in raw_list:
            body = _clean_str(item.get("body"))
            if not body or len(body) < 10:
                continue

            sig = canonical_question_signature(body)
            if sig in seen_sigs:
                continue
            if is_candidate_duplicate(body, None, [(b, None) for b in seen_bodies]):
                continue

            if is_conflicting_subject(None, canonical_subject_name, body=body):
                continue
            if is_math_question_body(body) and canonical_subject_name.casefold() != "mathematics":
                continue

            seen_sigs.add(sig)
            q_type_str = _clean_str(item.get("question_type")).lower()
            q_type = QuestionType.true_false if "true" in q_type_str else QuestionType.mcq
            ans = _clean_str(item.get("answer")) or "A"

            if q_type == QuestionType.true_false:
                is_t = ans.lower() in ("true", "t", "yes", "1")
                options = [
                    McqOption(key="true", text="True", is_correct=is_t),
                    McqOption(key="false", text="False", is_correct=not is_t),
                ]
                ans = "true" if is_t else "false"
            else:
                raw_opts = item.get("options") or []
                options = [
                    McqOption(
                        key=_clean_str(o.get("key")).upper(),
                        text=_clean_str(o.get("text")),
                        is_correct=(_clean_str(o.get("key")).upper() == ans.upper()),
                    )
                    for o in raw_opts
                    if isinstance(o, dict) and _clean_str(o.get("text"))
                ]
                if len(options) < 2:
                    continue

            q_obj = Question(
                id=f"qst_topup_{uuid4().hex[:12]}",
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                topic=topic,
                question_type=q_type,
                difficulty=DifficultyLevel.intermediate,
                body=body,
                options=options,
                answer=ans,
                explanation=_clean_str(item.get("explanation")),
                grading_hints=[],
                status=QuestionStatus.approved,
                source_chunk_ids=[],
                prompt_version="topup_variation_v1",
            )
            to_insert.append(q_obj.model_dump(by_alias=True))

        if to_insert:
            col_q = get_collection(tenant_id, QUESTION_QUEUE)
            await cosmos_retry(lambda: col_q.insert_many(to_insert, ordered=False))
            logger.info("Top-up: inserted %d fresh question variations for topic=%s", len(to_insert), topic)
            return len(to_insert)

    except Exception as exc:
        logger.warning("Failed question top-up for topic=%s: %s", topic, exc)
    return 0


async def _replenish_flashcard_variations(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    canonical_subject_name: str,
    topic: str,
    seen_fronts: list[str],
) -> int:
    """Generate 6-8 fresh flashcard variations using LLM concept manipulation."""
    sample_fronts = seen_fronts[-5:] if seen_fronts else []
    seed_block = "\n".join([f"- {f}" for f in sample_fronts]) if sample_fronts else "General concepts."

    system_prompt = (
        f"You are a master {canonical_subject_name} educator. "
        "Generate 6 to 8 fresh flashcards for the given topic. "
        "Strict rules:\n"
        "1. DO NOT repeat these existing card cues:\n"
        f"{seed_block}\n"
        "2. Test inverse aspects (e.g. given definition identify term, or practical scenario application).\n"
        "3. Front: clear cue. Back: concise explanation.\n"
        "4. Output strictly valid JSON."
    )

    user_prompt = (
        f"Subject: {canonical_subject_name}\n"
        f"Topic: {topic}\n\n"
        "Generate 6-8 fresh non-repeating flashcards in JSON:\n"
        "{\n"
        '  "flashcards": [\n'
        '    {\n'
        '      "front": "Fresh cue...",\n'
        '      "back": "Clear answer...",\n'
        '      "explanation": "Contextual reasoning..."\n'
        '    }\n'
        "  ]\n"
        "}"
    )

    try:
        resp = await asyncio.wait_for(
            azure_openai.chat_json(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                max_output_tokens=2500,
                temperature=0.3,
            ),
            timeout=30.0,
        )
        raw_list = resp.get("flashcards") or []
        to_insert: list[dict[str, Any]] = []
        seen_clean = {f.strip().casefold() for f in seen_fronts}

        for item in raw_list:
            front = _clean_str(item.get("front"))
            back = _clean_str(item.get("back"))
            if not front or not back or len(front) < 3:
                continue

            if front.strip().casefold() in seen_clean:
                continue
            seen_clean.add(front.strip().casefold())

            if is_conflicting_subject(None, canonical_subject_name, body=f"{front} {back}"):
                continue
            if is_math_question_body(f"{front} {back}") and canonical_subject_name.casefold() != "mathematics":
                continue

            card = Flashcard(
                id=f"fls_topup_{uuid4().hex[:12]}",
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                topic=topic,
                front=front,
                back=back,
                explanation=_clean_str(item.get("explanation")),
                status=FlashcardStatus.approved,
                source_chunk_ids=[],
                prompt_version="topup_variation_v1",
            )
            to_insert.append(card.model_dump(by_alias=True))

        if to_insert:
            col_fc = get_collection(tenant_id, FLASHCARDS)
            await cosmos_retry(lambda: col_fc.insert_many(to_insert, ordered=False))
            logger.info("Top-up: inserted %d fresh flashcard variations for topic=%s", len(to_insert), topic)
            return len(to_insert)

    except Exception as exc:
        logger.warning("Failed flashcard top-up for topic=%s: %s", topic, exc)
    return 0
