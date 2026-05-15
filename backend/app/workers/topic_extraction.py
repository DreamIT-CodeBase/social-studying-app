"""Topic extraction worker — Sprint 2.5.

Long-running asyncio loop that pulls messages off the ``topic-extraction``
Service Bus queue, runs the document's extracted text through GPT-4o for
topic mining, and writes the resulting :class:`TopicTag` list onto the
Cosmos document record.

Runs as its own Container App (see ``infra/bicep/modules/container-apps.bicep``,
resource ``topicWorkerApp``). Same image as the API; entrypoint is::

    python -m app.workers.topic_extraction

State machine owned by this worker
----------------------------------
``text_extracted``     (set by the text-extraction worker on the previous stage)
    → ``extracting_topics``   (this worker takes lock, GPT-4o call in flight)
        → ``topics_extracted``    (model returned valid JSON, tags persisted)
        → ``failed``              (permanent: prompt rejected, malformed JSON
                                    after retries)
        → (retry)                 (transient: model 429/503, blob 503)

Permanent vs transient classification
-------------------------------------
``ValueError`` from :func:`extract_topics` (invalid JSON, missing topics key)
and ``ResourceNotFoundError`` on the extracted-text blob are permanent — the
prompt or input is broken in a way retries won't fix. Dead-letter immediately.

Everything else (``ServiceUnavailableError`` for OpenAI 429/503, transport
errors) is transient — abandon and let Service Bus redeliver up to
``maxDeliveryCount`` (3) times.
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
    ``os.environ.setdefault`` is a no-op there. Local dev gets a free .env load.
    Must run BEFORE importing ``app.core.config``.
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

from azure.core.exceptions import ResourceNotFoundError  # noqa: E402

from app.core.database import DOCUMENTS, get_collection  # noqa: E402
from app.core.exceptions import ServiceUnavailableError  # noqa: E402
from app.models.base import utc_now  # noqa: E402
from app.models.document import DocumentStatus, TopicTag  # noqa: E402
from app.services import blob_storage, taxonomy, topic_extraction  # noqa: E402
from app.services.topic_queue import (  # noqa: E402
    ReceivedTopicMessage,
    TopicExtractionMessage,
    consume_topic_messages,
)

logger = logging.getLogger(__name__)


async def _set_status(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    status: DocumentStatus,
    extra: dict[str, object] | None = None,
) -> None:
    """Atomic Cosmos update of one document's status + companion fields.

    Same pattern as document_ingestion._set_status. Duplicated rather than
    extracted because the two workers will diverge as the pipeline matures
    (different fields, different concurrency guards) — premature abstraction
    would force shared shape on stages that don't have one.
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
        logger.warning(
            "Document not found during topic-extraction status update: "
            "tenant=%s workspace=%s doc=%s",
            tenant_id,
            workspace_id,
            document_id,
        )


async def _mark_failed(payload: TopicExtractionMessage, reason: str) -> None:
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


def _serialize_topics(topics: list[TopicTag]) -> list[dict[str, object]]:
    """Convert TopicTag pydantic models to JSON-safe dicts for $set.

    ``model_dump`` would include the default ``confidence=1.0`` and ``source="ai"``,
    which we want — they're part of the document's row representation.
    """
    return [t.model_dump() for t in topics]


# ── Per-message handler ──────────────────────────────────────────────────────


