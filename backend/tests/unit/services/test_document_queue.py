"""Unit tests for the document_queue service.

Mocks the Service Bus SDK so these run without any Azure connectivity.
"""

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services import document_queue
from app.services.document_queue import (
    ExtractionMessage,
    ReceivedExtractionMessage,
    publish_extraction_message,
)


def _msg(**overrides) -> ExtractionMessage:
    base = dict(
        document_id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        blob_path="ten_abc/wsp_abc/usr_abc/doc_abc/study.pdf",
        content_type="application/pdf",
        uploaded_by="usr_abc",
        uploaded_at="2026-05-08T10:00:00+00:00",
    )
    base.update(overrides)
    return ExtractionMessage(**base)


# ── ExtractionMessage roundtrip ──────────────────────────────────────────────


def test_extraction_message_roundtrip():
    """to_json / from_json must preserve every field."""
    original = _msg()
    decoded = ExtractionMessage.from_json(original.to_json())
    assert decoded == original


def test_extraction_message_from_json_accepts_bytes():
    original = _msg()
    decoded = ExtractionMessage.from_json(original.to_json().encode("utf-8"))
    assert decoded == original


def test_extraction_message_from_json_rejects_missing_field():
    bad = json.dumps(
        {"document_id": "doc_abc"}  # missing the rest
    )
    with pytest.raises(KeyError):
        ExtractionMessage.from_json(bad)


# ── publish_extraction_message ───────────────────────────────────────────────


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
        patch.object(document_queue.settings, "service_bus_connection", "Endpoint=sb://test"),
        patch.object(document_queue.settings, "service_bus_documents_queue", "document-ingestion"),
        patch(
            "app.services.document_queue.ServiceBusClient.from_connection_string",
            return_value=sb_client,
        ),
    ):
        await publish_extraction_message(_msg())

    sb_client.get_queue_sender.assert_called_once_with(queue_name="document-ingestion")
    sender.send_messages.assert_awaited_once()

    # The single positional arg is the ServiceBusMessage we constructed.
    sent = sender.send_messages.await_args.args[0]
    assert sent.message_id == "doc_abc"
    # Body roundtrip: message body bytes → ExtractionMessage matches input.
    body = b"".join(sent.body) if hasattr(sent, "body") else bytes(sent)
    decoded = ExtractionMessage.from_json(body)
    assert decoded == _msg()


@pytest.mark.asyncio
async def test_publish_raises_when_connection_string_missing():
    with patch.object(document_queue.settings, "service_bus_connection", ""):
        with pytest.raises(RuntimeError, match="not configured"):
            await publish_extraction_message(_msg())


# ── ReceivedExtractionMessage ack/abandon/dead-letter ────────────────────────


@pytest.mark.asyncio
async def test_received_message_complete_calls_receiver():
    receiver = MagicMock()
    receiver.complete_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedExtractionMessage(payload=_msg(), delivery_count=1, _receiver=receiver, _raw=raw)
    await rec.complete()
    receiver.complete_message.assert_awaited_once_with(raw)


@pytest.mark.asyncio
async def test_received_message_abandon_calls_receiver():
    receiver = MagicMock()
    receiver.abandon_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedExtractionMessage(payload=_msg(), delivery_count=2, _receiver=receiver, _raw=raw)
    await rec.abandon()
    receiver.abandon_message.assert_awaited_once_with(raw)


@pytest.mark.asyncio
async def test_received_message_dead_letter_passes_reason():
    receiver = MagicMock()
    receiver.dead_letter_message = AsyncMock()
    raw = MagicMock()
    rec = ReceivedExtractionMessage(payload=_msg(), delivery_count=3, _receiver=receiver, _raw=raw)
    await rec.dead_letter("UnsupportedContent", "DOCX is corrupt")
    receiver.dead_letter_message.assert_awaited_once_with(
        raw, reason="UnsupportedContent", error_description="DOCX is corrupt"
    )
