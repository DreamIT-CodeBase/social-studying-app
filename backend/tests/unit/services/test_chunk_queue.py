"""Unit tests for app.services.chunk_queue.

Mocks the Service Bus SDK so these run without Azure connectivity.
Mirrors test_topic_queue.py / test_document_queue.py.
"""

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services import chunk_queue
from app.services.chunk_queue import (
    ChunkingMessage,
    ReceivedChunkingMessage,
    publish_chunking_message,
)


def _msg(**overrides) -> ChunkingMessage:
    base = dict(
        document_id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        extracted_text_blob_path="ten_abc/wsp_abc/extracted-text/doc_abc.txt",
        topic_ids=["tpc_one", "tpc_two"],
    )
    base.update(overrides)
    return ChunkingMessage(**base)


# ── ChunkingMessage roundtrip ────────────────────────────────────────────────


def test_chunking_message_roundtrip():
    original = _msg()
    decoded = ChunkingMessage.from_json(original.to_json())
    assert decoded == original


def test_chunking_message_from_json_accepts_bytes():
    original = _msg()
    decoded = ChunkingMessage.from_json(original.to_json().encode("utf-8"))
    assert decoded == original


def test_chunking_message_from_json_rejects_missing_field():
    bad = json.dumps({"document_id": "doc_abc"})  # missing the rest
    with pytest.raises(KeyError):
        ChunkingMessage.from_json(bad)


def test_chunking_message_accepts_empty_topic_ids():
    """v1 hand-off passes [] — see comment in topic_extraction worker."""
    msg = _msg(topic_ids=[])
    decoded = ChunkingMessage.from_json(msg.to_json())
    assert decoded.topic_ids == []


# ── publish_chunking_message ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_publish_sends_one_message_with_doc_id_as_message_id():
    sender = MagicMock()
    sender.send_messages = AsyncMock()
    sender.__aenter__ = AsyncMock(return_value=sender)
    sender.__aexit__ = AsyncMock(return_value=None)

    sb_client = MagicMock()
    sb_client.get_queue_sender = MagicMock(return_value=sender)
    sb_client.__aenter__ = AsyncMock(return_value=sb_client)
    sb_client.__aexit__ = AsyncMock(return_value=None)

    with (
        patch.object(chunk_queue.settings, "service_bus_connection", "Endpoint=sb://test"),
        patch.object(chunk_queue.settings, "service_bus_chunks_queue", "chunking"),
        patch(
            "app.services.chunk_queue.ServiceBusClient.from_connection_string",
            return_value=sb_client,
        ),
    ):
        await publish_chunking_message(_msg())

    sb_client.get_queue_sender.assert_called_once_with(queue_name="chunking")
    sender.send_messages.assert_awaited_once()

    sent = sender.send_messages.await_args.args[0]
    assert sent.message_id == "doc_abc"
    body = b"".join(sent.body) if hasattr(sent, "body") else bytes(sent)
    decoded = ChunkingMessage.from_json(body)
    assert decoded == _msg()


@pytest.mark.asyncio
async def test_publish_raises_when_connection_string_missing():
    with (
        patch.object(chunk_queue.settings, "service_bus_connection", ""),
        pytest.raises(RuntimeError, match="not configured"),
    ):
        await publish_chunking_message(_msg())


# ── ReceivedChunkingMessage ack/abandon/dead-letter ──────────────────────────


@pytest.mark.asyncio
async def test_received_message_complete_calls_receiver():
    receiver = MagicMock()
    receiver.complete_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedChunkingMessage(
        payload=_msg(), delivery_count=1, _receiver=receiver, _raw=raw
    )
    await rec.complete()
    receiver.complete_message.assert_awaited_once_with(raw)


@pytest.mark.asyncio
async def test_received_message_abandon_calls_receiver():
    receiver = MagicMock()
    receiver.abandon_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedChunkingMessage(
        payload=_msg(), delivery_count=2, _receiver=receiver, _raw=raw
    )
    await rec.abandon()
    receiver.abandon_message.assert_awaited_once_with(raw)


@pytest.mark.asyncio
async def test_received_message_dead_letter_passes_reason():
    receiver = MagicMock()
    receiver.dead_letter_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedChunkingMessage(
        payload=_msg(), delivery_count=3, _receiver=receiver, _raw=raw
    )
    await rec.dead_letter("ChunkerInputInvalid", "negative target_chars")
    receiver.dead_letter_message.assert_awaited_once_with(
        raw, reason="ChunkerInputInvalid", error_description="negative target_chars"
    )
