"""RAG Evaluation orchestrator service.

Coordinates deterministic-first RAG evaluation, provenance tracking,
Evaluator LLM semantic fallback, metrics calculation, and Cosmos DB persistence.
"""

from __future__ import annotations

import logging
import time
from collections.abc import Iterable, Sequence
from typing import Any
from uuid import uuid4

from app.core.database import RAG_EVALUATIONS, get_collection
from app.models.base import utc_now
from app.models.rag_evaluation import (
    AnswerEvaluation,
    QuestionEvaluation,
    RAGEvaluationRecord,
    RetrievalEvaluation,
    RetrievedChunkTrace,
)
from app.services import rag_evaluator, rag_metrics

logger = logging.getLogger(__name__)


async def evaluate_and_persist_rag(
    *,
    tenant_id: str,
    workspace_id: str,
    student_id: str | None = None,
    session_id: str | None = None,
    selected_topic_id: str | None = None,
    selected_topic_name: str | None = None,
    active_document_ids: Iterable[str] | None = None,
    retrieved_chunks: Sequence[Any] = (),
    generation_chunk_ids: Sequence[str] = (),
    question_id: str | None = None,
    question_type: str = "mcq",
    question_body: str = "",
    reference_answer: str = "",
    explanation: str = "",
    known_source_chunk_ids: Sequence[str] | None = None,
    required_evidence: Sequence[str] | None = None,
    force_llm_evaluator: bool = False,
    persist_to_db: bool = True,
) -> RAGEvaluationRecord:
    """Run end-to-end deterministic-first RAG evaluation and persist the evaluation record."""
    start_time = time.perf_counter()
    active_doc_list = list(active_document_ids) if active_document_ids is not None else []
    topic_id_list = [selected_topic_id] if selected_topic_id else []

    # ── 1. Chunking & Retrieval Evaluation ────────────────────────────────────
    chunking_eval = rag_metrics.evaluate_chunking_quality(retrieved_chunks)

    scope_validity, invalid_chunk_ids, is_valid_flags = rag_metrics.evaluate_retrieval_scope(
        retrieved_chunks,
        expected_workspace_id=workspace_id,
        active_document_ids=active_doc_list if active_doc_list else None,
        allowed_topic_ids=topic_id_list if topic_id_list else None,
    )

    retrieved_traces: list[RetrievedChunkTrace] = []
    retrieved_chunk_ids: list[str] = []
    combined_context_parts: list[str] = []

    for idx, chunk in enumerate(retrieved_chunks, start=1):
        cid = getattr(chunk, "chunk_id", None) or getattr(chunk, "id", str(chunk))
        doc_id = getattr(chunk, "document_id", "")
        tids = getattr(chunk, "topic_ids", []) or []
        cidx = getattr(chunk, "chunk_index", 0)
        score = getattr(chunk, "score", None)
        text = getattr(chunk, "text", "")

        retrieved_chunk_ids.append(str(cid))
        if text:
            combined_context_parts.append(text)

        retrieved_traces.append(
            RetrievedChunkTrace(
                chunk_id=str(cid),
                document_id=str(doc_id),
                topic_ids=[str(t) for t in tids],
                chunk_index=int(cidx),
                rank=idx,
                search_score=float(score) if score is not None else None,
                is_scope_valid=is_valid_flags[idx - 1] if idx - 1 < len(is_valid_flags) else True,
                text_snippet=text[:150] if text else None,
            )
        )

    context_text = "\n\n".join(combined_context_parts)
    topic_name = selected_topic_name or ""

    # Context density & evidence coverage
    context_density = rag_metrics.evaluate_context_density(
        context_text,
        topic_name=topic_name,
        question_body=question_body,
    )

    evidence_coverage = rag_metrics.evaluate_evidence_coverage(
        required_evidence or [],
        context_text,
    )

    # Source provenance metrics
    source_hit, source_rank, source_recall = rag_metrics.calculate_source_provenance_metrics(
        retrieved_chunk_ids,
        known_source_chunk_ids,
        k=len(retrieved_chunk_ids) or 5,
    )

    retrieval_eval = RetrievalEvaluation(
        scope_validity=scope_validity,
        evidence_coverage=evidence_coverage,
        context_density=context_density,
        chunk_relevance_llm=1.0,
        chunk_sufficiency_llm=1.0,
        source_hit_at_k=source_hit,
        source_rank=source_rank,
        source_recall_at_k=source_recall,
        invalid_scope_chunk_ids=invalid_chunk_ids,
        passed=scope_validity >= 0.70 and (evidence_coverage is None or evidence_coverage >= 0.50),
        details={
            "retrieved_count": len(retrieved_chunks),
            "generation_chunk_count": len(generation_chunk_ids),
        },
    )

    # ── 2. Deterministic Checks & LLM Fallback Decision ───────────────────────
    llm_evaluator_used = False

    # Fast deterministic checks
    q_groundedness_det = rag_metrics.calculate_question_groundedness_deterministic(
        question_body, context_text, reference_answer=reference_answer
    )
    topic_norm = rag_metrics.normalize_text(topic_name)
    q_norm = rag_metrics.normalize_text(question_body)
    topic_relevant_det = bool(topic_norm in q_norm or topic_norm in rag_metrics.normalize_text(context_text))

    # Fast check on answer facts
    import re
    clean_ans = re.sub(r"^(?:option\s+)?[a-da-d][\)\:\.\-]\s*", "", reference_answer, flags=re.IGNORECASE).strip()
    answer_norm = rag_metrics.normalize_text(clean_ans or reference_answer)
    is_tf = question_type in ("true_false", "boolean") or clean_ans.lower() in ("true", "false")
    answer_in_context = (answer_norm in rag_metrics.normalize_text(context_text)) if (answer_norm and not is_tf) else is_tf

    ans_numbers = rag_metrics.extract_numbers_and_measures(reference_answer)
    ctx_numbers = set(rag_metrics.extract_numbers_and_measures(context_text))
    numbers_conflict = bool(ans_numbers and any(n not in ctx_numbers for n in ans_numbers))

    # Decide if semantic LLM evaluation is necessary
    needs_semantic_eval = force_llm_evaluator or (
        question_type in ("long_answer", "mathematical")
        or (not answer_in_context and len(answer_norm.split()) > 3 and not numbers_conflict)
        or (q_groundedness_det < 0.20 and not answer_in_context and not numbers_conflict)
    )

    if needs_semantic_eval and context_text.strip():
        llm_evaluator_used = True
        sem_result = await rag_evaluator.evaluate_rag_semantics(
            selected_topic=topic_name,
            retrieved_context=context_text,
            question_body=question_body,
            reference_answer=reference_answer,
            explanation=explanation,
            question_type=question_type,
        )

        retrieval_eval.chunk_relevance_llm = 1.0 if sem_result.chunks_relevant else 0.0
        retrieval_eval.chunk_sufficiency_llm = 1.0 if sem_result.chunks_sufficient else 0.0

        q_groundedness = 1.0 if sem_result.question_grounded else 0.0
        q_answerability = 1.0 if sem_result.question_answerable else 0.0
        q_topic_relevance = 1.0 if sem_result.question_topic_relevant else 0.0

        correctness, completeness, faithfulness = rag_metrics.calculate_answer_fact_metrics(
            sem_result.supported_facts,
            sem_result.missing_facts,
            sem_result.contradicted_facts,
            sem_result.uncertain_facts,
        )

        question_eval = QuestionEvaluation(
            groundedness=q_groundedness,
            answerability=q_answerability,
            topic_relevance=q_topic_relevance,
            passed=(q_groundedness >= 0.70 and q_answerability >= 0.70 and q_topic_relevance >= 0.70),
            reason=sem_result.question_reason,
        )

        answer_eval = AnswerEvaluation(
            correctness=correctness,
            completeness=completeness,
            faithfulness=faithfulness,
            supported_facts=sem_result.supported_facts,
            missing_facts=sem_result.missing_facts,
            contradicted_facts=sem_result.contradicted_facts,
            uncertain_facts=sem_result.uncertain_facts,
            passed=(correctness >= 0.70 and faithfulness >= 0.70 and len(sem_result.contradicted_facts) == 0),
        )
    else:
        # Deterministic-only path (Fast, zero extra LLM cost/latency)
        q_groundedness = max(0.0, min(1.0, q_groundedness_det))
        q_answerability = 1.0 if q_groundedness >= 0.50 else 0.0
        q_topic_relevance = 1.0 if topic_relevant_det else 0.8

        if numbers_conflict:
            supported = []
            missing = []
            contradicted = [reference_answer] if reference_answer else []
            correctness = 0.0
            completeness = 0.0
            faithfulness = 0.0
            answer_passed = False
        elif answer_in_context:
            supported = [reference_answer] if reference_answer else []
            missing = []
            contradicted = []
            correctness = 1.0
            completeness = 1.0
            faithfulness = 1.0
            answer_passed = True
        else:
            supported = []
            missing = [reference_answer] if reference_answer else []
            contradicted = []
            correctness = 0.5
            completeness = 0.5
            faithfulness = 1.0
            answer_passed = False

        question_eval = QuestionEvaluation(
            groundedness=q_groundedness,
            answerability=q_answerability,
            topic_relevance=q_topic_relevance,
            passed=q_groundedness >= 0.50 and q_topic_relevance >= 0.50,
            reason="Deterministic lexical verification",
        )

        answer_eval = AnswerEvaluation(
            correctness=correctness,
            completeness=completeness,
            faithfulness=faithfulness,
            supported_facts=supported,
            missing_facts=missing,
            contradicted_facts=contradicted,
            uncertain_facts=[],
            passed=answer_passed,
        )

    # ── 3. Final Composite Metrics & Stage Attribution ────────────────────────
    overall_score, overall_passed = rag_metrics.calculate_overall_rag_score(
        retrieval_eval, question_eval, answer_eval, chunking=chunking_eval
    )
    failed_stage, failure_reason = rag_metrics.attribute_failure_stage(
        retrieval_eval, question_eval, answer_eval, chunking=chunking_eval
    )

    duration_ms = float(round((time.perf_counter() - start_time) * 1000, 2))

    eval_id = f"rageval_{uuid4().hex}"
    record = RAGEvaluationRecord(
        **{"_id": eval_id},
        evaluation_version="rag_eval_v1",
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        student_id=student_id,
        session_id=session_id,
        selected_topic_id=selected_topic_id,
        selected_topic_name=selected_topic_name,
        active_document_ids=active_doc_list,
        retrieved_chunks=retrieved_traces,
        generation_chunk_ids=list(generation_chunk_ids),
        question_id=question_id,
        question_type=question_type,
        question_body=question_body,
        reference_answer=reference_answer,
        explanation=explanation,
        retrieval=retrieval_eval,
        chunking=chunking_eval,
        question=question_eval,
        answer=answer_eval,
        overall_score=overall_score,
        passed=overall_passed,
        failed_stage=failed_stage,
        failure_reason=failure_reason,
        llm_evaluator_used=llm_evaluator_used,
        evaluation_duration_ms=duration_ms,
        created_at=utc_now(),
        updated_at=utc_now(),
    )

    # ── 4. Cosmos DB Persistence ──────────────────────────────────────────────
    if persist_to_db:
        try:
            col = get_collection(tenant_id, RAG_EVALUATIONS)
            await col.insert_one(record.model_dump(by_alias=True))
        except Exception as exc:
            logger.warning("Failed to persist RAG evaluation record %s: %s", eval_id, exc)

    # ── 5. Structured Telemetry Logging ───────────────────────────────────────
    logger.info(
        "RAG Evaluation: id=%s workspace=%s qid=%s scope_validity=%.2f overall=%.2f passed=%s failed_stage=%s llm_used=%s duration_ms=%.1f",
        eval_id,
        workspace_id,
        question_id or "unassigned",
        retrieval_eval.scope_validity,
        overall_score,
        overall_passed,
        failed_stage.value if failed_stage else "NONE",
        llm_evaluator_used,
        duration_ms,
    )

    return record
