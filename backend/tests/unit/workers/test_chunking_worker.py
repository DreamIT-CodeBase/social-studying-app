"""Unit tests for the chunking worker handler.

Each test exercises one branch of the state machine in
``app.workers.chunking._handle``. Service Bus, blob storage, the text
chunker, chunk storage, and Cosmos are all mocked.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from azure.core.exceptions import ResourceNotFoundError

from app.models.document import DocumentStatus
from app.services.chunk_queue import ChunkingMessage, ReceivedChunkingMessage
from app.services.text_chunker import TextChunk
from app.workers import chunking as worker


def _payload(**overrides) -> ChunkingMessage:
    base = dict(
        document_id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        extracted_text_blob_path="ten_abc/wsp_abc/extracted-text/doc_abc.txt",
        topic_ids=[],
    )
    base.update(overrides)
    return ChunkingMessage(**base)


def _msg(payload=None, delivery_count=1) -> ReceivedChunkingMessage:
    return ReceivedChunkingMessage(
        payload=payload or _payload(),
        delivery_count=delivery_count,
        _receiver=MagicMock(),
        _raw=MagicMock(),
    )


def _mock_collection():
    col = MagicMock()
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    return col


def _raw_chunks(n: int = 3) -> list[TextChunk]:
    return [
        TextChunk(
            text=f"chunk text {i}",
            chunk_index=i,
            char_start=i * 100,
            char_end=i * 100 + 12,
        )
        for i in range(n)
    ]


# ── Happy path ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_handle_happy_path_persists_chunks_and_advances_status():
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.chunking.get_collection", return_value=col),
        patch(
            "app.workers.chunking.blob_storage.download_extracted_text",
            AsyncMock(return_value="long body text"),
        ) as mock_download,
        patch(
            "app.workers.chunking.text_chunker.chunk_text",
            return_value=_raw_chunks(3),
        ) as mock_chunker,
        patch(
            "app.workers.chunking.chunk_storage.replace_chunks",
            AsyncMock(return_value=3),
        ) as mock_replace,
        patch(
            "app.workers.chunking.publish_vectorization_message",
            AsyncMock(),
        ) as mock_publish_vec,
    ):
        await worker._handle(msg)

    mock_download.assert_awaited_once_with(msg.payload.extracted_text_blob_path)
    mock_chunker.assert_called_once_with("long body text")

    # replace_chunks called with the three Chunks built from raw output.
    mock_replace.assert_awaited_once()
    kwargs = mock_replace.await_args.kwargs
    assert kwargs["tenant_id"] == "ten_abc"
    assert kwargs["document_id"] == "doc_abc"
    assert len(kwargs["chunks"]) == 3
    for built in kwargs["chunks"]:
        assert built.document_id == "doc_abc"
        assert built.workspace_id == "wsp_abc"
        assert built.tenant_id == "ten_abc"
        assert built.chunker_version == "v1"

    # Status transitions: chunking → chunked.
    statuses = [call.args[1]["$set"]["status"] for call in col.update_one.await_args_list]
    assert statuses == [DocumentStatus.chunking.value, DocumentStatus.chunked.value]

    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert final_update["chunk_count"] == 3
    assert "chunking_completed_at" in final_update
    assert final_update["processing_error"] is None

    # Sprint 2.9 — handoff to vectorizer with the chunk count.
    mock_publish_vec.assert_awaited_once()
    vec_msg = mock_publish_vec.await_args.args[0]
    assert vec_msg.document_id == "doc_abc"
    assert vec_msg.tenant_id == "ten_abc"
    assert vec_msg.workspace_id == "wsp_abc"
    assert vec_msg.chunk_count == 3


# ── Topic ids propagate to chunks ────────────────────────────────────────────


@pytest.mark.asyncio
async def test_handle_propagates_topic_ids_onto_every_chunk():
    msg = _msg(_payload(topic_ids=["tpc_a", "tpc_b"]))
    col = _mock_collection()

    with (
        patch("app.workers.chunking.get_collection", return_value=col),
        patch(
            "app.workers.chunking.blob_storage.download_extracted_text",
            AsyncMock(return_value="text"),
        ),
        patch(
            "app.workers.chunking.text_chunker.chunk_text",
            return_value=_raw_chunks(2),
        ),
        patch(
            "app.workers.chunking.chunk_storage.replace_chunks",
            AsyncMock(return_value=2),
        ) as mock_replace,
        patch(
            "app.workers.chunking.publish_vectorization_message",
            AsyncMock(),
        ),
    ):
        await worker._handle(msg)

    built = mock_replace.await_args.kwargs["chunks"]
    assert all(c.topic_ids == ["tpc_a", "tpc_b"] for c in built)


# ── Empty chunker output still completes successfully ────────────────────────


@pytest.mark.asyncio
async def test_handle_empty_chunker_output_still_advances():
    """A cover-page doc → chunker returns [] → status still flips to chunked
    with chunk_count=0. Lets the pipeline keep moving for degenerate inputs."""
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.chunking.get_collection", return_value=col),
        patch(
            "app.workers.chunking.blob_storage.download_extracted_text",
            AsyncMock(return_value=""),
        ),
        patch(
            "app.workers.chunking.text_chunker.chunk_text",
            return_value=[],
        ),
        patch(
            "app.workers.chunking.chunk_storage.replace_chunks",
            AsyncMock(return_value=0),
        ),
        patch(
            "app.workers.chunking.publish_vectorization_message",
            AsyncMock(),
        ) as mock_publish_vec,
    ):
        await worker._handle(msg)

    statuses = [call.args[1]["$set"]["status"] for call in col.update_one.await_args_list]
    assert statuses[-1] == DocumentStatus.chunked.value
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert final_update["chunk_count"] == 0

    # Even with zero chunks, the handoff still fires — vectorizer will
    # short-circuit to ready with vector_count=0.
    mock_publish_vec.assert_awaited_once()
    assert mock_publish_vec.await_args.args[0].chunk_count == 0


# ── Permanent failure: blob missing → DLQ + status=failed ────────────────────


@pytest.mark.asyncio
async def test_handle_blob_not_found_marks_failed_and_dead_letters():
    msg = _msg()
    msg._receiver.dead_letter_message = AsyncMock()
    col = _mock_collection()

    with (
        patch("app.workers.chunking.get_collection", return_value=col),
        patch(
            "app.workers.chunking.blob_storage.download_extracted_text",
            AsyncMock(side_effect=ResourceNotFoundError("blob gone")),
        ),
    ):
        await worker._handle(msg)

    msg._receiver.dead_letter_message.assert_awaited_once()
    statuses = [call.args[1]["$set"]["status"] for call in col.update_one.await_args_list]
    assert statuses == [DocumentStatus.chunking.value, DocumentStatus.failed.value]
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert "Extracted text blob not found" in final_update["processing_error"]


# ── Permanent failure: chunker ValueError → DLQ ──────────────────────────────


@pytest.mark.asyncio
async def test_handle_chunker_value_error_marks_failed_and_dead_letters():
    """A misconfigured chunker (negative target_chars) raises ValueError —
    retrying with the same config won't help, so dead-letter."""
    msg = _msg()
    msg._receiver.dead_letter_message = AsyncMock()
    col = _mock_collection()

    with (
        patch("app.workers.chunking.get_collection", return_value=col),
        patch(
            "app.workers.chunking.blob_storage.download_extracted_text",
            AsyncMock(return_value="text"),
        ),
        patch(
            "app.workers.chunking.text_chunker.chunk_text",
            side_effect=ValueError("target_chars must be positive"),
        ),
    ):
        await worker._handle(msg)

    msg._receiver.dead_letter_message.assert_awaited_once()
    statuses = [call.args[1]["$set"]["status"] for call in col.update_one.await_args_list]
    assert statuses[-1] == DocumentStatus.failed.value
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert "Chunker rejected input" in final_update["processing_error"]


