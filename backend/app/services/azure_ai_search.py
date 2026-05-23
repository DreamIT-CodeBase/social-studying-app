"""Azure AI Search — per-tenant chunk index for Sprint 2.9 vectorization.

The vectorizer pushes embedded chunks to a tenant-scoped index so Sprint 3's
question generator can do hybrid (text + vector) retrieval inside that
tenant's data only. Per-tenant indexes mirror the Cosmos doctrine
(``one DB per tenant``) — isolation lives at the storage layer, not the
query layer.

Index naming
------------
Tenant ids look like ``ten_<uuid hex>``. Azure AI Search index names allow
only lowercase letters, digits, and dashes — no underscores. We sanitize
``ten_abc`` → ``ten-abc`` and prefix with the configured slug, yielding
``chunks-ten-abc``. ``index_name_for`` is the only place that mapping lives.

Schema (locked at create time)
------------------------------
- ``id``              (key, filterable)        — mirrors the Cosmos chunk id (``chk_<uuid>``)
- ``tenant_id``       (filterable)             — defence in depth though the index is per-tenant
- ``workspace_id``    (filterable)
- ``document_id``     (filterable)             — used by ``delete_for_document``
- ``chunk_index``     (filterable, sortable)
- ``text``            (searchable)             — for hybrid retrieval (lexical fallback)
- ``topic_ids``       (Collection, filterable) — resolved here (Sprint 2.8 deferred it)
- ``chunker_version`` (filterable)             — surfaces stale chunks for re-chunk migrations
- ``embedding_model`` (filterable)             — surfaces stale embeddings for model upgrades
- ``created_at``      (sortable)
- ``embedding``       (Collection<Single>, vector field, dim=1536, HNSW profile)

The ``dimensions`` on the vector field is fixed at index creation. Switching
to a model with a different dimensionality (e.g. text-embedding-3-large at
3072) requires deleting and recreating the index, not just a redeploy.

Re-vectorize semantics
----------------------
The vectorizer's happy path is ``delete_for_document`` then
``upsert_chunks``. Delete-then-upsert is safe under SB redelivery: a partial
state (deleted but not yet upserted) is fine because the doc's status flag
is the commit point — readers don't trust partial chunk sets.
"""

from __future__ import annotations

import logging
from collections.abc import Iterable
from typing import Any

from azure.core.credentials import AzureKeyCredential
from azure.core.exceptions import (
    HttpResponseError,
    ResourceExistsError,
    ResourceNotFoundError,
)
from azure.search.documents.aio import SearchClient
from azure.search.documents.indexes.aio import SearchIndexClient
from azure.search.documents.indexes.models import (
    HnswAlgorithmConfiguration,
    SearchableField,
    SearchField,
    SearchFieldDataType,
    SearchIndex,
    SimpleField,
    VectorSearch,
    VectorSearchProfile,
)

from app.core.config import settings
from app.core.exceptions import ServiceUnavailableError

logger = logging.getLogger(__name__)

# Vector search wiring. Names are arbitrary but must match between the
# field's ``vector_search_profile_name`` and the profile registered in the
# index's ``vector_search`` config.
_HNSW_PROFILE = "chunks-hnsw-profile"
_HNSW_ALGORITHM = "chunks-hnsw"

# In-process cache of indexes we know exist. Workers are long-lived and
# create one tenant's index on first use; after that ``ensure_index`` is a
# no-op. Cleared on process restart, which is cheap (one Search head HTTP
# call per tenant per process).
_KNOWN_INDEXES: set[str] = set()


# ── Naming ──────────────────────────────────────────────────────────────────


def index_name_for(tenant_id: str) -> str:
    """Return the AI Search index name for ``tenant_id``.

    Lowercases and replaces ``_`` with ``-`` because Search rejects
    underscores in index names. Tenant ids are already URL-safe so no
    further sanitisation is needed.
    """
    sanitized = tenant_id.lower().replace("_", "-")
    return f"{settings.search_chunks_index_prefix}-{sanitized}"


# ── Client construction ─────────────────────────────────────────────────────


