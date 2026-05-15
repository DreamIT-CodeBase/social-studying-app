"""Chunking worker — Sprint 2.8.

Long-running asyncio loop that pulls messages off the ``chunking`` Service
Bus queue, splits the document's extracted text into ~500-token overlapping
chunks, and writes them to the ``chunks`` Cosmos collection.

Runs as its own Container App (``ca-chunker-{env}``). Same image as the
API; entrypoint is::

    python -m app.workers.chunking

State machine owned by this worker
----------------------------------
``topics_extracted``    (set by the topic worker on the prior stage)
    → ``chunking``           (this worker takes lock)
        → ``chunked``            (chunks persisted, count written back to doc)
        → ``failed``             (permanent: blob missing, chunker raised, etc.)
        → (retry)                (transient: Cosmos timeouts)

Permanent vs transient classification
-------------------------------------
``ResourceNotFoundError`` on the extracted-text blob and any ``ValueError``
from the text chunker (oversized text with no boundaries — pathological)
are permanent — dead-letter immediately. Everything else (Cosmos transient
errors, blob 503s) is transient — abandon and let SB redeliver up to
``maxDeliveryCount`` (5).
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

    Same trick as document_ingestion — Container Apps inject env vars, so
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

from uuid import uuid4  # noqa: E402

from azure.core.exceptions import ResourceNotFoundError  # noqa: E402

from app.core.database import DOCUMENTS, get_collection  # noqa: E402
from app.models.base import utc_now  # noqa: E402
from app.models.chunk import Chunk  # noqa: E402
from app.models.document import DocumentStatus  # noqa: E402
from app.services import blob_storage, chunk_storage, text_chunker  # noqa: E402
from app.services.chunk_queue import (  # noqa: E402
    ChunkingMessage,
    ReceivedChunkingMessage,
    consume_chunking_messages,
)
from app.services.vectorization_queue import (  # noqa: E402
    VectorizationMessage,
    publish_vectorization_message,
)

logger = logging.getLogger(__name__)

_CHUNKER_VERSION = "v1"


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
            "Document not found during chunking status update: "
            "tenant=%s workspace=%s doc=%s",
            tenant_id,
            workspace_id,
            document_id,
        )


async def _mark_failed(payload: ChunkingMessage, reason: str) -> None:
    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.failed,
        extra={
            "processing_error": reason,
            "processing_completed_at": utc_now(),
        },
    )


def _build_chunks(
    *,
    payload: ChunkingMessage,
    text: str,
) -> list[Chunk]:
    """Run the text chunker and lift its output into Chunk models."""
    raw_chunks = text_chunker.chunk_text(text)
    out: list[Chunk] = []
    for raw in raw_chunks:
        out.append(
            Chunk(
                id=f"chk_{uuid4().hex}",
                tenant_id=payload.tenant_id,
                workspace_id=payload.workspace_id,
                document_id=payload.document_id,
                text=raw.text,
                chunk_index=raw.chunk_index,
                char_start=raw.char_start,
                char_end=raw.char_end,
                char_count=len(raw.text),
                topic_ids=list(payload.topic_ids),
                chunker_version=_CHUNKER_VERSION,
            )
        )
    return out


# ── Per-message handler ──────────────────────────────────────────────────────


async def _handle(msg: ReceivedChunkingMessage) -> None:
    """Process one chunking request end-to-end."""
    payload = msg.payload
    logger.info(
        "Handling chunking doc=%s delivery=%d blob=%s topics=%d",
        payload.document_id,
        msg.delivery_count,
        payload.extracted_text_blob_path,
        len(payload.topic_ids),
    )

    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.chunking,
        extra={"chunking_started_at": utc_now()},
    )

    # 1. Pull the extracted text blob (Sprint 2.3's output).
    try:
        text = await blob_storage.download_extracted_text(
            payload.extracted_text_blob_path
        )
    except ResourceNotFoundError as exc:
        await _mark_failed(
            payload, f"Extracted text blob not found: {payload.extracted_text_blob_path}"
        )
        await msg.dead_letter("ExtractedTextNotFound", str(exc))
        return

    # 2. Split into chunks. ValueError from the chunker means bad input
    #    (negative-or-zero target via misconfig) — treat as permanent so
    #    SB doesn't churn on it. text_chunker should never raise on normal
    #    input.
    try:
        chunks = _build_chunks(payload=payload, text=text)
    except ValueError as exc:
        await _mark_failed(payload, f"Chunker rejected input: {exc}")
        await msg.dead_letter("ChunkerInputInvalid", str(exc))
        return

    # 3. Atomic replace in Cosmos. Sets chunks for this document_id.
    inserted = await chunk_storage.replace_chunks(
        tenant_id=payload.tenant_id,
        document_id=payload.document_id,
        chunks=chunks,
    )

    # 4. Advance status + write the count back onto the document so the
    #    Flutter polling screen (Sprint 2.10) can render it.
    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.chunked,
        extra={
            "chunk_count": inserted,
            "chunking_completed_at": utc_now(),
            "processing_error": None,
        },
    )
    logger.info(
        "Chunking complete doc=%s chunks=%d char_total=%d",
        payload.document_id,
        inserted,
        sum(c.char_count for c in chunks),
    )

    # 5. Hand off to the vectorizer (Sprint 2.9). Best-effort, same pattern
    #    as the topic_extraction → chunking handoff: if publish fails the
    #    doc is already at `chunked` and a re-run of THIS worker would
    #    re-pay for the (cheap) chunker pass — acceptable cost. A sweep
    #    job (TBD) catches docs stuck without a matching vector row.
    try:
        await publish_vectorization_message(
            VectorizationMessage(
                document_id=payload.document_id,
                tenant_id=payload.tenant_id,
                workspace_id=payload.workspace_id,
                chunk_count=inserted,
            )
        )
    except Exception:
        logger.exception(
            "Failed to enqueue vectorization handoff for doc=%s — "
            "document is stuck at chunked",
            payload.document_id,
        )


# ── Main loop ────────────────────────────────────────────────────────────────


_MAX_DELIVERY = 5  # matches queue maxDeliveryCount in service-bus.bicep


async def run_forever(*, max_wait_seconds: int = 30) -> None:
    """Consume the chunking queue until cancelled."""
    logger.info("Chunking worker starting")
    async with consume_chunking_messages(max_wait_seconds=max_wait_seconds) as messages:
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
                    await _mark_failed(msg.payload, f"Max retries exceeded: {exc}")
                await msg.abandon()


def _install_shutdown_handlers(task: asyncio.Task[None]) -> None:
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        try:
            loop.add_signal_handler(sig, task.cancel)
        except NotImplementedError:
            # Windows has no signal handlers on the event loop — rely on
            # KeyboardInterrupt for local dev.
            pass


async def _amain() -> int:
    task = asyncio.create_task(run_forever())
    _install_shutdown_handlers(task)
    try:
        await task
    except asyncio.CancelledError:
        logger.info("Chunking worker shut down cleanly")
    return 0


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    return asyncio.run(_amain())


if __name__ == "__main__":
    sys.exit(main())