# ── Transient failure: Cosmos write fails → propagates ──────────────────────


@pytest.mark.asyncio
async def test_handle_transient_cosmos_failure_propagates():
    """A transient Cosmos failure during replace_chunks must propagate so
    Service Bus redelivers."""
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.chunking.get_collection", return_value=col),
        patch(
            "app.workers.chunking.blob_storage.download_extracted_text",
            AsyncMock(return_value="text"),
        ),
        patch(
            "app.workers.chunking.text_chunker.chunk_text",
            return_value=_raw_chunks(1),
        ),
        patch(
            "app.workers.chunking.chunk_storage.replace_chunks",
            AsyncMock(side_effect=RuntimeError("Cosmos timeout")),
        ),
        pytest.raises(RuntimeError),
    ):
        await worker._handle(msg)

    # We set status=chunking but never advanced to chunked — SB will redeliver.
    statuses = [call.args[1]["$set"]["status"] for call in col.update_one.await_args_list]
    assert statuses == [DocumentStatus.chunking.value]


# ── Sprint 2.9 — vectorization handoff failure is retried ───────────────────


@pytest.mark.asyncio
async def test_handle_vectorization_handoff_failure_propagates_for_retry():
    """A publish outage must not silently strand a chunked document."""
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.chunking.get_collection", return_value=col),
        patch(
            "app.workers.chunking.blob_storage.download_extracted_text",
            AsyncMock(return_value="text"),
        ),
        patch(
            "app.workers.chunking.text_chunker.chunk_text",
            return_value=_raw_chunks(2),
        ),
        patch(
            "app.workers.chunking.chunk_storage.replace_chunks",
            AsyncMock(return_value=2),
        ),
        patch(
            "app.workers.chunking.publish_vectorization_message",
            AsyncMock(side_effect=RuntimeError("SB unreachable")),
        ),
        pytest.raises(RuntimeError, match="SB unreachable"),
    ):
        await worker._handle(msg)

    statuses = [call.args[1]["$set"]["status"] for call in col.update_one.await_args_list]
    assert statuses[-1] == DocumentStatus.chunked.value
