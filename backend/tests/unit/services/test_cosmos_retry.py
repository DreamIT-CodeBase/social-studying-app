"""Tests for Cosmos DB throttling retries."""

from unittest.mock import AsyncMock, patch

import pytest

from app.services.cosmos_retry import run_with_throttle_retry


class _ThrottledError(Exception):
    code = 16500


@pytest.mark.asyncio
async def test_retries_16500_using_server_retry_delay():
    operation = AsyncMock(
        side_effect=[
            _ThrottledError("Error=16500, RetryAfterMs=457"),
            "deleted",
        ]
    )

    with patch("app.services.cosmos_retry.asyncio.sleep", AsyncMock()) as sleep:
        result = await run_with_throttle_retry(
            operation,
            operation_name="delete chunks",
        )

    assert result == "deleted"
    assert operation.await_count == 2
    sleep.assert_awaited_once_with(0.457)


@pytest.mark.asyncio
async def test_does_not_retry_non_throttle_errors():
    operation = AsyncMock(side_effect=RuntimeError("invalid query"))

    with pytest.raises(RuntimeError, match="invalid query"):
        await run_with_throttle_retry(
            operation,
            operation_name="delete chunks",
        )

    operation.assert_awaited_once()
