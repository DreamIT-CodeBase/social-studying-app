"""Service Bus glue for the vectorization stage (Sprint 2.9).

Mirrors the shape of ``document_queue.py`` / ``topic_queue.py`` /
``chunk_queue.py``. Per the sprint_2_9_decisions memo we deferred the
"refactor into a generic queue helper" call — four parallel files is loud
but lets each stage's payload diverge without coupling.

State arc owned by the vectorizer worker that consumes this queue:

    chunked → vectorizing → ready | failed
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
class VectorizationMessage:
    """Payload handed from the chunker worker to the vectorizer.

    No blob path — the vectorizer reads chunks straight from Cosmos via
    ``chunk_storage.find_for_document``. ``chunk_count`` is a sanity hint
    for logging and lets the worker fast-path a "no chunks → ready"
    transition without an unnecessary chunk read.
    """

    document_id: str
    tenant_id: str
    workspace_id: str
    chunk_count: int

    @classmethod
    def from_json(cls, payload: bytes | str) -> VectorizationMessage:
        data = json.loads(payload)
        return cls(
            document_id=data["document_id"],
            tenant_id=data["tenant_id"],
            workspace_id=data["workspace_id"],
            chunk_count=int(data.get("chunk_count") or 0),
        )

    def to_json(self) -> str:
        return json.dumps(
            {
                "document_id": self.document_id,
                "tenant_id": self.tenant_id,
                "workspace_id": self.workspace_id,
                "chunk_count": self.chunk_count,
            }
        )


# ── Publisher ────────────────────────────────────────────────────────────────


async def publish_vectorization_message(message: VectorizationMessage) -> None:
    """Send one vectorization message onto the queue.

    Uses ``document_id`` as message_id so any future duplicate-detection
    setting catches re-publish races (e.g. chunker worker retry → status
    update succeeds → enqueue retries succeed).

    Raises:
        RuntimeError: if SERVICE_BUS_CONNECTION is unset.
        azure.core.exceptions.AzureError: on transport failures. Caller is
            responsible for the rollback pattern (see chunking worker —
            wrap in best-effort try/except).
    """
    if not settings.service_bus_connection:
        raise RuntimeError("SERVICE_BUS_CONNECTION is not configured — cannot publish.")

    body = message.to_json()
    sb = ServiceBusClient.from_connection_string(settings.service_bus_connection)
    async with sb:
        sender = sb.get_queue_sender(queue_name=settings.service_bus_vectorization_queue)
        async with sender:
            sb_message = ServiceBusMessage(body, message_id=message.document_id)
            await sender.send_messages(sb_message)
    logger.info(
        "Published vectorization message: doc=%s queue=%s chunks=%d",
        message.document_id,
        settings.service_bus_vectorization_queue,
        message.chunk_count,
    )


# ── Consumer ─────────────────────────────────────────────────────────────────


@dataclass
class ReceivedVectorizationMessage:
    payload: VectorizationMessage
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
async def consume_vectorization_messages(
    *,
    max_wait_seconds: int = 30,
) -> AsyncIterator[AsyncIterator[ReceivedVectorizationMessage]]:
    """Yield vectorization messages forever.

    Same contract as the other consumers: caller MUST call exactly one of
    complete / abandon / dead_letter per message.
    """
    if not settings.service_bus_connection:
        raise RuntimeError("SERVICE_BUS_CONNECTION is not configured — cannot consume.")

    sb = ServiceBusClient.from_connection_string(settings.service_bus_connection)
    async with sb:
        receiver = sb.get_queue_receiver(
            queue_name=settings.service_bus_vectorization_queue,
            max_wait_time=max_wait_seconds,
        )
        async with receiver:
            yield _iter_received(receiver)


async def _iter_received(
    receiver: ServiceBusReceiver,
) -> AsyncIterator[ReceivedVectorizationMessage]:
    async for raw in receiver:
        body_bytes = b"".join(raw.body) if hasattr(raw, "body") else bytes(raw)
        try:
            payload = VectorizationMessage.from_json(body_bytes)
        except (json.JSONDecodeError, KeyError) as exc:
            logger.error("Malformed vectorization queue message; dead-lettering: %s", exc)
            await receiver.dead_letter_message(
                raw,
                reason="MalformedPayload",
                error_description=str(exc),
            )
            continue
        yield ReceivedVectorizationMessage(
            payload=payload,
            delivery_count=raw.delivery_count or 1,
            _receiver=receiver,
            _raw=raw,
        )
