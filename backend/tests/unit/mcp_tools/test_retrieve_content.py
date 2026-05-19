"""Unit tests for the retrieve_content MCP tool (Sprint 3.5).

The tool delegates to two service seams (azure_openai embeddings + Azure
AI Search). All three branches of the search-mode discriminator are
covered: hybrid (text + vector), text-only (embed-fallback OR no
embedding), and topic-only (wildcard text + topic filter).
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.core.exceptions import ServiceUnavailableError
from app.mcp_tools.retrieve_content import (
    RetrieveContentInput,
    RetrieveContentOutput,
    retrieve_content,
)
from app.services.azure_ai_search import RetrievedChunk as ServiceChunk


def _service_chunk(idx: int, score: float = 1.0, doc: str = "doc_a") -> ServiceChunk:
    return ServiceChunk(
        chunk_id=f"chk_{idx}",
        chunk_index=idx,
        document_id=doc,
        text=f"chunk {idx} text",
        topic_ids=[f"tpc_{idx}"],
        score=score,
    )


# ── Hybrid (text + vector) ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_hybrid_search_embeds_query_and_calls_search_with_vector():
    params = RetrieveContentInput(
        tenant_id="ten_a",
        workspace_id="wsp_a",
        topic_ids=["tpc_1"],
        query_text="how does photosynthesis work",
        top_k=3,
    )
    embed_vector = [0.1] * 8

    with (
        patch(
            "app.mcp_tools.retrieve_content.azure_openai.embed_texts",
            AsyncMock(return_value=[embed_vector]),
        ) as mock_embed,
        patch(
            "app.mcp_tools.retrieve_content.azure_ai_search.search_chunks",
            AsyncMock(
                return_value=[
                    _service_chunk(0, score=0.95),
                    _service_chunk(1, score=0.78),
                ]
            ),
        ) as mock_search,
    ):
        result = await retrieve_content(params)

    mock_embed.assert_awaited_once_with(texts=["how does photosynthesis work"])
    # Vector is forwarded; text path is also populated → hybrid in Azure.
    call_kwargs = mock_search.await_args.kwargs
    assert call_kwargs["tenant_id"] == "ten_a"
    assert call_kwargs["workspace_id"] == "wsp_a"
    assert call_kwargs["topic_ids"] == ["tpc_1"]
    assert call_kwargs["query_text"] == "how does photosynthesis work"
    assert call_kwargs["query_vector"] == embed_vector
    assert call_kwargs["top_k"] == 3

    assert isinstance(result, RetrieveContentOutput)
    assert result.mode == "hybrid"
    assert [c.chunk_id for c in result.chunks] == ["chk_0", "chk_1"]
    assert result.chunks[0].score == 0.95


# ── Embedding fallback: 503 from OpenAI doesn't kill retrieval ──────────────


@pytest.mark.asyncio
async def test_embedding_failure_falls_back_to_text_only_mode():
    params = RetrieveContentInput(
        tenant_id="ten_a",
        workspace_id="wsp_a",
        query_text="newtons laws",
    )

    with (
        patch(
            "app.mcp_tools.retrieve_content.azure_openai.embed_texts",
            AsyncMock(side_effect=ServiceUnavailableError("oai down")),
        ),
        patch(
            "app.mcp_tools.retrieve_content.azure_ai_search.search_chunks",
            AsyncMock(return_value=[_service_chunk(0)]),
        ) as mock_search,
    ):
        result = await retrieve_content(params)

    # BM25 is still attempted (text is provided, vector is None).
    call_kwargs = mock_search.await_args.kwargs
    assert call_kwargs["query_text"] == "newtons laws"
    assert call_kwargs["query_vector"] is None
    assert result.mode == "text"
    assert len(result.chunks) == 1


# ── Topic-only retrieval: no query_text, just a topic filter ────────────────


@pytest.mark.asyncio
async def test_topic_only_search_uses_wildcard_text_and_filter():
    """Topic-only retrieval still hits AI Search, but uses a wildcard
    ``*`` text query so the index doesn't reject a filter-only request.
    Embedding service must NOT be called.
    """
    params = RetrieveContentInput(
        tenant_id="ten_a",
        workspace_id="wsp_a",
        topic_ids=["tpc_photo", "tpc_resp"],
        query_text=None,
        top_k=4,
    )

    with (
        patch(
            "app.mcp_tools.retrieve_content.azure_openai.embed_texts",
            AsyncMock(),
        ) as mock_embed,
        patch(
            "app.mcp_tools.retrieve_content.azure_ai_search.search_chunks",
            AsyncMock(return_value=[_service_chunk(0), _service_chunk(1)]),
        ) as mock_search,
    ):
        result = await retrieve_content(params)

    mock_embed.assert_not_awaited()
    call_kwargs = mock_search.await_args.kwargs
    assert call_kwargs["topic_ids"] == ["tpc_photo", "tpc_resp"]
    assert call_kwargs["query_text"] == "*"
    assert "query_vector" not in call_kwargs  # topic-only path uses positional default
    assert result.mode == "text"
    assert [c.chunk_id for c in result.chunks] == ["chk_0", "chk_1"]


# ── No inputs at all → empty, no Azure calls ────────────────────────────────


@pytest.mark.asyncio
async def test_empty_inputs_returns_empty_without_calling_services():
    """Refusing to wildcard-search the index keeps callers honest. If the
    Learning Path Engine forgets to populate a topic or query, retrieval
    must surface an empty result, NOT every chunk in the workspace.
    """
    params = RetrieveContentInput(
        tenant_id="ten_a",
        workspace_id="wsp_a",
    )

    with (
        patch(
            "app.mcp_tools.retrieve_content.azure_openai.embed_texts",
            AsyncMock(),
        ) as mock_embed,
        patch(
            "app.mcp_tools.retrieve_content.azure_ai_search.search_chunks",
            AsyncMock(),
        ) as mock_search,
    ):
        result = await retrieve_content(params)

    mock_embed.assert_not_awaited()
    mock_search.assert_not_awaited()
    assert result.mode == "empty"
    assert result.chunks == []


# ── Search returns nothing — tool still produces a clean output ─────────────


@pytest.mark.asyncio
async def test_no_hits_returns_empty_chunks_list_with_mode_preserved():
    """When the index has docs but none match, the response should still
    report the mode that ran (hybrid vs text) so the caller can decide
    whether to broaden the query.
    """
    params = RetrieveContentInput(
        tenant_id="ten_a",
        workspace_id="wsp_a",
        query_text="something with no matches",
    )

    with (
        patch(
            "app.mcp_tools.retrieve_content.azure_openai.embed_texts",
            AsyncMock(return_value=[[0.0] * 8]),
        ),
        patch(
            "app.mcp_tools.retrieve_content.azure_ai_search.search_chunks",
            AsyncMock(return_value=[]),
        ),
    ):
        result = await retrieve_content(params)

    assert result.mode == "hybrid"
    assert result.chunks == []
