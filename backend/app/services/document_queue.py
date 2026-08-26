"""Service Bus glue for the document ingestion pipeline.

Publishes extraction-request messages from the upload API and yields them to
the worker. Both halves talk to the same ``document-ingestion`` queue. The
worker calls ``consume_extraction_messages`` in a long-running asyncio loop;
the API calls ``publish_extraction_message`` once per upload.

Queue name is fixed via ``settings.service_bus_documents_queue`` so the API and
worker can never disagree about which queue to use.

The Service Bus async SDK is used directly here. The previous-iteration
fallback (sync SDK + asyncio.to_thread) is documented in
``memory/sprint_2_3_decisions.md`` if we hit reliability issues.
"""

from __future__ import annotations

import json
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Any

from azure.servicebus import ServiceBusMessage
from azure.servicebus.aio import ServiceBusClient, ServiceBusReceiver

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class ExtractionMessage:
    """Decoded payload of a document-ingestion queue message.

    Mirrors the dict produced by the publisher. Keep in lockstep — both sides
    must change together.
    """

    document_id: str
    tenant_id: str
    workspace_id: str
    blob_path: str
    content_type: str
    uploaded_by: str
    uploaded_at: str

    @classmethod
    def from_json(cls, payload: bytes | str) -> ExtractionMessage:
        data = json.loads(payload)
        return cls(
            document_id=data["document_id"],
            tenant_id=data["tenant_id"],
            workspace_id=data["workspace_id"],
            blob_path=data["blob_path"],
            content_type=data["content_type"],
            uploaded_by=data["uploaded_by"],
            uploaded_at=data["uploaded_at"],
        )

    def to_json(self) -> str:
        return json.dumps(
            {
                "document_id": self.document_id,
                "tenant_id": self.tenant_id,
                "workspace_id": self.workspace_id,
                "blob_path": self.blob_path,
                "content_type": self.content_type,
                "uploaded_by": self.uploaded_by,
                "uploaded_at": self.uploaded_at,
            }
        )


# ── Publisher ────────────────────────────────────────────────────────────────


async def publish_extraction_message(message: ExtractionMessage) -> None:
    """Send a single message onto the document-ingestion queue.

    Sets ``message_id = document_id`` so Service Bus duplicate detection
    (when the namespace SKU supports it) catches accidental double-publishes
    from retries on the upload path.

    Raises:
        RuntimeError: if SERVICE_BUS_CONNECTION is unset.
        azure.core.exceptions.AzureError: from the SDK on transport failures.
            Caller is responsible for handling these (see
            ``app/api/documents.py`` for the rollback pattern).
    """
    if not settings.service_bus_connection:
        raise RuntimeError("SERVICE_BUS_CONNECTION is not configured — cannot publish.")

    body = message.to_json()
    sb = ServiceBusClient.from_connection_string(settings.service_bus_connection)
    async with sb:
        sender = sb.get_queue_sender(queue_name=settings.service_bus_documents_queue)
        async with sender:
            sb_message = ServiceBusMessage(body, message_id=message.document_id)
            await sender.send_messages(sb_message)
    logger.info(
        "Published extraction message: doc=%s queue=%s",
        message.document_id,
        settings.service_bus_documents_queue,
    )


# ── Consumer ─────────────────────────────────────────────────────────────────


@dataclass
class ReceivedExtractionMessage:
    """A message in flight, plus the handles needed to ack/abandon/dead-letter.

    The worker MUST call exactly one of ``complete()``, ``abandon()``, or
    ``dead_letter()`` per message. Failing to do so leaves the message locked
    until the lock duration (5 min) expires, at which point Service Bus
    redelivers it.
    """

    payload: ExtractionMessage
    delivery_count: int
    _receiver: ServiceBusReceiver
    _raw: Any  # azure.servicebus.aio.ServiceBusReceivedMessage

    async def complete(self) -> None:
        await self._receiver.complete_message(self._raw)

    async def abandon(self) -> None:
        """Release the lock so another delivery attempt can run.

        After ``max_delivery_count`` (5) abandonments, Service Bus moves the
        message to the DLQ automatically.
        """
        await self._receiver.abandon_message(self._raw)

    async def dead_letter(self, reason: str, description: str = "") -> None:
        """Move the message to the dead-letter sub-queue immediately.

        Use for permanent failures (UnsupportedContent, malformed payload)
        where retrying is pointless.
        """
        await self._receiver.dead_letter_message(
            self._raw, reason=reason, error_description=description
        )


@asynccontextmanager
async def consume_extraction_messages(
    *,
    max_wait_seconds: int = 30,
) -> AsyncIterator[AsyncIterator[ReceivedExtractionMessage]]:
    """Yield extraction messages from the document-ingestion queue forever.

    Usage::

        async with consume_extraction_messages() as messages:
            async for msg in messages:
                try:
                    await process(msg.payload)
                    await msg.complete()
                except PermanentError:
                    await msg.dead_letter("permanent")
                except Exception:
                    await msg.abandon()

    The outer context manager owns the underlying ServiceBusClient and
    receiver; cleaning it up closes the AMQP connection cleanly on
    shutdown signals.
    """
    if not settings.service_bus_connection:
        raise RuntimeError("SERVICE_BUS_CONNECTION is not configured — cannot consume.")

    sb = ServiceBusClient.from_connection_string(settings.service_bus_connection)
    async with sb:
        receiver = sb.get_queue_receiver(
            queue_name=settings.service_bus_documents_queue,
            max_wait_time=max_wait_seconds,
        )
        async with receiver:
            yield _iter_received(receiver)


async def _iter_received(
    receiver: ServiceBusReceiver,
) -> AsyncIterator[ReceivedExtractionMessage]:
    async for raw in receiver:
        body_bytes = b"".join(raw.body) if hasattr(raw, "body") else bytes(raw)
        try:
            payload = ExtractionMessage.from_json(body_bytes)
        except (json.JSONDecodeError, KeyError) as exc:
            # Malformed messages can't be retried productively — DLQ them so
            # operators can inspect rather than the worker crashing.
            logger.error("Malformed queue message; dead-lettering: %s", exc)
            await receiver.dead_letter_message(
                raw,
                reason="MalformedPayload",
                error_description=str(exc),
            )
            continue
        yield ReceivedExtractionMessage(
            payload=payload,
            delivery_count=raw.delivery_count or 1,
            _receiver=receiver,
            _raw=raw,
        )
