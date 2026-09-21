"""Automated document question extractor.

Inspects document chunks for structured practice problems, equations,
and answer keys (e.g. Algebra 1 200 Equation Practice Quiz), and directly
converts them into approved Question objects in QUESTION_QUEUE without
relying on external LLM availability or rate limits.
"""

from __future__ import annotations

import asyncio
import logging
import random
import re
from typing import Any
from uuid import uuid4

from app.core.database import CHUNKS, QUESTION_QUEUE, cosmos_retry, get_collection
from app.models.question import DifficultyLevel, McqOption, Question, QuestionStatus, QuestionType

logger = logging.getLogger(__name__)


def _generate_distractors(ans_val: int) -> list[int]:
    """Generate 3 plausible integer distractors for a numeric answer."""
    candidates: set[int] = set()
    if ans_val != 0:
        candidates.add(-ans_val)
    for offset in [1, -1, 2, -2, 3, -3, 5, -5]:
        cand = ans_val + offset
        if cand != ans_val:
            candidates.add(cand)
        if len(candidates) >= 6:
            break
    candidates.discard(ans_val)
    chosen = list(candidates)[:3]
    while len(chosen) < 3:
        cand = ans_val + len(chosen) + 10
        if cand != ans_val and cand not in chosen:
            chosen.append(cand)
    return chosen


