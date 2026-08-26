"""Unit tests for the flashcard generation service (Sprint 3.12).

Tighter contract than the question generator — no per-type branches,
no difficulty calibration, no option-list validation. Three checks
cover the contract:

1. Happy path: GPT-4o returns the expected JSON shape → GeneratedFlashcard.
2. Insufficient-source sentinel → InsufficientFlashcardSource raised.
3. Missing required field → FlashcardShapeError raised.

Plus prompt-variable substitution: topic + source + seen_cards all
land in the user prompt the SDK receives.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.mcp_tools.retrieve_content import RetrievedChunk
from app.services import flashcard_generation
from app.services.flashcard_generation import (
    FlashcardShapeError,
    GeneratedFlashcard,
    InsufficientFlashcardSource,
    generate_flashcard,
)


def _chunk(text: str | None = None) -> RetrievedChunk:
    return RetrievedChunk(
        chunk_id="chk_0",
        chunk_index=0,
        document_id="doc_a",
        text=text or "Photosynthesis converts sunlight into chemical energy.",
        topic_ids=["tpc_photo"],
        score=0.9,
    )


def _mock_chat(response: dict):
    mock = AsyncMock(return_value=response)
    return patch.object(flashcard_generation.azure_openai, "chat_json", mock), mock


# ── Happy path ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_happy_path_returns_generated_flashcard():
    response = {
        "front": "What is photosynthesis?",
        "back": "The process by which plants convert sunlight to chemical energy.",
        "explanation": "Occurs in chloroplasts using chlorophyll to capture photons.",
    }
    patched, mock = _mock_chat(response)
    with patched:
        result = await generate_flashcard(
            topic="Photosynthesis",
            grounding_chunks=[_chunk()],
        )

    assert isinstance(result, GeneratedFlashcard)
    assert result.front == "What is photosynthesis?"
    assert result.back.startswith("The process")
    assert "chloroplasts" in result.explanation
    assert result.prompt_version == "flashcard_v1"

    user_prompt = mock.await_args.kwargs["user_prompt"]
    assert "Photosynthesis" in user_prompt
    # Source content bled through.
    assert "chemical energy" in user_prompt


@pytest.mark.asyncio
async def test_strips_whitespace_around_fields():
    response = {
        "front": "  What is ATP?  ",
        "back": "\nThe primary energy currency of the cell.\n",
        "explanation": " Cells store and transfer energy via ATP.\n",
    }
    patched, _ = _mock_chat(response)
    with patched:
        result = await generate_flashcard(
            topic="Cellular Energy",
            grounding_chunks=[_chunk(text="ATP is the energy currency.")],
        )
    assert result.front == "What is ATP?"
    assert result.back == "The primary energy currency of the cell."
    assert result.explanation == "Cells store and transfer energy via ATP."


# ── Insufficient source ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_insufficient_source_sentinel_raises_insufficient_flashcard_source():
    patched, _ = _mock_chat({"insufficient_source": True})
    with patched, pytest.raises(InsufficientFlashcardSource):
        await generate_flashcard(
            topic="Quantum Field Theory",
            grounding_chunks=[_chunk(text="Plants like sunlight.")],
        )


@pytest.mark.asyncio
async def test_empty_grounding_chunks_raises_immediately():
    """Refusing to call GPT-4o without source material — same rule as
    the question generator. The model would invent grounding from its
    training set otherwise, and we want every card anchored to the
    workspace's actual material.
    """
    with (
        patch.object(flashcard_generation.azure_openai, "chat_json", AsyncMock()) as mock_call,
        pytest.raises(InsufficientFlashcardSource, match="No grounding chunks"),
    ):
        await generate_flashcard(
            topic="Anything",
            grounding_chunks=[],
        )
    mock_call.assert_not_awaited()


# ── Shape errors ───────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_missing_front_raises_shape_error():
    response = {
        "back": "An answer.",
        "explanation": "Some context.",
    }
    patched, _ = _mock_chat(response)
    with patched, pytest.raises(FlashcardShapeError, match="'front'"):
        await generate_flashcard(
            topic="X",
            grounding_chunks=[_chunk()],
        )


@pytest.mark.asyncio
async def test_empty_back_raises_shape_error():
    response = {
        "front": "Q?",
        "back": "   ",  # whitespace-only counts as empty
        "explanation": "ctx",
    }
    patched, _ = _mock_chat(response)
    with patched, pytest.raises(FlashcardShapeError, match="'back'"):
        await generate_flashcard(
            topic="X",
            grounding_chunks=[_chunk()],
        )


@pytest.mark.asyncio
async def test_missing_explanation_does_not_raise_shape_error():
    response = {
        "front": "Q?",
        "back": "A",
    }
    patched, _ = _mock_chat(response)
    with patched:
        result = await generate_flashcard(
            topic="X",
            grounding_chunks=[_chunk()],
        )
    assert result.explanation == ""


# ── Prompt-variable substitution ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_prompt_substitutes_topic_source_and_seen_cards():
    response = {
        "front": "Q?",
        "back": "A.",
        "explanation": "ctx.",
    }
    patched, mock = _mock_chat(response)
    with patched:
        await generate_flashcard(
            topic="Cellular Respiration",
            grounding_chunks=[
                _chunk(text="Glycolysis breaks glucose into pyruvate."),
                _chunk(text="The Krebs cycle produces NADH and CO2."),
            ],
            seen_card_fronts=[
                "What is glycolysis?",
                "Where does the Krebs cycle occur?",
            ],
        )

    user_prompt = mock.await_args.kwargs["user_prompt"]
    assert "Cellular Respiration" in user_prompt
    assert "[Source 1]" in user_prompt
    assert "[Source 2]" in user_prompt
    assert "Glycolysis" in user_prompt
    assert "Krebs cycle" in user_prompt
    assert "- What is glycolysis?" in user_prompt
    assert "- Where does the Krebs cycle occur?" in user_prompt


@pytest.mark.asyncio
async def test_no_seen_cards_renders_none_placeholder():
    response = {
        "front": "Q?",
        "back": "A.",
        "explanation": "ctx.",
    }
    patched, mock = _mock_chat(response)
    with patched:
        await generate_flashcard(
            topic="X",
            grounding_chunks=[_chunk()],
        )
    assert "(none)" in mock.await_args.kwargs["user_prompt"]
