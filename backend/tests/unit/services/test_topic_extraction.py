"""Unit tests for app.services.topic_extraction.

Mock azure_openai.chat_json so tests are offline. We verify: empty
short-circuit, JSON-shape coercion, dedup, page_refs sanitization,
complexity clamping, schema-error handling, truncation.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.services import topic_extraction

# ── Empty short-circuit ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_empty_text_returns_empty_list_without_api_call():
    with patch("app.services.topic_extraction.azure_openai.chat_json") as mock_chat:
        result = await topic_extraction.extract_topics("")
    assert result == []
    mock_chat.assert_not_called()


@pytest.mark.asyncio
async def test_whitespace_text_returns_empty_list_without_api_call():
    with patch("app.services.topic_extraction.azure_openai.chat_json") as mock_chat:
        result = await topic_extraction.extract_topics("   \n\t  ")
    assert result == []
    mock_chat.assert_not_called()


# ── Happy path: well-formed model output ─────────────────────────────────────


@pytest.mark.asyncio
async def test_extracts_well_formed_topics():
    response = {
        "topics": [
            {
                "name": "Photosynthesis",
                "description": "Plants converting sunlight to energy.",
                "complexity_level": 2,
                "page_refs": [1, 3],
            },
            {
                "name": "Cellular Respiration",
                "description": "Energy release in cells.",
                "complexity_level": 3,
                "page_refs": [5],
            },
        ]
    }
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("biology textbook")

    assert len(topics) == 2
    assert topics[0].name == "Photosynthesis"
    assert topics[0].complexity_level == 2
    assert topics[0].page_refs == [1, 3]
    assert topics[0].description == "Plants converting sunlight to energy."
    assert topics[0].source == "ai"
    assert topics[0].confidence == 1.0


# ── Dedup ────────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_deduplicates_topic_names_case_insensitive():
    response = {
        "topics": [
            {"name": "Photosynthesis", "complexity_level": 2},
            {"name": "photosynthesis", "complexity_level": 5},
            {"name": "Mitosis", "complexity_level": 3},
        ]
    }
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("text")

    names = [t.name for t in topics]
    assert names == ["Photosynthesis", "Mitosis"]


# ── Field coercion / clamping ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_clamps_complexity_to_one_to_five():
    response = {
        "topics": [
            {"name": "TooLow", "complexity_level": 0},
            {"name": "TooHigh", "complexity_level": 99},
            {"name": "JustRight", "complexity_level": 3},
        ]
    }
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("text")

    by_name = {t.name: t for t in topics}
    assert by_name["TooLow"].complexity_level == 1
    assert by_name["TooHigh"].complexity_level == 5
    assert by_name["JustRight"].complexity_level == 3


@pytest.mark.asyncio
async def test_string_complexity_coerced_to_int():
    response = {"topics": [{"name": "X", "complexity_level": "3"}]}
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("text")
    assert topics[0].complexity_level == 3


@pytest.mark.asyncio
async def test_unparseable_complexity_drops_to_none():
    response = {"topics": [{"name": "X", "complexity_level": "high"}]}
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("text")
    assert topics[0].complexity_level is None


@pytest.mark.asyncio
async def test_page_refs_sanitized():
    response = {
        "topics": [
            {
                "name": "X",
                "page_refs": [1, "3", "not-a-page", 0, -5, 7],
            }
        ]
    }
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("text")
    # Strings that parse as ints survive; non-int strings and non-positive
    # numbers are dropped (page numbers are 1-indexed).
    assert topics[0].page_refs == [1, 3, 7]


@pytest.mark.asyncio
async def test_empty_topic_name_dropped():
    response = {
        "topics": [
            {"name": "", "complexity_level": 2},
            {"name": "  ", "complexity_level": 2},
            {"name": "Valid", "complexity_level": 2},
        ]
    }
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("text")
    assert [t.name for t in topics] == ["Valid"]


@pytest.mark.asyncio
async def test_missing_optional_fields_default_correctly():
    response = {"topics": [{"name": "OnlyName"}]}
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("text")
    t = topics[0]
    assert t.name == "OnlyName"
    assert t.description is None
    assert t.complexity_level is None
    assert t.page_refs == []


# ── Schema error handling ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_missing_topics_key_raises_value_error():
    """Model returned valid JSON but wrong schema — surface as ValueError so
    the worker dead-letters rather than silently producing no topics."""
    response = {"things": []}
    with (
        patch(
            "app.services.topic_extraction.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
        pytest.raises(ValueError, match="missing 'topics'"),
    ):
        await topic_extraction.extract_topics("text")


@pytest.mark.asyncio
async def test_topics_not_a_list_raises_value_error():
    response = {"topics": "Photosynthesis"}
    with (
        patch(
            "app.services.topic_extraction.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
        pytest.raises(ValueError),
    ):
        await topic_extraction.extract_topics("text")


@pytest.mark.asyncio
async def test_non_dict_rows_are_skipped():
    response = {"topics": ["just-a-string", {"name": "Real"}, 42]}
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("text")
    assert [t.name for t in topics] == ["Real"]


# ── Truncation ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_long_text_is_truncated_to_settings_budget(monkeypatch):
    monkeypatch.setattr(topic_extraction.settings, "openai_topic_extraction_max_input_chars", 100)
    long_text = "X" * 5_000

    captured: dict[str, str] = {}

    async def _fake_chat(**kwargs):
        captured["user_prompt"] = kwargs["user_prompt"]
        return {"topics": []}

    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(side_effect=_fake_chat),
    ):
        await topic_extraction.extract_topics(long_text)

    # The user prompt should contain ≤100 X's worth of source — well below
    # 5,000. We don't need to measure precisely, just confirm truncation
    # happened.
    assert captured["user_prompt"].count("X") <= 100


# ── Empty-but-valid response ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_empty_topics_list_returns_empty():
    """Cover-page documents: prompt says return [], we accept it."""
    response = {"topics": []}
    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(return_value=response),
    ):
        topics = await topic_extraction.extract_topics("table of contents page")
    assert topics == []


# ── Length-aware extraction guidance (< 2K, > 3K, 2K-3K) ─────────────────────


@pytest.mark.asyncio
async def test_short_file_under_2k_chars_uses_granular_guidance():
    short_text = (
        "Photosynthesis occurs in chloroplasts. Chlorophyll absorbs sunlight. "
        "Light reactions produce ATP and NADPH. Calvin cycle fixes CO2 into glucose."
    )
    assert len(short_text) < 2000

    captured: dict[str, str] = {}

    async def _fake_chat(**kwargs):
        captured["system_prompt"] = kwargs["system_prompt"]
        captured["user_prompt"] = kwargs["user_prompt"]
        return {"topics": [{"name": "Photosynthesis Light Reactions", "complexity_level": 2}]}

    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(side_effect=_fake_chat),
    ):
        topics = await topic_extraction.extract_topics(short_text)

    assert len(topics) == 1
    assert "GRANULAR EXTRACTION" in captured["system_prompt"]
    assert "< 2,000 characters" in captured["system_prompt"]
    assert "Photosynthesis occurs in chloroplasts" in captured["user_prompt"]


@pytest.mark.asyncio
async def test_large_file_over_3k_chars_uses_whole_document_main_topics_guidance():
    sections = [
        f"Chapter {i}: Core Unit {i}\n" + ("This is detailed curriculum content for section. " * 30)
        for i in range(1, 5)
    ]
    long_text = "\n\n".join(sections)
    assert len(long_text) > 3000

    captured: dict[str, str] = {}

    async def _fake_chat(**kwargs):
        captured["system_prompt"] = kwargs["system_prompt"]
        captured["user_prompt"] = kwargs["user_prompt"]
        return {"topics": [{"name": "Core Unit 1", "complexity_level": 3}]}

    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(side_effect=_fake_chat),
    ):
        topics = await topic_extraction.extract_topics(long_text)

    assert len(topics) == 1
    assert "WHOLE-DOCUMENT ANALYSIS" in captured["system_prompt"]
    assert "MAIN TOPICS ONLY" in captured["system_prompt"]
    assert "> 3,000 characters" in captured["system_prompt"]
    # Check that it read wholly through (both beginning Chapter 1 and end Chapter 4 are present)
    assert "Chapter 1" in captured["user_prompt"]
    assert "Chapter 4" in captured["user_prompt"]


@pytest.mark.asyncio
async def test_medium_file_between_2k_and_3k_chars_uses_balanced_guidance():
    medium_text = "A" * 2500
    captured: dict[str, str] = {}

    async def _fake_chat(**kwargs):
        captured["system_prompt"] = kwargs["system_prompt"]
        return {"topics": []}

    with patch(
        "app.services.topic_extraction.azure_openai.chat_json",
        AsyncMock(side_effect=_fake_chat),
    ):
        await topic_extraction.extract_topics(medium_text)

    assert "BALANCED EXTRACTION" in captured["system_prompt"]
    assert "2,000 - 3,000 characters" in captured["system_prompt"]
