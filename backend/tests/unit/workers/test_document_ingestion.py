"""Unit tests for the document ingestion worker handler.

Each test exercises one branch of the state machine in
``app.workers.document_ingestion._handle``. Service Bus, blob storage,
Document Intelligence, Content Safety, and Cosmos are all mocked.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from azure.core.exceptions import HttpResponseError, ResourceNotFoundError

from app.models.document import DocumentStatus
from app.models.moderation import ModerationAction
from app.services.content_safety import SafetyVerdict
from app.services.document_intelligence import ExtractedDocument
from app.services.document_queue import ExtractionMessage, ReceivedExtractionMessage
from app.workers import document_ingestion


def _clean_verdict() -> SafetyVerdict:
    return SafetyVerdict(
        severities={"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0},
        flagged_categories=[],
    )


def _flagged_verdict(category: str = "Hate", severity: int = 4) -> SafetyVerdict:
    sevs = {"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0}
    sevs[category] = severity
    return SafetyVerdict(severities=sevs, flagged_categories=[category])


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


def _msg(
    payload: ExtractionMessage | None = None, delivery_count: int = 1
) -> ReceivedExtractionMessage:
    return ReceivedExtractionMessage(
        payload=payload or _payload(),
        delivery_count=delivery_count,
        _receiver=MagicMock(),
        _raw=MagicMock(),
    )


def _mock_collection_with_match():
    col = MagicMock()
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    col.insert_one = AsyncMock(return_value=MagicMock(inserted_id="x"))
    return col


def _collection_router():
    """Build a router that returns separate mocks for documents vs moderation_log.

    The handler calls ``get_collection(tenant_id, DOCUMENTS)`` for status updates
    and ``get_collection(tenant_id, MODERATION_LOG)`` for audit writes. Tests
    care about both — return distinct mocks so we can assert on each.
    """
    docs = MagicMock()
    docs.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    logs = MagicMock()
    logs.insert_one = AsyncMock(return_value=MagicMock(inserted_id="mod_x"))

    from app.core.database import DOCUMENTS, MODERATION_LOG

    def _route(_tenant_id, collection):
        if collection == DOCUMENTS:
            return docs
        if collection == MODERATION_LOG:
            return logs
        raise AssertionError(f"Unexpected collection: {collection}")

    return docs, logs, _route


# ── Happy path ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_handle_happy_path_transitions_pending_to_text_extracted():
    msg = _msg()
    docs, logs, route = _collection_router()

    extracted = ExtractedDocument(text="hello world", page_count=2, languages=["en"])

    with (
        patch("app.workers.document_ingestion.get_collection", side_effect=route),
        patch(
            "app.workers.document_ingestion.blob_storage.create_blob_read_url",
            return_value="https://example.com/blob.pdf",
        ) as mock_url,
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text_from_url",
            AsyncMock(return_value=extracted),
        ) as mock_extract,
        patch(
            "app.workers.document_ingestion.blob_storage.upload_extracted_text",
            AsyncMock(return_value="ten_abc/wsp_abc/extracted-text/doc_abc.txt"),
        ) as mock_upload_text,
        patch(
            "app.workers.document_ingestion.content_safety.analyze_extracted_text",
            AsyncMock(return_value=_clean_verdict()),
        ) as mock_scan,
        patch(
            "app.workers.document_ingestion.publish_topic_message",
            AsyncMock(),
        ) as mock_publish,
    ):
        await document_ingestion._handle(msg)

    mock_url.assert_called_once_with(msg.payload.blob_path)
    mock_extract.assert_awaited_once_with("https://example.com/blob.pdf")
    mock_upload_text.assert_awaited_once()
    mock_scan.assert_awaited_once_with("hello world")

    # Two doc updates: status=extracting at start, status=text_extracted at end.
    assert docs.update_one.await_count == 2
    statuses = [call.args[1]["$set"]["status"] for call in docs.update_one.await_args_list]
    assert statuses == [DocumentStatus.extracting.value, DocumentStatus.text_extracted.value]

    # Final update carries the extracted-text metadata.
    final_update = docs.update_one.await_args_list[-1].args[1]["$set"]
    assert final_update["text_char_count"] == len("hello world")
    assert final_update["page_count"] == 2
    assert final_update["languages"] == ["en"]
    assert "extracted_text_blob_path" in final_update
    assert final_update.get("moderation_flagged") is not True

    # Audit log: one auto_approved entry on the happy path.
    logs.insert_one.assert_awaited_once()
    log_doc = logs.insert_one.await_args.args[0]
    assert log_doc["action"] == ModerationAction.auto_approved.value
    assert log_doc["target_type"] == "document"
    assert log_doc["target_id"] == msg.payload.document_id
    assert log_doc["flagged_categories"] == []
    assert log_doc["severities"] == {"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0}

    # Sprint 2.5 hand-off — clean docs trigger the topic worker.
    mock_publish.assert_awaited_once()
    handoff = mock_publish.await_args.args[0]
    assert handoff.document_id == msg.payload.document_id
    assert handoff.tenant_id == msg.payload.tenant_id
    assert handoff.workspace_id == msg.payload.workspace_id
    assert handoff.extracted_text_blob_path == "ten_abc/wsp_abc/extracted-text/doc_abc.txt"


@pytest.mark.asyncio
async def test_handle_scraped_plain_text_bypasses_document_intelligence():
    msg = _msg(_payload(content_type="text/plain", blob_path="ten/wsp/doc/page.txt"))
    docs, logs, route = _collection_router()

    with (
        patch("app.workers.document_ingestion.get_collection", side_effect=route),
        patch(
            "app.workers.document_ingestion.blob_storage.download_document",
            AsyncMock(return_value=b"  Article heading\\nUseful study text  "),
        ),
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text",
            AsyncMock(),
        ) as mock_extract,
        patch(
            "app.workers.document_ingestion.blob_storage.upload_extracted_text",
            AsyncMock(return_value="extracted/doc.txt"),
        ) as mock_upload,
        patch(
            "app.workers.document_ingestion.content_safety.analyze_extracted_text",
            AsyncMock(return_value=_clean_verdict()),
        ),
        patch("app.workers.document_ingestion.publish_topic_message", AsyncMock()),
    ):
        await document_ingestion._handle(msg)

    mock_extract.assert_not_awaited()
    mock_upload.assert_awaited_once_with(
        tenant_id=msg.payload.tenant_id,
        workspace_id=msg.payload.workspace_id,
        document_id=msg.payload.document_id,
        text="Article heading\\nUseful study text",
    )
    assert (
        docs.update_one.await_args_list[-1].args[1]["$set"]["status"]
        == DocumentStatus.text_extracted.value
    )


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
            "app.workers.document_ingestion.blob_storage.create_blob_read_url",
            return_value="https://example.com/blob.pdf",
        ),
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text_from_url",
            AsyncMock(side_effect=error),
        ),
    ):
        await document_ingestion._handle(msg)

    msg._receiver.dead_letter_message.assert_awaited_once()
    # Two status writes: extracting, then failed.
    statuses = [call.args[1]["$set"]["status"] for call in col.update_one.await_args_list]
    assert statuses == [DocumentStatus.extracting.value, DocumentStatus.failed.value]
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert "Document Intelligence rejected" in final_update["processing_error"]


# ── Permanent failure: missing blob → dead-letter + status=failed ────────────


@pytest.mark.asyncio
async def test_handle_blob_not_found_marks_failed_and_dead_letters():
    msg = _msg(_payload(content_type="text/plain"))
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
    statuses = [call.args[1]["$set"]["status"] for call in col.update_one.await_args_list]
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
            "app.workers.document_ingestion.blob_storage.create_blob_read_url",
            return_value="https://example.com/blob.pdf",
        ),
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text_from_url",
            AsyncMock(side_effect=error),
        ),
        pytest.raises(HttpResponseError),
    ):
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


# ── Content safety: flagged path (Sprint 2.4) ────────────────────────────────


@pytest.mark.asyncio
async def test_handle_content_safety_flagged_sets_status_flagged_and_logs():
    """When content safety flags, the doc lands at status=flagged with audit."""
    msg = _msg()
    docs, logs, route = _collection_router()

    extracted = ExtractedDocument(text="some objectionable passage", page_count=3, languages=["en"])
    flagged = _flagged_verdict(category="Hate", severity=4)

    with (
        patch("app.workers.document_ingestion.get_collection", side_effect=route),
        patch(
            "app.workers.document_ingestion.blob_storage.create_blob_read_url",
            return_value="https://example.com/blob.pdf",
        ),
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text_from_url",
            AsyncMock(return_value=extracted),
        ),
        patch(
            "app.workers.document_ingestion.blob_storage.upload_extracted_text",
            AsyncMock(return_value="ten_abc/wsp_abc/extracted-text/doc_abc.txt"),
        ),
        patch(
            "app.workers.document_ingestion.content_safety.analyze_extracted_text",
            AsyncMock(return_value=flagged),
        ),
        patch(
            "app.workers.document_ingestion.publish_topic_message",
            AsyncMock(),
        ) as mock_publish,
    ):
        await document_ingestion._handle(msg)

    # Flagged docs do NOT advance to topic extraction.
    mock_publish.assert_not_awaited()

    statuses = [call.args[1]["$set"]["status"] for call in docs.update_one.await_args_list]
    assert statuses == [DocumentStatus.extracting.value, DocumentStatus.flagged.value]

    final_update = docs.update_one.await_args_list[-1].args[1]["$set"]
    assert final_update["moderation_flagged"] is True
    # Even on a flagged doc we still persist the text blob + metadata so admins
    # can read the offending content during review.
    assert "extracted_text_blob_path" in final_update
    assert final_update["text_char_count"] == len("some objectionable passage")

    # Audit log: action=flagged with category list + severities.
    logs.insert_one.assert_awaited_once()
    log_doc = logs.insert_one.await_args.args[0]
    assert log_doc["action"] == ModerationAction.flagged.value
    assert log_doc["flagged_categories"] == ["Hate"]
    assert log_doc["severities"]["Hate"] == 4
    assert log_doc["reason"] == "Hate"


@pytest.mark.asyncio
async def test_handle_content_safety_transient_error_propagates():
    """A Content Safety 503 must bubble so Service Bus redelivers — the doc
    must NOT advance past extracting under any circumstances when the
    moderation gate hasn't actually been crossed.
    """
    msg = _msg()
    docs, _logs, route = _collection_router()

    extracted = ExtractedDocument(text="hi", page_count=1, languages=["en"])

    with (
        patch("app.workers.document_ingestion.get_collection", side_effect=route),
        patch(
            "app.workers.document_ingestion.blob_storage.create_blob_read_url",
            return_value="https://example.com/blob.pdf",
        ),
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text_from_url",
            AsyncMock(return_value=extracted),
        ),
        patch(
            "app.workers.document_ingestion.blob_storage.upload_extracted_text",
            AsyncMock(return_value="ten_abc/wsp_abc/extracted-text/doc_abc.txt"),
        ),
        patch(
            "app.workers.document_ingestion.content_safety.analyze_extracted_text",
            AsyncMock(side_effect=HttpResponseError(message="503")),
        ),
        pytest.raises(HttpResponseError),
    ):
        await document_ingestion._handle(msg)

    # Only the extracting transition fired; no text_extracted or flagged write.
    statuses = [call.args[1]["$set"]["status"] for call in docs.update_one.await_args_list]
    assert statuses == [DocumentStatus.extracting.value]


@pytest.mark.asyncio
async def test_handle_moderation_log_write_failure_does_not_crash():
    """If the audit log write fails, the document state is already correct —
    don't re-raise and trigger a costly redelivery.
    """
    msg = _msg()
    docs, logs, route = _collection_router()
    logs.insert_one = AsyncMock(side_effect=RuntimeError("cosmos down"))

    extracted = ExtractedDocument(text="hello world", page_count=1, languages=["en"])

    with (
        patch("app.workers.document_ingestion.get_collection", side_effect=route),
        patch(
            "app.workers.document_ingestion.blob_storage.create_blob_read_url",
            return_value="https://example.com/blob.pdf",
        ),
        patch(
            "app.workers.document_ingestion.document_intelligence.extract_text_from_url",
            AsyncMock(return_value=extracted),
        ),
        patch(
            "app.workers.document_ingestion.blob_storage.upload_extracted_text",
            AsyncMock(return_value="ten_abc/wsp_abc/extracted-text/doc_abc.txt"),
        ),
        patch(
            "app.workers.document_ingestion.content_safety.analyze_extracted_text",
            AsyncMock(return_value=_clean_verdict()),
        ),
    ):
        await document_ingestion._handle(msg)  # must not raise

    # Document still made it to text_extracted.
    statuses = [call.args[1]["$set"]["status"] for call in docs.update_one.await_args_list]
    assert statuses[-1] == DocumentStatus.text_extracted.value
