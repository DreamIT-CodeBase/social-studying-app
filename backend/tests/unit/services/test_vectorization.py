"""Unit tests for app.services.vectorization.

The orchestrator pulls chunks + workspace from Cosmos, embeds via OpenAI,
and pushes to AI Search. All three IO seams are mocked.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.chunk import Chunk
from app.models.document import Document, DocumentStatus, DocumentType, TopicTag
from app.models.workspace import CanonicalTopic, Taxonomy, Workspace
from app.services import vectorization
from app.services.vectorization import DocumentNotFound


def _document(**overrides) -> Document:
    base = dict(
        id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        uploaded_by="usr_x",
        filename="hist.pdf",
        blob_url="https://blob/x",
        file_size_bytes=1000,
        doc_type=DocumentType.pdf,
        status=DocumentStatus.chunked,
        chunk_count=3,
        topic_tags=[
            TopicTag(name="Photosynthesis", complexity_level=2),
            TopicTag(name="Mitosis", complexity_level=3),
        ],
    )
    base.update(overrides)
    return Document(**base)


def _workspace(**overrides) -> Workspace:
    base = dict(
        id="wsp_abc",
        tenant_id="ten_abc",
        name="Bio 101",
        taxonomy=Taxonomy(
            topics=[
                CanonicalTopic(
                    id="tpc_photo",
                    name="Photosynthesis",
                    aliases=["Photo Synthesis"],
                ),
                CanonicalTopic(
                    id="tpc_mitosis",
                    name="Cell Division",
                    aliases=["Mitosis"],
                ),
                CanonicalTopic(id="tpc_unrelated", name="Calculus"),
            ]
        ),
        taxonomy_version=2,
    )
    base.update(overrides)
    return Workspace(**base)


def _chunk(i: int, **overrides) -> Chunk:
    base = dict(
        id=f"chk_{i}",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        document_id="doc_abc",
        text=f"chunk text {i}",
        chunk_index=i,
        char_start=i * 100,
        char_end=i * 100 + 12,
        char_count=12,
        topic_ids=[],
        chunker_version="v1",
    )
    base.update(overrides)
    return Chunk(**base)


# ── Topic id resolution ─────────────────────────────────────────────────────


def test_resolve_topic_ids_matches_canonical_name_case_insensitive():
    doc = _document(topic_tags=[TopicTag(name="photosynthesis")])
    ws = _workspace()
    out = vectorization._resolve_topic_ids(document=doc, workspace=ws)
    assert out == ["tpc_photo"]


def test_resolve_topic_ids_matches_alias():
    """Mitosis is an alias of Cell Division — should resolve to the canonical id."""
    doc = _document(topic_tags=[TopicTag(name="Mitosis")])
    ws = _workspace()
    out = vectorization._resolve_topic_ids(document=doc, workspace=ws)
    assert out == ["tpc_mitosis"]


def test_resolve_topic_ids_dedupes_resolved_ids():
    """Both name and alias landed on same canonical id → list is unique."""
    doc = _document(
        topic_tags=[
            TopicTag(name="Photosynthesis"),
            TopicTag(name="Photo Synthesis"),  # alias of same canonical
        ]
    )
    ws = _workspace()
    out = vectorization._resolve_topic_ids(document=doc, workspace=ws)
    assert out == ["tpc_photo"]


def test_resolve_topic_ids_drops_unmatched_names():
    doc = _document(topic_tags=[TopicTag(name="Quantum Foam")])
    ws = _workspace()
    out = vectorization._resolve_topic_ids(document=doc, workspace=ws)
    assert out == []


def test_resolve_topic_ids_empty_when_workspace_missing():
    doc = _document()
    out = vectorization._resolve_topic_ids(document=doc, workspace=None)
    assert out == []


def test_resolve_topic_ids_empty_when_taxonomy_empty():
    doc = _document()
    ws = _workspace(taxonomy=Taxonomy(topics=[]))
    out = vectorization._resolve_topic_ids(document=doc, workspace=ws)
    assert out == []


def test_resolve_topic_ids_empty_when_doc_has_no_tags():
    doc = _document(topic_tags=[])
    ws = _workspace()
    out = vectorization._resolve_topic_ids(document=doc, workspace=ws)
    assert out == []


def test_resolve_topic_ids_preserves_order_from_doc():
    doc = _document(
        topic_tags=[
            TopicTag(name="Mitosis"),
            TopicTag(name="Photosynthesis"),
        ]
    )
    ws = _workspace()
    out = vectorization._resolve_topic_ids(document=doc, workspace=ws)
    assert out == ["tpc_mitosis", "tpc_photo"]


# ── _build_index_docs ───────────────────────────────────────────────────────


def test_build_index_docs_zips_chunks_and_vectors():
    chunks = [_chunk(0), _chunk(1), _chunk(2)]
    vectors = [[0.1], [0.2], [0.3]]
    out = vectorization._build_index_docs(
        chunks=chunks,
        vectors=vectors,
        topic_ids=["tpc_photo"],
        embedding_model="text-embedding-3-small",
    )
    assert len(out) == 3
    for i, doc in enumerate(out):
        assert doc["id"] == f"chk_{i}"
        assert doc["chunk_index"] == i
        assert doc["embedding"] == vectors[i]
        assert doc["topic_ids"] == ["tpc_photo"]
        assert doc["embedding_model"] == "text-embedding-3-small"


def test_build_index_docs_length_mismatch_raises():
    chunks = [_chunk(0), _chunk(1)]
    vectors = [[0.1]]  # one short
    with pytest.raises(RuntimeError, match="does not match"):
        vectorization._build_index_docs(
            chunks=chunks,
            vectors=vectors,
            topic_ids=[],
            embedding_model="m",
        )


# ── vectorize_document end-to-end ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_vectorize_document_happy_path():
    doc = _document()
    ws = _workspace()
    chunks = [_chunk(0), _chunk(1)]

    with (
        patch(
            "app.services.vectorization._read_document",
            AsyncMock(return_value=doc),
        ),
        patch(
            "app.services.vectorization._read_workspace",
            AsyncMock(return_value=ws),
        ),
        patch(
            "app.services.vectorization.chunk_storage.find_for_document",
            AsyncMock(return_value=chunks),
        ),
        patch(
            "app.services.vectorization.azure_ai_search.ensure_index",
            AsyncMock(return_value="chunks-ten-abc"),
        ) as mock_ensure,
        patch(
            "app.services.vectorization.azure_ai_search.delete_for_document",
            AsyncMock(return_value=4),
        ) as mock_delete,
        patch(
            "app.services.vectorization.azure_openai.embed_texts",
            AsyncMock(return_value=[[0.1], [0.2]]),
        ) as mock_embed,
        patch(
            "app.services.vectorization.azure_ai_search.upsert_chunks",
            AsyncMock(return_value=2),
        ) as mock_upsert,
    ):
        outcome = await vectorization.vectorize_document(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_abc",
        )

    mock_ensure.assert_awaited_once_with("ten_abc")
    mock_delete.assert_awaited_once_with(tenant_id="ten_abc", document_id="doc_abc")
    mock_embed.assert_awaited_once()
    embed_kwargs = mock_embed.await_args.kwargs
    assert embed_kwargs["texts"] == ["chunk text 0", "chunk text 1"]

    mock_upsert.assert_awaited_once()
    upsert_docs = mock_upsert.await_args.kwargs["documents"]
    assert len(upsert_docs) == 2
    # Resolved canonical topic_ids land on every chunk doc.
    assert all(d["topic_ids"] == ["tpc_photo", "tpc_mitosis"] for d in upsert_docs)

    assert outcome.chunks_read == 2
    assert outcome.chunks_indexed == 2
    assert outcome.deleted_stale == 4
    assert outcome.topic_ids_resolved == 2
    assert outcome.workspace_missing is False
    assert outcome.embedding_model  # non-empty


@pytest.mark.asyncio
async def test_vectorize_document_empty_chunks_skips_embed_and_upsert():
    """A doc with no chunks (cover page) advances cleanly to ready with 0."""
    doc = _document(topic_tags=[])
    ws = _workspace()

    with (
        patch(
            "app.services.vectorization._read_document",
            AsyncMock(return_value=doc),
        ),
        patch(
            "app.services.vectorization._read_workspace",
            AsyncMock(return_value=ws),
        ),
        patch(
            "app.services.vectorization.chunk_storage.find_for_document",
            AsyncMock(return_value=[]),
        ),
        patch(
            "app.services.vectorization.azure_ai_search.ensure_index",
            AsyncMock(return_value="chunks-ten-abc"),
        ),
        patch(
            "app.services.vectorization.azure_ai_search.delete_for_document",
            AsyncMock(return_value=0),
        ),
        patch(
            "app.services.vectorization.azure_openai.embed_texts",
            AsyncMock(),
        ) as mock_embed,
        patch(
            "app.services.vectorization.azure_ai_search.upsert_chunks",
            AsyncMock(),
        ) as mock_upsert,
    ):
        outcome = await vectorization.vectorize_document(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_abc",
        )

    mock_embed.assert_not_awaited()
    mock_upsert.assert_not_awaited()
    assert outcome.chunks_read == 0
    assert outcome.chunks_indexed == 0


@pytest.mark.asyncio
async def test_vectorize_document_workspace_missing_still_indexes_without_topics():
    """If workspace was deleted, vectorize anyway with empty topic_ids."""
    doc = _document()
    chunks = [_chunk(0)]

    with (
        patch(
            "app.services.vectorization._read_document",
            AsyncMock(return_value=doc),
        ),
        patch(
            "app.services.vectorization._read_workspace",
            AsyncMock(return_value=None),  # workspace gone
        ),
        patch(
            "app.services.vectorization.chunk_storage.find_for_document",
            AsyncMock(return_value=chunks),
        ),
        patch(
            "app.services.vectorization.azure_ai_search.ensure_index",
            AsyncMock(return_value="chunks-ten-abc"),
        ),
        patch(
            "app.services.vectorization.azure_ai_search.delete_for_document",
            AsyncMock(return_value=0),
        ),
        patch(
            "app.services.vectorization.azure_openai.embed_texts",
            AsyncMock(return_value=[[0.1]]),
        ),
        patch(
            "app.services.vectorization.azure_ai_search.upsert_chunks",
            AsyncMock(return_value=1),
        ) as mock_upsert,
    ):
        outcome = await vectorization.vectorize_document(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_abc",
        )

    upsert_docs = mock_upsert.await_args.kwargs["documents"]
    assert upsert_docs[0]["topic_ids"] == []
    assert outcome.workspace_missing is True
    assert outcome.topic_ids_resolved == 0
    assert outcome.chunks_indexed == 1


@pytest.mark.asyncio
async def test_vectorize_document_missing_doc_raises_documentnotfound():
    with patch(
        "app.services.vectorization._read_document",
        AsyncMock(return_value=None),
    ):
        with pytest.raises(DocumentNotFound):
            await vectorization.vectorize_document(
                tenant_id="ten_abc",
                workspace_id="wsp_abc",
                document_id="doc_gone",
            )
