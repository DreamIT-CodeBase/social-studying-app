"""Unit tests for permanent study-material deletion."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

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
)
from app.models.document import Document, DocumentType
from app.models.workspace import CanonicalTopic, Taxonomy, Workspace
from app.services.document_purge import _taxonomy_without_document, purge_document


class _Cursor:
    def __init__(self, rows: list[dict]) -> None:
        self.rows = rows

    async def to_list(self, *, length: int) -> list[dict]:
        return self.rows[:length]


def _document() -> Document:
    return Document(
        **{"_id": "doc_remove"},
        tenant_id="ten_test",
        workspace_id="wsp_test",
        uploaded_by="usr_owner",
        filename="wrong.pdf",
        blob_url="https://storage/wrong.pdf",
        file_size_bytes=123,
        doc_type=DocumentType.pdf,
    )


def _workspace() -> Workspace:
    return Workspace(
        **{"_id": "wsp_test"},
        tenant_id="ten_test",
        name="Study",
        document_count=2,
        taxonomy=Taxonomy(
            topics=[
                CanonicalTopic(
                    id="topic_remove",
                    name="Wrong topic",
                    source_document_ids=["doc_remove"],
                ),
                CanonicalTopic(
                    id="topic_keep",
                    name="Shared topic",
                    parent_id="topic_remove",
                    source_document_ids=["doc_remove", "doc_keep"],
                ),
            ]
        ),
        taxonomy_version=3,
    )


def _collection() -> MagicMock:
    col = MagicMock()
    col.delete_many = AsyncMock(return_value=MagicMock(deleted_count=1))
    col.delete_one = AsyncMock(return_value=MagicMock(deleted_count=1))
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    col.find_one = AsyncMock(return_value=None)
    col.find = MagicMock(return_value=_Cursor([]))
    return col


def test_taxonomy_without_document_drops_orphaned_topics_and_parent_edges():
    cleaned = _taxonomy_without_document(_workspace().taxonomy, "doc_remove")

    assert [topic.id for topic in cleaned.topics] == ["topic_keep"]
    assert cleaned.topics[0].source_document_ids == ["doc_keep"]
    assert cleaned.topics[0].parent_id is None


@pytest.mark.asyncio
async def test_purge_document_erases_all_material_content_and_source_references():
    collections = {
        name: _collection()
        for name in (
            ADAPTIVE_SESSIONS,
            CHUNKS,
            DOCUMENTS,
            FLASHCARD_RATINGS,
            FLASHCARDS,
            INTERACTIONS,
            MODERATION_LOG,
            QUESTION_QUEUE,
            WORKSPACES,
        )
    }
    collections[QUESTION_QUEUE].find.return_value = _Cursor(
        [{"_id": "que_1"}, {"_id": "que_2"}]
    )
    collections[FLASHCARDS].find.return_value = _Cursor([{"_id": "flc_1"}])
    collections[WORKSPACES].find_one.return_value = _workspace().model_dump(by_alias=True)

    def get_collection(_tenant_id: str, collection: str) -> MagicMock:
        return collections[collection]

    with (
        patch("app.services.document_purge.get_collection", side_effect=get_collection),
        patch(
            "app.services.document_purge.blob_storage.delete_document",
            AsyncMock(return_value=None),
        ) as delete_raw,
        patch(
            "app.services.document_purge.blob_storage.delete_extracted_text",
            AsyncMock(return_value=None),
        ) as delete_text,
        patch(
            "app.services.document_purge.azure_ai_search.delete_for_document",
            AsyncMock(return_value=4),
        ) as delete_search,
        patch(
            "app.services.document_purge.question_pipeline.invalidate_workspace_cache",
            AsyncMock(return_value=2),
        ) as invalidate_cache,
    ):
        await purge_document(document=_document())

    delete_raw.assert_awaited_once_with(
        tenant_id="ten_test",
        workspace_id="wsp_test",
        user_id="usr_owner",
        document_id="doc_remove",
        filename="wrong.pdf",
    )
    delete_text.assert_awaited_once_with(
        tenant_id="ten_test",
        workspace_id="wsp_test",
        document_id="doc_remove",
    )
    delete_search.assert_awaited_once_with(
        tenant_id="ten_test",
        document_id="doc_remove",
    )
    invalidate_cache.assert_awaited_once_with(workspace_id="wsp_test")
    collections[CHUNKS].delete_many.assert_awaited_once_with(
        {"workspace_id": "wsp_test", "document_id": "doc_remove"}
    )
    collections[QUESTION_QUEUE].delete_many.assert_awaited_once()
    collections[FLASHCARDS].delete_many.assert_awaited_once()

    moderation_filter = collections[MODERATION_LOG].delete_many.await_args.args[0]
    assert set(moderation_filter["target_id"]["$in"]) == {
        "doc_remove",
        "que_1",
        "que_2",
        "flc_1",
    }
    collections[INTERACTIONS].delete_many.assert_awaited_once()
    collections[FLASHCARD_RATINGS].delete_many.assert_awaited_once()
    collections[ADAPTIVE_SESSIONS].delete_many.assert_awaited_once()
    session_filter = collections[ADAPTIVE_SESSIONS].delete_many.await_args.args[0]
    assert {"status": "prepared"} in session_filter["$or"]

    workspace_update = collections[WORKSPACES].update_one.await_args.args[1]
    assert workspace_update["$inc"] == {
        "document_count": -1,
        "taxonomy_version": 1,
    }
    assert workspace_update["$set"]["taxonomy"]["topics"] == [
        {
            "id": "topic_keep",
            "name": "Shared topic",
            "aliases": [],
            "description": None,
            "complexity_level": None,
            "parent_id": None,
            "source_document_ids": ["doc_keep"],
        }
    ]
    collections[DOCUMENTS].delete_one.assert_awaited_once_with(
        {
            "_id": "doc_remove",
            "workspace_id": "wsp_test",
            "tenant_id": "ten_test",
        }
    )
