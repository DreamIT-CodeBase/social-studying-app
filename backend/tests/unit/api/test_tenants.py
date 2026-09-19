"""Unit tests for tenant CRUD endpoints."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.tenant import Tenant, TenantStatus, TenantType
from app.models.user import UserRole
from tests.unit.conftest import make_user


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


def _col_with_doc(doc: dict | None):
    col = MagicMock()
    col.find_one = AsyncMock(return_value=doc)
    col.insert_one = AsyncMock(return_value=MagicMock(inserted_id="ten_new"))
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    return col


def _tenant_doc(tenant_id: str = "ten_test001", admin_email: str = "admin@example.com") -> dict:
    return Tenant(
        **{"_id": tenant_id},
        name="Test Tenant",
        type=TenantType.school,
        status=TenantStatus.trial,
        admin_email=admin_email,
    ).model_dump(by_alias=True)


# ── POST /api/v1/tenants/ ─────────────────────────────────────────────────────


def test_create_tenant_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)  # no duplicate

    with patch("app.api.tenants.get_collection", return_value=col):
        response = client.post(
            "/api/v1/tenants/",
            json={
                "name": "Lincoln High",
                "type": "school",
                "admin_email": "principal@lincoln.edu",
            },
        )

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Lincoln High"
    assert data["type"] == "school"
    assert data["admin_email"] == "principal@lincoln.edu"
    assert data["status"] == "trial"
    assert data["id"].startswith("ten_")
    col.insert_one.assert_awaited_once()


def test_create_tenant_does_not_provision_dedicated_throughput(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)

    with (
        patch("app.api.tenants.get_collection", return_value=col),
        patch("app.core.database._get_client") as get_client,
    ):
        response = client.post(
            "/api/v1/tenants/",
            json={
                "name": "Cost Safe School",
                "type": "school",
                "admin_email": "admin@costsafe.example",
            },
        )

    assert response.status_code == 201
    get_client.assert_not_called()


def test_create_tenant_duplicate_email_returns_409(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(_tenant_doc(admin_email="dup@school.com"))

    with patch("app.api.tenants.get_collection", return_value=col):
        response = client.post(
            "/api/v1/tenants/",
            json={
                "name": "Dup School",
                "type": "school",
                "admin_email": "dup@school.com",
            },
        )

    assert response.status_code == 409
    col.insert_one.assert_not_awaited()


def test_create_tenant_as_student_is_forbidden(client):
    student = make_user(role=UserRole.student)
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.post(
        "/api/v1/tenants/",
        json={
            "name": "Sneaky Inc",
            "type": "family",
            "admin_email": "kid@home.com",
        },
    )

    assert response.status_code == 403


def test_create_tenant_as_workspace_admin_is_forbidden(client):
    """Only tenant_admins can create new tenants — even workspace admins cannot."""
    ws_admin = make_user(role=UserRole.workspace_admin)
    app.dependency_overrides[get_current_user] = lambda: ws_admin

    response = client.post(
        "/api/v1/tenants/",
        json={
            "name": "Side School",
            "type": "school",
            "admin_email": "ws@school.com",
        },
    )

    assert response.status_code == 403


def test_create_tenant_invalid_email_returns_422(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    response = client.post(
        "/api/v1/tenants/",
        json={"name": "Bad Email", "type": "school", "admin_email": "not-an-email"},
    )

    assert response.status_code == 422


def test_create_tenant_invalid_type_returns_422(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    response = client.post(
        "/api/v1/tenants/",
        json={"name": "Bad Type", "type": "corporation", "admin_email": "x@y.com"},
    )

    assert response.status_code == 422


# ── GET /api/v1/tenants/{tenant_id} ───────────────────────────────────────────


def test_get_tenant_own_tenant_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin, tenant_id="ten_test001")
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(_tenant_doc(tenant_id="ten_test001"))

    with patch("app.api.tenants.get_collection", return_value=col):
        response = client.get("/api/v1/tenants/ten_test001")

    assert response.status_code == 200
    assert response.json()["id"] == "ten_test001"


def test_get_tenant_cross_tenant_returns_404(client):
    """A user reading a tenant they don't belong to must get 404, not 403 — no leakage."""
    admin = make_user(role=UserRole.tenant_admin, tenant_id="ten_mine")
    app.dependency_overrides[get_current_user] = lambda: admin

    response = client.get("/api/v1/tenants/ten_someone_else")

    assert response.status_code == 404


def test_get_tenant_not_found_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin, tenant_id="ten_test001")
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)

    with patch("app.api.tenants.get_collection", return_value=col):
        response = client.get("/api/v1/tenants/ten_test001")

    assert response.status_code == 404


def test_get_tenant_as_student_succeeds_for_own_tenant(client):
    """Students can read their own tenant — only cross-tenant is blocked."""
    student = make_user(role=UserRole.student, tenant_id="ten_test001")
    app.dependency_overrides[get_current_user] = lambda: student
    col = _col_with_doc(_tenant_doc(tenant_id="ten_test001"))

    with patch("app.api.tenants.get_collection", return_value=col):
        response = client.get("/api/v1/tenants/ten_test001")

    assert response.status_code == 200


# ── DELETE /api/v1/tenants/{tenant_id} ───────────────────────────────────────


def test_delete_tenant_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin, tenant_id="ten_test001")
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    with patch("app.api.tenants.get_collection", return_value=col):
        response = client.delete("/api/v1/tenants/ten_test001")

    assert response.status_code == 204
    col.update_one.assert_awaited_once()


def test_delete_tenant_cross_tenant_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin, tenant_id="ten_mine")
    app.dependency_overrides[get_current_user] = lambda: admin

    response = client.delete("/api/v1/tenants/ten_someone_else")

    assert response.status_code == 404


def test_delete_tenant_not_found_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin, tenant_id="ten_test001")
    app.dependency_overrides[get_current_user] = lambda: admin
    col = MagicMock()
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=0))

    with patch("app.api.tenants.get_collection", return_value=col):
        response = client.delete("/api/v1/tenants/ten_test001")

    assert response.status_code == 404


def test_delete_tenant_as_student_is_forbidden(client):
    student = make_user(role=UserRole.student, tenant_id="ten_test001")
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.delete("/api/v1/tenants/ten_test001")

    assert response.status_code == 403
