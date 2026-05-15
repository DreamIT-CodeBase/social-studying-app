"""Unit tests for the taxonomy CRUD endpoints (Sprint 2.11).

The route layer is thin — most of the meaty logic lives in
``app.services.taxonomy`` and is covered by ``test_taxonomy_service.py``
extensions. This file asserts:

- Auth (member can read, only admins can write / regenerate).
- Wiring (service is called with the right arguments).
- Error translation (validation errors → 422, version conflict → 409,
  missing workspace → 404).
- 202 Accepted on regenerate plus a scheduled BackgroundTask.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.user import UserRole
from app.models.workspace import CanonicalTopic, Taxonomy
from app.services.taxonomy import (
    RegenerateOutcome,
    TaxonomyValidationError,
    TaxonomyVersionConflict,
)
from tests.unit.conftest import make_user, make_workspace


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


def _workspace_with_taxonomy(
    *,
    workspace_id: str = "wsp_test001",
    tenant_id: str = "ten_test001",
    topics: list[CanonicalTopic] | None = None,
    version: int = 0,
) -> dict:
    """Return a workspace row dict matching what Cosmos's find_one yields."""
    ws = make_workspace(workspace_id=workspace_id, tenant_id=tenant_id)
    ws.taxonomy = Taxonomy(topics=topics or [])
    ws.taxonomy_version = version
    return ws.model_dump(by_alias=True)


def _topic(
    topic_id: str,
    name: str,
    *,
    parent_id: str | None = None,
    description: str | None = None,
) -> CanonicalTopic:
    return CanonicalTopic(
        id=topic_id,
        name=name,
        parent_id=parent_id,
        description=description,
    )


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/v1/workspaces/{ws}/taxonomy
# ─────────────────────────────────────────────────────────────────────────────


def test_get_taxonomy_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    workspace_doc = _workspace_with_taxonomy(
        topics=[
            _topic("tpc_a", "Photosynthesis"),
            _topic("tpc_b", "Cellular Respiration", parent_id="tpc_a"),
        ],
        version=4,
    )
    col = MagicMock()
    col.find_one = AsyncMock(return_value=workspace_doc)

    with patch("app.api.taxonomy.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/taxonomy")

    assert response.status_code == 200
    body = response.json()
    assert body["taxonomy_version"] == 4
    assert len(body["topics"]) == 2
    by_id = {t["id"]: t for t in body["topics"]}
    assert by_id["tpc_b"]["parent_id"] == "tpc_a"


def test_get_taxonomy_workspace_member_succeeds(client):
    """Students who belong to the workspace can read the taxonomy."""
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student

    col = MagicMock()
    col.find_one = AsyncMock(return_value=_workspace_with_taxonomy())

    with patch("app.api.taxonomy.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/taxonomy")

    assert response.status_code == 200


def test_get_taxonomy_non_member_student_forbidden(client):
    student = make_user(role=UserRole.student, workspace_ids=[])
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.get("/api/v1/workspaces/wsp_test001/taxonomy")
    assert response.status_code == 403


def test_get_taxonomy_workspace_not_found(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)

    with patch("app.api.taxonomy.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_missing/taxonomy")

    assert response.status_code == 404


# ─────────────────────────────────────────────────────────────────────────────
# PUT /api/v1/workspaces/{ws}/taxonomy
# ─────────────────────────────────────────────────────────────────────────────


def _put_payload(topics: list[CanonicalTopic], version: int) -> dict:
    return {
        "topics": [t.model_dump() for t in topics],
        "taxonomy_version": version,
    }


def test_put_taxonomy_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    new_topics = [_topic("tpc_a", "Photosynthesis")]
    # The service returns the refreshed Workspace (with bumped version).
    refreshed = make_workspace()
    refreshed.taxonomy = Taxonomy(topics=new_topics)
    refreshed.taxonomy_version = 5

    with patch(
        "app.api.taxonomy.taxonomy_service.replace_taxonomy",
        AsyncMock(return_value=refreshed),
    ) as mock_replace:
        response = client.put(
            "/api/v1/workspaces/wsp_test001/taxonomy",
            json=_put_payload(new_topics, version=4),
        )

    assert response.status_code == 200
    body = response.json()
    assert body["taxonomy_version"] == 5
    assert len(body["topics"]) == 1
    kwargs = mock_replace.await_args.kwargs
    assert kwargs["expected_version"] == 4
    assert kwargs["workspace_id"] == "wsp_test001"
    assert kwargs["tenant_id"] == admin.tenant_id
    assert len(kwargs["topics"]) == 1


