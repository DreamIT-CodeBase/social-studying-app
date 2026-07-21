"""Unit tests for workspace CRUD endpoints."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.user import UserRole, WorkspaceMembership
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
    query = col.find.call_args.args[0]
    assert query["_id"] == {"$not": {"$regex": "^wsp_self_"}}


def test_list_workspaces_workspace_admin_excludes_self_learning(client):
    admin = make_user(
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_self_usr_test001", "wsp_classroom"],
    )
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_doc(None)

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/")

    assert response.status_code == 200
    query = col.find.call_args.args[0]
    assert query["_id"]["$in"] == ["wsp_classroom"]


def test_list_workspaces_student_keeps_self_learning(client):
    student = make_user(
        user_id="usr_student",
        role=UserRole.student,
        workspace_ids=["wsp_self_usr_student", "wsp_classroom"],
    )
    app.dependency_overrides[get_current_user] = lambda: student
    col = _col_with_doc(None)

    with patch("app.api.workspaces.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/")

    assert response.status_code == 200
    query = col.find.call_args.args[0]
    assert query["_id"]["$in"] == [
        "wsp_self_usr_student",
        "wsp_classroom",
    ]


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


# ── POST /api/v1/workspaces/{id}/members ──────────────────────────────────────


def test_add_member_does_not_downgrade_tenant_admin(client):
    admin = make_user(role=UserRole.tenant_admin, workspace_ids=["wsp_existing"])
    app.dependency_overrides[get_current_user] = lambda: admin
    workspace = make_workspace(workspace_id="wsp_new", admin_ids=["usr_owner"])

    workspace_col = _col_with_doc(workspace.model_dump(by_alias=True))
    user_col = _col_with_doc(admin.model_dump(by_alias=True))

    with patch(
        "app.api.workspaces.get_collection",
        side_effect=[workspace_col, user_col, workspace_col],
    ):
        response = client.post(
            "/api/v1/workspaces/wsp_new/members",
            json={
                "email": admin.email,
                "display_name": admin.display_name,
                "role": "student",
            },
        )

    assert response.status_code == 201
    saved_user = user_col.replace_one.call_args.args[1]
    assert saved_user["role"] == UserRole.tenant_admin.value


def test_add_member_keeps_workspace_admin_with_other_admin_membership(client):
    current_admin = make_user(role=UserRole.tenant_admin)
    target = make_user(
        user_id="usr_target",
        role=UserRole.workspace_admin,
        workspace_ids=[],
    )
    target.workspace_memberships = [
        WorkspaceMembership(
            workspace_id="wsp_existing",
            role=UserRole.workspace_admin,
            joined_at="2026-01-01T00:00:00+00:00",
        )
    ]
    app.dependency_overrides[get_current_user] = lambda: current_admin
    workspace = make_workspace(workspace_id="wsp_new", admin_ids=["usr_owner"])

    workspace_col = _col_with_doc(workspace.model_dump(by_alias=True))
    user_col = _col_with_doc(target.model_dump(by_alias=True))

    with patch(
        "app.api.workspaces.get_collection",
        side_effect=[workspace_col, user_col, workspace_col],
    ):
        response = client.post(
            "/api/v1/workspaces/wsp_new/members",
            json={
                "email": target.email,
                "display_name": target.display_name,
                "role": "student",
            },
        )

    assert response.status_code == 201
    saved_user = user_col.replace_one.call_args.args[1]
    assert saved_user["role"] == UserRole.workspace_admin.value


# ── DELETE /api/v1/workspaces/{id}/members/{user_id} ──────────────────────────


def test_remove_workspace_member_success(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    
    student = make_user(user_id="usr_student", role=UserRole.student)
    student.workspace_memberships = [
        WorkspaceMembership(
            workspace_id="wsp_test",
            role=UserRole.student,
            joined_at="2026-01-01T00:00:00+00:00",
        )
    ]
    
    workspace = make_workspace(workspace_id="wsp_test")
    workspace.student_ids = ["usr_student"]

    workspace_col = MagicMock()
    workspace_col.find_one = AsyncMock(return_value=workspace.model_dump(by_alias=True))
    workspace_col.update_one = AsyncMock()
    
    user_col = MagicMock()
    user_col.find_one = AsyncMock(return_value=student.model_dump(by_alias=True))
    user_col.update_one = AsyncMock()

    with patch(
        "app.api.workspaces.get_collection",
        side_effect=[workspace_col, user_col],
    ):
        response = client.delete("/api/v1/workspaces/wsp_test/members/usr_student")

    assert response.status_code == 204
    workspace_col.update_one.assert_called_once()
    user_col.update_one.assert_called_once()


def test_remove_workspace_member_forbidden_for_non_admin(client):
    student_caller = make_user(user_id="usr_caller", role=UserRole.student)
    app.dependency_overrides[get_current_user] = lambda: student_caller
    
    response = client.delete("/api/v1/workspaces/wsp_test/members/usr_student")
    assert response.status_code == 403

