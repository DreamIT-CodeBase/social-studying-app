"""Unit tests for the topic extraction worker handler.

Each test exercises one branch of the state machine in
``app.workers.topic_extraction._handle``. Service Bus, blob storage,
topic_extraction service, and Cosmos are all mocked.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from azure.core.exceptions import ResourceNotFoundError

from app.core.exceptions import ServiceUnavailableError
from app.models.document import DocumentStatus, TopicTag
from app.services.topic_queue import ReceivedTopicMessage, TopicExtractionMessage
from app.workers import topic_extraction as worker


def _payload(**overrides) -> TopicExtractionMessage:
    base = dict(
        document_id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        extracted_text_blob_path="ten_abc/wsp_abc/extracted-text/doc_abc.txt",
    )
    base.update(overrides)
    return TopicExtractionMessage(**base)


def _msg(payload=None, delivery_count=1) -> ReceivedTopicMessage:
    return ReceivedTopicMessage(
        payload=payload or _payload(),
        delivery_count=delivery_count,
        _receiver=MagicMock(),
        _raw=MagicMock(),
    )


def _mock_collection():
    col = MagicMock()
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    return col


# ── Happy path ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_handle_happy_path_writes_topics_and_advances_status():
    msg = _msg()
    col = _mock_collection()

    topics = [
        TopicTag(
            name="Photosynthesis",
            description="Plants make energy.",
            complexity_level=2,
            page_refs=[1, 3],
        ),
        TopicTag(name="Mitosis", complexity_level=3),
    ]

    with (
        patch("app.workers.topic_extraction.get_collection", return_value=col),
        patch(
            "app.workers.topic_extraction.blob_storage.download_document",
            AsyncMock(return_value=b"hello world"),
        ) as mock_download,
        patch(
            "app.workers.topic_extraction.topic_extraction.extract_topics",
            AsyncMock(return_value=topics),
        ) as mock_extract,
    ):
        await worker._handle(msg)

    mock_download.assert_awaited_once_with(msg.payload.extracted_text_blob_path)
    mock_extract.assert_awaited_once_with("hello world")

    # Two updates: extracting_topics, then topics_extracted.
    assert col.update_one.await_count == 2
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [
        DocumentStatus.extracting_topics.value,
        DocumentStatus.topics_extracted.value,
    ]

    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    persisted = final_update["topic_tags"]
    assert len(persisted) == 2
    assert persisted[0]["name"] == "Photosynthesis"
    assert persisted[0]["complexity_level"] == 2
    assert persisted[0]["page_refs"] == [1, 3]
    assert persisted[1]["name"] == "Mitosis"
    assert final_update["processing_error"] is None


# ── Empty topics still completes successfully ────────────────────────────────


@pytest.mark.asyncio
async def test_handle_empty_topics_list_still_advances_to_topics_extracted():
    """A cover-page doc with no topics is a valid outcome, not a failure."""
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.topic_extraction.get_collection", return_value=col),
        patch(
            "app.workers.topic_extraction.blob_storage.download_document",
            AsyncMock(return_value=b"cover page"),
        ),
        patch(
            "app.workers.topic_extraction.topic_extraction.extract_topics",
            AsyncMock(return_value=[]),
        ),
    ):
        await worker._handle(msg)

    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses[-1] == DocumentStatus.topics_extracted.value
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert final_update["topic_tags"] == []


# ── Permanent failure: missing blob → DLQ + status=failed ────────────────────


@pytest.mark.asyncio
async def test_handle_blob_not_found_marks_failed_and_dead_letters():
    msg = _msg()
    msg._receiver.dead_letter_message = AsyncMock()
    col = _mock_collection()

    with (
        patch("app.workers.topic_extraction.get_collection", return_value=col),
        patch(
            "app.workers.topic_extraction.blob_storage.download_document",
            AsyncMock(side_effect=ResourceNotFoundError("blob gone")),
        ),
    ):
        await worker._handle(msg)

    msg._receiver.dead_letter_message.assert_awaited_once()
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [
        DocumentStatus.extracting_topics.value,
        DocumentStatus.failed.value,
    ]
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert "Extracted text blob not found" in final_update["processing_error"]


# ── Permanent failure: prompt returned malformed JSON → DLQ ──────────────────


@pytest.mark.asyncio
async def test_handle_prompt_failure_marks_failed_and_dead_letters():
    """ValueError from extract_topics = the model returned malformed output.
    Retrying won't help, so dead-letter."""
    msg = _msg()
    msg._receiver.dead_letter_message = AsyncMock()
    col = _mock_collection()

    with (
        patch("app.workers.topic_extraction.get_collection", return_value=col),
        patch(
            "app.workers.topic_extraction.blob_storage.download_document",
            AsyncMock(return_value=b"hello"),
        ),
        patch(
            "app.workers.topic_extraction.topic_extraction.extract_topics",
            AsyncMock(side_effect=ValueError("missing 'topics' list")),
        ),
    ):
        await worker._handle(msg)

    msg._receiver.dead_letter_message.assert_awaited_once()
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses[-1] == DocumentStatus.failed.value
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert "Topic extraction prompt failure" in final_update["processing_error"]


# ── Transient failure: OpenAI 429/503 propagates so SB redelivers ────────────


@pytest.mark.asyncio
async def test_handle_transient_openai_error_propagates():
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.topic_extraction.get_collection", return_value=col),
        patch(
            "app.workers.topic_extraction.blob_storage.download_document",
            AsyncMock(return_value=b"hello"),
        ),
        patch(
            "app.workers.topic_extraction.topic_extraction.extract_topics",
            AsyncMock(side_effect=ServiceUnavailableError("OpenAI 503")),
        ),
    ):
        with pytest.raises(ServiceUnavailableError):
            await worker._handle(msg)

    # Status got set to extracting_topics, but no final write — the worker
    # is left "in flight" so Service Bus redelivers and we try again.
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [DocumentStatus.extracting_topics.value]


# ── Decode of non-UTF8 bytes uses errors="replace" (doesn't crash) ──────────


@pytest.mark.asyncio
async def test_handle_non_utf8_blob_does_not_crash():
    """Worker must not crash on stray non-UTF8 bytes (Document Intelligence
    output is UTF-8, but defense-in-depth)."""
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.topic_extraction.get_collection", return_value=col),
        patch(
            "app.workers.topic_extraction.blob_storage.download_document",
            AsyncMock(return_value=b"\xff\xfe broken \x80 bytes"),
        ),
        patch(
            "app.workers.topic_extraction.topic_extraction.extract_topics",
            AsyncMock(return_value=[]),
        ) as mock_extract,
    ):
        await worker._handle(msg)

    # Worker passed *some* string (with replacement chars) to extract_topics.
    mock_extract.assert_awaited_once()
    text_arg = mock_extract.await_args.args[0]
    assert isinstance(text_arg, str)
