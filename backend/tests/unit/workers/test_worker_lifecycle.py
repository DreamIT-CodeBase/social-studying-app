"""Regression coverage for queue workers remaining alive while idle."""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from types import ModuleType
from unittest.mock import patch

import pytest

from app.workers import chunking, document_ingestion, topic_extraction, vectorization


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("worker", "consumer_path"),
    [
        (document_ingestion, "app.workers.document_ingestion.consume_extraction_messages"),
        (topic_extraction, "app.workers.topic_extraction.consume_topic_messages"),
        (chunking, "app.workers.chunking.consume_chunking_messages"),
        (vectorization, "app.workers.vectorization.consume_vectorization_messages"),
    ],
)
async def test_worker_reopens_the_receiver_after_an_idle_window(
    worker: ModuleType,
    consumer_path: str,
) -> None:
    """An empty receive must not let the Container App process exit."""
    opens = 0

    @asynccontextmanager
    async def empty_consumer(*, max_wait_seconds: int):
        nonlocal opens
        assert max_wait_seconds == 0
        opens += 1
        if opens == 2:
            raise asyncio.CancelledError

        async def no_messages():
            if False:
                yield None

        yield no_messages()

    with patch(consumer_path, empty_consumer), pytest.raises(asyncio.CancelledError):
        await worker.run_forever(max_wait_seconds=0)

    assert opens == 2
