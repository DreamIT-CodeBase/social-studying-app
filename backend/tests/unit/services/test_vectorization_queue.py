"""Unit tests for app.services.vectorization_queue.

Mocks the Service Bus SDK so these run without Azure connectivity.
Mirrors test_chunk_queue.py / test_topic_queue.py / test_document_queue.py.
"""

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services import vectorization_queue
from app.services.vectorization_queue import (
    ReceivedVectorizationMessage,
    VectorizationMessage,
    publish_vectorization_message,
)


def _msg(**overrides) -> VectorizationMessage:
    base = dict(
        document_id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        chunk_count=7,
    )
    base.update(overrides)
    return VectorizationMessage(**base)


# ── VectorizationMessage roundtrip ───────────────────────────────────────────


def test_vectorization_message_roundtrip():
    original = _msg()
    decoded = VectorizationMessage.from_json(original.to_json())
    assert decoded == original


def test_vectorization_message_from_json_accepts_bytes():
    original = _msg()
    decoded = VectorizationMessage.from_json(original.to_json().encode("utf-8"))
    assert decoded == original


def test_vectorization_message_from_json_rejects_missing_field():
    bad = json.dumps({"document_id": "doc_abc"})  # missing tenant/workspace
    with pytest.raises(KeyError):
        VectorizationMessage.from_json(bad)


def test_vectorization_message_defaults_chunk_count_when_missing():
    """Old messages on the queue without chunk_count still parse — default 0."""
    body = json.dumps(
        {
            "document_id": "doc_abc",
            "tenant_id": "ten_abc",
            "workspace_id": "wsp_abc",
        }
    )
    decoded = VectorizationMessage.from_json(body)
    assert decoded.chunk_count == 0


# ── publish_vectorization_message ───────────────────────────────────────────


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
        patch.object(
            vectorization_queue.settings, "service_bus_connection", "Endpoint=sb://test"
        ),
        patch.object(
            vectorization_queue.settings,
            "service_bus_vectorization_queue",
            "vectorization",
        ),
        patch(
            "app.services.vectorization_queue.ServiceBusClient.from_connection_string",
            return_value=sb_client,
        ),
    ):
        await publish_vectorization_message(_msg())

    sb_client.get_queue_sender.assert_called_once_with(queue_name="vectorization")
    sender.send_messages.assert_awaited_once()

    sent = sender.send_messages.await_args.args[0]
    assert sent.message_id == "doc_abc"
    body = b"".join(sent.body) if hasattr(sent, "body") else bytes(sent)
    decoded = VectorizationMessage.from_json(body)
    assert decoded == _msg()


@pytest.mark.asyncio
async def test_publish_raises_when_connection_string_missing():
    with (
        patch.object(vectorization_queue.settings, "service_bus_connection", ""),
        pytest.raises(RuntimeError, match="not configured"),
    ):
        await publish_vectorization_message(_msg())


# ── ReceivedVectorizationMessage ack/abandon/dead-letter ────────────────────


@pytest.mark.asyncio
async def test_received_message_complete_calls_receiver():
    receiver = MagicMock()
    receiver.complete_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedVectorizationMessage(
        payload=_msg(), delivery_count=1, _receiver=receiver, _raw=raw
    )
    await rec.complete()
    receiver.complete_message.assert_awaited_once_with(raw)


@pytest.mark.asyncio
async def test_received_message_abandon_calls_receiver():
    receiver = MagicMock()
    receiver.abandon_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedVectorizationMessage(
        payload=_msg(), delivery_count=2, _receiver=receiver, _raw=raw
    )
    await rec.abandon()
    receiver.abandon_message.assert_awaited_once_with(raw)


@pytest.mark.asyncio
async def test_received_message_dead_letter_passes_reason():
    receiver = MagicMock()
    receiver.dead_letter_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedVectorizationMessage(
        payload=_msg(), delivery_count=3, _receiver=receiver, _raw=raw
    )
    await rec.dead_letter("DocumentNotFound", "doc vanished")
    receiver.dead_letter_message.assert_awaited_once_with(
        raw, reason="DocumentNotFound", error_description="doc vanished"
    )
