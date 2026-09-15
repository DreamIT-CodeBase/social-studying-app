"""Unit tests for the API versioning middleware (Sprint 6.7)."""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.versioning import (
    API_VERSIONS,
    DEFAULT_VERSION,
    VersionResponseMiddleware,
    _extract_version,
)

# ── Path parsing ──────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("path", "expected"),
    [
        ("/api/v1/users/me", "v1"),
        ("/api/v1/", "v1"),
        ("/api/v1", "v1"),
        ("/api/v2/things", None),  # not in the known set
        ("/api/random-string/route", None),
        ("/health", None),
        ("/", None),
        ("/api", None),
    ],
)
def test_extract_version(path: str, expected: str | None):
    known = {v.version for v in API_VERSIONS}
    assert _extract_version(path, known=known) == expected


# ── Middleware end-to-end ────────────────────────────────────────────────


def _build_app() -> FastAPI:
    """Minimal app to exercise the middleware in isolation."""
    app = FastAPI()
    app.add_middleware(VersionResponseMiddleware)

    @app.get("/api/v1/probe")
    async def _probe_v1() -> dict:
        return {"ok": True}

    @app.get("/health")
    async def _health() -> dict:
        return {"ok": True}

    return app


def test_versioned_route_carries_matching_header():
    client = TestClient(_build_app())
    response = client.get("/api/v1/probe")
    assert response.status_code == 200
    assert response.headers["X-API-Version"] == "v1"


def test_unversioned_route_carries_default_version_header():
    """``/health`` doesn't live under ``/api/<v>`` so we tag it with
    the default. Observability tools then bucket every response by
    version without a missing-key path."""
    client = TestClient(_build_app())
    response = client.get("/health")
    assert response.headers["X-API-Version"] == DEFAULT_VERSION


def test_unknown_version_falls_back_to_default():
    """A request to ``/api/v99/...`` (an unsupported version) doesn't
    invent a header value — the response gets the default tag."""
    app = _build_app()

    @app.get("/api/v99/probe")
    async def _probe_v99() -> dict:
        return {"ok": True}

    client = TestClient(app)
    response = client.get("/api/v99/probe")
    assert response.headers["X-API-Version"] == DEFAULT_VERSION
