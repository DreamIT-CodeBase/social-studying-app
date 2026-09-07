"""Cosmos DB for MongoDB API — tenant-aware async client."""

import asyncio
import logging
from collections.abc import Mapping
from copy import deepcopy
from functools import lru_cache
from typing import Any

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorCollection, AsyncIOMotorDatabase

from app.core.config import settings

logger = logging.getLogger(__name__)

# ── Cosmos 429 retry helper ──────────────────────────────────────────────────

_COSMOS_429_CODE = 16500
_MAX_RETRY_ATTEMPTS = 3
_MAX_RETRY_WAIT_MS = 2000  # never wait more than 2 s regardless of server hint


async def cosmos_retry(coro_factory, *, max_attempts: int = _MAX_RETRY_ATTEMPTS):
    """Run ``coro_factory()`` and retry automatically on Cosmos TooManyRequests (429).

    Usage::

        docs = await cosmos_retry(lambda: cursor.to_list(length=300))

    Args:
        coro_factory: zero-arg callable that returns a coroutine. Re-called on
            each retry so a fresh coroutine is produced every time.
        max_attempts: maximum total tries (default 3).

    Returns:
        The first successful coroutine result.

    Raises:
        The last exception when all retries are exhausted.
    """
    import re
    for attempt in range(1, max_attempts + 1):
        try:
            return await coro_factory()
        except Exception as exc:
            # Check for Cosmos TooManyRequests (pymongo OperationFailure code 16500)
            code = getattr(exc, "code", None)
            if code != _COSMOS_429_CODE or attempt >= max_attempts:
                raise
            # Extract RetryAfterMs from the error message when available
            match = re.search(r"RetryAfterMs=(\d+)", str(exc))
            wait_ms = int(match.group(1)) if match else 500
            wait_ms = min(wait_ms, _MAX_RETRY_WAIT_MS)
            logger.warning(
                "Cosmos 429 on attempt %d/%d - waiting %d ms before retry",
                attempt, max_attempts, wait_ms,
            )
            await asyncio.sleep(wait_ms / 1000.0)

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
FLASHCARDS = "flashcards"  # Sprint 3.12 — per-card store
FLASHCARD_RATINGS = "flashcard_ratings"  # Sprint 3.12 — append-only rating events
ADAPTIVE_SESSIONS = "adaptive_sessions"  # Prepared, offline-ready study sessions
XP_EVENTS = "xp_events"  # Idempotency ledger for one-off XP events
NOTIFICATION_TOKENS = "notification_tokens"  # Sprint 5.7 — per-(user, installation) FCM tokens
NOTIFICATION_DISPATCHES = "notification_dispatches"  # Sprint 5.7 — append-only push log
SCREEN_TIME_SETTINGS = "screen_time_settings"  # Cloud-backed workspace blocking config
SCREEN_TIME_WALLETS = "screen_time_wallets"  # Cloud-backed per-student usage wallet
RAG_EVALUATIONS = "rag_evaluations"  # End-to-end RAG trace and evaluation records
SUBSCRIPTIONS = "subscriptions"  # Stripe customer & subscription records


# Parental / Device Control
DEVICE_USAGE_LOGS = "device_usage_logs"
APP_USAGE_LOGS = "app_usage_logs"
SCREEN_TIME_LOGS = "screen_time_logs"
APP_RESTRICTIONS = "app_restrictions"
PARENTAL_CONTROLS = "parental_controls"
PERMISSION_STATUS = "permission_status"
DB_STATS = "db_stats"


class TenantScopeViolation(ValueError):
    """Raised when a write attempts to escape its logical tenant scope."""


