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

import logging
from uuid import uuid4

from app.core.database import CHUNKS, get_collection
from app.models.base import utc_now
from app.models.chunk import Chunk

logger = logging.getLogger(__name__)


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
    col = get_collection(tenant_id, CHUNKS)

    delete_result = await col.delete_many({"document_id": document_id})
    if delete_result.deleted_count:
        logger.info(
            "Deleted %d stale chunks for document=%s before re-write",
            delete_result.deleted_count,
            document_id,
        )

    if not chunks:
        return 0

    docs = []
    for chunk in chunks:
        if not chunk.id:
            chunk = chunk.model_copy(update={"id": f"chk_{uuid4().hex}"})
        chunk = chunk.model_copy(update={"updated_at": utc_now()})
        docs.append(chunk.model_dump(by_alias=True))

    result = await col.insert_many(docs)
    inserted = len(result.inserted_ids) if hasattr(result, "inserted_ids") else len(docs)
    logger.info(
        "Inserted %d chunks for document=%s tenant=%s",
        inserted,
        document_id,
        tenant_id,
    )
    return inserted


async def count_for_document(*, tenant_id: str, document_id: str) -> int:
    """Return the number of chunks currently stored for ``document_id``.

    Useful as a post-write sanity check and as the source of truth for the
    document record's ``chunk_count`` field after Sprint 2.8 lands.
    """
    col = get_collection(tenant_id, CHUNKS)
    return await col.count_documents({"document_id": document_id})
