"""Permanent deletion of an uploaded study material and its derived data.

Deleting only the ``documents`` row leaves the original upload in Blob
Storage and searchable text in Cosmos / Azure AI Search. This service owns the
complete, idempotent purge used by the document DELETE endpoint.
"""

from __future__ import annotations

import asyncio
import logging

from app.core.database import (
    ADAPTIVE_SESSIONS,
    CHUNKS,
    DOCUMENTS,
    FLASHCARD_RATINGS,
    FLASHCARDS,
    INTERACTIONS,
    MODERATION_LOG,
    QUESTION_QUEUE,
    WORKSPACES,
    get_collection,
)
from app.models.base import utc_now
from app.models.document import Document
from app.models.workspace import Taxonomy, Workspace
from app.services import azure_ai_search, blob_storage, question_pipeline
from app.services.cosmos_retry import run_with_throttle_retry

logger = logging.getLogger(__name__)

_MAX_RELATED_IDS = 10_000
_MAX_WORKSPACE_UPDATE_RETRIES = 4


async def purge_document(*, document: Document) -> None:
    """Erase a document from all stores that can retain its study content.

    Every operation is safe to retry. The API hides the source row before it
    calls this function, preventing new reads while the multi-store purge is in
    progress.
    """
    # Keep Cosmos operations sequential. These collections share a small RU
    # budget in dev; firing every delete concurrently causes predictable 429s.
    question_ids = await _related_ids(
        tenant_id=document.tenant_id,
        collection=QUESTION_QUEUE,
        workspace_id=document.workspace_id,
        document_id=document.id,
    )
    flashcard_ids = await _related_ids(
        tenant_id=document.tenant_id,
        collection=FLASHCARDS,
        workspace_id=document.workspace_id,
        document_id=document.id,
    )

    await asyncio.gather(
        blob_storage.delete_document(
            tenant_id=document.tenant_id,
            workspace_id=document.workspace_id,
            user_id=document.uploaded_by,
            document_id=document.id,
            filename=document.filename,
        ),
        blob_storage.delete_extracted_text(
            tenant_id=document.tenant_id,
            workspace_id=document.workspace_id,
            document_id=document.id,
        ),
        azure_ai_search.delete_for_document(
            tenant_id=document.tenant_id,
            document_id=document.id,
        ),
    )

    await _delete_direct_document_data(document=document)
    await _delete_derived_content(
        document=document,
        question_ids=question_ids,
        flashcard_ids=flashcard_ids,
    )
    await question_pipeline.invalidate_workspace_cache(workspace_id=document.workspace_id)
    await _remove_from_workspace(document=document)

    result = await run_with_throttle_retry(
        lambda: get_collection(document.tenant_id, DOCUMENTS).delete_one(
            {
                "_id": document.id,
                "workspace_id": document.workspace_id,
                "tenant_id": document.tenant_id,
            }
        ),
        operation_name=f"hard-delete document {document.id}",
    )
    if result.deleted_count != 1:
        raise RuntimeError(f"Document row disappeared during purge: {document.id}")

    logger.info(
        "Permanently purged document=%s workspace=%s tenant=%s",
        document.id,
        document.workspace_id,
        document.tenant_id,
    )


async def _related_ids(
    *,
    tenant_id: str,
    collection: str,
    workspace_id: str,
    document_id: str,
) -> list[str]:
    async def _fetch() -> list[dict]:
        cursor = get_collection(tenant_id, collection).find(
            {"workspace_id": workspace_id, "document_id": document_id},
            {"_id": 1},
        )
        return await cursor.to_list(length=_MAX_RELATED_IDS)

    rows = await run_with_throttle_retry(
        _fetch,
        operation_name=f"read related {collection} for {document_id}",
    )
    return [str(row["_id"]) for row in rows if row.get("_id")]


async def _delete_direct_document_data(*, document: Document) -> None:
    await run_with_throttle_retry(
        lambda: get_collection(document.tenant_id, CHUNKS).delete_many(
            {
                "workspace_id": document.workspace_id,
                "document_id": document.id,
            }
        ),
        operation_name=f"delete chunks for {document.id}",
    )


