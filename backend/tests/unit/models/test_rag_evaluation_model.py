"""Unit tests for the RAGEvaluationRecord Cosmos model."""

from app.models.rag_evaluation import (
    AnswerEvaluation,
    QuestionEvaluation,
    RAGEvaluationRecord,
    RetrievalEvaluation,
    RetrievedChunkTrace,
)


def test_rag_evaluation_model_validation():
    chunk_trace = RetrievedChunkTrace(
        chunk_id="chk_123",
        document_id="doc_456",
        topic_ids=["tpc_algebra"],
        chunk_index=0,
        rank=1,
        search_score=0.95,
        is_scope_valid=True,
    )

    record = RAGEvaluationRecord(
        **{"_id": "rageval_test_01"},
        tenant_id="ten_001",
        workspace_id="wsp_001",
        student_id="usr_001",
        session_id="ses_001",
        selected_topic_id="tpc_algebra",
        selected_topic_name="Algebra Fundamentals",
        active_document_ids=["doc_456"],
        retrieved_chunks=[chunk_trace],
        generation_chunk_ids=["chk_123"],
        question_id="qst_001",
        question_type="mcq",
        question_body="What is 2x = 6?",
        reference_answer="x = 3",
        retrieval=RetrievalEvaluation(scope_validity=1.0, passed=True),
        question=QuestionEvaluation(
            groundedness=1.0, answerability=1.0, topic_relevance=1.0, passed=True
        ),
        answer=AnswerEvaluation(
            correctness=1.0,
            completeness=1.0,
            faithfulness=1.0,
            supported_facts=["x = 3"],
            passed=True,
        ),
        overall_score=1.0,
        passed=True,
        failed_stage=None,
        failure_reason=None,
        llm_evaluator_used=False,
    )

    assert record.id == "rageval_test_01"
    assert record.evaluation_version == "rag_eval_v1"
    assert record.overall_score == 1.0
    assert record.passed is True
    assert len(record.retrieved_chunks) == 1
    assert record.retrieved_chunks[0].chunk_id == "chk_123"

    dumped = record.model_dump(by_alias=True)
    assert dumped["_id"] == "rageval_test_01"
    assert dumped["retrieval"]["scope_validity"] == 1.0
    assert dumped["failed_stage"] is None
