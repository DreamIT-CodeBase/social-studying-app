"""Unit tests for the vectorization worker handler.

Each test exercises one branch of the state machine in
``app.workers.vectorization._handle``. Service Bus, Cosmos, and the
vectorization service are all mocked.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.exceptions import ServiceUnavailableError
from app.models.document import DocumentStatus
from app.services.vectorization import DocumentNotFound, VectorizeOutcome
from app.services.vectorization_queue import (
    ReceivedVectorizationMessage,
    VectorizationMessage,
)
from app.workers import vectorization as worker


def _payload(**overrides) -> VectorizationMessage:
    base = dict(
        document_id="doc_abc",
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        chunk_count=3,
    )
    base.update(overrides)
    return VectorizationMessage(**base)


def _msg(payload=None, delivery_count=1) -> ReceivedVectorizationMessage:
    return ReceivedVectorizationMessage(
        payload=payload or _payload(),
        delivery_count=delivery_count,
        _receiver=MagicMock(),
        _raw=MagicMock(),
    )


def _outcome(
    *,
    read: int = 3,
    indexed: int = 3,
    deleted: int = 0,
    model: str = "text-embedding-3-small",
    topics: int = 1,
    workspace_missing: bool = False,
) -> VectorizeOutcome:
    return VectorizeOutcome(
        chunks_read=read,
        chunks_indexed=indexed,
        deleted_stale=deleted,
        embedding_model=model,
        topic_ids_resolved=topics,
        workspace_missing=workspace_missing,
    )


def _mock_collection():
    col = MagicMock()
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    return col


# ── Happy path ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_handle_happy_path_writes_vector_count_and_advances_to_ready():
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.vectorization.get_collection", return_value=col),
        patch(
            "app.workers.vectorization.vectorization.vectorize_document",
            AsyncMock(return_value=_outcome(read=3, indexed=3, deleted=2)),
        ) as mock_vec,
    ):
        await worker._handle(msg)

    mock_vec.assert_awaited_once_with(
        tenant_id="ten_abc",
        workspace_id="wsp_abc",
        document_id="doc_abc",
    )

    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [
        DocumentStatus.vectorizing.value,
        DocumentStatus.ready.value,
    ]

    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert final_update["vector_count"] == 3
    assert final_update["embedding_model"] == "text-embedding-3-small"
    assert "vectorization_completed_at" in final_update
    assert final_update["processing_error"] is None


# ── Empty chunks: still advances to ready with vector_count=0 ────────────────


@pytest.mark.asyncio
async def test_handle_empty_chunks_advances_with_zero_vectors():
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.vectorization.get_collection", return_value=col),
        patch(
            "app.workers.vectorization.vectorization.vectorize_document",
            AsyncMock(return_value=_outcome(read=0, indexed=0)),
        ),
    ):
        await worker._handle(msg)

    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert final_update["vector_count"] == 0
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses[-1] == DocumentStatus.ready.value


# ── Permanent failure: doc missing → DLQ + status=failed ────────────────────


@pytest.mark.asyncio
async def test_handle_document_not_found_marks_failed_and_dead_letters():
    msg = _msg()
    msg._receiver.dead_letter_message = AsyncMock()
    col = _mock_collection()

    with (
        patch("app.workers.vectorization.get_collection", return_value=col),
        patch(
            "app.workers.vectorization.vectorization.vectorize_document",
            AsyncMock(side_effect=DocumentNotFound("doc gone")),
        ),
    ):
        await worker._handle(msg)

    msg._receiver.dead_letter_message.assert_awaited_once()
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [
        DocumentStatus.vectorizing.value,
        DocumentStatus.failed.value,
    ]
    final_update = col.update_one.await_args_list[-1].args[1]["$set"]
    assert "Document not found" in final_update["processing_error"]


# ── Transient failure: ServiceUnavailable propagates so SB redelivers ───────


@pytest.mark.asyncio
async def test_handle_transient_service_unavailable_propagates():
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.vectorization.get_collection", return_value=col),
        patch(
            "app.workers.vectorization.vectorization.vectorize_document",
            AsyncMock(side_effect=ServiceUnavailableError("OpenAI 503")),
        ),
    ):
        with pytest.raises(ServiceUnavailableError):
            await worker._handle(msg)

    # Status was set to vectorizing but never advanced — SB will redeliver.
    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses == [DocumentStatus.vectorizing.value]


# ── Workspace-missing flag passes through to logging without failing ────────


@pytest.mark.asyncio
async def test_handle_workspace_missing_outcome_still_advances():
    """The orchestrator returns workspace_missing=True; worker still ready."""
    msg = _msg()
    col = _mock_collection()

    with (
        patch("app.workers.vectorization.get_collection", return_value=col),
        patch(
            "app.workers.vectorization.vectorization.vectorize_document",
            AsyncMock(
                return_value=_outcome(
                    read=2, indexed=2, topics=0, workspace_missing=True
                )
            ),
        ),
    ):
        await worker._handle(msg)

    statuses = [
        call.args[1]["$set"]["status"]
        for call in col.update_one.await_args_list
    ]
    assert statuses[-1] == DocumentStatus.ready.value