def _require_credentials() -> tuple[str, AzureKeyCredential]:
    if not settings.search_endpoint or not settings.search_key:
        raise ServiceUnavailableError(
            "Azure AI Search is not configured "
            "(set SEARCH_ENDPOINT and SEARCH_KEY)."
        )
    return settings.search_endpoint, AzureKeyCredential(settings.search_key)


def _index_client() -> SearchIndexClient:
    endpoint, credential = _require_credentials()
    return SearchIndexClient(endpoint=endpoint, credential=credential)


def _data_client(index_name: str) -> SearchClient:
    endpoint, credential = _require_credentials()
    return SearchClient(endpoint=endpoint, index_name=index_name, credential=credential)


# ── Index management ────────────────────────────────────────────────────────


def _build_index_definition(name: str) -> SearchIndex:
    """Construct the SearchIndex object for a tenant's chunks index.

    Centralised so ``ensure_index`` and any future migration code share one
    schema definition.
    """
    fields = [
        SimpleField(
            name="id",
            type=SearchFieldDataType.String,
            key=True,
            filterable=True,
        ),
        SimpleField(name="tenant_id", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="workspace_id", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="document_id", type=SearchFieldDataType.String, filterable=True),
        SimpleField(
            name="chunk_index",
            type=SearchFieldDataType.Int32,
            filterable=True,
            sortable=True,
        ),
        SearchableField(name="text", type=SearchFieldDataType.String),
        SimpleField(
            name="topic_ids",
            type=SearchFieldDataType.Collection(SearchFieldDataType.String),
            filterable=True,
        ),
        SimpleField(name="chunker_version", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="embedding_model", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="created_at", type=SearchFieldDataType.String, sortable=True),
        SearchField(
            name="embedding",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=settings.azure_openai_embedding_dim,
            vector_search_profile_name=_HNSW_PROFILE,
        ),
    ]

    vector_search = VectorSearch(
        algorithms=[HnswAlgorithmConfiguration(name=_HNSW_ALGORITHM)],
        profiles=[
            VectorSearchProfile(
                name=_HNSW_PROFILE,
                algorithm_configuration_name=_HNSW_ALGORITHM,
            )
        ],
    )

    return SearchIndex(name=name, fields=fields, vector_search=vector_search)


async def ensure_index(tenant_id: str) -> str:
    """Create the tenant's chunks index if it doesn't already exist.

    Idempotent and safe under concurrent callers — if two workers race the
    create, the loser's ``ResourceExistsError`` is caught and treated as
    success. Returns the index name.

    Raises:
        ServiceUnavailableError: Search not configured or transport failure
            on the create call (other than the benign already-exists race).
    """
    name = index_name_for(tenant_id)
    if name in _KNOWN_INDEXES:
        return name

    definition = _build_index_definition(name)

    try:
        async with _index_client() as client:
            await client.create_index(definition)
        logger.info("Created AI Search index: %s", name)
    except ResourceExistsError:
        # Concurrent worker won the race. Fine — the schema is the same.
        logger.debug("AI Search index already exists: %s", name)
    except HttpResponseError as exc:
        # 409 Conflict shows up here too on some SDK versions when the index
        # already exists. Treat that as success; everything else propagates.
        if getattr(exc, "status_code", None) == 409:
            logger.debug("AI Search index already exists (409): %s", name)
        else:
            logger.exception("Failed to create AI Search index %s", name)
            raise ServiceUnavailableError(
                f"Could not create AI Search index {name}: {exc}"
            ) from exc

    _KNOWN_INDEXES.add(name)
    return name


# ── Data operations ─────────────────────────────────────────────────────────


