"""Unit tests for the master RAG Evaluation Orchestrator."""

from unittest.mock import AsyncMock, MagicMock, patch
import pytest

from app.models.rag_evaluation import RAGFailureStage
from app.services import rag_evaluation


class DummyChunk:
    def __init__(self, chunk_id, document_id, topic_ids, text, score=0.9, chunk_index=0, workspace_id="wsp_1"):
        self.chunk_id = chunk_id
        self.document_id = document_id
        self.topic_ids = topic_ids
        self.text = text
        self.score = score
        self.chunk_index = chunk_index
        self.workspace_id = workspace_id


@pytest.mark.asyncio
async def test_deterministic_fast_path():
    chunks = [
        DummyChunk("chk_1", "doc_1", ["tpc_1"], "Mitochondria are known as the powerhouse of the cell."),
        DummyChunk("chk_2", "doc_1", ["tpc_1"], "They generate most of the cell's supply of ATP."),
    ]

    mock_col = MagicMock()
    mock_col.insert_one = AsyncMock(return_value=None)

    with patch("app.services.rag_evaluation.get_collection", return_value=mock_col):
        record = await rag_evaluation.evaluate_and_persist_rag(
            tenant_id="ten_1",
            workspace_id="wsp_1",
            student_id="usr_student",
            session_id="ses_1",
            selected_topic_id="tpc_1",
            selected_topic_name="Cellular Respiration",
            active_document_ids=["doc_1"],
            retrieved_chunks=chunks,
            generation_chunk_ids=["chk_1", "chk_2"],
            question_id="qst_1",
            question_type="mcq",
            question_body="What organelle produces ATP?",
            reference_answer="Mitochondria",
            known_source_chunk_ids=["chk_1"],
        )

        assert record.passed is True
        assert record.overall_score >= 0.70
        assert record.llm_evaluator_used is False  # Fast deterministic path used
        assert record.retrieval.scope_validity == 1.0
        assert record.retrieval.source_hit_at_k is True
        assert record.retrieval.source_rank == 1
        assert record.failed_stage is None
        mock_col.insert_one.assert_awaited_once()


@pytest.mark.asyncio
async def test_out_of_scope_retrieval_failure():
    chunks = [
        DummyChunk("chk_alien", "doc_foreign", ["tpc_alien"], "Ancient Rome was founded in 753 BC.", workspace_id="wsp_other"),
    ]

    mock_col = MagicMock()
    mock_col.insert_one = AsyncMock(return_value=None)

    with patch("app.services.rag_evaluation.get_collection", return_value=mock_col):
        record = await rag_evaluation.evaluate_and_persist_rag(
            tenant_id="ten_1",
            workspace_id="wsp_1",
            student_id="usr_student",
            selected_topic_id="tpc_math",
            selected_topic_name="Algebra",
            active_document_ids=["doc_math_1"],
            retrieved_chunks=chunks,
            generation_chunk_ids=["chk_alien"],
            question_id="qst_bad",
            question_body="When was Rome founded?",
            reference_answer="753 BC",
            persist_to_db=False,
        )

        assert record.retrieval.scope_validity == 0.0
        assert record.passed is False
        assert record.failed_stage == RAGFailureStage.retrieval
        assert "Retrieval scope violation" in record.failure_reason


