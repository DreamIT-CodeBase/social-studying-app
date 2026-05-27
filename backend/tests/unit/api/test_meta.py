"""Tests for the meta + discovery endpoints (Sprint 6.10).

Covers the OpenAPI metadata polish + the ``/api/versions``
discovery endpoint. The goal isn't to assert every word of the
description — it's to pin the contract pieces that downstream
tooling (Swagger UI consumers, codegen scripts, observability
dashboards) actually parses.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.core.versioning import API_VERSIONS
from app.main import app


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


# ── /api/versions ────────────────────────────────────────────────────────


def test_versions_endpoint_mirrors_the_canonical_table(client):
    response = client.get("/api/versions")
    assert response.status_code == 200
    body = response.json()
    assert "versions" in body
    rows = body["versions"]
    # One wire row per ``API_VERSIONS`` entry, in the same order.
    assert len(rows) == len(API_VERSIONS)
    for wire, canonical in zip(rows, API_VERSIONS, strict=True):
        assert wire["version"] == canonical.version
        assert wire["status"] == canonical.status
        assert wire["sunset_date"] == canonical.sunset_date
        assert wire["base_path"] == canonical.base_path


def test_versions_endpoint_carries_default_version_header(client):
    """The discovery endpoint isn't itself under ``/api/v1`` so the
    versioning middleware tags it with the default version."""
    response = client.get("/api/versions")
    assert response.headers["X-API-Version"] == "v1"


def test_versions_endpoint_does_not_require_auth(client):
    """Clients have to discover versions before they can authenticate,
    so this route must work without a token."""
    # The TestClient doesn't attach auth by default — a 200 here
    # proves the route is public.
    response = client.get("/api/versions")
    assert response.status_code == 200


# ── OpenAPI metadata ─────────────────────────────────────────────────────


def test_openapi_spec_carries_title_and_version(client):
    response = client.get("/openapi.json")
    assert response.status_code == 200
    spec = response.json()
    assert spec["info"]["title"] == "Social Study App API"
    assert spec["info"]["version"] == "0.1.0"


def test_openapi_spec_carries_description(client):
    response = client.get("/openapi.json")
    spec = response.json()
    # The full text isn't pinned — just key markers a Swagger UI
    # consumer would scan for.
    description = spec["info"]["description"]
    assert "Social Study App" in description
    assert "/api/v1" in description
    assert "X-API-Version" in description


def test_openapi_spec_carries_tag_metadata(client):
    """Every tag entry shipped in main.py should appear in the spec
    with its description — Swagger UI groups endpoints by these
    tags + renders the description as the group header."""
    response = client.get("/openapi.json")
    spec = response.json()
    tags = {t["name"]: t.get("description") for t in spec.get("tags", [])}
    for expected_tag in (
        "tenants",
        "workspaces",
        "users",
        "documents",
        "taxonomy",
        "questions",
        "flashcards",
        "gamification",
        "analytics",
        "notifications",
        "meta",
    ):
        assert expected_tag in tags, f"missing tag: {expected_tag}"
        assert tags[expected_tag], f"empty description for tag: {expected_tag}"


def test_openapi_spec_includes_the_versions_endpoint(client):
    response = client.get("/openapi.json")
    spec = response.json()
    assert "/api/versions" in spec["paths"]
    versions_get = spec["paths"]["/api/versions"]["get"]
    assert "meta" in versions_get.get("tags", [])
