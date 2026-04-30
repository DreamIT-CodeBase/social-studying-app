"""Unit tests for workspace CRUD endpoints."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.user import UserRole
from tests.unit.conftest import make_user, make_workspace


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


def _col_with_doc(doc: dict | None):
    """Return a mock collection whose find_one returns doc."""
    col = MagicMock()
    col.find_one = AsyncMock(return_value=doc)
    col.insert_one = AsyncMock(return_value=MagicMock(inserted_id="wsp_new"))
    col.replace_one = AsyncMock(return_value=MagicMock(matched_count=1))
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    class _AsyncCursor:
        def __init__(self, docs):
            self._docs = docs
            self._idx = 0

        def __aiter__(self):
            return self

        async def __anext__(self):
            if self._idx >= len(self._docs):
                raise StopAsyncIteration
            doc = self._docs[self._idx]
            self._idx += 1
            return doc

    col.find = MagicMock(return_value=_AsyncCursor([]))
    return col


# ── POST /api/v1/workspaces/ ──────────────────────────────────────────────────


def test_create_workspace_as_tenant_admin(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)  # no duplicate

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.post(
            "/api/v1/workspaces/",
            json={"name": "Science Class", "description": "Grade 9 science"},
        )

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Science Class"
    assert data["tenant_id"] == admin.tenant_id


def test_create_workspace_duplicate_name_returns_409(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    existing = make_workspace(tenant_id=admin.tenant_id).model_dump(by_alias=True)
    col = _col_with_doc(existing)

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.post(
            "/api/v1/workspaces/",
            json={"name": "Test Workspace"},
        )

    assert response.status_code == 409


# ── GET /api/v1/workspaces/ ───────────────────────────────────────────────────


def test_list_workspaces_tenant_admin_sees_all(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/")

    assert response.status_code == 200
    assert response.json() == []


# ── GET /api/v1/workspaces/{id} ───────────────────────────────────────────────


def test_get_workspace_not_found_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_missing")

    assert response.status_code == 404


def test_get_workspace_non_member_student_returns_403(client):
    student = make_user(role=UserRole.student, workspace_ids=[])  # not a member
    app.dependency_overrides[get_current_user] = lambda: student
    workspace = make_workspace()
    col = _col_with_doc(workspace.model_dump(by_alias=True))

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001")

    assert response.status_code == 403


def test_get_workspace_member_student_succeeds(client):
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student
    workspace = make_workspace()
    col = _col_with_doc(workspace.model_dump(by_alias=True))

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001")

    assert response.status_code == 200
    assert response.json()["id"] == "wsp_test001"


# ── DELETE /api/v1/workspaces/{id} ───────────────────────────────────────────


def test_delete_workspace_not_found_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = MagicMock()
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=0))

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.delete("/api/v1/workspaces/wsp_missing")

    assert response.status_code == 404


# ── POST /api/v1/workspaces/{id}/invite-codes ─────────────────────────────────


def test_generate_invite_code_returns_code(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    workspace = make_workspace()
    col = _col_with_doc(workspace.model_dump(by_alias=True))
    col.replace_one = AsyncMock(return_value=MagicMock(matched_count=1))

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.post("/api/v1/workspaces/wsp_test001/invite-codes")

    assert response.status_code == 201
    data = response.json()
    assert "code" in data
    assert len(data["code"]) == 8
