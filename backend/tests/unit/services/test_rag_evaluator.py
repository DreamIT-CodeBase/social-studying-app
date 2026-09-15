"""Unit tests for the RAG Evaluator LLM service."""

from unittest.mock import AsyncMock, patch

import pytest

from app.services import rag_evaluator


@pytest.mark.asyncio
async def test_rag_evaluator_success():
    mock_payload = {
        "question": {
            "grounded": True,
            "answerable": True,
            "topic_relevant": True,
            "reason": "The question is directly grounded in photosynthesis definition.",
        },
        "answer": {
            "supported_facts": [
                "Chloroplasts contain chlorophyll",
                "Light energy converted to glucose",
            ],
            "missing_facts": [],
            "contradicted_facts": [],
            "uncertain_facts": [],
        },
    }

    with patch("app.services.azure_openai.chat_json", new=AsyncMock(return_value=mock_payload)):
        result = await rag_evaluator.evaluate_rag_semantics(
            selected_topic="Photosynthesis",
            retrieved_context="Photosynthesis occurs in chloroplasts where light is converted into chemical energy.",
            question_body="Where does photosynthesis occur?",
            reference_answer="In chloroplasts",
            explanation="Chloroplasts house chlorophyll pigments.",
            question_type="short_answer",
        )

        assert result.question_grounded is True
        assert result.question_answerable is True
        assert result.question_topic_relevant is True
        assert len(result.supported_facts) == 2
        assert len(result.contradicted_facts) == 0


@pytest.mark.asyncio
async def test_rag_evaluator_contradiction_detection():
    mock_payload = {
        "question": {
            "grounded": True,
            "answerable": True,
            "topic_relevant": True,
            "reason": "Grounded question.",
        },
        "answer": {
            "supported_facts": ["Photosynthesis occurs in chloroplasts"],
            "missing_facts": [],
            "contradicted_facts": ["Occurs in mitochondria"],
            "uncertain_facts": [],
        },
    }

    with patch("app.services.azure_openai.chat_json", new=AsyncMock(return_value=mock_payload)):
        result = await rag_evaluator.evaluate_rag_semantics(
            selected_topic="Photosynthesis",
            retrieved_context="Photosynthesis occurs in chloroplasts.",
            question_body="Where does photosynthesis occur?",
            reference_answer="In mitochondria",
            question_type="short_answer",
        )

        assert result.question_grounded is True
        assert "Occurs in mitochondria" in result.contradicted_facts


@pytest.mark.asyncio
async def test_rag_evaluator_llm_failure_fallback():
    with patch("app.services.azure_openai.chat_json", side_effect=RuntimeError("OpenAI 503")):
        result = await rag_evaluator.evaluate_rag_semantics(
            selected_topic="Cell Biology",
            retrieved_context="Mitochondria produce ATP.",
            question_body="What produces ATP?",
            reference_answer="Mitochondria",
        )

        # Gracefully returns deterministic fallback structure without raising
        assert result.question_grounded is True
        assert "Mitochondria" in result.supported_facts
        assert "fallback" in result.question_reason
