"""Service Bus glue for the topic-extraction stage (Sprint 2.5).

Mirrors the shape of ``document_queue.py``. We deliberately keep these two
files as a duplicated pair — when a third pipeline stage (chunking, 2.8)
appears, we'll extract the common bits into a generic helper. Two queues is
not enough to justify the abstraction overhead today.

State arc owned by the topic worker that consumes this queue:

    text_extracted → extracting_topics → topics_extracted | failed
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
class TopicExtractionMessage:
    """Payload handed from the text-extraction worker to the topic worker.

    ``extracted_text_blob_path`` lets the topic worker fetch text directly
    without re-reading the Cosmos document record. Saves one round trip per
    message and keeps the document update non-blocking on the producer side.
    """

    document_id: str
    tenant_id: str
    workspace_id: str
    extracted_text_blob_path: str

    @classmethod
    def from_json(cls, payload: bytes | str) -> TopicExtractionMessage:
        data = json.loads(payload)
        return cls(
            document_id=data["document_id"],
            tenant_id=data["tenant_id"],
            workspace_id=data["workspace_id"],
            extracted_text_blob_path=data["extracted_text_blob_path"],
        )

    def to_json(self) -> str:
        return json.dumps(
            {
                "document_id": self.document_id,
                "tenant_id": self.tenant_id,
                "workspace_id": self.workspace_id,
                "extracted_text_blob_path": self.extracted_text_blob_path,
            }
        )


# ── Publisher ────────────────────────────────────────────────────────────────


async def publish_topic_message(message: TopicExtractionMessage) -> None:
    """Send one topic-extraction message onto the queue.

    Uses ``document_id`` as message_id so any future duplicate-detection
    setting catches re-publish races (e.g. worker retry → status update
    succeeds → enqueue retries succeed).

    Raises:
        RuntimeError: if SERVICE_BUS_CONNECTION is unset.
        azure.core.exceptions.AzureError: from the SDK on transport failures.
    """
    if not settings.service_bus_connection:
        raise RuntimeError("SERVICE_BUS_CONNECTION is not configured — cannot publish.")

    body = message.to_json()
    sb = ServiceBusClient.from_connection_string(settings.service_bus_connection)
    async with sb:
        sender = sb.get_queue_sender(queue_name=settings.service_bus_topics_queue)
        async with sender:
            sb_message = ServiceBusMessage(body, message_id=message.document_id)
            await sender.send_messages(sb_message)
    logger.info(
        "Published topic-extraction message: doc=%s queue=%s",
        message.document_id,
        settings.service_bus_topics_queue,
    )


# ── Consumer ─────────────────────────────────────────────────────────────────


@dataclass
class ReceivedTopicMessage:
    payload: TopicExtractionMessage
    delivery_count: int
    _receiver: ServiceBusReceiver
    _raw: Any

    async def complete(self) -> None:
        await self._receiver.complete_message(self._raw)

    async def abandon(self) -> None:
        await self._receiver.abandon_message(self._raw)

    async def dead_letter(self, reason: str, description: str = "") -> None:
        await self._receiver.dead_letter_message(
            self._raw, reason=reason, error_description=description
        )

    async def renew_lock(self) -> None:
        """Renew the Service Bus message lock to prevent expiry-driven redelivery."""
        await self._receiver.renew_message_lock(self._raw)


@asynccontextmanager
async def consume_topic_messages(
    *,
    max_wait_seconds: int = 30,
) -> AsyncIterator[AsyncIterator[ReceivedTopicMessage]]:
    """Yield topic-extraction messages forever.

    Same contract as ``consume_extraction_messages``: caller MUST call
    exactly one of complete/abandon/dead_letter per message.
    """
    if not settings.service_bus_connection:
        raise RuntimeError("SERVICE_BUS_CONNECTION is not configured — cannot consume.")

    sb = ServiceBusClient.from_connection_string(settings.service_bus_connection)
    async with sb:
        receiver = sb.get_queue_receiver(
            queue_name=settings.service_bus_topics_queue,
            max_wait_time=max_wait_seconds,
        )
        async with receiver:
            yield _iter_received(receiver)


async def _iter_received(
    receiver: ServiceBusReceiver,
) -> AsyncIterator[ReceivedTopicMessage]:
    async for raw in receiver:
        body_bytes = b"".join(raw.body) if hasattr(raw, "body") else bytes(raw)
        try:
            payload = TopicExtractionMessage.from_json(body_bytes)
        except (json.JSONDecodeError, KeyError) as exc:
            logger.error("Malformed topic queue message; dead-lettering: %s", exc)
            await receiver.dead_letter_message(
                raw,
                reason="MalformedPayload",
                error_description=str(exc),
            )
            continue
        yield ReceivedTopicMessage(
            payload=payload,
            delivery_count=raw.delivery_count or 1,
            _receiver=receiver,
            _raw=raw,
        )