async def _handle(msg: ReceivedTopicMessage) -> None:
    """Process a single topic-extraction request end-to-end.

    Returns normally on success (caller calls ``msg.complete()``). Raises to
    indicate the caller should abandon (transient) or dead-letter (permanent).
    """
    payload = msg.payload
    logger.info(
        "Handling topic extraction doc=%s delivery=%d blob=%s",
        payload.document_id,
        msg.delivery_count,
        payload.extracted_text_blob_path,
    )

    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.extracting_topics,
        extra={"processing_started_at": utc_now()},
    )

    # 1. Pull extracted text from blob. Sprint 2.3 wrote it; 2.4 confirmed
    #    it's safe; we now mine it for topics.
    try:
        content_bytes = await blob_storage.download_document(
            payload.extracted_text_blob_path
        )
    except ResourceNotFoundError as exc:
        # Extracted-text blob is gone — permanent.
        await _mark_failed(
            payload, f"Extracted text blob not found: {payload.extracted_text_blob_path}"
        )
        await msg.dead_letter("ExtractedTextBlobNotFound", str(exc))
        return

    text = content_bytes.decode("utf-8", errors="replace")

    # 2. Run topic extraction. ValueError → permanent (prompt failure);
    #    ServiceUnavailableError → transient (let SB redeliver).
    try:
        topics = await topic_extraction.extract_topics(text)
    except ValueError as exc:
        await _mark_failed(payload, f"Topic extraction prompt failure: {exc}")
        await msg.dead_letter("PromptFailure", str(exc))
        return
    except ServiceUnavailableError:
        # Transient — re-raise so the run loop abandons + retries.
        raise

    # 3. Merge into the workspace canonical taxonomy (Sprint 2.6).
    #    Best-effort: a merge failure logs loudly but the doc still advances
    #    to topics_extracted. The per-doc TopicTags are useful for 2.8
    #    chunking even without a fresh workspace taxonomy, and the admin
    #    "regenerate taxonomy" endpoint (2.11) can rebuild from scratch.
    merge_ok = False
    try:
        outcome = await taxonomy.merge_into_workspace(
            tenant_id=payload.tenant_id,
            workspace_id=payload.workspace_id,
            document_id=payload.document_id,
            new_topics=topics,
        )
        merge_ok = True
        logger.info(
            "Taxonomy merge doc=%s workspace_version=%d total=%d added=%d seeded=%s",
            payload.document_id,
            outcome.taxonomy_version,
            outcome.topics_total,
            outcome.topics_added,
            outcome.seeded,
        )
    except Exception:
        logger.exception(
            "Taxonomy merge failed for doc=%s — workspace taxonomy left stale, "
            "document will still advance to topics_extracted",
            payload.document_id,
        )

    # 4. Infer prerequisite edges over the workspace's canonical taxonomy
    #    (Sprint 2.7). Eager trigger on every successful merge — cost is one
    #    extra GPT-4o call per upload, accepted for demo phase. Skipped when
    #    the merge above failed (the taxonomy didn't change, so re-inferring
    #    deps is wasted money). Best-effort: failure logs but doesn't crash
    #    the doc.
    if merge_ok:
        try:
            deps_outcome = await taxonomy.infer_dependencies(
                tenant_id=payload.tenant_id,
                workspace_id=payload.workspace_id,
            )
            logger.info(
                "Dep inference doc=%s workspace_version=%d topics=%d "
                "edges_set=%d edges_changed=%d dropped=%d skipped=%s",
                payload.document_id,
                deps_outcome.taxonomy_version,
                deps_outcome.topics_total,
                deps_outcome.edges_set,
                deps_outcome.edges_changed,
                deps_outcome.edges_dropped_invalid,
                deps_outcome.skipped,
            )
        except Exception:
            logger.exception(
                "Dep inference failed for doc=%s — workspace deps left stale, "
                "document will still advance to topics_extracted",
                payload.document_id,
            )

    # 5. Persist topics + advance status.
    await _set_status(
        tenant_id=payload.tenant_id,
        workspace_id=payload.workspace_id,
        document_id=payload.document_id,
        status=DocumentStatus.topics_extracted,
        extra={
            "topic_tags": _serialize_topics(topics),
            "processing_completed_at": utc_now(),
            "processing_error": None,
        },
    )
    logger.info(
        "Extracted topics doc=%s count=%d",
        payload.document_id,
        len(topics),
    )


# ── Main loop ────────────────────────────────────────────────────────────────


async def run_forever(*, max_wait_seconds: int = 30) -> None:
    """Consume the topic-extraction queue until cancelled.

    Cancellation comes from SIGTERM (Container Apps shutdown) or SIGINT
    (local dev Ctrl-C). On cancel, the current message in flight is
    abandoned (not completed) so a sibling replica will retry it.
    """
    logger.info("Topic extraction worker starting")
    async with consume_topic_messages(max_wait_seconds=max_wait_seconds) as messages:
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
                    "Transient failure handling topic doc=%s delivery=%d: %s",
                    msg.payload.document_id,
                    msg.delivery_count,
                    exc,
                )
                # maxDeliveryCount=3 for this queue (see service-bus.bicep).
                if msg.delivery_count >= 3:
                    await _mark_failed(
                        msg.payload, f"Max retries exceeded: {exc}"
                    )
                await msg.abandon()


def _install_shutdown_handlers(task: asyncio.Task[None]) -> None:
    """Cancel the main task on SIGTERM/SIGINT for clean shutdown."""
    import contextlib

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        with contextlib.suppress(NotImplementedError):
            loop.add_signal_handler(sig, task.cancel)


async def _amain() -> int:
    task = asyncio.create_task(run_forever())
    _install_shutdown_handlers(task)
    try:
        await task
    except asyncio.CancelledError:
        logger.info("Topic extraction worker shut down cleanly")
    return 0


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    return asyncio.run(_amain())


if __name__ == "__main__":
    sys.exit(main())