async def upsert_chunks(
    *,
    tenant_id: str,
    documents: list[dict[str, Any]],
) -> int:
    """Upsert chunk documents to the tenant's index.

    ``documents`` are plain dicts matching the index schema (see
    :func:`_build_index_definition`). The ``id`` field is the merge key —
    matching ids overwrite, new ids insert.

    Returns the number of documents the service confirmed succeeded. A
    partial-failure response (some succeeded, some didn't) raises
    ServiceUnavailableError so the worker can retry the whole batch.

    Empty input short-circuits without an HTTP call.

    Raises:
        ServiceUnavailableError: Search not configured, transport failure,
            or any document in the batch failed.
    """
    if not documents:
        return 0

    name = index_name_for(tenant_id)
    try:
        async with _data_client(name) as client:
            results = await client.merge_or_upload_documents(documents=documents)
    except HttpResponseError as exc:
        logger.exception(
            "AI Search upsert failed: index=%s docs=%d", name, len(documents)
        )
        raise ServiceUnavailableError(
            f"AI Search upsert failed for index {name}: {exc}"
        ) from exc

    succeeded = sum(1 for r in results if getattr(r, "succeeded", False))
    if succeeded != len(documents):
        # Mixed outcome — log enough detail to debug (the failing keys),
        # then refuse to claim the write was successful. SB redelivers the
        # whole batch; idempotent because upsert overwrites.
        failures = [
            {"key": getattr(r, "key", "?"), "error": getattr(r, "error_message", "")}
            for r in results
            if not getattr(r, "succeeded", False)
        ]
        logger.error(
            "AI Search upsert partial failure: index=%s ok=%d/%d failures=%s",
            name,
            succeeded,
            len(documents),
            failures,
        )
        raise ServiceUnavailableError(
            f"AI Search upsert: {succeeded}/{len(documents)} succeeded for {name}"
        )

    logger.info("AI Search upserted %d chunks into %s", succeeded, name)
    return succeeded


async def delete_for_document(
    *,
    tenant_id: str,
    document_id: str,
) -> int:
    """Delete every chunk document for ``document_id`` from the tenant's index.

    AI Search has no delete-by-filter. We page through ``document_id``
    matches collecting keys, then submit a batch delete. Returns the number
    deleted. Returns 0 (without raising) if the index doesn't exist yet —
    that's the normal state for a tenant's first vectorization.

    Raises:
        ServiceUnavailableError: Search not configured, transport failure,
            or any delete in the batch failed.
    """
    name = index_name_for(tenant_id)

    try:
        async with _data_client(name) as client:
            keys = await _collect_chunk_ids(client, document_id=document_id)
            if not keys:
                return 0
            results = await client.delete_documents(
                documents=[{"id": k} for k in keys]
            )
    except ResourceNotFoundError:
        # Index doesn't exist yet (first vectorization for this tenant) —
        # nothing to delete. Not an error.
        logger.debug(
            "AI Search delete skipped: index %s does not exist yet", name
        )
        return 0
    except HttpResponseError as exc:
        # Some SDK paths surface "index not found" as a 404 HttpResponseError
        # rather than ResourceNotFoundError. Treat it the same way.
        if getattr(exc, "status_code", None) == 404:
            logger.debug(
                "AI Search delete skipped (404): index %s does not exist yet", name
            )
            return 0
        logger.exception(
            "AI Search delete failed: index=%s document=%s",
            name,
            document_id,
        )
        raise ServiceUnavailableError(
            f"AI Search delete failed for {document_id} in {name}: {exc}"
        ) from exc

    succeeded = sum(1 for r in results if getattr(r, "succeeded", False))
    if succeeded != len(keys):
        failures = [
            getattr(r, "error_message", "") for r in results
            if not getattr(r, "succeeded", False)
        ]
        logger.error(
            "AI Search delete partial failure: index=%s document=%s ok=%d/%d failures=%s",
            name,
            document_id,
            succeeded,
            len(keys),
            failures,
        )
        raise ServiceUnavailableError(
            f"AI Search delete: {succeeded}/{len(keys)} succeeded for {document_id}"
        )

    logger.info(
        "AI Search deleted %d chunks for document=%s from %s",
        succeeded,
        document_id,
        name,
    )
    return succeeded


async def _collect_chunk_ids(
    client: SearchClient,
    *,
    document_id: str,
) -> list[str]:
    """Page through search results gathering ``id`` for one document.

    Uses ``select=id`` so the response payload is small and ``$filter`` so
    the service does the matching. Page size 1000 is the AI Search max.
    """
    keys: list[str] = []
    paged = await client.search(
        search_text="*",
        filter=f"document_id eq '{_escape_odata(document_id)}'",
        select=["id"],
        top=1000,
    )
    async for result in paged:
        chunk_id = result.get("id") if isinstance(result, dict) else None
        if isinstance(chunk_id, str):
            keys.append(chunk_id)
    return keys


