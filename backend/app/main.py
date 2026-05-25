from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import (
    analytics,
    documents,
    flashcards,
    gamification,
    notifications,
    questions,
    taxonomy,
    tenants,
    users,
    workspaces,
)
from app.core.config import settings
from app.core.database import ping as db_ping
from app.core.redis_client import close_redis, get_redis


@asynccontextmanager
async def lifespan(application: FastAPI) -> AsyncIterator[None]:
    await get_redis()  # warm up connection pool on startup
    yield
    await close_redis()


app = FastAPI(
    title="Social Study App API",
    version="0.1.0",
    docs_url="/docs" if settings.environment != "production" else None,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(tenants.router, prefix="/api/v1")
app.include_router(workspaces.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(documents.router, prefix="/api/v1")
app.include_router(taxonomy.router, prefix="/api/v1")
app.include_router(questions.router, prefix="/api/v1")
app.include_router(flashcards.router, prefix="/api/v1")
app.include_router(gamification.router, prefix="/api/v1")
app.include_router(analytics.workspace_router, prefix="/api/v1")
app.include_router(analytics.tenant_router, prefix="/api/v1")
app.include_router(notifications.users_router, prefix="/api/v1")
app.include_router(notifications.admin_router, prefix="/api/v1")


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