def test_put_taxonomy_version_conflict_returns_409(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    with patch(
        "app.api.taxonomy.taxonomy_service.replace_taxonomy",
        AsyncMock(side_effect=TaxonomyVersionConflict("stale")),
    ):
        response = client.put(
            "/api/v1/workspaces/wsp_test001/taxonomy",
            json=_put_payload([_topic("tpc_a", "X")], version=99),
        )

    assert response.status_code == 409
    assert "modified by another writer" in response.json()["detail"]


def test_put_taxonomy_validation_error_returns_422(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    with patch(
        "app.api.taxonomy.taxonomy_service.replace_taxonomy",
        AsyncMock(side_effect=TaxonomyValidationError("cycle through tpc_a")),
    ):
        response = client.put(
            "/api/v1/workspaces/wsp_test001/taxonomy",
            json=_put_payload([_topic("tpc_a", "X")], version=0),
        )

    assert response.status_code == 422
    assert "cycle" in response.json()["detail"]


def test_put_taxonomy_missing_workspace_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    with patch(
        "app.api.taxonomy.taxonomy_service.replace_taxonomy",
        AsyncMock(side_effect=RuntimeError("Workspace wsp_missing not found")),
    ):
        response = client.put(
            "/api/v1/workspaces/wsp_missing/taxonomy",
            json=_put_payload([_topic("tpc_a", "X")], version=0),
        )

    assert response.status_code == 404


def test_put_taxonomy_as_non_admin_forbidden(client):
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.put(
        "/api/v1/workspaces/wsp_test001/taxonomy",
        json=_put_payload([_topic("tpc_a", "X")], version=0),
    )
    assert response.status_code == 403


def test_put_taxonomy_as_workspace_admin_member_succeeds(client):
    """Workspace admins (teachers/parents) can edit even without tenant_admin."""
    ws_admin = make_user(
        role=UserRole.workspace_admin, workspace_ids=["wsp_test001"]
    )
    app.dependency_overrides[get_current_user] = lambda: ws_admin

    new_topics = [_topic("tpc_a", "X")]
    refreshed = make_workspace()
    refreshed.taxonomy = Taxonomy(topics=new_topics)
    refreshed.taxonomy_version = 1

    with patch(
        "app.api.taxonomy.taxonomy_service.replace_taxonomy",
        AsyncMock(return_value=refreshed),
    ):
        response = client.put(
            "/api/v1/workspaces/wsp_test001/taxonomy",
            json=_put_payload(new_topics, version=0),
        )

    assert response.status_code == 200


def test_put_taxonomy_as_non_member_workspace_admin_forbidden(client):
    """A workspace_admin who is NOT a member of this workspace must be blocked."""
    ws_admin = make_user(
        role=UserRole.workspace_admin, workspace_ids=["wsp_other"]
    )
    app.dependency_overrides[get_current_user] = lambda: ws_admin

    response = client.put(
        "/api/v1/workspaces/wsp_test001/taxonomy",
        json=_put_payload([_topic("tpc_a", "X")], version=0),
    )
    assert response.status_code == 403


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/workspaces/{ws}/taxonomy/regenerate
# ─────────────────────────────────────────────────────────────────────────────


def test_regenerate_happy_path_returns_202(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    col = MagicMock()
    col.find_one = AsyncMock(return_value=_workspace_with_taxonomy(version=2))

    # Patch the service so the BackgroundTask doesn't actually try to run
    # the merge pipeline against the (mocked) DB.
    with (
        patch("app.api.taxonomy.get_collection", return_value=col),
        patch(
            "app.api.taxonomy.taxonomy_service.regenerate_from_documents",
            AsyncMock(
                return_value=RegenerateOutcome(
                    documents_merged=3, topics_total=12, final_version=6
                )
            ),
        ) as mock_regen,
    ):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/taxonomy/regenerate"
        )

    assert response.status_code == 202
    body = response.json()
    assert body["status"] == "accepted"
    assert body["workspace_id"] == "wsp_test001"
    # BackgroundTask runs after the response is sent — TestClient waits
    # for it, so by here it must have called the service.
    mock_regen.assert_awaited_once()
    kwargs = mock_regen.await_args.kwargs
    assert kwargs["tenant_id"] == admin.tenant_id
    assert kwargs["workspace_id"] == "wsp_test001"


def test_regenerate_missing_workspace_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)

    with patch("app.api.taxonomy.get_collection", return_value=col):
        response = client.post(
            "/api/v1/workspaces/wsp_missing/taxonomy/regenerate"
        )

    assert response.status_code == 404


def test_regenerate_as_non_admin_forbidden(client):
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.post(
        "/api/v1/workspaces/wsp_test001/taxonomy/regenerate"
    )
    assert response.status_code == 403


def test_regenerate_background_failure_does_not_crash_request(client):
    """A failure inside the BackgroundTask must not surface to the admin
    as a 5xx — the request already returned 202.
    """
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    col = MagicMock()
    col.find_one = AsyncMock(return_value=_workspace_with_taxonomy())

    with (
        patch("app.api.taxonomy.get_collection", return_value=col),
        patch(
            "app.api.taxonomy.taxonomy_service.regenerate_from_documents",
            AsyncMock(side_effect=RuntimeError("OpenAI is having a moment")),
        ),
    ):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/taxonomy/regenerate"
        )

    assert response.status_code == 202
