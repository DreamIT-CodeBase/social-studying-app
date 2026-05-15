"""Chunk model — per-document text fragment, the retrieval unit for Sprint 3.

Sprint 2.8 owns the write side: the chunking worker splits a document's
extracted text into 2K-char overlapping chunks and persists each one here.
Sprint 2.9 will read these back, embed them, and push to Azure AI Search.
Sprint 3's question generator retrieves the most relevant chunks by topic
+ vector similarity to ground each generated question.

Partition key
-------------
``document_id``. A document's chunks always live together — every read
path (re-vectorize, re-chunk, soft-delete) is keyed by document, never
across documents. This is the same partitioning shape as TopicTags on
the document record, just promoted to its own collection because the
1-to-many fan-out (a 60K-char doc produces ~30 chunks) makes inline
storage impractical.

Why a separate collection rather than embedding in the document
---------------------------------------------------------------
Cosmos has a 2 MB document size limit. A textbook with ~30 chunks of
~2K chars each = 60K of text + per-chunk metadata fits, but once Sprint
2.9 attaches 1536-float embeddings (~6KB per chunk), inline storage
blows the limit. Splitting now avoids a painful migration later.
"""

from pydantic import Field

from app.models.base import CosmosDocument


class Chunk(CosmosDocument):
    """A single text fragment from a document, ready for vectorization.

    Stored in the tenant's database, ``chunks`` collection.
    """

    # ── Identifiers ──────────────────────────────────────────────────────────
    tenant_id: str
    workspace_id: str
    document_id: str

    # ── Content ──────────────────────────────────────────────────────────────
    text: str
    # 0-indexed position inside the document. With ``document_id`` it forms
    # the natural composite key for re-chunking idempotency.
    chunk_index: int = Field(ge=0)
    char_start: int = Field(ge=0)
    char_end: int = Field(ge=0)
    char_count: int = Field(ge=0)

    # ── Metadata for Sprint 3 retrieval ──────────────────────────────────────
    # Union of the document's TopicTag ids that match the workspace's
    # canonical taxonomy at chunking time. Sprint 2.8 v1 over-tags every
    # chunk with the document's full topic list (page-keyed precision is
    # deferred — see sprint_2_8_decisions.md). Sprint 2.9 mirrors this onto
    # the AI Search index for filtered retrieval.
    topic_ids: list[str] = Field(default_factory=list)
    # Schema version of the chunker output — bump when the splitter rules
    # change (overlap policy, boundary heuristics) so old chunks can be
    # identified and re-chunked.
    chunker_version: str = "v1"