def _escape_odata(value: str) -> str:
    """Escape a single string literal for an OData filter expression.

    Single quotes are the only character that needs escaping inside
    ``'...'`` literals; doubled-up single quotes are the OData-spec escape.
    Document ids are ``doc_<uuid hex>`` so this is mostly defence-in-depth,
    but free.
    """
    return value.replace("'", "''")


# ── Retrieval (Sprint 3.5) ──────────────────────────────────────────────────


from dataclasses import dataclass  # noqa: E402  — kept near the dataclass it defines


@dataclass(frozen=True, slots=True)
class RetrievedChunk:
    """One chunk returned by :func:`search_chunks` with its relevance score.

    Field names match the index schema (see :func:`_build_index_definition`)
    so a caller can serialize this straight into a tool response or LLM
    grounding payload.
    """

    chunk_id: str
    chunk_index: int
    document_id: str
    text: str
    topic_ids: list[str]
    score: float


async def search_chunks(
    *,
    tenant_id: str,
    workspace_id: str,
    topic_ids: list[str] | None = None,
    query_text: str | None = None,
    query_vector: list[float] | None = None,
    top_k: int = 5,
) -> list[RetrievedChunk]:
    """Search the tenant's chunks index, returning the top relevance hits.

    Search mode is chosen by which inputs are populated:

    - ``query_vector`` only          → pure vector k-NN (semantic).
    - ``query_text`` only            → BM25 keyword search (lexical fallback,
      useful for exact-phrase questions Sprint 3 may want).
    - Both                           → hybrid: AI Search combines text +
      vector scores via the index's default fusion. Best default for
      open-ended student queries.
    - Neither                        → returns ``[]`` immediately. Refusing
      to issue a wildcard ``*`` search is intentional — it would return
      arbitrary chunks and is almost always a caller bug.

    Filters are AND-composed against the index. ``workspace_id`` is
    ALWAYS applied (defence in depth even though the index is per-tenant).
    ``topic_ids`` are OR-composed via ``topic_ids/any(t: t eq '...')`` —
    a chunk that touches ANY of the requested topics is a match.

    Args:
        tenant_id: routes to the tenant's per-tenant chunks index.
        workspace_id: hard filter — only this workspace's chunks come back.
        topic_ids: optional subset of canonical topic ids to constrain to.
            Empty / None = no topic constraint.
        query_text: optional. If set, runs BM25 over the ``text`` field.
        query_vector: optional. If set, runs k-NN over the ``embedding``
            field. Length MUST match the index dim
            (``settings.azure_openai_embedding_dim``) — Search rejects
            mismatches with a 400.
        top_k: how many hits to return. Capped at 50 by the SDK; we bound
            at 50 here too for predictability.

    Returns:
        List of :class:`RetrievedChunk` ordered by relevance (highest
        score first). Empty list if no inputs are provided OR if the
        index doesn't exist yet (e.g. workspace has had no documents
        successfully vectorize).

    Raises:
        ServiceUnavailableError: Search not configured or transport
            failure on the search call. ``ResourceNotFoundError`` (index
            doesn't exist) is caught and converted to an empty list — that's
            a normal "empty workspace" state, not an error.
    """
    if not query_text and not query_vector:
        return []
    if top_k < 1:
        return []
    top_k = min(top_k, 50)

    name = index_name_for(tenant_id)
    filter_expr = _build_filter(workspace_id=workspace_id, topic_ids=topic_ids or [])

    try:
        async with _data_client(name) as client:
            kwargs: dict[str, Any] = {
                "filter": filter_expr,
                "select": [
                    "id",
                    "chunk_index",
                    "document_id",
                    "text",
                    "topic_ids",
                ],
                "top": top_k,
            }
            if query_text:
                kwargs["search_text"] = query_text
            if query_vector is not None:
                # Import locally so module import doesn't require the model
                # being present (eases unit testing of error paths).
                from azure.search.documents.models import VectorizedQuery

                # azure-search-documents 11.7.0b2 renamed the legacy
                # ``k_nearest_neighbors`` kwarg to ``k`` — the SDK now
                # logs a "not a known attribute" warning and silently
                # drops the legacy name, defaulting the k-NN limit to
                # the index max. Pass ``k`` explicitly so the vector
                # leg honours ``top_k``.
                kwargs["vector_queries"] = [
                    VectorizedQuery(
                        vector=list(query_vector),
                        k=top_k,
                        fields="embedding",
                    )
                ]

            paged = await client.search(**kwargs)
            out: list[RetrievedChunk] = []
            async for raw in paged:
                out.append(_row_to_chunk(raw))
            logger.info(
                "AI Search query: index=%s topics=%d text=%s vector=%s hits=%d",
                name,
                len(topic_ids or []),
                bool(query_text),
                query_vector is not None,
                len(out),
            )
            return out
    except ResourceNotFoundError:
        logger.debug(
            "AI Search retrieval: index %s does not exist yet — returning []",
            name,
        )
        return []
    except HttpResponseError as exc:
        if getattr(exc, "status_code", None) == 404:
            logger.debug(
                "AI Search retrieval (404): index %s does not exist yet", name
            )
            return []
        logger.exception("AI Search retrieval failed: index=%s", name)
        raise ServiceUnavailableError(
            f"AI Search retrieval failed for index {name}: {exc}"
        ) from exc


