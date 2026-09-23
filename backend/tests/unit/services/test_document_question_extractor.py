"""Unit tests for document_question_extractor.py supporting Science rubrics and Math worksheets."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.question import QuestionType
from app.services.document_question_extractor import extract_and_queue_document_questions


@pytest.mark.asyncio
async def test_extract_science_document_with_mcq_rubric():
    """Verify that a Science document with answer rubric extracts clean science MCQ questions."""
    doc_text = """
Biology Chapter 4: Cellular Processes Practice Exam

1. Which organelle is responsible for synthesizing ATP during cellular respiration?
A) Ribosome
B) Mitochondria
C) Nucleus
D) Endoplasmic reticulum

2. What biological process allows plants to convert solar energy into glucose?
A) Photosynthesis
B) Cellular respiration
C) Fermentation
D) Transpiration

Complete Answer Rubric:
1. B
2. A
"""
    chunks = [{"_id": "chk_1", "chunk_index": 0, "text": doc_text}]
    doc_meta = {
        "_id": "doc_sci_1",
        "category": "Science",
        "subcategory": "Cell Biology",
        "filename": "cell_biology_practice.pdf",
    }

    mock_chunks_col = MagicMock()
    mock_cursor = MagicMock()
    mock_cursor.to_list = AsyncMock(return_value=chunks)
    mock_chunks_col.find = MagicMock(return_value=mock_cursor)

    mock_docs_col = MagicMock()
    mock_docs_col.find_one = AsyncMock(return_value=doc_meta)

    mock_q_col = MagicMock()
    mock_q_cursor = MagicMock()
    mock_q_cursor.to_list = AsyncMock(return_value=[])
    mock_q_col.find = MagicMock(return_value=mock_q_cursor)
    mock_q_col.insert_many = AsyncMock()

    def get_col_side_effect(tenant_id, name):
        if name == "chunks":
            return mock_chunks_col
        elif name == "documents":
            return mock_docs_col
        elif name == "question_queue":
            return mock_q_col
        return MagicMock()

    with patch("app.services.document_question_extractor.get_collection", side_effect=get_col_side_effect):
        questions = await extract_and_queue_document_questions(
            tenant_id="ten_test",
            workspace_id="wsp_test",
            document_id="doc_sci_1",
        )

    assert len(questions) == 2
    q1 = questions[0]
    assert q1.question_type == QuestionType.mcq
    assert "organelle is responsible for synthesizing atp" in q1.body.lower()
    assert q1.answer == "B"
    assert q1.topic == "Cell Biology"
    assert len(q1.options) == 4
    # Option B should be correct
    opt_b = next((o for o in q1.options if o.key == "B"), None)
    assert opt_b is not None
    assert opt_b.is_correct is True
    assert "mitochondria" in opt_b.text.lower()
    # Zero math
    assert "solve for x" not in q1.body.lower()

    q2 = questions[1]
    assert q2.question_type == QuestionType.mcq
    assert "convert solar energy into glucose" in q2.body.lower()
    assert q2.answer == "A"
    opt_a = next((o for o in q2.options if o.key == "A"), None)
    assert opt_a is not None
    assert opt_a.is_correct is True
    assert "photosynthesis" in opt_a.text.lower()


@pytest.mark.asyncio
async def test_extract_science_document_with_true_false_rubric():
    """Verify that True/False science questions in documents are parsed with True/False options."""
    doc_text = """
Middle School Science Quiz

1. Chloroplasts are found in both plant and animal cells.
2. DNA carries hereditary information in living organisms.

Answer Rubric:
1. False
2. True
"""
    chunks = [{"_id": "chk_2", "chunk_index": 0, "text": doc_text}]
    doc_meta = {
        "_id": "doc_sci_2",
        "category": "Science",
        "subcategory": "Genetics",
        "filename": "genetics_quiz.txt",
    }

    mock_chunks_col = MagicMock()
    mock_cursor = MagicMock()
    mock_cursor.to_list = AsyncMock(return_value=chunks)
    mock_chunks_col.find = MagicMock(return_value=mock_cursor)

    mock_docs_col = MagicMock()
    mock_docs_col.find_one = AsyncMock(return_value=doc_meta)

    mock_q_col = MagicMock()
    mock_q_cursor = MagicMock()
    mock_q_cursor.to_list = AsyncMock(return_value=[])
    mock_q_col.find = MagicMock(return_value=mock_q_cursor)
    mock_q_col.insert_many = AsyncMock()

    def get_col_side_effect(tenant_id, name):
        if name == "chunks":
            return mock_chunks_col
        elif name == "documents":
            return mock_docs_col
        elif name == "question_queue":
            return mock_q_col
        return MagicMock()

    with patch("app.services.document_question_extractor.get_collection", side_effect=get_col_side_effect):
        questions = await extract_and_queue_document_questions(
            tenant_id="ten_test",
            workspace_id="wsp_test",
            document_id="doc_sci_2",
        )

    assert len(questions) == 2
    assert questions[0].question_type == QuestionType.true_false
    assert questions[0].answer == "false"
    assert questions[1].question_type == QuestionType.true_false
    assert questions[1].answer == "true"
    assert questions[0].topic == "Genetics"


@pytest.mark.asyncio
async def test_extract_math_worksheet_preserved():
    """Verify that pure Algebra worksheets with x = numeric answer key continue extracting equations."""
    doc_text = """
Algebra 1 Linear Equations Worksheet

1. 3x + 6 = 21
2. 5x - 10 = 15

Answer Key:
1. x = 5
2. x = 5
"""
    chunks = [{"_id": "chk_3", "chunk_index": 0, "text": doc_text}]
    doc_meta = {
        "_id": "doc_math_1",
        "category": "Mathematics",
        "subcategory": "Linear Equations",
        "filename": "algebra_equations.txt",
    }

    mock_chunks_col = MagicMock()
    mock_cursor = MagicMock()
    mock_cursor.to_list = AsyncMock(return_value=chunks)
    mock_chunks_col.find = MagicMock(return_value=mock_cursor)

    mock_docs_col = MagicMock()
    mock_docs_col.find_one = AsyncMock(return_value=doc_meta)

    mock_q_col = MagicMock()
    mock_q_cursor = MagicMock()
    mock_q_cursor.to_list = AsyncMock(return_value=[])
    mock_q_col.find = MagicMock(return_value=mock_q_cursor)
    mock_q_col.insert_many = AsyncMock()

    def get_col_side_effect(tenant_id, name):
        if name == "chunks":
            return mock_chunks_col
        elif name == "documents":
            return mock_docs_col
        elif name == "question_queue":
            return mock_q_col
        return MagicMock()

    with patch("app.services.document_question_extractor.get_collection", side_effect=get_col_side_effect):
        questions = await extract_and_queue_document_questions(
            tenant_id="ten_test",
            workspace_id="wsp_test",
            document_id="doc_math_1",
        )

    assert len(questions) == 2
    assert "Solve for x: 3x + 6 = 21" in questions[0].body
    assert "Solve for x: 5x - 10 = 15" in questions[1].body