async def extract_and_queue_document_questions(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
) -> list[Question]:
    """Extract equations/questions directly from document chunks and save to QUESTION_QUEUE.

    Returns the list of parsed Question objects.
    """
    col_chunks = get_collection(tenant_id, CHUNKS)
    cursor = col_chunks.find({"document_id": document_id, "deleted_at": None})
    chunks = await cosmos_retry(lambda: cursor.to_list(length=100))
    if not chunks:
        return []

    chunks.sort(key=lambda x: int(x.get("chunk_index", 0)))
    full_text = "\n".join([c.get("text", "") for c in chunks])
    chunk_ids = [str(c["_id"]) for c in chunks]

    # Check if this document contains an answer key and numbered problems
    has_answer_key = bool(
        re.search(r"(?:complete\s+)?answer\s+key|answer\s+rubric", full_text, re.IGNORECASE)
    )
    if not has_answer_key:
        return []

    # Find answer key boundary
    split_pos = -1
    for match in re.finditer(r"(?:complete\s+)?answer\s+key|answer\s+rubric", full_text, re.IGNORECASE):
        # We want the answer key section, usually near the latter half of the document
        if match.start() > len(full_text) * 0.3:
            split_pos = match.start()
            break

    if split_pos == -1:
        return []

    problems_text = full_text[:split_pos]
    answers_text = full_text[split_pos:]

    # 1. Parse answers
    answers: dict[int, int] = {}
    for m in re.finditer(r"(?:^|\n)\s*(\d{1,4})\.\s*x\s*=\s*(-?\s*\d+)", answers_text, re.IGNORECASE):
        q_num = int(m.group(1))
        ans_val = int(m.group(2).replace(" ", ""))
        answers[q_num] = ans_val

    if not answers:
        return []

    # 2. Parse problems
    problems: dict[int, str] = {}
    for m in re.finditer(r"(?:^|\n)\s*(\d{1,4})\.\s*([^\n\r=]+=[^\n\r]+)", problems_text):
        q_num = int(m.group(1))
        eq = m.group(2).strip()
        eq = re.sub(r"\s+", " ", eq)
        eq = eq.replace("=-", "= -").replace("- -", "+ ")
        if not re.match(r"^x\s*=\s*-?\d+$", eq, re.IGNORECASE):
            problems[q_num] = eq

    if not problems:
        return []

    def get_topic_for_num(num: int) -> tuple[str, DifficultyLevel]:
        if 1 <= num <= 40:
            return "One-Step Equations", DifficultyLevel.beginner
        elif 41 <= num <= 80:
            return "Multiplication and Division Equations", DifficultyLevel.beginner
        elif 81 <= num <= 120:
            return "Two-Step Equations", DifficultyLevel.intermediate
        elif 121 <= num <= 160:
            return "Distributive Property Equations", DifficultyLevel.intermediate
        elif 161 <= num <= 180:
            return "Variables on Both Sides", DifficultyLevel.intermediate
        else:
            return "Mixed Algebra 1 Equations", DifficultyLevel.advanced

    rng = random.Random(42)
    keys = ["A", "B", "C", "D"]
    questions_to_insert: list[dict[str, Any]] = []
    parsed_questions: list[Question] = []

    for q_num in sorted(problems.keys()):
        if q_num not in answers:
            continue

        eq = problems[q_num]
        ans = answers[q_num]
        topic, diff = get_topic_for_num(q_num)

        distractors = _generate_distractors(ans)
        all_vals = [ans, *distractors]
        rng.shuffle(all_vals)

        correct_key = "A"
        options: list[McqOption] = []
        for idx, val in enumerate(all_vals):
            is_corr = (val == ans)
            k = keys[idx]
            if is_corr:
                correct_key = k
            options.append(McqOption(key=k, text=str(val), is_correct=is_corr))

        q_id = f"qst_{uuid4().hex}"
        explanation = f"To solve {eq}: isolating x yields x = {ans}."

        q = Question(
            id=q_id,
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            document_id=document_id,
            topic=topic,
            question_type=QuestionType.mcq,
            difficulty=diff,
            body=f"Solve for x: {eq}",
            options=options,
            answer=correct_key,
            explanation=explanation,
            grading_hints=[str(ans), f"x = {ans}", f"x={ans}"],
            source_chunk_ids=chunk_ids[:3],
            status=QuestionStatus.approved,
            prompt_version="doc_extracted_v1",
        )
        questions_to_insert.append(q.model_dump(by_alias=True))
        parsed_questions.append(q)

    if not questions_to_insert:
        return []

    # Check for existing questions in QUESTION_QUEUE for this doc
    col_q = get_collection(tenant_id, QUESTION_QUEUE)
    cursor_ex = col_q.find({"document_id": document_id}, {"body": 1})
    existing_raw = await cosmos_retry(lambda: cursor_ex.to_list(length=500))
    existing_bodies = {r.get("body", "").strip().lower() for r in existing_raw}

    filtered_inserts = [
        q for q in questions_to_insert
        if q.get("body", "").strip().lower() not in existing_bodies
    ]

    if filtered_inserts:
        async def _persist_in_background(chunks_to_insert: list[dict[str, Any]]) -> None:
            batch_size = 5
            for i in range(0, len(chunks_to_insert), batch_size):
                b_chunk = chunks_to_insert[i:i + batch_size]
                for attempt in range(6):
                    try:
                        await col_q.insert_many(b_chunk, ordered=False)
                        await asyncio.sleep(0.1)
                        break
                    except Exception as exc:
                        retry_ms = 1000
                        m = re.search(r"RetryAfterMs=(\d+)", str(exc))
                        if m:
                            try:
                                retry_ms = int(m.group(1))
                            except ValueError:
                                pass
                        logger.warning(
                            "Retry bulk insert chunk on error (attempt %d/6, wait %dms): %s",
                            attempt + 1,
                            retry_ms,
                            exc,
                        )
                        await asyncio.sleep((retry_ms / 1000.0) + 0.1)

            logger.info(
                "Extracted and queued %d questions from document %s",
                len(chunks_to_insert),
                document_id,
            )

        # Launch background persistence or await first batch
        try:
            # Synchronously insert the first batch of 15 questions so they are definitely in DB
            first_batch = filtered_inserts[:15]
            remaining_batch = filtered_inserts[15:]
            if first_batch:
                await col_q.insert_many(first_batch, ordered=False)
            if remaining_batch:
                asyncio.create_task(_persist_in_background(remaining_batch))
        except Exception as insert_err:
            logger.warning("First batch insert encountered error, running all in background: %s", insert_err)
            asyncio.create_task(_persist_in_background(filtered_inserts))

    # Return full list of available questions for this doc
    try:
        all_cursor = col_q.find({"document_id": document_id, "deleted_at": None})
        all_raw = await cosmos_retry(lambda: all_cursor.to_list(length=500))
        db_questions = [Question.model_validate(r) for r in all_raw]
        if db_questions:
            # Merge with parsed_questions for maximum immediate coverage
            seen_ids = {q.id for q in db_questions}
            for pq in parsed_questions:
                if pq.id not in seen_ids:
                    db_questions.append(pq)
                    seen_ids.add(pq.id)
            return db_questions
    except Exception as query_err:
        logger.warning("Failed to query inserted questions: %s", query_err)

    return parsed_questions
