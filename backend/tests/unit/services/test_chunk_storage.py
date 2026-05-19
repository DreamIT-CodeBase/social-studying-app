"""Unit tests for app.services.chunk_storage.

Cosmos is mocked. We verify the two operations preserve invariants:
- ``replace_chunks`` always deletes by document_id before inserting.
- ``replace_chunks`` skips the insert when given an empty list (but still wipes).
- ``replace_chunks`` assigns a chk_ id when one isn't provided.
- ``count_for_document`` filters by document_id (partition-key locality).
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.chunk import Chunk
from app.services import chunk_storage


def _chunk(**overrides) -> Chunk:
    base = dict(
        id="chk_pre_filled",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        document_id="doc_abc",
        text="hello world",
        chunk_index=0,
        char_start=0,
        char_end=11,
        char_count=11,
        topic_ids=["tpc_a"],
        chunker_version="v1",
    )
    base.update(overrides)
    return Chunk(**base)


def _mock_collection(*, deleted: int = 0, inserted_count: int = 0) -> MagicMock:
    col = MagicMock()
    col.delete_many = AsyncMock(return_value=MagicMock(deleted_count=deleted))
    col.insert_many = AsyncMock(
        return_value=MagicMock(inserted_ids=[f"chk_{i}" for i in range(inserted_count)])
    )
    col.count_documents = AsyncMock(return_value=0)
    return col


# ── replace_chunks: happy path ───────────────────────────────────────────────


@pytest.mark.asyncio
async def test_replace_chunks_deletes_then_inserts():
    col = _mock_collection(deleted=5, inserted_count=3)
    chunks = [_chunk(chunk_index=i, id=f"chk_{i}") for i in range(3)]

    with patch("app.services.chunk_storage.get_collection", return_value=col):
        inserted = await chunk_storage.replace_chunks(
            tenant_id="ten_abc",
            document_id="doc_abc",
            chunks=chunks,
        )

    col.delete_many.assert_awaited_once_with({"document_id": "doc_abc"})
    col.insert_many.assert_awaited_once()
    docs = col.insert_many.await_args.args[0]
    assert len(docs) == 3
    assert all(d["document_id"] == "doc_abc" for d in docs)
    assert inserted == 3


@pytest.mark.asyncio
async def test_replace_chunks_empty_list_still_wipes_but_skips_insert():
    """Re-chunking an empty input should still clean out old rows."""
    col = _mock_collection(deleted=7)

    with patch("app.services.chunk_storage.get_collection", return_value=col):
        inserted = await chunk_storage.replace_chunks(
            tenant_id="ten_abc",
            document_id="doc_abc",
            chunks=[],
        )

    col.delete_many.assert_awaited_once_with({"document_id": "doc_abc"})
    col.insert_many.assert_not_awaited()
    assert inserted == 0


@pytest.mark.asyncio
async def test_replace_chunks_assigns_id_when_missing():
    """A Chunk with id='' should get a fresh chk_<uuid> before insert."""
    col = _mock_collection(inserted_count=1)
    chunk = _chunk(id="")
    with patch("app.services.chunk_storage.get_collection", return_value=col):
        await chunk_storage.replace_chunks(
            tenant_id="ten_abc",
            document_id="doc_abc",
            chunks=[chunk],
        )
    docs = col.insert_many.await_args.args[0]
    assert docs[0]["_id"].startswith("chk_")
    assert docs[0]["_id"] != ""


@pytest.mark.asyncio
async def test_replace_chunks_preserves_provided_id():
    col = _mock_collection(inserted_count=1)
    chunk = _chunk(id="chk_explicit")
    with patch("app.services.chunk_storage.get_collection", return_value=col):
        await chunk_storage.replace_chunks(
            tenant_id="ten_abc",
            document_id="doc_abc",
            chunks=[chunk],
        )
    docs = col.insert_many.await_args.args[0]
    assert docs[0]["_id"] == "chk_explicit"


# ── count_for_document ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_count_for_document_filters_by_document_id():
    col = _mock_collection()
    col.count_documents = AsyncMock(return_value=42)

    with patch("app.services.chunk_storage.get_collection", return_value=col):
        n = await chunk_storage.count_for_document(
            tenant_id="ten_abc", document_id="doc_abc"
        )

    assert n == 42
    col.count_documents.assert_awaited_once_with({"document_id": "doc_abc"})


# ── find_for_document ──────────────────────────────────────────────────────


class _FakeCursor:
    """Tiny async-iterable stand-in for motor's find() cursor.

    We can't use AsyncMock here because the real cursor's `.sort(...)`
    returns the cursor itself (so the chain is `find(...).sort(...)` →
    iterable). Mirroring that shape keeps the tests honest.
    """

    def __init__(self, docs: list[dict]):
        self._docs = docs
        self.sort_called_with: tuple | None = None

    def sort(self, key: str, direction: int) -> "_FakeCursor":
        self.sort_called_with = (key, direction)
        return self

    def __aiter__(self):
        async def gen():
            for doc in self._docs:
                yield doc

        return gen()


@pytest.mark.asyncio
async def test_find_for_document_returns_chunks_sorted_by_index():
    """Sort happens CLIENT-SIDE — Cosmos MongoDB rejects $sort without an
    explicit index on chunk_index, so the service does the ordering after
    pulling the unsorted batch. Feed the fake an out-of-order list to
    verify the ordering is enforced by the service, not by the cursor.
    """
    raw_docs = [
        {**_chunk(chunk_index=i, id=f"chk_{i}").model_dump(by_alias=True)}
        for i in (2, 0, 1)
    ]
    cursor = _FakeCursor(raw_docs)
    col = MagicMock()
    col.find = MagicMock(return_value=cursor)

    with patch("app.services.chunk_storage.get_collection", return_value=col):
        chunks = await chunk_storage.find_for_document(
            tenant_id="ten_abc", document_id="doc_abc"
        )

    col.find.assert_called_once_with({"document_id": "doc_abc"})
    # The service must NOT call cursor.sort() — Cosmos would reject it.
    assert cursor.sort_called_with is None
    assert [c.id for c in chunks] == ["chk_0", "chk_1", "chk_2"]
    assert all(c.document_id == "doc_abc" for c in chunks)


@pytest.mark.asyncio
async def test_find_for_document_returns_empty_list_when_no_chunks():
    cursor = _FakeCursor([])
    col = MagicMock()
    col.find = MagicMock(return_value=cursor)

    with patch("app.services.chunk_storage.get_collection", return_value=col):
        chunks = await chunk_storage.find_for_document(
            tenant_id="ten_abc", document_id="doc_missing"
        )

    assert chunks == []