async def _delete_derived_content(
    *,
    document: Document,
    question_ids: list[str],
    flashcard_ids: list[str],
) -> None:
    tenant_id = document.tenant_id
    workspace_id = document.workspace_id
    target_ids = [document.id, *question_ids, *flashcard_ids]
    await _delete_many(
        tenant_id=tenant_id,
        collection=QUESTION_QUEUE,
        filter_={"workspace_id": workspace_id, "document_id": document.id},
        operation_name=f"delete questions for {document.id}",
    )
    await _delete_many(
        tenant_id=tenant_id,
        collection=FLASHCARDS,
        filter_={"workspace_id": workspace_id, "document_id": document.id},
        operation_name=f"delete flashcards for {document.id}",
    )
    await _delete_many(
        tenant_id=tenant_id,
        collection=MODERATION_LOG,
        filter_={"workspace_id": workspace_id, "target_id": {"$in": target_ids}},
        operation_name=f"delete moderation logs for {document.id}",
    )

    if question_ids:
        await _delete_many(
            tenant_id=tenant_id,
            collection=INTERACTIONS,
            filter_={"workspace_id": workspace_id, "question_id": {"$in": question_ids}},
            operation_name=f"delete interactions for {document.id}",
        )
    if flashcard_ids:
        await _delete_many(
            tenant_id=tenant_id,
            collection=FLASHCARD_RATINGS,
            filter_={"workspace_id": workspace_id, "flashcard_id": {"$in": flashcard_ids}},
            operation_name=f"delete flashcard ratings for {document.id}",
        )

    # A prepared plan is a snapshot that may contain legacy `batch_source`
    # questions whose real document was not recorded. Invalidate every
    # unfinished plan when the workspace source set changes; the learner can
    # immediately prepare a fresh session from the remaining documents.
    session_conditions: list[dict[str, object]] = [{"status": "prepared"}]
    if question_ids:
        session_conditions.append({"plan.questions.id": {"$in": question_ids}})
        session_conditions.append(
            {"plan.flashcards.id": {"$in": [f"derived_{item}" for item in question_ids]}}
        )
    if flashcard_ids:
        session_conditions.append({"plan.flashcards.id": {"$in": flashcard_ids}})
    await _delete_many(
        tenant_id=tenant_id,
        collection=ADAPTIVE_SESSIONS,
        filter_={"workspace_id": workspace_id, "$or": session_conditions},
        operation_name=f"delete adaptive sessions for {document.id}",
    )


async def _delete_many(
    *,
    tenant_id: str,
    collection: str,
    filter_: dict[str, object],
    operation_name: str,
) -> None:
    await run_with_throttle_retry(
        lambda: get_collection(tenant_id, collection).delete_many(filter_),
        operation_name=operation_name,
    )


async def _remove_from_workspace(*, document: Document) -> None:
    """Remove source references and decrement document_count under a CAS."""
    col = get_collection(document.tenant_id, WORKSPACES)
    for _ in range(_MAX_WORKSPACE_UPDATE_RETRIES):
        raw = await run_with_throttle_retry(
            lambda: col.find_one({"_id": document.workspace_id, "deleted_at": None}),
            operation_name=f"read workspace {document.workspace_id} during purge",
        )
        if raw is None:
            raise RuntimeError(
                f"Workspace not found during document purge: {document.workspace_id}"
            )

        workspace = Workspace.model_validate(raw)
        taxonomy = _taxonomy_without_document(workspace.taxonomy, document.id)
        expected_version = workspace.taxonomy_version
        taxonomy_dump = taxonomy.model_dump()
        result = await run_with_throttle_retry(
            lambda expected_version=expected_version, taxonomy_dump=taxonomy_dump: col.update_one(
                {
                    "_id": document.workspace_id,
                    "taxonomy_version": expected_version,
                },
                {
                    "$set": {
                        "taxonomy": taxonomy_dump,
                        "updated_at": utc_now(),
                    },
                    "$inc": {
                        "document_count": -1,
                        "taxonomy_version": 1,
                    },
                },
            ),
            operation_name=f"update workspace {document.workspace_id} during purge",
        )
        if result.matched_count == 1:
            return

    raise RuntimeError(
        f"Workspace changed repeatedly during document purge: {document.workspace_id}"
    )


def _taxonomy_without_document(taxonomy: Taxonomy, document_id: str) -> Taxonomy:
    retained = []
    removed_topic_ids: set[str] = set()
    for topic in taxonomy.topics:
        source_ids = [item for item in topic.source_document_ids if item != document_id]
        if not source_ids:
            removed_topic_ids.add(topic.id)
            continue
        retained.append(topic.model_copy(update={"source_document_ids": source_ids}))

    cleaned = [
        topic.model_copy(update={"parent_id": None})
        if topic.parent_id in removed_topic_ids
        else topic
        for topic in retained
    ]
    return Taxonomy(topics=cleaned, last_merged_at=taxonomy.last_merged_at)
