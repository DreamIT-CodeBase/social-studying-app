"""Cosmos persistence for Sprint 2.8 chunks.

Thin wrapper over the ``chunks`` collection. Owns two operations:

1. ``replace_chunks`` — atomically swap out a document's full chunk set.
   Used by the chunker worker so re-runs (delivery_count > 1 or admin
   "re-chunk") leave a consistent state even if the worker crashes
   mid-write.
2. ``count_for_document`` — sanity-check helper used by the worker after
   the write and by future admin endpoints.

Why a dedicated module and not inline in the worker
---------------------------------------------------
Sprint 2.11's admin "regenerate chunks" endpoint will reuse
``replace_chunks``, and Sprint 2.9's vectorization worker reads via
``find_for_document`` (added there). Centralising the I/O patterns keeps
filter clauses (always include ``document_id`` for partition-key
locality) in one place.
"""

from __future__ import annotations

import asyncio
import logging
import re
from collections.abc import Awaitable, Callable
from uuid import uuid4

from app.core.database import CHUNKS, get_collection
from app.models.base import utc_now
from app.models.chunk import Chunk

logger = logging.getLogger(__name__)

# A website can produce substantially more chunks than a normal PDF. Cosmos
# can throttle a Mongo bulk insert part-way through, which makes retries
# expensive because the prior partial batch must be deleted. Upserts are
# idempotent, and the small pacing delay keeps a single scrape within the
# shared Cosmos RU budget.
_MAX_THROTTLE_RETRIES = 5
_THROTTLE_CODES = frozenset({429, 16500})
_RETRY_AFTER_PATTERN = re.compile(r"RetryAfterMs=(\d+)")
_CHUNK_WRITE_PACE_SECONDS = 0.1


def _is_throttle_error(exc: Exception) -> bool:
    """Return whether a Motor/PyMongo error represents Cosmos throttling."""
    if getattr(exc, "code", None) in _THROTTLE_CODES:
        return True

    details = getattr(exc, "details", None)
    if isinstance(details, dict):
        if details.get("code") in _THROTTLE_CODES:
            return True
        write_errors = details.get("writeErrors", [])
        if isinstance(write_errors, list):
            return any(
                isinstance(error, dict) and error.get("code") in _THROTTLE_CODES
                for error in write_errors
            )
    return False


def _throttle_delay_seconds(exc: Exception, attempt: int) -> float:
    """Calculate a bounded delay, honoring Cosmos' ``RetryAfterMs`` hint."""
    suggested = 0.0
    match = _RETRY_AFTER_PATTERN.search(str(exc))
    if match:
        suggested = int(match.group(1)) / 1000
    exponential = 0.25 * (2**attempt)
    return min(max(suggested, exponential), 5.0)


async def _run_with_throttle_retry(
    operation: Callable[[], Awaitable[object]],
    *,
    document_id: str,
) -> object:
    """Run one idempotent Cosmos operation with bounded 429 backoff."""
    for attempt in range(_MAX_THROTTLE_RETRIES + 1):
        try:
            return await operation()
        except Exception as exc:
            if not _is_throttle_error(exc) or attempt >= _MAX_THROTTLE_RETRIES:
                raise

            delay = _throttle_delay_seconds(exc, attempt)
            logger.warning(
                "Cosmos throttled chunk write for document=%s; retrying in %.2fs (attempt %d/%d)",
                document_id,
                delay,
                attempt + 1,
                _MAX_THROTTLE_RETRIES,
            )
            await asyncio.sleep(delay)

    raise AssertionError("unreachable")


async def replace_chunks(
    *,
    tenant_id: str,
    document_id: str,
    chunks: list[Chunk],
) -> int:
    """Atomically replace ALL existing chunks for a document.

    Deletes existing rows then inserts the new set. Not a true Cosmos
    transaction (MongoDB API doesn't support multi-doc transactions
    inside our SKU), but the delete + insert sequence inside a single
    partition key (``document_id``) is safe enough for our re-chunking
    semantics:

    - If delete succeeds and insert fails, the worker's redelivery picks
      this back up with delivery_count > 1 and replays the whole sequence.
      Intermediate state (no chunks present) is fine because no other
      reader cares about chunks until status flips to ``chunked``.
    - If insert succeeds, the document's status update is the commit
      point; readers don't trust partial chunk sets.

    Returns the number of chunks inserted. Skips the insert when
    ``chunks`` is empty (still wipes any prior chunks).
    """
    docs = []
    for chunk in chunks:
        if not chunk.id:
            chunk = chunk.model_copy(update={"id": f"chk_{uuid4().hex}"})
        chunk = chunk.model_copy(update={"updated_at": utc_now()})
        docs.append(chunk.model_dump(by_alias=True))

    col = get_collection(tenant_id, CHUNKS)
    delete_result = await _run_with_throttle_retry(
        lambda: col.delete_many({"document_id": document_id}),
        document_id=document_id,
    )
    if delete_result.deleted_count:
        logger.info(
            "Deleted %d stale chunks for document=%s before re-write",
            delete_result.deleted_count,
            document_id,
        )

    for index, doc in enumerate(docs):
        await _run_with_throttle_retry(
            lambda doc=doc: col.replace_one({"_id": doc["_id"]}, doc, upsert=True),
            document_id=document_id,
        )
        if index < len(docs) - 1:
            await asyncio.sleep(_CHUNK_WRITE_PACE_SECONDS)

    logger.info(
        "Inserted %d chunks for document=%s tenant=%s",
        len(docs),
        document_id,
        tenant_id,
    )
    return len(docs)


async def count_for_document(*, tenant_id: str, document_id: str) -> int:
    """Return the number of chunks currently stored for ``document_id``.

    Useful as a post-write sanity check and as the source of truth for the
    document record's ``chunk_count`` field after Sprint 2.8 lands.
    """
    col = get_collection(tenant_id, CHUNKS)
    return await col.count_documents({"document_id": document_id})


async def find_for_document(
    *,
    tenant_id: str,
    document_id: str,
) -> list[Chunk]:
    """Return every chunk for ``document_id`` ordered by ``chunk_index``.

    Used by Sprint 2.9's vectorizer to pull a document's chunk set as a
    single ordered batch for embedding. Filter scopes to ``document_id``
    only — that's the partition key and ensures the read stays inside
    one partition.

    Sort runs CLIENT-SIDE rather than via ``cursor.sort(...)`` because
    Cosmos MongoDB API rejects sort operations unless an explicit index
    exists on the sort field, and our chunks collection ships without
    one. ``O(n log n)`` on ~30 chunks/doc is free; the index would need a
    collection-creation hook we don't have today.
    """
    col = get_collection(tenant_id, CHUNKS)
    cursor = col.find({"document_id": document_id})
    out: list[Chunk] = []
    async for raw in cursor:
        out.append(Chunk.model_validate(raw))
    out.sort(key=lambda c: c.chunk_index)
    return out
