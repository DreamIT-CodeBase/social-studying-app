"""Unit tests for app.services.azure_ai_search.

The real Azure AI Search SDKs are mocked end-to-end. We verify:
- index name sanitization (tenant_id -> Search-legal name)
- ensure_index idempotency (cache hit, ResourceExistsError, 409)
- ensure_index credential gating
- upsert_chunks happy path + partial-failure handling + empty input
- delete_for_document search-then-delete dance + index-not-found tolerance
- chunk_to_index_doc shape preservation
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from azure.core.exceptions import (
    HttpResponseError,
    ResourceExistsError,
    ResourceNotFoundError,
)

from app.core.exceptions import ServiceUnavailableError
from app.services import azure_ai_search


@pytest.fixture(autouse=True)
def _clear_index_cache():
    """Each test starts with an empty `_KNOWN_INDEXES` cache."""
    azure_ai_search._KNOWN_INDEXES.clear()
    yield
    azure_ai_search._KNOWN_INDEXES.clear()


# ── Naming ──────────────────────────────────────────────────────────────────


def test_index_name_for_lowercases_and_replaces_underscores(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_chunks_index_prefix", "chunks")
    assert azure_ai_search.index_name_for("ten_ABC123") == "chunks-ten-abc123"


def test_index_name_for_uses_configured_prefix(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_chunks_index_prefix", "study-chunks")
    assert azure_ai_search.index_name_for("ten_xyz") == "study-chunks-ten-xyz"


# ── ensure_index ────────────────────────────────────────────────────────────


def _patched_index_client(create_side_effect=None):
    client = MagicMock()
    client.create_index = AsyncMock(side_effect=create_side_effect)
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    return patch.object(azure_ai_search, "_index_client", return_value=client), client


@pytest.mark.asyncio
async def test_ensure_index_creates_when_missing(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    patched, client = _patched_index_client()
    with patched:
        name = await azure_ai_search.ensure_index("ten_abc")
    assert name == azure_ai_search.index_name_for("ten_abc")
    client.create_index.assert_awaited_once()


@pytest.mark.asyncio
async def test_ensure_index_caches_after_first_call(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    patched, client = _patched_index_client()
    with patched:
        await azure_ai_search.ensure_index("ten_abc")
        await azure_ai_search.ensure_index("ten_abc")
    # Second call should hit the cache, not the SDK.
    assert client.create_index.await_count == 1


@pytest.mark.asyncio
async def test_ensure_index_treats_resource_exists_as_success(monkeypatch):
    """Concurrent worker won the create race — that's success, not an error."""
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    patched, client = _patched_index_client(create_side_effect=ResourceExistsError("already there"))
    with patched:
        name = await azure_ai_search.ensure_index("ten_abc")
    assert name == azure_ai_search.index_name_for("ten_abc")
    assert name in azure_ai_search._KNOWN_INDEXES


@pytest.mark.asyncio
async def test_ensure_index_treats_409_http_error_as_success(monkeypatch):
    """Some SDK paths raise HttpResponseError(409) instead of ResourceExistsError."""
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    err = HttpResponseError(message="conflict")
    err.status_code = 409
    patched, _ = _patched_index_client(create_side_effect=err)
    with patched:
        name = await azure_ai_search.ensure_index("ten_abc")
    assert name == azure_ai_search.index_name_for("ten_abc")


@pytest.mark.asyncio
async def test_ensure_index_treats_resource_name_already_in_use_as_success(monkeypatch):
    """GA 12.x SDK on search API 2026-04-01 reports an existing index as
    HttpResponseError(400, code='ResourceNameAlreadyInUse'), NOT 409. The
    old 409-only check mistook this for a fatal error and dead-lettered every
    document after a tenant's first upload — stranding vectorization. Treat
    it as success.
    """
    from types import SimpleNamespace

    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    err = HttpResponseError(
        message="Cannot create index 'chunks-ten-abc' because it already exists."
    )
    err.status_code = 400
    err.error = SimpleNamespace(code="ResourceNameAlreadyInUse")
    patched, _ = _patched_index_client(create_side_effect=err)
    with patched:
        name = await azure_ai_search.ensure_index("ten_abc")
    assert name == azure_ai_search.index_name_for("ten_abc")
    assert name in azure_ai_search._KNOWN_INDEXES


