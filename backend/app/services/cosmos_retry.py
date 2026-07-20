"""Bounded retry support for Cosmos DB Mongo API throttling."""

from __future__ import annotations

import asyncio
import logging
import re
from collections.abc import Awaitable, Callable

logger = logging.getLogger(__name__)

_MAX_THROTTLE_RETRIES = 8
_THROTTLE_CODES = frozenset({429, 16500})
_RETRY_AFTER_PATTERN = re.compile(r"RetryAfterMs=(\d+)")

def is_throttle_error(exc: Exception) -> bool:
    """Return whether a Motor/PyMongo exception represents Cosmos throttling."""
    if getattr(exc, "code", None) in _THROTTLE_CODES:
        return True

    details = getattr(exc, "details", None)
    if isinstance(details, dict):
        if details.get("code") in _THROTTLE_CODES:
            return True
        write_errors = details.get("writeErrors", [])
        if isinstance(write_errors, list):
            return any(
                isinstance(error, dict) and error.get("code") in _THROTTLE_CODES
                for error in write_errors
            )
    return False


def _retry_delay_seconds(exc: Exception, attempt: int) -> float:
    match = _RETRY_AFTER_PATTERN.search(str(exc))
    server_delay = int(match.group(1)) / 1000 if match else 0.0
    exponential_delay = 0.25 * (2**attempt)
    return min(max(server_delay, exponential_delay), 5.0)


async def run_with_throttle_retry[T](
    operation: Callable[[], Awaitable[T]],
    *,
    operation_name: str,
) -> T:
    """Run an idempotent Cosmos operation with bounded 429 backoff."""
    for attempt in range(_MAX_THROTTLE_RETRIES + 1):
        try:
            return await operation()
        except Exception as exc:
            if not is_throttle_error(exc) or attempt >= _MAX_THROTTLE_RETRIES:
                raise

            delay = _retry_delay_seconds(exc, attempt)
            logger.warning(
                "Cosmos throttled %s; retrying in %.2fs (attempt %d/%d)",
                operation_name,
                delay,
                attempt + 1,
                _MAX_THROTTLE_RETRIES,
            )
            await asyncio.sleep(delay)

    raise AssertionError("unreachable")
