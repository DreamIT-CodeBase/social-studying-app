"""Unit tests for the document ingestion worker handler.

Each test exercises one branch of the state machine in
``app.workers.document_ingestion._handle``. Service Bus, blob storage,
Document Intelligence, and Cosmos are all mocked.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from azure.core.exceptions import HttpResponseError, ResourceNotFoundError

from app.models.document import DocumentStatus
from app.services.document_intelligence import ExtractedDocument
from app.services.document_queue import ExtractionMessage, ReceivedExtractionMessage
from app.workers import document_ingestion


def _payload(**overrides) -> ExtractionMessage:
    base = dict(
        document_id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        blob_path="ten_abc/wsp_abc/usr_abc/doc_abc/study.pdf",
        content_type="application/pdf",
        uploaded_by="usr_abc",
        uploaded_at="2026-05-08T10:00:00+00:00",
    )
    base.update(overrides)
    return ExtractionMessage(**base)


def _msg(payload: ExtractionMessage | None = None, delivery_count: int = 1) -> ReceivedExtractionMessage:
    return ReceivedExtractionMessage(
        payload=payload or _payload(),
        delivery_count=delivery_count,
        _receiver=MagicMock(),
        _raw=MagicMock(),
    )


def _mock_collection_with_match():
    col = MagicMock()
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    return col


# ── Happy path ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_handle_happy_path_transitions_pending_to_text_extracted():
    msg = _msg()
    col = _mock_collection_with_match()

    extracted = ExtractedDocument(text="hello world", page_count=2, languages=["en"])

    with (
        patch("app.workers.document_ingestion.get_collection", return_value=col),
        patch(
            "app.workers.document_ingestion.blob_storage.download_document",
            AsyncMock(return_value=b"%PDF-1.4 fake"),
        ) as mock_download,
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text",
            AsyncMock(return_value=extracted),
        ) as mock_extract,
        patch(
            "app.workers.document_ingestion.blob_storage.upload_extracted_text",
            AsyncMock(return_value="ten_abc/wsp_abc/extracted-text/doc_abc.txt"),
        ) as mock_upload_text,
    ):
        await document_ingestion._handle(msg)

    mock_download.assert_awaited_once_with(msg.payload.blob_path)
    mock_extract.assert_awaited_once_with(b"%PDF-1.4 fake", content_type="application/pdf")
    mock_upload_text.assert_awaited_once()

    # Two updates: status=extracting at start, status=text_extracted at end.
    assert col.update_one.await_count == 2
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [DocumentStatus.extracting.value, DocumentStatus.text_extracted.value]

    # Final update carries the extracted-text metadata.
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert final_update["text_char_count"] == len("hello world")
    assert final_update["page_count"] == 2
    assert final_update["languages"] == ["en"]
    assert "extracted_text_blob_path" in final_update


# ── Permanent failure: unsupported content → dead-letter + status=failed ─────


@pytest.mark.asyncio
async def test_handle_unsupported_content_marks_failed_and_dead_letters():
    msg = _msg()
    msg._receiver.dead_letter_message = AsyncMock()
    col = _mock_collection_with_match()

    # Build a Document Intelligence error with the magic 'UnsupportedContent' code.
    error = HttpResponseError(message="bad")
    error.error = MagicMock(code="InvalidRequest")
    error.error.details = [MagicMock(code="UnsupportedContent")]

    with (
        patch("app.workers.document_ingestion.get_collection", return_value=col),
        patch(
            "app.workers.document_ingestion.blob_storage.download_document",
            AsyncMock(return_value=b"corrupt"),
        ),
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text",
            AsyncMock(side_effect=error),
        ),
    ):
        await document_ingestion._handle(msg)

    msg._receiver.dead_letter_message.assert_awaited_once()
    # Two status writes: extracting, then failed.
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [DocumentStatus.extracting.value, DocumentStatus.failed.value]
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert "Document Intelligence rejected" in final_update["processing_error"]


# ── Permanent failure: missing blob → dead-letter + status=failed ────────────


@pytest.mark.asyncio
async def test_handle_blob_not_found_marks_failed_and_dead_letters():
    msg = _msg()
    msg._receiver.dead_letter_message = AsyncMock()
    col = _mock_collection_with_match()

    with (
        patch("app.workers.document_ingestion.get_collection", return_value=col),
        patch(
            "app.workers.document_ingestion.blob_storage.download_document",
            AsyncMock(side_effect=ResourceNotFoundError("blob gone")),
        ),
    ):
        await document_ingestion._handle(msg)

    msg._receiver.dead_letter_message.assert_awaited_once()
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [DocumentStatus.extracting.value, DocumentStatus.failed.value]


# ── Transient failure: DI 503 raises so caller can abandon ───────────────────


@pytest.mark.asyncio
async def test_handle_transient_di_error_propagates():
    """Non-permanent DI errors must propagate so the run loop abandons + retries."""
    msg = _msg()
    col = _mock_collection_with_match()

    error = HttpResponseError(message="service busy")
    error.error = MagicMock(code="ServiceBusy")
    error.error.details = []

    with (
        patch("app.workers.document_ingestion.get_collection", return_value=col),
        patch(
            "app.workers.document_ingestion.blob_storage.download_document",
            AsyncMock(return_value=b"ok"),
        ),
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text",
            AsyncMock(side_effect=error),
        ),
    ):
        with pytest.raises(HttpResponseError):
            await document_ingestion._handle(msg)


# ── _is_permanent classifier ─────────────────────────────────────────────────


def test_is_permanent_recognises_top_level_unsupported_content():
    err = HttpResponseError(message="x")
    err.error = MagicMock(code="UnsupportedContent", details=[])
    assert document_ingestion._is_permanent(err) is True


def test_is_permanent_recognises_nested_unsupported_content():
    err = HttpResponseError(message="x")
    err.error = MagicMock(
        code="InvalidRequest",
        details=[MagicMock(code="UnsupportedContent")],
    )
    assert document_ingestion._is_permanent(err) is True


def test_is_permanent_returns_false_for_transient_codes():
    err = HttpResponseError(message="x")
    err.error = MagicMock(code="ServiceBusy", details=[])
    assert document_ingestion._is_permanent(err) is False


def test_is_permanent_handles_missing_error_attr():
    err = HttpResponseError(message="x")
    err.error = None
    assert document_ingestion._is_permanent(err) is False