class TenantScopedCollection:
    """Motor collection facade that enforces a tenant predicate on every operation.

    Dynamic tenants share physical domain collections. This facade is the
    isolation boundary: callers cannot omit ``tenant_id`` from reads and every
    inserted/replaced document is stamped with the owning tenant.
    """

    def __init__(self, collection: AsyncIOMotorCollection, tenant_id: str) -> None:  # type: ignore[type-arg]
        self._collection = collection
        self._tenant_id = tenant_id

    def _filter(self, filter_: Mapping[str, Any] | None = None) -> dict[str, Any]:
        scoped = dict(filter_ or {})
        requested_tenant = scoped.get("tenant_id")
        if requested_tenant is not None and requested_tenant != self._tenant_id:
            raise TenantScopeViolation(
                f"Query tenant_id {requested_tenant!r} does not match scope {self._tenant_id!r}"
            )
        scoped["tenant_id"] = self._tenant_id
        return scoped

    def _document(self, document: Mapping[str, Any]) -> dict[str, Any]:
        scoped = deepcopy(dict(document))
        requested_tenant = scoped.get("tenant_id")
        if requested_tenant is not None and requested_tenant != self._tenant_id:
            raise TenantScopeViolation(
                f"Document tenant_id {requested_tenant!r} does not match scope {self._tenant_id!r}"
            )
        scoped["tenant_id"] = self._tenant_id
        return scoped

    def _update(self, update: Mapping[str, Any]) -> dict[str, Any]:
        scoped = deepcopy(dict(update))
        for operator in ("$set", "$setOnInsert"):
            values = scoped.get(operator)
            if isinstance(values, Mapping):
                requested_tenant = values.get("tenant_id")
                if requested_tenant is not None and requested_tenant != self._tenant_id:
                    raise TenantScopeViolation("Updates cannot change tenant_id")
        if "tenant_id" in scoped.get("$unset", {}):
            raise TenantScopeViolation("Updates cannot remove tenant_id")
        return scoped

    def find(self, filter_: Mapping[str, Any] | None = None, *args: Any, **kwargs: Any):
        return self._collection.find(self._filter(filter_), *args, **kwargs)

    async def find_one(self, filter_: Mapping[str, Any] | None = None, *args: Any, **kwargs: Any):
        return await self._collection.find_one(self._filter(filter_), *args, **kwargs)

    async def insert_one(self, document: Mapping[str, Any], *args: Any, **kwargs: Any):
        return await self._collection.insert_one(self._document(document), *args, **kwargs)

    async def insert_many(self, documents: list[Mapping[str, Any]], *args: Any, **kwargs: Any):
        return await self._collection.insert_many(
            [self._document(document) for document in documents], *args, **kwargs
        )

    async def update_one(
        self, filter_: Mapping[str, Any], update: Mapping[str, Any], *args: Any, **kwargs: Any
    ):
        return await self._collection.update_one(
            self._filter(filter_), self._update(update), *args, **kwargs
        )

    async def update_many(
        self, filter_: Mapping[str, Any], update: Mapping[str, Any], *args: Any, **kwargs: Any
    ):
        return await self._collection.update_many(
            self._filter(filter_), self._update(update), *args, **kwargs
        )

    async def replace_one(
        self, filter_: Mapping[str, Any], replacement: Mapping[str, Any], *args: Any, **kwargs: Any
    ):
        return await self._collection.replace_one(
            self._filter(filter_), self._document(replacement), *args, **kwargs
        )

    async def delete_one(self, filter_: Mapping[str, Any], *args: Any, **kwargs: Any):
        return await self._collection.delete_one(self._filter(filter_), *args, **kwargs)

    async def delete_many(self, filter_: Mapping[str, Any], *args: Any, **kwargs: Any):
        return await self._collection.delete_many(self._filter(filter_), *args, **kwargs)

    async def count_documents(self, filter_: Mapping[str, Any], *args: Any, **kwargs: Any):
        return await self._collection.count_documents(self._filter(filter_), *args, **kwargs)

    async def find_one_and_update(
        self, filter_: Mapping[str, Any], update: Mapping[str, Any], *args: Any, **kwargs: Any
    ):
        return await self._collection.find_one_and_update(
            self._filter(filter_), self._update(update), *args, **kwargs
        )

    async def create_index(self, *args: Any, **kwargs: Any):
        return await self._collection.create_index(*args, **kwargs)


@lru_cache(maxsize=1)
def _get_client() -> AsyncIOMotorClient:  # type: ignore[type-arg]
    """Single motor client, created once per process."""
    client: AsyncIOMotorClient = AsyncIOMotorClient(settings.cosmos_connection_string)  # type: ignore[type-arg]
    logger.info("Cosmos DB client initialised")
    return client


def get_database(tenant_id: str) -> AsyncIOMotorDatabase:  # type: ignore[type-arg]
    """Return the physical database for a logical tenant.

    Dynamic tenants share a database-level throughput pool. Explicitly mapped
    demo/smoke tenants and the platform database retain their own databases.
    """
    db_name = settings.get_db_name(tenant_id)
    return _get_client()[db_name]


def get_collection(
    tenant_id: str, collection: str
) -> AsyncIOMotorCollection | TenantScopedCollection:  # type: ignore[type-arg]
    """Return a tenant-isolated collection using shared throughput when applicable."""
    physical_collection = get_database(tenant_id)[collection]
    if settings.get_db_name(tenant_id) == settings.tenant_data_database:
        return TenantScopedCollection(physical_collection, tenant_id)
    return physical_collection


async def ping() -> bool:
    """Health probe — returns True if the Cosmos DB endpoint is reachable."""
    try:
        await _get_client().admin.command("ping")
        return True
    except Exception:
        logger.exception("Cosmos DB ping failed")
        return False
