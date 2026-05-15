"""Service Bus glue for the chunking stage (Sprint 2.8).

Mirrors the shape of ``document_queue.py`` and ``topic_queue.py``. We keep
these three files as a parallel set rather than abstracting into a generic
queue helper — see the Sprint 2.3 memo. The fourth queue (vectorization,
Sprint 2.9) is the trigger to refactor.

State arc owned by the chunker worker that consumes this queue:

    topics_extracted → chunking → chunked | failed
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
class ChunkingMessage:
    """Payload handed from the topic-extraction worker to the chunker.

    ``extracted_text_blob_path`` lets the chunker fetch the text without
    re-reading the document record. ``topic_ids`` carries the doc's full
    canonical-topic id set so every emitted chunk can be tagged without
    a separate workspace lookup — saves one Cosmos read per chunk.
    """

    document_id: str
    tenant_id: str
    workspace_id: str
    extracted_text_blob_path: str
    topic_ids: list[str]

    @classmethod
    def from_json(cls, payload: bytes | str) -> ChunkingMessage:
        data = json.loads(payload)
        return cls(
            document_id=data["document_id"],
            tenant_id=data["tenant_id"],
            workspace_id=data["workspace_id"],
            extracted_text_blob_path=data["extracted_text_blob_path"],
            topic_ids=list(data.get("topic_ids") or []),
        )

    def to_json(self) -> str:
        return json.dumps(
            {
                "document_id": self.document_id,
                "tenant_id": self.tenant_id,
                "workspace_id": self.workspace_id,
                "extracted_text_blob_path": self.extracted_text_blob_path,
                "topic_ids": self.topic_ids,
            }
        )


# ── Publisher ────────────────────────────────────────────────────────────────


async def publish_chunking_message(message: ChunkingMessage) -> None:
    """Send one chunking message onto the queue.

    Uses ``document_id`` as message_id so any future duplicate-detection
    setting catches re-publish races (e.g. topic worker retry → status
    update succeeds → enqueue retries succeed).

    Raises:
        RuntimeError: if SERVICE_BUS_CONNECTION is unset.
        azure.core.exceptions.AzureError: on transport failures. Caller is
            responsible for the rollback pattern (see topic_extraction
            worker — wrap in best-effort try/except).
    """
    if not settings.service_bus_connection:
        raise RuntimeError(
            "SERVICE_BUS_CONNECTION is not configured — cannot publish."
        )

    body = message.to_json()
    sb = ServiceBusClient.from_connection_string(settings.service_bus_connection)
    async with sb:
        sender = sb.get_queue_sender(queue_name=settings.service_bus_chunks_queue)
        async with sender:
            sb_message = ServiceBusMessage(body, message_id=message.document_id)
            await sender.send_messages(sb_message)
    logger.info(
        "Published chunking message: doc=%s queue=%s topics=%d",
        message.document_id,
        settings.service_bus_chunks_queue,
        len(message.topic_ids),
    )


# ── Consumer ─────────────────────────────────────────────────────────────────


@dataclass
class ReceivedChunkingMessage:
    payload: ChunkingMessage
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


@asynccontextmanager
async def consume_chunking_messages(
    *,
    max_wait_seconds: int = 30,
) -> AsyncIterator[AsyncIterator[ReceivedChunkingMessage]]:
    """Yield chunking messages forever.

    Same contract as the other consumers: caller MUST call exactly one of
    complete/abandon/dead_letter per message.
    """
    if not settings.service_bus_connection:
        raise RuntimeError(
            "SERVICE_BUS_CONNECTION is not configured — cannot consume."
        )

    sb = ServiceBusClient.from_connection_string(settings.service_bus_connection)
    async with sb:
        receiver = sb.get_queue_receiver(
            queue_name=settings.service_bus_chunks_queue,
            max_wait_time=max_wait_seconds,
        )
        async with receiver:
            yield _iter_received(receiver)


async def _iter_received(
    receiver: ServiceBusReceiver,
) -> AsyncIterator[ReceivedChunkingMessage]:
    async for raw in receiver:
        body_bytes = b"".join(raw.body) if hasattr(raw, "body") else bytes(raw)
        try:
            payload = ChunkingMessage.from_json(body_bytes)
        except (json.JSONDecodeError, KeyError) as exc:
            logger.error("Malformed chunking queue message; dead-lettering: %s", exc)
            await receiver.dead_letter_message(
                raw,
                reason="MalformedPayload",
                error_description=str(exc),
            )
            continue
        yield ReceivedChunkingMessage(
            payload=payload,
            delivery_count=raw.delivery_count or 1,
            _receiver=receiver,
            _raw=raw,
        )