@pytest.mark.asyncio
async def test_ensure_index_propagates_non_409_http_error(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    err = HttpResponseError(message="server boom")
    err.status_code = 500
    patched, _ = _patched_index_client(create_side_effect=err)
    with patched, pytest.raises(ServiceUnavailableError, match="Could not create"):
        await azure_ai_search.ensure_index("ten_abc")
    assert azure_ai_search.index_name_for("ten_abc") not in azure_ai_search._KNOWN_INDEXES


@pytest.mark.asyncio
async def test_ensure_index_raises_when_credentials_missing(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "")
    with pytest.raises(ServiceUnavailableError):
        await azure_ai_search.ensure_index("ten_abc")


# ── upsert_chunks ───────────────────────────────────────────────────────────


def _patched_data_client(*, upload_results=None, search_results=None, delete_results=None):
    client = MagicMock()
    if upload_results is not None:
        client.merge_or_upload_documents = AsyncMock(return_value=upload_results)
    if delete_results is not None:
        client.delete_documents = AsyncMock(return_value=delete_results)
    if search_results is not None:
        # search() returns an awaitable yielding an async iterator.
        async def fake_search(**_kwargs):
            async def gen():
                for r in search_results:
                    yield r

            return gen()

        client.search = AsyncMock(side_effect=fake_search)
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    return patch.object(azure_ai_search, "_data_client", return_value=client), client


def _success(key: str = "chk_x"):
    r = MagicMock()
    r.succeeded = True
    r.key = key
    return r


def _failure(key: str = "chk_x", error: str = "boom"):
    r = MagicMock()
    r.succeeded = False
    r.key = key
    r.error_message = error
    return r


@pytest.mark.asyncio
async def test_upsert_chunks_returns_success_count(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    docs = [{"id": "chk_a"}, {"id": "chk_b"}]
    patched, client = _patched_data_client(upload_results=[_success("chk_a"), _success("chk_b")])
    with patched:
        n = await azure_ai_search.upsert_chunks(tenant_id="ten_x", documents=docs)
    assert n == 2
    client.merge_or_upload_documents.assert_awaited_once_with(documents=docs)


@pytest.mark.asyncio
async def test_upsert_chunks_empty_input_short_circuits(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    patched, client = _patched_data_client(upload_results=[])
    with patched:
        n = await azure_ai_search.upsert_chunks(tenant_id="ten_x", documents=[])
    assert n == 0
    client.merge_or_upload_documents.assert_not_awaited()


@pytest.mark.asyncio
async def test_upsert_chunks_partial_failure_raises(monkeypatch):
    """If even one doc in a batch fails, the whole call raises so SB redelivers."""
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    patched, _ = _patched_data_client(upload_results=[_success("chk_a"), _failure("chk_b", "rate")])
    with patched, pytest.raises(ServiceUnavailableError, match="1/2 succeeded"):
        await azure_ai_search.upsert_chunks(
            tenant_id="ten_x",
            documents=[{"id": "chk_a"}, {"id": "chk_b"}],
        )


@pytest.mark.asyncio
async def test_upsert_chunks_http_error_raises_service_unavailable(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    err = HttpResponseError(message="503")
    err.status_code = 503
    client = MagicMock()
    client.merge_or_upload_documents = AsyncMock(side_effect=err)
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    with patch.object(azure_ai_search, "_data_client", return_value=client):
        with pytest.raises(ServiceUnavailableError, match="upsert failed"):
            await azure_ai_search.upsert_chunks(tenant_id="ten_x", documents=[{"id": "chk_a"}])


# ── delete_for_document ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_delete_for_document_searches_then_deletes(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    search_hits = [{"id": "chk_a"}, {"id": "chk_b"}, {"id": "chk_c"}]
    patched, client = _patched_data_client(
        search_results=search_hits,
        delete_results=[_success("chk_a"), _success("chk_b"), _success("chk_c")],
    )
    with patched:
        n = await azure_ai_search.delete_for_document(tenant_id="ten_x", document_id="doc_abc")
    assert n == 3
    # delete_documents got the ids extracted from the search.
    client.delete_documents.assert_awaited_once()
    delete_args = client.delete_documents.await_args.kwargs["documents"]
    assert delete_args == [
        {"id": "chk_a"},
        {"id": "chk_b"},
        {"id": "chk_c"},
    ]
    # Filter included an OData clause on document_id.
    search_kwargs = client.search.await_args.kwargs
    assert "doc_abc" in search_kwargs["filter"]
    assert search_kwargs["select"] == ["id"]


@pytest.mark.asyncio
async def test_delete_for_document_empty_search_skips_delete(monkeypatch):
    """No matches → no delete call, return 0."""
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    patched, client = _patched_data_client(search_results=[], delete_results=[])
    with patched:
        n = await azure_ai_search.delete_for_document(tenant_id="ten_x", document_id="doc_abc")
    assert n == 0
    client.delete_documents.assert_not_awaited()


@pytest.mark.asyncio
async def test_delete_for_document_index_not_found_returns_zero(monkeypatch):
    """First-time vectorization for a tenant: index doesn't exist yet — no error."""
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    client = MagicMock()
    client.search = AsyncMock(side_effect=ResourceNotFoundError("no index"))
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    with patch.object(azure_ai_search, "_data_client", return_value=client):
        n = await azure_ai_search.delete_for_document(tenant_id="ten_x", document_id="doc_abc")
    assert n == 0


@pytest.mark.asyncio
async def test_delete_for_document_404_http_error_returns_zero(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    err = HttpResponseError(message="not found")
    err.status_code = 404
    client = MagicMock()
    client.search = AsyncMock(side_effect=err)
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    with patch.object(azure_ai_search, "_data_client", return_value=client):
        n = await azure_ai_search.delete_for_document(tenant_id="ten_x", document_id="doc_abc")
    assert n == 0


@pytest.mark.asyncio
async def test_delete_for_document_partial_failure_raises(monkeypatch):
    monkeypatch.setattr(azure_ai_search.settings, "search_endpoint", "https://x")
    monkeypatch.setattr(azure_ai_search.settings, "search_key", "k")
    patched, _ = _patched_data_client(
        search_results=[{"id": "chk_a"}, {"id": "chk_b"}],
        delete_results=[_success("chk_a"), _failure("chk_b")],
    )
    with patched, pytest.raises(ServiceUnavailableError, match="1/2 succeeded"):
        await azure_ai_search.delete_for_document(tenant_id="ten_x", document_id="doc_abc")


# ── chunk_to_index_doc ──────────────────────────────────────────────────────


def test_chunk_to_index_doc_shape_matches_schema():
    out = azure_ai_search.chunk_to_index_doc(
        chunk_id="chk_1",
        tenant_id="ten_x",
        workspace_id="wsp_y",
        document_id="doc_z",
        chunk_index=4,
        text="hello",
        topic_ids=["tpc_a", "tpc_b"],
        chunker_version="v1",
        embedding_model="text-embedding-3-small",
        embedding=[0.1, 0.2, 0.3],
        created_at="2026-05-15T00:00:00+00:00",
    )
    assert out == {
        "id": "chk_1",
        "tenant_id": "ten_x",
        "workspace_id": "wsp_y",
        "document_id": "doc_z",
        "chunk_index": 4,
        "text": "hello",
        "topic_ids": ["tpc_a", "tpc_b"],
        "chunker_version": "v1",
        "embedding_model": "text-embedding-3-small",
        "embedding": [0.1, 0.2, 0.3],
        "created_at": "2026-05-15T00:00:00+00:00",
    }


def test_chunk_to_index_doc_materializes_topic_ids_iterable():
    """Generator inputs must end up as a list (Search rejects generators)."""
    out = azure_ai_search.chunk_to_index_doc(
        chunk_id="chk_1",
        tenant_id="ten_x",
        workspace_id="wsp_y",
        document_id="doc_z",
        chunk_index=0,
        text="t",
        topic_ids=(t for t in ["tpc_a", "tpc_b"]),
        chunker_version="v1",
        embedding_model="m",
        embedding=[],
        created_at="2026-05-15T00:00:00+00:00",
    )
    assert out["topic_ids"] == ["tpc_a", "tpc_b"]


# ── _escape_odata ───────────────────────────────────────────────────────────


def test_escape_odata_doubles_single_quotes():
    assert azure_ai_search._escape_odata("o'reilly") == "o''reilly"


def test_escape_odata_passthrough_when_safe():
    assert azure_ai_search._escape_odata("doc_abc123") == "doc_abc123"


# ── search_chunks (Sprint 3.5) ──────────────────────────────────────────────


class _AsyncIter:
    """Async-iterable stand-in for the SDK's paged search results."""

    def __init__(self, rows: list[dict]):
        self._rows = rows

    def __aiter__(self):
        async def _gen():
            for r in self._rows:
                yield r

        return _gen()


def _hit(idx: int, score: float = 1.0, doc: str = "doc_a") -> dict:
    """Build a fake AI Search hit. The ``@search.score`` key is what the
    SDK actually returns for relevance — our search_chunks reader must
    project it onto RetrievedChunk.score.
    """
    return {
        "id": f"chk_{idx}",
        "chunk_index": idx,
        "document_id": doc,
        "text": f"chunk {idx}",
        "topic_ids": [f"tpc_{idx}"],
        "@search.score": score,
    }


def _client_returning(rows: list[dict]):
    """Build a mock SearchClient that ``_data_client`` will hand back.

    The client is used as an async context manager (``async with``),
    then ``.search(**kwargs)`` returns the async iterable of rows.
    """
    client = MagicMock()
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    client.search = AsyncMock(return_value=_AsyncIter(rows))
    return client


@pytest.mark.asyncio
async def test_search_chunks_returns_empty_when_no_query_inputs():
    """No text and no vector = refuse to wildcard-search the index.
    The tool layer (Sprint 3.5) already short-circuits this case, but
    the service must also be safe to call directly.
    """
    out = await azure_ai_search.search_chunks(tenant_id="ten_a", workspace_id="wsp_a")
    assert out == []


@pytest.mark.asyncio
async def test_search_chunks_text_only_runs_bm25_and_projects_score():
    rows = [_hit(0, score=0.7), _hit(1, score=0.55)]
    client = _client_returning(rows)
    with patch("app.services.azure_ai_search._data_client", return_value=client):
        result = await azure_ai_search.search_chunks(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            query_text="newton",
            top_k=4,
        )

    client.search.assert_awaited_once()
    kwargs = client.search.await_args.kwargs
    assert kwargs["search_text"] == "newton"
    assert "vector_queries" not in kwargs
    assert kwargs["top"] == 4
    assert kwargs["filter"] == "workspace_id eq 'wsp_a'"
    assert [c.chunk_id for c in result] == ["chk_0", "chk_1"]
    assert result[0].score == 0.7


@pytest.mark.asyncio
async def test_search_chunks_topic_filter_uses_or_composition():
    """Two topic_ids → OData ``topic_ids/any(t: t eq '..' or t eq '..')``."""
    client = _client_returning([])
    with patch("app.services.azure_ai_search._data_client", return_value=client):
        await azure_ai_search.search_chunks(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            topic_ids=["tpc_1", "tpc_2"],
            query_text="x",
        )

    flt = client.search.await_args.kwargs["filter"]
    assert flt.startswith("workspace_id eq 'wsp_a'")
    assert "topic_ids/any(t:" in flt
    assert "t eq 'tpc_1'" in flt
    assert "t eq 'tpc_2'" in flt
    assert " or " in flt


@pytest.mark.asyncio
async def test_search_chunks_hybrid_passes_vector_query_to_sdk():
    client = _client_returning([_hit(0)])
    vec = [0.1, 0.2, 0.3]
    with patch("app.services.azure_ai_search._data_client", return_value=client):
        await azure_ai_search.search_chunks(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            query_text="x",
            query_vector=vec,
            top_k=3,
        )

    kwargs = client.search.await_args.kwargs
    assert "vector_queries" in kwargs
    vq = kwargs["vector_queries"][0]
    assert list(vq.vector) == vec
    assert vq.fields == "embedding"
    # Lock the k-NN kwarg name. The production code constructs a *real*
    # VectorizedQuery (the import is not mocked), so an SDK that doesn't
    # accept this kwarg raises TypeError right here — which is exactly the
    # 500 that hit /questions/next and /flashcards/next when the image ran
    # GA 12.x while the code passed the beta-only ``k=``. Asserting the
    # value (not just presence) also catches the 11.7.0bX silent-drop,
    # where ``k_nearest_neighbors`` was accepted but ignored.
    assert vq.k_nearest_neighbors == 3


@pytest.mark.asyncio
async def test_search_chunks_returns_empty_on_index_not_found():
    """A workspace whose chunks index hasn't been created yet is the
    normal "empty workspace" state. Don't propagate as an error.
    """
    client = MagicMock()
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    client.search = AsyncMock(side_effect=ResourceNotFoundError("no index"))
    with patch("app.services.azure_ai_search._data_client", return_value=client):
        out = await azure_ai_search.search_chunks(
            tenant_id="ten_a", workspace_id="wsp_a", query_text="x"
        )
    assert out == []


@pytest.mark.asyncio
async def test_search_chunks_treats_404_http_error_as_empty():
    """Some SDK paths surface "index not found" as an HttpResponseError
    with status_code=404 rather than ResourceNotFoundError. Handle both
    paths the same way.
    """
    err = HttpResponseError(message="not found")
    err.status_code = 404
    client = MagicMock()
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    client.search = AsyncMock(side_effect=err)
    with patch("app.services.azure_ai_search._data_client", return_value=client):
        out = await azure_ai_search.search_chunks(
            tenant_id="ten_a", workspace_id="wsp_a", query_text="x"
        )
    assert out == []


@pytest.mark.asyncio
async def test_search_chunks_wraps_other_http_errors_as_service_unavailable():
    """Non-404 transport failures should be retryable from the caller's
    point of view — surface as ServiceUnavailableError so the worker /
    endpoint layer can decide whether to retry or fail the request.
    """
    err = HttpResponseError(message="500 internal")
    err.status_code = 500
    client = MagicMock()
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=False)
    client.search = AsyncMock(side_effect=err)
    with (
        patch("app.services.azure_ai_search._data_client", return_value=client),
        pytest.raises(ServiceUnavailableError),
    ):
        await azure_ai_search.search_chunks(tenant_id="ten_a", workspace_id="wsp_a", query_text="x")


# ── _build_filter ───────────────────────────────────────────────────────────


def test_build_filter_workspace_only():
    assert (
        azure_ai_search._build_filter(workspace_id="wsp_a", topic_ids=[])
        == "workspace_id eq 'wsp_a'"
    )


def test_build_filter_escapes_workspace_quote():
    f = azure_ai_search._build_filter(workspace_id="wsp_o'reilly", topic_ids=[])
    assert "'wsp_o''reilly'" in f


def test_build_filter_with_topics_uses_or_composition():
    f = azure_ai_search._build_filter(workspace_id="wsp_a", topic_ids=["tpc_1", "tpc_2"])
    assert f == ("workspace_id eq 'wsp_a' and topic_ids/any(t: t eq 'tpc_1' or t eq 'tpc_2')")
