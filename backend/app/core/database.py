"""Cosmos DB for MongoDB API — tenant-aware async client."""

import logging
from functools import lru_cache

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorCollection, AsyncIOMotorDatabase

from app.core.config import settings

logger = logging.getLogger(__name__)

# Collection names — one per domain, shared across all tenant databases
USERS = "users"
WORKSPACES = "workspaces"
DOCUMENTS = "documents"
CHUNKS = "chunks"  # Sprint 2.8 — per-document text chunks; partition by document_id
KNOWLEDGE_STATES = "knowledge_states"
INTERACTIONS = "interactions"
GAMIFICATION = "gamification"
MODERATION_LOG = "moderation_log"
QUESTION_QUEUE = "question_queue"
FLASHCARDS = "flashcards"                       # Sprint 3.12 — per-card store
FLASHCARD_RATINGS = "flashcard_ratings"         # Sprint 3.12 — append-only rating events


@lru_cache(maxsize=1)
def _get_client() -> AsyncIOMotorClient:  # type: ignore[type-arg]
    """Single motor client, created once per process."""
    client: AsyncIOMotorClient = AsyncIOMotorClient(settings.cosmos_connection_string)  # type: ignore[type-arg]
    logger.info("Cosmos DB client initialised")
    return client


def get_database(tenant_id: str) -> AsyncIOMotorDatabase:  # type: ignore[type-arg]
    """Return the per-tenant database.

    Each tenant gets an isolated Cosmos DB database named after their tenant_id.
    This enforces data isolation at the storage layer, not just the query layer.
    """
    return _get_client()[tenant_id]


def get_collection(tenant_id: str, collection: str) -> AsyncIOMotorCollection:  # type: ignore[type-arg]
    """Shorthand — return a named collection inside the tenant's database."""
    return get_database(tenant_id)[collection]


async def ping() -> bool:
    """Health probe — returns True if the Cosmos DB endpoint is reachable."""
    try:
        await _get_client().admin.command("ping")
        return True
    except Exception:
        logger.exception("Cosmos DB ping failed")
        return False