def _row_to_chunk(raw: Any) -> RetrievedChunk:
    """Project one AI Search hit (dict-like or object) into a RetrievedChunk.

    The SDK returns both shapes depending on serialization mode — guard
    against both rather than assuming dict access works. AI Search puts
    the relevance score under the special ``@search.score`` key.
    """
    if hasattr(raw, "get"):

        def field(name: str, default: Any = None) -> Any:
            return raw.get(name, default)

    else:

        def field(name: str, default: Any = None) -> Any:
            return getattr(raw, name, default)

    score = field("@search.score", 0.0) or 0.0
    return RetrievedChunk(
        chunk_id=field("id"),
        chunk_index=int(field("chunk_index", 0) or 0),
        document_id=field("document_id"),
        text=field("text") or "",
        topic_ids=list(field("topic_ids") or []),
        score=float(score),
    )


def _build_filter(*, workspace_id: str, topic_ids: list[str]) -> str:
    """Assemble the OData filter for :func:`search_chunks`.

    Pulled out so unit tests can verify the filter shape without standing
    up the whole search call. ``workspace_id`` is always present; the
    ``topic_ids`` clause is appended only when ids are supplied.
    """
    parts = [f"workspace_id eq '{_escape_odata(workspace_id)}'"]
    if topic_ids:
        # OData ``any`` over a collection field. Build one ``t eq '<id>'``
        # disjunct per requested topic.
        ored = " or ".join(
            f"t eq '{_escape_odata(tid)}'" for tid in topic_ids
        )
        parts.append(f"topic_ids/any(t: {ored})")
    return " and ".join(parts)


# ── Helpers used by the vectorization service ───────────────────────────────


def chunk_to_index_doc(
    *,
    chunk_id: str,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    chunk_index: int,
    text: str,
    topic_ids: Iterable[str],
    chunker_version: str,
    embedding_model: str,
    embedding: list[float],
    created_at: str,
) -> dict[str, Any]:
    """Build the dict shape ``upsert_chunks`` expects from one chunk.

    Pulled out of ``vectorization.py`` so the schema-coupled construction
    sits next to the schema definition above. Tests can call this directly
    to verify shape without standing up the whole vectorizer.
    """
    return {
        "id": chunk_id,
        "tenant_id": tenant_id,
        "workspace_id": workspace_id,
        "document_id": document_id,
        "chunk_index": chunk_index,
        "text": text,
        "topic_ids": list(topic_ids),
        "chunker_version": chunker_version,
        "embedding_model": embedding_model,
        "embedding": embedding,
        "created_at": created_at,
    }
