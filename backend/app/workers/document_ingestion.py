"""Document ingestion worker — Sprint 2.3.

Long-running asyncio loop that pulls extraction requests off the
``document-ingestion`` Service Bus queue, runs the file through Azure
Document Intelligence (``prebuilt-read``), persists the extracted text to
blob storage, and updates the corresponding Cosmos document record.

Runs as its own Container App (see ``infra/bicep/modules/container-apps.bicep``,
resource ``workerApp``). Same image as the API; entrypoint is::

    python -m app.workers.document_ingestion

State machine owned by this worker
----------------------------------
``pending``         (set by upload API)
    → ``extracting``        (this worker takes lock + records start time)
        → ``text_extracted``    (DI succeeded; text persisted; metadata updated)
        → ``failed``            (permanent: malformed file / unsupported content)
        → (retry)              (transient: blob 404 / DI 503 / Cosmos timeout)

Permanent vs transient classification
-------------------------------------
``UnsupportedContent`` from Document Intelligence and ``KeyError`` while parsing
the message are permanent — dead-letter immediately so we don't waste 5 retries.
Everything else (transport, timeout, DI 503) is transient — abandon the message
and let Service Bus redeliver up to ``maxDeliveryCount`` (5) times before
auto-DLQing.
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

    No-op in Container Apps: the platform injects env vars, and
    ``os.environ.setdefault`` doesn't overwrite anything already set.
    Must run BEFORE importing ``app.core.config`` so pydantic-settings
    picks up the values at class instantiation time.
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

from azure.core.exceptions import HttpResponseError, ResourceNotFoundError  # noqa: E402

from app.core.database import DOCUMENTS, get_collection  # noqa: E402
from app.models.base import utc_now  # noqa: E402
from app.models.document import DocumentStatus  # noqa: E402
from app.services import blob_storage, document_intelligence  # noqa: E402
from app.services.document_queue import (  # noqa: E402
    ExtractionMessage,
    ReceivedExtractionMessage,
    consume_extraction_messages,
)

logger = logging.getLogger(__name__)

_PERMANENT_DI_ERROR_CODES = {"UnsupportedContent", "InvalidContent"}


async def _set_status(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    status: DocumentStatus,
    extra: dict[str, object] | None = None,
) -> None:
    """Atomic Cosmos update of a single document's status + companion fields.

    Uses ``$set`` rather than a full ``replace_one`` because we want to update
    only the fields the worker owns — the rest of the document (filename,
    blob_url, uploaded_by, …) must not be clobbered if a later step or admin
    edited them concurrently.
    """
    update: dict[str, object] = {"status": status.value, "updated_at": utc_now()}
    if extra:
        update.update(extra)
    col = get_collection(tenant_id, DOCUMENTS)
    result = await col.update_one(
        {"_id": document_id, "workspace_id": workspace_id},
        {"$set": update},
    )
    if result.matched_count == 0:
        # The doc was deleted between upload and worker pickup. Log loudly —
        # this means the queue message references a vanished document.
        logger.warning(
            "Document not found during status update: tenant=%s workspace=%s doc=%s",
            tenant_id,
            workspace_id,
            document_id,
        )


# ── Per-message handler ──────────────────────────────────────────────────────


async def _handle(msg: ReceivedExtractionMessage) -> None:
    """Process a single extraction request end-to-end.

    Returns normally on success (caller calls ``msg.complete()``). Raises to
    indicate the caller should abandon (transient) or dead-letter (permanent).
    """
    payload: ExtractionMessage = msg.payload
    logger.info(
        "Handling doc=%s delivery=%d blob=%s",
        payload.document_id,
        msg.delivery_count,
        payload.blob_path,
    )

    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.extracting,
        extra={"processing_started_at": utc_now()},
    )

    # 1. Pull bytes from blob.
    try:
        content = await blob_storage.download_document(payload.blob_path)
    except ResourceNotFoundError as exc:
        # Blob is gone for good — no point retrying. DLQ + mark failed.
        await _mark_failed(payload, f"Source blob not found: {payload.blob_path}")
        await msg.dead_letter("BlobNotFound", str(exc))
        return

    # 2. Send to Document Intelligence (prebuilt-read).
    try:
        extracted = await document_intelligence.extract_text(
            content, content_type=payload.content_type
        )
    except HttpResponseError as exc:
        if _is_permanent(exc):
            await _mark_failed(payload, f"Document Intelligence rejected file: {exc.message}")
            await msg.dead_letter("UnsupportedContent", str(exc))
            return
        # Transient — let Service Bus redeliver.
        raise

    # 3. Persist extracted text.
    blob_path = await blob_storage.upload_extracted_text(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        text=extracted.text,
    )

    # 4. Mark document text_extracted with metadata.
    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.text_extracted,
        extra={
            "extracted_text_blob_path": blob_path,
            "text_char_count": len(extracted.text),
            "page_count": extracted.page_count,
            "languages": extracted.languages,
            "processing_completed_at": utc_now(),
            "processing_error": None,
        },
    )
    logger.info(
        "Extracted doc=%s pages=%d chars=%d langs=%s",
        payload.document_id,
        extracted.page_count,
        len(extracted.text),
        extracted.languages or ["unknown"],
    )


async def _mark_failed(payload: ExtractionMessage, reason: str) -> None:
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


def _is_permanent(exc: HttpResponseError) -> bool:
    """Classify a Document Intelligence error.

    Looks at both the top-level error code and any nested ``Exception Details``
    (the SDK exposes these as ``.error.code`` and inside ``.error.details``).
    """
    code = getattr(getattr(exc, "error", None), "code", None) or ""
    if code in _PERMANENT_DI_ERROR_CODES:
        return True
    details = getattr(getattr(exc, "error", None), "details", None) or []
    for detail in details:
        detail_code = getattr(detail, "code", None) or ""
        if detail_code in _PERMANENT_DI_ERROR_CODES:
            return True
    return False


# ── Main loop ────────────────────────────────────────────────────────────────


async def run_forever(*, max_wait_seconds: int = 30) -> None:
    """Consume the document-ingestion queue until cancelled.

    Cancellation comes from SIGTERM (Container Apps shutdown) or SIGINT
    (local dev Ctrl-C). On cancel, the current message in flight is
    abandoned (not completed) so a sibling replica will retry it.
    """
    logger.info("Document ingestion worker starting")
    async with consume_extraction_messages(max_wait_seconds=max_wait_seconds) as messages:
        async for msg in messages:
            try:
                await _handle(msg)
                await msg.complete()
            except asyncio.CancelledError:
                logger.warning("Cancelled while handling doc=%s — abandoning", msg.payload.document_id)
                await msg.abandon()
                raise
            except Exception as exc:
                # Anything else is transient. Log and abandon so Service Bus
                # redelivers; after maxDeliveryCount (5) it auto-DLQs.
                logger.exception(
                    "Transient failure handling doc=%s delivery=%d: %s",
                    msg.payload.document_id,
                    msg.delivery_count,
                    exc,
                )
                # If we've burned through retries, mark the doc failed too so
                # the admin UI doesn't show it stuck in 'extracting' forever.
                if msg.delivery_count >= 5:
                    await _mark_failed(msg.payload, f"Max retries exceeded: {exc}")
                await msg.abandon()


def _install_shutdown_handlers(task: asyncio.Task[None]) -> None:
    """Cancel the main task on SIGTERM/SIGINT for clean shutdown.

    Container Apps sends SIGTERM with a 30-second grace period before SIGKILL.
    Cancelling lets the in-flight message abandon cleanly.
    """
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        try:
            loop.add_signal_handler(sig, task.cancel)
        except NotImplementedError:
            # Windows doesn't support add_signal_handler; rely on KeyboardInterrupt.
            pass


async def _amain() -> int:
    task = asyncio.create_task(run_forever())
    _install_shutdown_handlers(task)
    try:
        await task
    except asyncio.CancelledError:
        logger.info("Worker shut down cleanly")
    return 0


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    return asyncio.run(_amain())


if __name__ == "__main__":
    sys.exit(main())
