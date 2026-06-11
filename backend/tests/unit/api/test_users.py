"""Unit tests for user management API endpoints."""

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
    col = MagicMock()
    col.find_one = AsyncMock(return_value=doc)
    col.insert_one = AsyncMock(return_value=MagicMock(inserted_id="usr_new"))
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
            d = self._docs[self._idx]
            self._idx += 1
            return d

    col.find = MagicMock(return_value=_AsyncCursor([]))
    return col


# ── GET /api/v1/users/me ──────────────────────────────────────────────────────


def test_get_me_returns_current_user(client):
    user = make_user(role=UserRole.student)
    app.dependency_overrides[get_current_user] = lambda: user

    response = client.get("/api/v1/users/me")

    assert response.status_code == 200
    assert response.json()["id"] == user.id
    assert response.json()["email"] == user.email


# ── POST /api/v1/users/ ───────────────────────────────────────────────────────


def test_create_user_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)  # no duplicate

    with patch("app.api.users.get_collection", return_value=col):
        response = client.post(
            "/api/v1/users/",
            json={"email": "student@school.com", "display_name": "Alice", "role": "student"},
        )

    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "student@school.com"
    assert data["role"] == "student"


def test_create_user_duplicate_email_returns_409(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    existing = make_user(user_id="usr_existing").model_dump(by_alias=True)
    col = _col_with_doc(existing)

    with patch("app.api.users.get_collection", return_value=col):
        response = client.post(
            "/api/v1/users/",
            json={"email": "test@example.com", "display_name": "Dup", "role": "student"},
        )

    assert response.status_code == 409


def test_create_user_student_role_is_forbidden(client):
    """Students cannot create users — only tenant_admin and workspace_admin can."""
    student = make_user(role=UserRole.student)
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.post(
        "/api/v1/users/",
        json={"email": "new@school.com", "display_name": "New", "role": "student"},
    )

    assert response.status_code == 403


# ── GET /api/v1/users/{user_id} ───────────────────────────────────────────────


def test_get_user_not_found_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)

    with patch("app.api.users.get_collection", return_value=col):
        response = client.get("/api/v1/users/usr_missing")

    assert response.status_code == 404


def test_get_user_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    target = make_user(user_id="usr_target", role=UserRole.student)
    col = _col_with_doc(target.model_dump(by_alias=True))

    with patch("app.api.users.get_collection", return_value=col):
        response = client.get("/api/v1/users/usr_target")

    assert response.status_code == 200
    assert response.json()["id"] == "usr_target"


# ── DELETE /api/v1/users/{user_id} ───────────────────────────────────────────


def test_deactivate_user_not_found_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=0))

    with patch("app.api.users.get_collection", return_value=col):
        response = client.delete("/api/v1/users/usr_missing")

    assert response.status_code == 404


def test_deactivate_user_as_student_is_forbidden(client):
    student = make_user(role=UserRole.student)
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.delete("/api/v1/users/usr_other")

    assert response.status_code == 403


# ── POST /api/v1/users/join ───────────────────────────────────────────────────


def test_redeem_invite_code_invalid_returns_422(client):
    student = make_user(role=UserRole.student)
    app.dependency_overrides[get_current_user] = lambda: student
    col = _col_with_doc(None)  # no workspace found for this code

    with patch("app.api.users.get_collection", return_value=col):
        response = client.post(
            "/api/v1/users/join",
            json={"code": "BADCODE1"},
        )

    assert response.status_code == 422


def test_redeem_invite_code_already_member_returns_409(client):
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student
    workspace = make_workspace()
    from app.models.workspace import InviteCode

    workspace.invite_codes.append(
        InviteCode(code="ABCD1234", created_by="usr_admin", is_active=True)
    )
    col = _col_with_doc(workspace.model_dump(by_alias=True))

    with patch("app.api.users.get_collection", return_value=col):
        response = client.post(
            "/api/v1/users/join",
            json={"code": "ABCD1234"},
        )

    assert response.status_code == 409