@pytest.mark.asyncio
async def test_semantic_fallback_for_long_answer():
    chunks = [
        DummyChunk("chk_1", "doc_1", ["tpc_1"], "Photosynthesis transforms water and carbon dioxide into glucose and oxygen using light."),
    ]

    mock_sem_res = MagicMock(
        question_grounded=True,
        question_answerable=True,
        question_topic_relevant=True,
        question_reason="Fully grounded explanation.",
        supported_facts=["Converts CO2 and H2O to glucose", "Releases oxygen as byproduct"],
        missing_facts=[],
        contradicted_facts=[],
        uncertain_facts=[],
        raw_response={},
    )

    with patch("app.services.rag_evaluator.evaluate_rag_semantics", new=AsyncMock(return_value=mock_sem_res)), \
         patch("app.services.rag_evaluation.get_collection", return_value=MagicMock(insert_one=AsyncMock())):
        record = await rag_evaluation.evaluate_and_persist_rag(
            tenant_id="ten_1",
            workspace_id="wsp_1",
            selected_topic_id="tpc_1",
            selected_topic_name="Photosynthesis",
            active_document_ids=["doc_1"],
            retrieved_chunks=chunks,
            question_id="qst_essay",
            question_type="long_answer",
            question_body="Explain the chemical transformation occurring in photosynthesis.",
            reference_answer="Light energy converts water and carbon dioxide into glucose, releasing oxygen.",
            force_llm_evaluator=True,
            persist_to_db=False,
        )

        assert record.llm_evaluator_used is True
        assert record.passed is True
        assert record.answer.completeness == 1.0
        assert record.answer.faithfulness == 1.0
        assert len(record.answer.supported_facts) == 2


@pytest.mark.asyncio
async def test_empty_retrieval_handling():
    record = await rag_evaluation.evaluate_and_persist_rag(
        tenant_id="ten_1",
        workspace_id="wsp_1",
        selected_topic_id="tpc_empty",
        selected_topic_name="Unknown Topic",
        active_document_ids=[],
        retrieved_chunks=[],
        question_id="qst_empty",
        question_body="What is unknown?",
        reference_answer="Nothing",
        persist_to_db=False,
    )
    assert record.retrieval.scope_validity == 1.0
    assert len(record.retrieved_chunks) == 0


@pytest.mark.asyncio
async def test_contradiction_causes_answer_generation_failure():
    chunks = [
        DummyChunk("chk_1", "doc_1", ["tpc_1"], "Water boils at 100 degrees Celsius at sea level."),
    ]

    mock_sem_res = MagicMock(
        question_grounded=True,
        question_answerable=True,
        question_topic_relevant=True,
        question_reason="Grounded question.",
        supported_facts=[],
        missing_facts=[],
        contradicted_facts=["Water boils at 50 degrees Celsius"],
        uncertain_facts=[],
        raw_response={},
    )

    with patch("app.services.rag_evaluator.evaluate_rag_semantics", new=AsyncMock(return_value=mock_sem_res)):
        record = await rag_evaluation.evaluate_and_persist_rag(
            tenant_id="ten_1",
            workspace_id="wsp_1",
            selected_topic_id="tpc_1",
            selected_topic_name="Thermodynamics",
            active_document_ids=["doc_1"],
            retrieved_chunks=chunks,
            question_id="qst_contra",
            question_type="short_answer",
            question_body="At what temperature does water boil?",
            reference_answer="50 degrees Celsius",
            force_llm_evaluator=True,
            persist_to_db=False,
        )

        assert record.passed is False
        assert record.failed_stage == RAGFailureStage.answer_generation
        assert "contradictions" in record.failure_reason


@pytest.mark.asyncio
async def test_cosmos_persistence_error_graceful_handling():
    chunks = [
        DummyChunk("chk_1", "doc_1", ["tpc_1"], "Gravity accelerates objects downwards."),
    ]

    mock_col = MagicMock()
    mock_col.insert_one = AsyncMock(side_effect=RuntimeError("Cosmos rate limit 429"))

    with patch("app.services.rag_evaluation.get_collection", return_value=mock_col):
        # Should not raise exception even if Cosmos insert fails
        record = await rag_evaluation.evaluate_and_persist_rag(
            tenant_id="ten_1",
            workspace_id="wsp_1",
            selected_topic_id="tpc_1",
            selected_topic_name="Physics",
            active_document_ids=["doc_1"],
            retrieved_chunks=chunks,
            question_id="qst_phys",
            question_body="What direction does gravity pull?",
            reference_answer="Downwards",
            persist_to_db=True,
        )
        assert record.passed is True
        mock_col.insert_one.assert_awaited_once()
