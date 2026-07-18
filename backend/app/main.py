from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.api import (
    adaptive_sessions,
    analytics,
    device_management,
    documents,
    flashcards,
    gamification,
    moderation,
    notifications,
    questions,
    screen_time,
    taxonomy,
    tenants,
    users,
    workspaces,
)
from app.core.config import settings
from app.core.database import ping as db_ping
from app.core.redis_client import close_redis, get_redis
from app.core.versioning import API_VERSIONS, VersionResponseMiddleware

_startup_logger = logging.getLogger("app.main")

# ── Inline worker loop ────────────────────────────────────────────────────────
# Local developers can opt into running the pipeline workers as asyncio tasks
# inside the same uvicorn process. Deployed environments use dedicated
# Container Apps, even when their API environment is "development" for the
# dev-auth bypass.

async def _run_worker_loop(name: str) -> None:
    """Import and run a worker's run_forever(), restarting when it exits."""
    import importlib
    while True:
        try:
            mod = importlib.import_module(f"app.workers.{name}")
            await mod.run_forever()
        except asyncio.CancelledError:
            _startup_logger.info("Worker %s cancelled — shutting down.", name)
            return
        except Exception:
            _startup_logger.exception("Worker %s crashed — restarting in 2 s.", name)
        await asyncio.sleep(2)


_INLINE_WORKERS = [
    "document_ingestion",
    "topic_extraction",
    "chunking",
    "vectorization",
]


@asynccontextmanager
async def lifespan(application: FastAPI) -> AsyncIterator[None]:
    await get_redis()  # warm up connection pool on startup
    startup_logger = logging.getLogger("app.main")
    startup_logger.info("MongoDB databases configured on startup:")
    startup_logger.info(f"  - Tenant 'ten_smoke001' maps to database: {settings.db_name_smoke}")
    startup_logger.info(f"  - Tenant 'ten_demo_001' maps to database: {settings.db_name_demo}")
    startup_logger.info(f"  - Tenant '93e3ce50-a29e-462b-8956-85674a34d167' maps to database: {settings.db_name_uuid}")

    # Start inline workers only when explicitly enabled for local development.
    worker_tasks: list[asyncio.Task] = []
    if settings.inline_workers_enabled and settings.service_bus_connection:
        for worker_name in _INLINE_WORKERS:
            task = asyncio.create_task(
                _run_worker_loop(worker_name), name=f"worker-{worker_name}"
            )
            worker_tasks.append(task)
        startup_logger.info(
            "Inline workers started: %s", ", ".join(_INLINE_WORKERS)
        )
    else:
        startup_logger.info(
            "Inline workers skipped (disabled or SERVICE_BUS_CONNECTION not set)."
        )

    yield

    # Shutdown: cancel all worker tasks and wait for clean exit
    for task in worker_tasks:
        task.cancel()
    if worker_tasks:
        await asyncio.gather(*worker_tasks, return_exceptions=True)
        startup_logger.info("All inline workers stopped.")

    await close_redis()


_API_DESCRIPTION = """\
The backend for the Social Study App — an AI-powered, multi-tenant
study platform for families and schools.

## What this API serves

* **Tenants + workspaces** — multi-tenant signup, workspace creation,
  invite-code redemption.
* **Documents** — upload + status polling for the ingestion pipeline
  (extract → safety scan → topic extraction → chunking → vectorize).
* **Taxonomy** — per-workspace topic graph (read, edit, regenerate).
* **Questions + flashcards** — AI-generated, served by an adaptive
  learning engine. Skip / answer / rate.
* **Gamification** — XP, level, streak, badges, leaderboard.
* **Analytics** — per-student progress, workspace dashboards, tenant
  roll-ups.
* **Notifications** — FCM-backed push registration + a milestone /
  reminder / streak / re-prompt scheduler.

## Versioning

All routes live under ``/api/v1``. Discover live versions at
``GET /api/versions``. Every response carries ``X-API-Version``
identifying the version that served it.

## Authentication

JWT bearer tokens issued by Microsoft Entra External ID
(formerly Azure AD B2C). Pass as ``Authorization: Bearer <jwt>``.
The token's ``oid`` claim drives the per-request ``current_user``
lookup; tenant + workspace scope is enforced at the route layer.

## Wire-shape conventions

* Timestamps are ISO 8601 UTC strings (``2026-05-26T14:30:00+00:00``).
* IDs are typed-prefixed UUIDs: ``usr_``, ``wsp_``, ``ten_``,
  ``doc_``, ``qst_``, ``fc_``, ``gam_``, ``ks_``, ``nd_``, ``ntk_``.
* Deletion is soft — every collection carries ``deleted_at`` and
  every read filters on ``deleted_at == null``.
"""


