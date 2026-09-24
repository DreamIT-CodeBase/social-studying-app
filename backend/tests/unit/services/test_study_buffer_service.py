"""Unit tests for study_buffer_service.py supporting smart sliding pre-warm and replenishment."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.study_buffer_service import (
    get_remaining_study_buffer_count,
    prefill_document_study_buffers,
    topup_topic_study_buffer,
)


@pytest.mark.asyncio
async def test_prefill_document_study_buffers_generates_questions_and_flashcards():
    """Verify that ready documents trigger initial question and flashcard buffer pre-fill."""
    doc_meta = {
        "_id": "doc_physics_1",
        "workspace_id": "ws_123",
        "category": "Physics",
        "subcategory": "Laws of Motion",
        "filename": "physics_laws.pdf",
        "topic_tags": [{"name": "Laws of Motion"}, {"name": "Inertia"}],
    }
    chunks = [
        {"_id": "chk_1", "chunk_index": 0, "text": "Newton's First Law states that an object at rest remains at rest."},
        {"_id": "chk_2", "chunk_index": 1, "text": "Force is equal to mass times acceleration: F = ma."},
    ]

    mock_docs_col = MagicMock()
    mock_docs_col.find_one = AsyncMock(return_value=doc_meta)

    mock_chunks_col = MagicMock()
    mock_chunks_cursor = MagicMock()
    mock_chunks_cursor.to_list = AsyncMock(return_value=chunks)
    mock_chunks_col.find = MagicMock(return_value=mock_chunks_cursor)

    mock_q_col = MagicMock()
    mock_q_col.count_documents = AsyncMock(return_value=0)
    mock_q_col.insert_many = AsyncMock()

    mock_fc_col = MagicMock()
    mock_fc_col.count_documents = AsyncMock(return_value=0)
    mock_fc_col.insert_many = AsyncMock()

    def get_col_side_effect(tenant_id, name):
        if name == "documents":
            return mock_docs_col
        elif name == "chunks":
            return mock_chunks_col
        elif name == "question_queue":
            return mock_q_col
        elif name == "flashcards":
            return mock_fc_col
        return MagicMock()

    sample_questions_response = {
        "questions": [
            {
                "topic": "Laws of Motion",
                "question_type": "mcq",
                "body": "According to Newton's First Law, what keeps an object in uniform motion?",
                "options": [
                    {"key": "A", "text": "Absence of net external force"},
                    {"key": "B", "text": "Constant applied force"},
                    {"key": "C", "text": "Friction"},
                    {"key": "D", "text": "Gravity"},
                ],
                "answer": "A",
                "explanation": "Newton's First Law (inertia) states that velocity remains constant unless acted upon by a net force.",
            }
        ]
    }

    sample_flashcards_response = {
        "flashcards": [
            {
                "topic": "Laws of Motion",
                "front": "What is Newton's Second Law formula?",
                "back": "F = ma",
                "explanation": "Net force equals mass times acceleration.",
            }
        ]
    }

    with patch("app.services.study_buffer_service.get_collection", side_effect=get_col_side_effect), \
         patch("app.services.study_buffer_service.azure_openai.chat_json", side_effect=[sample_questions_response, sample_flashcards_response]), \
         patch("app.services.document_question_extractor.extract_and_queue_document_questions", new_callable=AsyncMock):

        await prefill_document_study_buffers(
            tenant_id="tenant_test",
            workspace_id="ws_123",
            document_id="doc_physics_1",
        )

        assert mock_q_col.insert_many.called
        q_args = mock_q_col.insert_many.call_args[0][0]
        assert len(q_args) == 1
        assert q_args[0]["topic"] == "Laws of Motion"
        assert q_args[0]["body"] == "According to Newton's First Law, what keeps an object in uniform motion?"

        assert mock_fc_col.insert_many.called
        fc_args = mock_fc_col.insert_many.call_args[0][0]
        assert len(fc_args) == 1
        assert fc_args[0]["front"] == "What is Newton's Second Law formula?"
        assert fc_args[0]["back"] == "F = ma"


@pytest.mark.asyncio
async def test_get_remaining_study_buffer_count():
    """Verify remaining study buffer count logic."""
    mock_q_col = MagicMock()
    mock_q_col.count_documents = AsyncMock(return_value=7)

    with patch("app.services.study_buffer_service.get_collection", return_value=mock_q_col):
        count = await get_remaining_study_buffer_count(
            tenant_id="tenant_test",
            workspace_id="ws_123",
            document_ids=["doc_1"],
            subject="Physics",
            topic="Laws of Motion",
            is_flashcard=False,
            seen_ids={"qst_seen_1", "qst_seen_2"},
        )
        assert count == 7


@pytest.mark.asyncio
async def test_topup_topic_study_buffer_generates_variations_and_respects_limit():
    """Verify that low watermark topup generates variations and enforces round limit."""
    doc_meta = {
        "_id": "doc_physics_1",
        "workspace_id": "ws_123",
        "category": "Physics",
        "subcategory": "Laws of Motion",
        "var_round_laws of motion": 1,
    }

    mock_docs_col = MagicMock()
    mock_docs_col.find_one = AsyncMock(return_value=doc_meta)
    mock_docs_col.update_one = AsyncMock()

    mock_q_col = MagicMock()
    mock_q_col.insert_many = AsyncMock()

    def get_col_side_effect(tenant_id, name):
        if name == "documents":
            return mock_docs_col
        elif name == "question_queue":
            return mock_q_col
        return MagicMock()

    sample_var_resp = {
        "questions": [
            {
                "question_type": "mcq",
                "body": "A 10 kg mass accelerates at 4 m/s^2. What is the net force?",
                "options": [
                    {"key": "A", "text": "40 N"},
                    {"key": "B", "text": "2.5 N"},
                    {"key": "C", "text": "14 N"},
                    {"key": "D", "text": "6 N"},
                ],
                "answer": "A",
                "explanation": "F = ma = 10 * 4 = 40 N.",
            }
        ]
    }

    with patch("app.services.study_buffer_service.get_collection", side_effect=get_col_side_effect), \
         patch("app.services.study_buffer_service.azure_openai.chat_json", return_value=sample_var_resp):

        added = await topup_topic_study_buffer(
            tenant_id="tenant_test",
            workspace_id="ws_123",
            document_id="doc_physics_1",
            subject="Physics",
            topic="Laws of Motion",
            is_flashcard=False,
            seen_ids={"qst_1"},
            seen_bodies_or_fronts=["Original Question text."],
            round_limit=3,
        )

        assert added == 1
        assert mock_docs_col.update_one.called
        assert mock_q_col.insert_many.called

    # When round limit reached (e.g. current_round=3, limit=3)
    doc_meta_exhausted = {
        "_id": "doc_physics_1",
        "workspace_id": "ws_123",
        "category": "Physics",
        "subcategory": "Laws of Motion",
        "var_round_laws of motion": 3,
    }
    mock_docs_col.find_one = AsyncMock(return_value=doc_meta_exhausted)
    with patch("app.services.study_buffer_service.get_collection", side_effect=get_col_side_effect):
        added = await topup_topic_study_buffer(
            tenant_id="tenant_test",
            workspace_id="ws_123",
            document_id="doc_physics_1",
            subject="Physics",
            topic="Laws of Motion",
            is_flashcard=False,
            seen_ids=set(),
            seen_bodies_or_fronts=[],
            round_limit=3,
        )
        assert added == 0  # Reached limit, no generation
