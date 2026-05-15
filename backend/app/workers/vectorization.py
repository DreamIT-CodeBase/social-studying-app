"""Vectorization worker — Sprint 2.9.

Long-running asyncio loop that pulls messages off the ``vectorization``
Service Bus queue, embeds each chunk via Azure OpenAI, and pushes the
result to the tenant's per-tenant Azure AI Search index.

Runs as its own Container App (``ca-vectorizer-{env}``). Same image as the
API; entrypoint is::

    python -m app.workers.vectorization

State machine owned by this worker
----------------------------------
``chunked``         (set by the chunker on the prior stage)
    → ``vectorizing``  (this worker takes lock, embeddings + Search push)
        → ``ready``        (chunks indexed, document done)
        → ``failed``       (permanent: doc record gone, malformed payload)
        → (retry)          (transient: OpenAI 429/503, Search transient)

Permanent vs transient classification
-------------------------------------
``DocumentNotFound`` (the document record was deleted between chunking and
vectorization) is permanent — dead-letter immediately.

Everything else (``ServiceUnavailableError`` from OpenAI / AI Search,
Cosmos transient errors) is transient — abandon and let SB redeliver up to
``maxDeliveryCount`` (3, matches the topic-extraction queue: model calls
are expensive and a doc that fails three times has a structural issue).
"""

from __future__ import annotations

import asyncio
import logging
import os
import signal
import sys
from pathlib import Path


def _bootstrap_env() -> None:
    """Load backend/.env or backend/.env.dev for local development.

    Same trick as the other workers — Container Apps inject env vars, so
    ``os.environ.setdefault`` is a no-op there. Must run BEFORE importing
    ``app.core.config`` so pydantic-settings picks up the values at class
    instantiation time.
    """
    backend_dir = Path(__file__).resolve().parent.parent.parent
    for fname in (".env", ".env.dev"):
        path = backend_dir / fname
        if not path.exists():
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_bootstrap_env()

from app.core.database import DOCUMENTS, get_collection  # noqa: E402
from app.core.exceptions import ServiceUnavailableError  # noqa: E402
from app.models.base import utc_now  # noqa: E402
from app.models.document import DocumentStatus  # noqa: E402
from app.services import vectorization  # noqa: E402
from app.services.vectorization import DocumentNotFound  # noqa: E402
from app.services.vectorization_queue import (  # noqa: E402
    ReceivedVectorizationMessage,
    VectorizationMessage,
    consume_vectorization_messages,
)

logger = logging.getLogger(__name__)


# ── Status writes ────────────────────────────────────────────────────────────


async def _set_status(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    status: DocumentStatus,
    extra: dict[str, object] | None = None,
) -> None:
    """Atomic Cosmos update of the document's status + companion fields."""
    update: dict[str, object] = {"status": status.value, "updated_at": utc_now()}
    if extra:
        update.update(extra)
    col = get_collection(tenant_id, DOCUMENTS)
    result = await col.update_one(
        {"_id": document_id, "workspace_id": workspace_id},
        {"$set": update},
    )
    if result.matched_count == 0:
        logger.warning(
            "Document not found during vectorization status update: "
            "tenant=%s workspace=%s doc=%s",
            tenant_id,
            workspace_id,
            document_id,
        )


async def _mark_failed(payload: VectorizationMessage, reason: str) -> None:
    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.failed,
        extra={
            "processing_error": reason,
            "vectorization_completed_at": utc_now(),
        },
    )


# ── Per-message handler ──────────────────────────────────────────────────────


async def _handle(msg: ReceivedVectorizationMessage) -> None:
    """Process one vectorization request end-to-end."""
    payload = msg.payload
    logger.info(
        "Handling vectorization doc=%s delivery=%d hinted_chunks=%d",
        payload.document_id,
        msg.delivery_count,
        payload.chunk_count,
    )

    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.vectorizing,
        extra={"vectorization_started_at": utc_now()},
    )

    try:
        outcome = await vectorization.vectorize_document(
            tenant_id=payload.tenant_id,
            workspace_id=payload.workspace_id,
            document_id=payload.document_id,
        )
    except DocumentNotFound as exc:
        # Document record was deleted between chunking and vectorization —
        # nothing to embed, no recovery possible.
        await _mark_failed(payload, f"Document not found: {exc}")
        await msg.dead_letter("DocumentNotFound", str(exc))
        return
    except ServiceUnavailableError:
        # Embeddings or Search transient — re-raise so the run loop abandons
        # and Service Bus redelivers.
        raise

    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.ready,
        extra={
            "vector_count": outcome.chunks_indexed,
            "embedding_model": outcome.embedding_model,
            "vectorization_completed_at": utc_now(),
            "processing_error": None,
        },
    )
    logger.info(
        "Vectorization complete doc=%s indexed=%d deleted_stale=%d topics=%d "
        "workspace_missing=%s",
        payload.document_id,
        outcome.chunks_indexed,
        outcome.deleted_stale,
        outcome.topic_ids_resolved,
        outcome.workspace_missing,
    )


# ── Main loop ────────────────────────────────────────────────────────────────


_MAX_DELIVERY = 3  # matches queue maxDeliveryCount in service-bus.bicep


async def run_forever(*, max_wait_seconds: int = 30) -> None:
    """Consume the vectorization queue until cancelled."""
    logger.info("Vectorization worker starting")
    async with consume_vectorization_messages(
        max_wait_seconds=max_wait_seconds
    ) as messages:
        async for msg in messages:
            try:
                await _handle(msg)
                await msg.complete()
            except asyncio.CancelledError:
                logger.warning(
                    "Cancelled while handling doc=%s — abandoning",
                    msg.payload.document_id,
                )
                await msg.abandon()
                raise
            except Exception as exc:
                logger.exception(
                    "Transient failure handling doc=%s delivery=%d: %s",
                    msg.payload.document_id,
                    msg.delivery_count,
                    exc,
                )
                if msg.delivery_count >= _MAX_DELIVERY:
                    await _mark_failed(
                        msg.payload, f"Max retries exceeded: {exc}"
                    )
                await msg.abandon()


def _install_shutdown_handlers(task: asyncio.Task[None]) -> None:
    """Cancel the main task on SIGTERM/SIGINT for clean shutdown."""
    import contextlib

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        # Windows has no signal handlers on the event loop — rely on
        # KeyboardInterrupt for local dev.
        with contextlib.suppress(NotImplementedError):
            loop.add_signal_handler(sig, task.cancel)


async def _amain() -> int:
    task = asyncio.create_task(run_forever())
    _install_shutdown_handlers(task)
    try:
        await task
    except asyncio.CancelledError:
        logger.info("Vectorization worker shut down cleanly")
    return 0


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    return asyncio.run(_amain())


if __name__ == "__main__":
    sys.exit(main())