_OPENAPI_TAGS = [
    {
        "name": "tenants",
        "description": "Tenant signup + multi-tenant root resources.",
    },
    {
        "name": "workspaces",
        "description": "Workspace CRUD, settings, invite codes.",
    },
    {
        "name": "users",
        "description": (
            "User management — direct creation (admin), invite-code "
            "redemption (self), and the ``/users/me`` self-profile."
        ),
    },
    {
        "name": "documents",
        "description": (
            "Document upload + ingestion status. The actual pipeline "
            "runs async across four Container App workers."
        ),
    },
    {
        "name": "taxonomy",
        "description": "Per-workspace canonical topic graph.",
    },
    {
        "name": "questions",
        "description": (
            "AI-generated questions — ``/next`` for the adaptive "
            "fetch, ``/answer`` to submit, ``/skip`` to defer."
        ),
    },
    {
        "name": "flashcards",
        "description": "Flashcard generation + self-rating.",
    },
    {
        "name": "adaptive-sessions",
        "description": "Prepare-once adaptive study, revision, and flashcard sessions.",
    },
    {
        "name": "gamification",
        "description": (
            "XP / level / streak / badges / leaderboard. The engine "
            "is the single writer over the gamification collection."
        ),
    },
    {
        "name": "analytics",
        "description": (
            "Student progress + workspace dashboard + tenant "
            "roll-up. Read-only aggregation."
        ),
    },
    {
        "name": "notifications",
        "description": (
            "FCM token registration + scheduler tick endpoint. "
            "Pushes are dispatched through Azure Notification Hubs."
        ),
    },
    {
        "name": "moderation",
        "description": "Admin review of flagged content.",
    },
    {
        "name": "meta",
        "description": (
            "Discovery + version metadata. Stable across API "
            "versions."
        ),
    },
]


app = FastAPI(
    title="Social Study App API",
    version="0.1.0",
    description=_API_DESCRIPTION,
    summary=(
        "AI-powered adaptive study platform. Multi-tenant, "
        "FCM push, gamification engine, document ingestion pipeline."
    ),
    openapi_tags=_OPENAPI_TAGS,
    contact={
        "name": "Social Study App engineering",
        "email": "chirag@socialstudying.ai",
    },
    license_info={"name": "Proprietary", "identifier": "LicenseRef-Proprietary"},
    docs_url="/docs" if settings.environment != "production" else None,
    redoc_url="/redoc" if settings.environment != "production" else None,
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

_logger = logging.getLogger(__name__)


@app.exception_handler(Exception)
async def _unhandled_exception_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    """Catch-all for unhandled exceptions — logs the full traceback and
    returns a clean 500 JSON body so clients always see structured errors.
    FastAPI/Starlette's default is a plain-text 500; this replaces it.
    """
    _logger.exception(
        "Unhandled exception: %s %s", request.method, request.url, exc_info=exc
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Check server logs."},
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    # Non-prod only: also accept any localhost port so Flutter web dev servers
    # (random port per run) aren't CORS-blocked. None in prod → explicit
    # allowed_origins is the sole allowlist. See settings.allowed_origin_regex.
    allow_origin_regex=(
        settings.allowed_origin_regex
        if settings.environment != "production"
        else None
    ),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Sprint 6.7 — stamp every response with ``X-API-Version``. Mounted
# *after* CORS so the preflight pass-through still includes the
# header on the actual response.
app.add_middleware(VersionResponseMiddleware)


# The leading underscore was stripped on /review (Sprint 6) — FastAPI
# emits class names verbatim into the OpenAPI ``components/schemas``
# section, and a Dart / TypeScript code generator on the spec will
# mangle ``_ApiVersionView`` into something ugly or rejected.
class ApiVersionView(BaseModel):
    """Wire view of :class:`app.core.versioning.ApiVersion`."""

    version: str
    status: str
    sunset_date: str | None
    base_path: str


class ApiVersionsResponse(BaseModel):
    versions: list[ApiVersionView]


@app.get("/api/versions", response_model=ApiVersionsResponse, tags=["meta"])
async def list_api_versions() -> ApiVersionsResponse:
    """Discovery endpoint for the live API versions.

    Clients hit this once at startup to discover the base path for
    each supported version + its lifecycle status. The list is
    canonical — anything not in here isn't supported.
    """
    return ApiVersionsResponse(
        versions=[
            ApiVersionView(
                version=v.version,
                status=v.status,
                sunset_date=v.sunset_date,
                base_path=v.base_path,
            )
            for v in API_VERSIONS
        ]
    )

app.include_router(tenants.router, prefix="/api/v1")
app.include_router(workspaces.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(documents.router, prefix="/api/v1")
app.include_router(taxonomy.router, prefix="/api/v1")
app.include_router(moderation.router, prefix="/api/v1")
app.include_router(questions.router, prefix="/api/v1")
app.include_router(flashcards.router, prefix="/api/v1")
app.include_router(adaptive_sessions.router, prefix="/api/v1")
app.include_router(gamification.router, prefix="/api/v1")
app.include_router(analytics.workspace_router, prefix="/api/v1")
app.include_router(analytics.tenant_router, prefix="/api/v1")
app.include_router(notifications.users_router, prefix="/api/v1")
app.include_router(notifications.admin_router, prefix="/api/v1")
app.include_router(screen_time.router, prefix="/api/v1")
app.include_router(device_management.router, prefix="/api/v1")


@app.get("/health")
async def health_check() -> dict:
    cosmos_ok = await db_ping()
    try:
        redis = await get_redis()
        await redis.ping()
        redis_ok = True
    except Exception:
        redis_ok = False

    return {
        "status": "ok" if (cosmos_ok and redis_ok) else "degraded",
        "version": "0.1.0",
        "services": {"cosmos_db": cosmos_ok, "redis": redis_ok},
    }
