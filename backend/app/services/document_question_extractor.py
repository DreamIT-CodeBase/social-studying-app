"""Automated document question extractor.

Inspects document chunks for structured practice problems, equations,
and answer keys/rubrics (e.g. Algebra 1 Equation Quiz or Science Practice Questions),
and directly converts them into approved Question objects in QUESTION_QUEUE without
relying on external LLM availability or rate limits.
"""

from __future__ import annotations

import asyncio
import logging
import random
import re
from typing import Any
from uuid import uuid4

from app.core.database import CHUNKS, DOCUMENTS, QUESTION_QUEUE, cosmos_retry, get_collection
from app.models.question import DifficultyLevel, McqOption, Question, QuestionStatus, QuestionType
from app.services.subject_classifier import classify_subject_from_text, subjects_match

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

    # Check if this document contains an answer key / rubric and numbered problems
    has_answer_key = bool(
        re.search(r"(?:complete\s+)?answer\s+key|answer\s+rubric|scoring\s+rubric|solutions\s+key", full_text, re.IGNORECASE)
    )
    if not has_answer_key:
        return []

    # Find answer key boundary
    split_pos = -1
    for match in re.finditer(r"(?:complete\s+)?answer\s+key|answer\s+rubric|scoring\s+rubric|solutions\s+key", full_text, re.IGNORECASE):
        # We want the answer key section, usually near the latter half of the document
        if match.start() > len(full_text) * 0.2:
            split_pos = match.start()
            break

    if split_pos == -1:
        return []

    problems_text = full_text[:split_pos]
    answers_text = full_text[split_pos:]

    # Fetch document metadata for subject and topic tagging
    col_docs = get_collection(tenant_id, DOCUMENTS)
    doc_meta = await cosmos_retry(lambda: col_docs.find_one({"_id": document_id})) or {}
    category = doc_meta.get("category") or ""
    subcategory = doc_meta.get("subcategory") or ""
    filename = doc_meta.get("filename") or ""

    sample_meta = f"{filename} {category} {subcategory} {full_text[:1000]}".lower()
    doc_subj = category or classify_subject_from_text(f"{filename} {subcategory} {full_text[:500]}")
    is_science_doc = subjects_match(doc_subj, "Science") or any(
        k in sample_meta
        for k in (
            "science", "biology", "chemistry", "physics", "earth", "space",
            "photosynthesis", "cell", "organelle", "mitochondria", "dna",
            "ecosystem", "ecology", "geology", "organism", "hypothesis"
        )
    )

    # 1. Parse Answers
    # 1a. Math Equation Answers (x = ...)
    math_eq_answers: dict[int, int] = {}
    for m in re.finditer(r"(?:^|\n)\s*(\d{1,4})\.\s*x\s*=\s*(-?\s*\d+)", answers_text, re.IGNORECASE):
        math_eq_answers[int(m.group(1))] = int(m.group(2).replace(" ", ""))

    # 1b. Multiple Choice Option Letters (e.g. 1. A, 2) B, Q3: C, 4. Option D)
    mcq_answers: dict[int, str] = {}
    for m in re.finditer(r"(?:^|\n)\s*(?:Q(?:uestion)?\s*)?(\d{1,4})[\.\):\-]\s*(?:(?:option|choice|answer)\s+)?([A-D])\b", answers_text, re.IGNORECASE):
        mcq_answers[int(m.group(1))] = m.group(2).upper()

    # 1c. True/False Answers (e.g. 1. True, 2. False, 3. T, 4. F)
    tf_answers: dict[int, str] = {}
    for m in re.finditer(r"(?:^|\n)\s*(?:Q(?:uestion)?\s*)?(\d{1,4})[\.\):\-]\s*(?:(?:answer|choice)\s+)?(true|false|t|f)\b", answers_text, re.IGNORECASE):
        q_num = int(m.group(1))
        tf_val = m.group(2).lower()
        tf_answers[q_num] = "true" if tf_val in ("true", "t") else "false"

    # 1d. Short Text / Concept Answers (e.g. 1. Photosynthesis, 2. Mitochondria)
    text_answers: dict[int, str] = {}
    for m in re.finditer(r"(?:^|\n)\s*(?:Q(?:uestion)?\s*)?(\d{1,4})[\.\):\-]\s*(?:(?:answer|solution|explanation)\s*:\s*)?([^\n\r]+)", answers_text, re.IGNORECASE):
        q_num = int(m.group(1))
        raw_val = m.group(2).strip()
        if raw_val and q_num not in mcq_answers and q_num not in tf_answers and q_num not in math_eq_answers:
            text_answers[q_num] = raw_val

    questions_to_insert: list[dict[str, Any]] = []
    parsed_questions: list[Question] = []
    rng = random.Random(42)

    # 2. Parse Problems
    # If pure math equations worksheet (and not classified as science):
    if math_eq_answers and not is_science_doc:
        problems: dict[int, str] = {}
        for m in re.finditer(r"(?:^|\n)\s*(\d{1,4})\.\s*([^\n\r=]+=[^\n\r]+)", problems_text):
            q_num = int(m.group(1))
            eq = m.group(2).strip()
            eq = re.sub(r"\s+", " ", eq).replace("=-", "= -").replace("- -", "+ ")
            if not re.match(r"^x\s*=\s*-?\d+$", eq, re.IGNORECASE):
                problems[q_num] = eq

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

        keys = ["A", "B", "C", "D"]
        for q_num in sorted(problems.keys()):
            if q_num not in math_eq_answers:
                continue

            eq = problems[q_num]
            ans = math_eq_answers[q_num]
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
                explanation=f"To solve {eq}: isolating x yields x = {ans}.",
                grading_hints=[str(ans), f"x = {ans}", f"x={ans}"],
                source_chunk_ids=chunk_ids[:3],
                status=QuestionStatus.approved,
                prompt_version="doc_extracted_v1",
            )
            questions_to_insert.append(q.model_dump(by_alias=True))
            parsed_questions.append(q)

    else:
        # Science or general structured practice questions with answer rubric
        prob_splits = list(re.finditer(r"(?:^|\n)\s*(?:Question\s+)?(\d{1,4})[\.\)]\s*", problems_text, re.IGNORECASE))
        doc_topic = subcategory or (doc_subj if doc_subj and doc_subj.lower() != "study" else ("Science" if is_science_doc else "General Knowledge"))

        for i, m in enumerate(prob_splits):
            q_num = int(m.group(1))
            start_idx = m.end()
            end_idx = prob_splits[i + 1].start() if i + 1 < len(prob_splits) else len(problems_text)
            item_text = problems_text[start_idx:end_idx].strip()

            if not item_text:
                continue

            has_mcq_ans = q_num in mcq_answers
            has_tf_ans = q_num in tf_answers
            has_text_ans = q_num in text_answers

            if not (has_mcq_ans or has_tf_ans or has_text_ans):
                continue

            # Check if MCQ options are listed (e.g. A) ... B) ... C) ... D) or A. ... B. ...)
            raw_options = re.findall(r"(?:^|\n|\s+)\(?([A-D])[\)\.\:\-]\s*([^\n\r]+)", item_text)
            diff = DifficultyLevel.beginner if q_num <= 15 else (DifficultyLevel.intermediate if q_num <= 35 else DifficultyLevel.advanced)

            if len(raw_options) >= 2 or has_mcq_ans:
                # Multiple choice question
                body_match = re.split(r"(?:^|\n|\s+)\(?[A-D][\)\.\:\-]", item_text, maxsplit=1)
                body = body_match[0].strip() if body_match else item_text
                correct_key = mcq_answers.get(q_num, "A")

                options_list: list[McqOption] = []
                if raw_options:
                    for opt_key, opt_text in raw_options:
                        k = opt_key.upper()
                        options_list.append(McqOption(key=k, text=opt_text.strip(), is_correct=(k == correct_key)))
                else:
                    for k in ["A", "B", "C", "D"]:
                        options_list.append(McqOption(key=k, text=f"Option {k}", is_correct=(k == correct_key)))

                q = Question(
                    id=f"qst_doc_sci_{uuid4().hex[:8]}",
                    tenant_id=tenant_id,
                    workspace_id=workspace_id,
                    document_id=document_id,
                    topic=doc_topic,
                    question_type=QuestionType.mcq,
                    difficulty=diff,
                    body=body,
                    options=options_list,
                    answer=correct_key,
                    explanation=f"According to the document answer rubric, the correct response for problem {q_num} is option {correct_key}.",
                    grading_hints=[correct_key],
                    source_chunk_ids=chunk_ids[:3],
                    status=QuestionStatus.approved,
                    prompt_version="doc_extracted_v1",
                )
                questions_to_insert.append(q.model_dump(by_alias=True))
                parsed_questions.append(q)

            elif has_tf_ans or any(w in item_text.lower() for w in ("true or false", "true/false")):
                # True/False question
                correct_tf = tf_answers.get(q_num, "true")
                q = Question(
                    id=f"qst_doc_sci_{uuid4().hex[:8]}",
                    tenant_id=tenant_id,
                    workspace_id=workspace_id,
                    document_id=document_id,
                    topic=doc_topic,
                    question_type=QuestionType.true_false,
                    difficulty=diff,
                    body=item_text,
                    options=[
                        McqOption(key="true", text="True", is_correct=(correct_tf == "true")),
                        McqOption(key="false", text="False", is_correct=(correct_tf == "false")),
                    ],
                    answer=correct_tf,
                    explanation=f"According to the document rubric, the correct response for problem {q_num} is {correct_tf}.",
                    grading_hints=[correct_tf],
                    source_chunk_ids=chunk_ids[:3],
                    status=QuestionStatus.approved,
                    prompt_version="doc_extracted_v1",
                )
                questions_to_insert.append(q.model_dump(by_alias=True))
                parsed_questions.append(q)

            elif has_text_ans:
                # Short Answer question
                ans_text = text_answers[q_num]
                q = Question(
                    id=f"qst_doc_sci_{uuid4().hex[:8]}",
                    tenant_id=tenant_id,
                    workspace_id=workspace_id,
                    document_id=document_id,
                    topic=doc_topic,
                    question_type=QuestionType.short_answer,
                    difficulty=diff,
                    body=item_text,
                    options=[],
                    answer=ans_text,
                    explanation=f"According to the document rubric for problem {q_num}: {ans_text}.",
                    grading_hints=[ans_text],
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

        # Synchronously insert the first batch so they are immediately available
        try:
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
            seen_ids = {q.id for q in db_questions}
            for pq in parsed_questions:
                if pq.id not in seen_ids:
                    db_questions.append(pq)
                    seen_ids.add(pq.id)
            return db_questions
    except Exception as query_err:
        logger.warning("Failed to query inserted questions: %s", query_err)

    return parsed_questions
