"""Async Redis client — single connection pool, lazy-initialised."""

import logging

from redis.asyncio import Redis

from app.core.config import settings

logger = logging.getLogger(__name__)

_redis: Redis | None = None  # type: ignore[type-arg]


async def get_redis() -> Redis:  # type: ignore[type-arg]
    """Return the shared Redis connection, creating it on first call."""
    global _redis
    if _redis is None:
        _redis = Redis.from_url(settings.redis_url, decode_responses=True)
        logger.info("Redis client initialised")
    return _redis


async def close_redis() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None
        logger.info("Redis client closed")
