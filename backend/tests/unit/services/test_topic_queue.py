"""Unit tests for the topic_queue service.

Same shape as test_document_queue — mirror-image queue, mirror-image tests.
Service Bus SDK is fully mocked.
"""

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services import topic_queue
from app.services.topic_queue import (
    ReceivedTopicMessage,
    TopicExtractionMessage,
    publish_topic_message,
)


def _msg(**overrides) -> TopicExtractionMessage:
    base = dict(
        document_id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        extracted_text_blob_path="ten_abc/wsp_abc/extracted-text/doc_abc.txt",
    )
    base.update(overrides)
    return TopicExtractionMessage(**base)


# ── TopicExtractionMessage roundtrip ─────────────────────────────────────────


def test_topic_message_roundtrip():
    original = _msg()
    decoded = TopicExtractionMessage.from_json(original.to_json())
    assert decoded == original


def test_topic_message_from_json_accepts_bytes():
    original = _msg()
    decoded = TopicExtractionMessage.from_json(original.to_json().encode("utf-8"))
    assert decoded == original


def test_topic_message_from_json_rejects_missing_field():
    bad = json.dumps({"document_id": "doc_abc"})
    with pytest.raises(KeyError):
        TopicExtractionMessage.from_json(bad)


# ── publish_topic_message ────────────────────────────────────────────────────


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
        patch.object(topic_queue.settings, "service_bus_connection", "Endpoint=sb://test"),
        patch.object(topic_queue.settings, "service_bus_topics_queue", "topic-extraction"),
        patch(
            "app.services.topic_queue.ServiceBusClient.from_connection_string",
            return_value=sb_client,
        ),
    ):
        await publish_topic_message(_msg())

    sb_client.get_queue_sender.assert_called_once_with(queue_name="topic-extraction")
    sender.send_messages.assert_awaited_once()

    sent = sender.send_messages.await_args.args[0]
    assert sent.message_id == "doc_abc"
    body = b"".join(sent.body) if hasattr(sent, "body") else bytes(sent)
    decoded = TopicExtractionMessage.from_json(body)
    assert decoded == _msg()


@pytest.mark.asyncio
async def test_publish_raises_when_connection_string_missing():
    with patch.object(topic_queue.settings, "service_bus_connection", ""):
        with pytest.raises(RuntimeError, match="not configured"):
            await publish_topic_message(_msg())


# ── ReceivedTopicMessage ack/abandon/dead-letter ─────────────────────────────


@pytest.mark.asyncio
async def test_received_message_complete_calls_receiver():
    receiver = MagicMock()
    receiver.complete_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedTopicMessage(payload=_msg(), delivery_count=1, _receiver=receiver, _raw=raw)
    await rec.complete()
    receiver.complete_message.assert_awaited_once_with(raw)


@pytest.mark.asyncio
async def test_received_message_abandon_calls_receiver():
    receiver = MagicMock()
    receiver.abandon_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedTopicMessage(payload=_msg(), delivery_count=2, _receiver=receiver, _raw=raw)
    await rec.abandon()
    receiver.abandon_message.assert_awaited_once_with(raw)


@pytest.mark.asyncio
async def test_received_message_dead_letter_passes_reason():
    receiver = MagicMock()
    receiver.dead_letter_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedTopicMessage(payload=_msg(), delivery_count=3, _receiver=receiver, _raw=raw)
    await rec.dead_letter("PromptFailure", "missing topics key")
    receiver.dead_letter_message.assert_awaited_once_with(
        raw, reason="PromptFailure", error_description="missing topics key"
    )
