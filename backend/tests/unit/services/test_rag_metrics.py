"""Unit tests for deterministic RAG metrics calculation."""

import pytest

from app.models.rag_evaluation import (
    AnswerEvaluation,
    QuestionEvaluation,
    RAGFailureStage,
    RetrievalEvaluation,
)
from app.services import rag_metrics


def test_normalize_text():
    raw = "  Photosynthesis: An essential Process (in 2026)!  "
    norm = rag_metrics.normalize_text(raw)
    assert norm == "photosynthesis an essential process in 2026"

    # Unicode diacritics stripping
    assert rag_metrics.normalize_text("Café & Résumé") == "cafe resume"


def test_extract_numbers_and_measures():
    text = "In 2024, the revenue grew by 15.5% with 10 casual leaves costing $500.00."
    nums = rag_metrics.extract_numbers_and_measures(text)
    assert "2024" in nums
    assert "15.5%" in nums
    assert "10" in nums
    assert "500.00" in nums


def test_scope_validity_all_valid():
    class DummyChunk:
        def __init__(self, cid, doc_id, tids, ws_id):
            self.chunk_id = cid
            self.document_id = doc_id
            self.topic_ids = tids
            self.workspace_id = ws_id

    chunks = [
        DummyChunk("c1", "doc_1", ["t1"], "ws_1"),
        DummyChunk("c2", "doc_1", ["t1", "t2"], "ws_1"),
        DummyChunk("c3", "doc_2", ["t1"], "ws_1"),
    ]

    validity, invalid_ids, flags = rag_metrics.evaluate_retrieval_scope(
        chunks,
        expected_workspace_id="ws_1",
        active_document_ids=["doc_1", "doc_2"],
        allowed_topic_ids=["t1"],
    )
    assert validity == 1.0
    assert invalid_ids == []
    assert flags == [True, True, True]


def test_scope_validity_mixed_and_invalid():
    class DummyChunk:
        def __init__(self, cid, doc_id, tids, ws_id):
            self.chunk_id = cid
            self.document_id = doc_id
            self.topic_ids = tids
            self.workspace_id = ws_id

    chunks = [
        DummyChunk("c1", "doc_1", ["t1"], "ws_1"),  # VALID
        DummyChunk("c2", "doc_old", ["t1"], "ws_1"),  # INVALID doc
        DummyChunk("c3", "doc_1", ["t_wrong"], "ws_1"),  # INVALID topic
        DummyChunk("c4", "doc_1", ["t1"], "ws_other"),  # INVALID workspace
    ]

    validity, invalid_ids, flags = rag_metrics.evaluate_retrieval_scope(
        chunks,
        expected_workspace_id="ws_1",
        active_document_ids=["doc_1"],
        allowed_topic_ids=["t1"],
    )
    assert validity == 0.25
    assert invalid_ids == ["c2", "c3", "c4"]
    assert flags == [True, False, False, False]


def test_scope_validity_empty():
    validity, invalid_ids, flags = rag_metrics.evaluate_retrieval_scope(
        [],
        expected_workspace_id="ws_1",
    )
    assert validity == 1.0
    assert invalid_ids == []
    assert flags == []


def test_evidence_coverage():
    context = (
        "Employees are entitled to 10 casual leaves per calendar year. "
        "Approval must be obtained from the direct manager."
    )
    required = ["10", "casual leaves", "direct manager"]

    coverage = rag_metrics.evaluate_evidence_coverage(required, context)
    assert coverage == 1.0

    # Partial coverage
    partial_req = ["10", "casual leaves", "unlimited remote work"]
    coverage_partial = rag_metrics.evaluate_evidence_coverage(partial_req, context)
    assert coverage_partial == pytest.approx(2 / 3, rel=1e-3)

    # Empty required evidence returns None (not applicable)
    assert rag_metrics.evaluate_evidence_coverage([], context) is None

    # Empty context with required evidence returns 0.0
    assert rag_metrics.evaluate_evidence_coverage(["fact"], "") == 0.0


def test_source_provenance_metrics():
    retrieved = ["c1", "c2", "c3", "c4", "c5"]
    known_sources = ["c3", "c7"]

    hit, rank, recall = rag_metrics.calculate_source_provenance_metrics(
        retrieved, known_sources, k=5
    )
    assert hit is True
    assert rank == 3
    assert recall == 0.5  # 1 of 2 sources recovered

    # No known sources
    hit_none, rank_none, recall_none = rag_metrics.calculate_source_provenance_metrics(
        retrieved, None, k=5
    )
    assert hit_none is None
    assert rank_none is None
    assert recall_none is None

    # Source not found in Top-2
    hit_2, rank_2, recall_2 = rag_metrics.calculate_source_provenance_metrics(
        retrieved, known_sources, k=2
    )
    assert hit_2 is False
    assert rank_2 is None
    assert recall_2 == 0.0


def test_answer_fact_metrics():
    # Clean scenario: all supported
    correctness, completeness, faithfulness = rag_metrics.calculate_answer_fact_metrics(
        supported_facts=["fact 1", "fact 2"],
        missing_facts=[],
        contradicted_facts=[],
    )
    assert correctness == 1.0
    assert completeness == 1.0
    assert faithfulness == 1.0

    # Contradicted scenario
    c, comp, faith = rag_metrics.calculate_answer_fact_metrics(
        supported_facts=["fact 1"],
        missing_facts=["fact 2"],
        contradicted_facts=["fact 3"],
    )
    assert c == 0.0  # (1 - 1) / 3
    assert comp == pytest.approx(1 / 3, rel=1e-3)
    assert faith == 0.5  # 1 supported / 2 total claims

    # Empty facts
    c_empty, comp_empty, faith_empty = rag_metrics.calculate_answer_fact_metrics([], [], [])
    assert c_empty == 1.0
    assert comp_empty == 1.0
    assert faith_empty == 1.0


def test_overall_score_and_stage_attribution():
    retrieval_pass = RetrievalEvaluation(scope_validity=1.0, passed=True)
    question_pass = QuestionEvaluation(groundedness=1.0, answerability=1.0, topic_relevance=1.0, passed=True)
    answer_pass = AnswerEvaluation(correctness=1.0, completeness=1.0, faithfulness=1.0, passed=True)

    score, passed = rag_metrics.calculate_overall_rag_score(retrieval_pass, question_pass, answer_pass)
    assert score == 1.0
    assert passed is True

    stage, reason = rag_metrics.attribute_failure_stage(retrieval_pass, question_pass, answer_pass)
    assert stage is None
    assert reason is None

    # Retrieval failure attribution
    retrieval_fail = RetrievalEvaluation(
        scope_validity=0.4,
        invalid_scope_chunk_ids=["chk_bad"],
        passed=False,
    )
    stage_r, reason_r = rag_metrics.attribute_failure_stage(retrieval_fail, question_pass, answer_pass)
    assert stage_r == RAGFailureStage.retrieval
    assert "chk_bad" in reason_r

    # Question groundedness failure attribution
    question_ungrounded = QuestionEvaluation(groundedness=0.3, passed=False)
    stage_g, reason_g = rag_metrics.attribute_failure_stage(retrieval_pass, question_ungrounded, answer_pass)
    assert stage_g == RAGFailureStage.grounding

    # Answer contradiction failure attribution
    answer_contra = AnswerEvaluation(
        correctness=0.0,
        contradicted_facts=["false statement"],
        faithfulness=0.0,
        passed=False,
    )
    stage_a, reason_a = rag_metrics.attribute_failure_stage(retrieval_pass, question_pass, answer_contra)
    assert stage_a == RAGFailureStage.answer_generation
    assert "contradictions" in reason_a
