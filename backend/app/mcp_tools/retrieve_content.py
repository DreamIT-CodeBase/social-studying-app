"""MCP tool: retrieve_content — Sprint 3.5.

Pull the top-k most relevant chunks from a workspace's vector index,
optionally constrained by canonical topic ids. This is the grounding
seam the question-generation pipeline (Sprint 3.7+) uses to keep AI
output anchored to the workspace's actual study materials.

Why a tool and not a raw service call
-------------------------------------
The orchestration layer (Sprint 3.9's ``POST /questions/next``) needs to
think about retrieval as a declared capability with a typed contract,
not as "import a function". Same shape an MCP server would publish.
This file is the contract; the implementation delegates to
:func:`app.services.azure_ai_search.search_chunks` and the embedding
service.

Search mode
-----------
- If ``query_text`` is provided and embeddings are configured, runs
  HYBRID search (text + vector). Best default — students may search for
  exact phrases ("Pythagorean theorem") or open-ended concepts
  ("how plants make energy").
- If only ``query_text`` is provided AND embeddings can't be produced
  (e.g. ServiceUnavailableError on the embed call), falls back to BM25
  text-only. Logged as a warning.
- If neither ``query_text`` nor ``topic_ids`` is provided, returns an
  empty list — refusing to do a wildcard search keeps callers honest.
"""

from __future__ import annotations

import logging

from pydantic import BaseModel, Field

from app.core.exceptions import ServiceUnavailableError
from app.mcp_tools import register_tool
from app.services import azure_ai_search, azure_openai

logger = logging.getLogger(__name__)


# ── Input ────────────────────────────────────────────────────────────────────


class RetrieveContentInput(BaseModel):
    """Parameters for :func:`retrieve_content`.

    Field names match the typical MCP convention: snake_case, scalar
    types first, optional collections after.
    """

    tenant_id: str = Field(
        ...,
        min_length=1,
        description="Tenant whose chunks index to query. Routes to the per-tenant AI Search index.",
    )
    workspace_id: str = Field(
        ...,
        min_length=1,
        description="Workspace ID — applied as a hard filter on every hit.",
    )
    topic_ids: list[str] = Field(
        default_factory=list,
        description=(
            "Optional canonical topic ids (`tpc_<uuid>`) to restrict the "
            "search to. OR-composed: a chunk that touches ANY of these "
            "topics is a match. Empty = no topic constraint."
        ),
    )
    query_text: str | None = Field(
        default=None,
        description=(
            "Free-text query. If set, runs hybrid (text + vector) search; "
            "the text gets embedded inline. Omit for topic-only filtering "
            "(returns empty if topic_ids is also empty)."
        ),
    )
    top_k: int = Field(
        default=5,
        ge=1,
        le=50,
        description="Maximum number of chunks to return. Capped at 50 by the index.",
    )


# ── Output ───────────────────────────────────────────────────────────────────


class RetrievedChunk(BaseModel):
    """One hit returned by the tool, with relevance score.

    Mirrors :class:`app.services.azure_ai_search.RetrievedChunk` but lives
    on Pydantic so the MCP transport can serialize it directly.
    """

    chunk_id: str
    chunk_index: int
    document_id: str
    text: str
    topic_ids: list[str]
    score: float = Field(
        description="Combined hybrid score from AI Search. Higher = more relevant.",
    )


class RetrieveContentOutput(BaseModel):
    """Result of :func:`retrieve_content`.

    ``mode`` is reported back so the caller knows whether the retrieval
    fell back to text-only (embed failure) or ran the intended hybrid
    path — useful for downstream prompt grounding heuristics.
    """

    chunks: list[RetrievedChunk]
    mode: str = Field(
        description=(
            "Which search mode actually ran: ``'hybrid'`` (text + vector), "
            "``'text'`` (BM25 only, embed-fallback or no embedding), or "
            "``'empty'`` (no inputs)."
        )
    )


# ── Handler ──────────────────────────────────────────────────────────────────


@register_tool(
    name="retrieve_content",
    description=(
        "Search the workspace's vector index for chunks matching a topic "
        "or query text. Used by the question-generation pipeline to ground "
        "every AI response in the workspace's own study materials."
    ),
    input_model=RetrieveContentInput,
    output_model=RetrieveContentOutput,
)
async def retrieve_content(params: RetrieveContentInput) -> RetrieveContentOutput:
    """Run a hybrid AI Search query and return the top hits as a tool output.

    See module docstring for fallback behavior.
    """
    # No query at all — refuse rather than wildcard-search the index.
    if not params.query_text and not params.topic_ids:
        return RetrieveContentOutput(chunks=[], mode="empty")

    query_vector: list[float] | None = None
    mode = "text"
    if params.query_text:
        try:
            vectors = await azure_openai.embed_texts(texts=[params.query_text])
            if vectors:
                query_vector = vectors[0]
                mode = "hybrid"
        except ServiceUnavailableError as exc:
            # Embed failure shouldn't kill retrieval — BM25 alone is still
            # useful, especially for the prompt-eval test fixtures.
            logger.warning(
                "retrieve_content: embedding failed (%s); falling back to text-only search",
                exc,
            )

    if not params.query_text and params.topic_ids:
        # Topic-only retrieval. AI Search rejects a filter-only query, so
        # use a wildcard text query — within the topic filter that's still
        # bounded and meaningful.
        hits = await azure_ai_search.search_chunks(
            tenant_id=params.tenant_id,
            workspace_id=params.workspace_id,
            topic_ids=params.topic_ids,
            query_text="*",
            top_k=params.top_k,
        )
        mode = "text"
    else:
        hits = await azure_ai_search.search_chunks(
            tenant_id=params.tenant_id,
            workspace_id=params.workspace_id,
            topic_ids=params.topic_ids,
            query_text=params.query_text,
            query_vector=query_vector,
            top_k=params.top_k,
        )

    chunks = [
        RetrievedChunk(
            chunk_id=h.chunk_id,
            chunk_index=h.chunk_index,
            document_id=h.document_id,
            text=h.text,
            topic_ids=list(h.topic_ids),
            score=h.score,
        )
        for h in hits
    ]
    return RetrieveContentOutput(chunks=chunks, mode=mode)
