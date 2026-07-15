"""Unit tests for document upload, list, and delete endpoints."""

from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.document import Document, DocumentStatus, DocumentType
from app.models.user import UserRole
from tests.unit.conftest import make_user


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


def _col_with_docs(docs: list[dict]):
    """Mock collection where find() returns the supplied documents."""
    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)
    col.insert_one = AsyncMock(return_value=MagicMock(inserted_id="doc_new"))
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    class _AsyncCursor:
        def __init__(self, items):
            self._items = items
            self._idx = 0

        def __aiter__(self):
            return self

        async def __anext__(self):
            if self._idx >= len(self._items):
                raise StopAsyncIteration
            item = self._items[self._idx]
            self._idx += 1
            return item

    col.find = MagicMock(return_value=_AsyncCursor(docs))
    return col


def _document_doc(
    document_id: str = "doc_test001",
    workspace_id: str = "wsp_test001",
    tenant_id: str = "ten_test001",
    status_: DocumentStatus = DocumentStatus.pending,
) -> dict:
    return Document(
        **{"_id": document_id},
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        uploaded_by="usr_test001",
        filename="study.pdf",
        blob_url="https://example.blob.core.windows.net/docs/study.pdf",
        file_size_bytes=2048,
        doc_type=DocumentType.pdf,
        status=status_,
    ).model_dump(by_alias=True)


# POST /api/v1/workspaces/{ws}/documents/scrape


@pytest.mark.parametrize(
    "url",
    [
        "http://127.0.0.1/",
        "http://169.254.169.254/latest/meta-data/",
        "http://[::1]/",
        "http://localhost/",
    ],
)
def test_scrape_document_rejects_private_destinations(client, url):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    response = client.post(
        "/api/v1/workspaces/wsp_test001/documents/scrape",
        json={"url": url},
    )

    assert response.status_code == 422
    assert "private or local" in response.json()["detail"].lower()


def test_scrape_document_happy_path_saves_plain_text(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_docs([])
    page = b"<html><body><h1>Photosynthesis</h1><p>Light &amp; energy</p></body></html>"

    with (
        patch("app.api.documents.get_collection", return_value=col),
        patch(
            "app.api.documents._fetch_public_document",
            AsyncMock(
                return_value=(
                    page,
                    "text/html",
                    httpx.URL("https://example.com/biology/lesson"),
                )
            ),
        ),
        patch(
            "app.api.documents.blob_storage.upload_document",
            AsyncMock(return_value="https://x.blob/scraped.txt"),
        ) as mock_upload,
        patch(
            "app.api.documents.document_queue.publish_extraction_message",
            AsyncMock(return_value=None),
        ) as mock_publish,
    ):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/documents/scrape",
            json={"url": "https://example.com/biology/lesson"},
        )

    assert response.status_code == 201
    assert response.json()["filename"] == "scraped_example.com_biology_lesson.txt"
    saved_text = mock_upload.await_args.kwargs["content"].decode("utf-8")
    assert "<html>" not in saved_text
    assert "Photosynthesis" in saved_text
    assert "Light & energy" in saved_text
    mock_publish.assert_awaited_once()


# ── POST /api/v1/workspaces/{ws}/documents ────────────────────────────────────


def test_upload_document_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_docs([])

    blob_url = "https://example.blob.core.windows.net/docs/study.pdf"
    with (
        patch("app.api.documents.get_collection", return_value=col),
        patch(
            "app.api.documents.blob_storage.upload_document",
            AsyncMock(return_value=blob_url),
        ) as mock_upload,
        patch(
            "app.api.documents.document_queue.publish_extraction_message",
            AsyncMock(return_value=None),
        ) as mock_publish,
    ):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/documents",
            files={"file": ("study.pdf", b"%PDF-1.4 fake content", "application/pdf")},
        )

    assert response.status_code == 201
    data = response.json()
    assert data["filename"] == "study.pdf"
    assert data["doc_type"] == "pdf"
    assert data["status"] == "pending"
    assert data["id"].startswith("doc_")
    mock_upload.assert_awaited_once()
    mock_publish.assert_awaited_once()
    col.insert_one.assert_awaited_once()

    # Verify the queue message carries every field the worker needs.
    sent_msg = mock_publish.await_args.args[0]
    assert sent_msg.document_id == data["id"]
    assert sent_msg.workspace_id == "wsp_test001"
    assert sent_msg.content_type == "application/pdf"
    assert sent_msg.blob_path.endswith("/study.pdf")


def test_upload_document_as_workspace_admin_member_succeeds(client):
    """A workspace admin who belongs to the workspace can upload."""
    ws_admin = make_user(
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_test001"],
    )
    app.dependency_overrides[get_current_user] = lambda: ws_admin
    col = _col_with_docs([])

    with (
        patch("app.api.documents.get_collection", return_value=col),
        patch(
            "app.api.documents.blob_storage.upload_document",
            AsyncMock(return_value="https://x.blob/study.pdf"),
        ),
        patch(
            "app.api.documents.document_queue.publish_extraction_message",
            AsyncMock(return_value=None),
        ),
    ):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/documents",
            files={"file": ("study.pdf", b"%PDF-1.4 fake", "application/pdf")},
        )

    assert response.status_code == 201


def test_upload_document_as_workspace_admin_non_member_is_forbidden(client):
    """Workspace admin uploading to a workspace they don't belong to → 403."""
    ws_admin = make_user(
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_other"],  # not wsp_test001
    )
    app.dependency_overrides[get_current_user] = lambda: ws_admin

    col = _col_with_docs([])
    with patch("app.api.documents.get_collection", return_value=col):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/documents",
            files={"file": ("study.pdf", b"%PDF-1.4 fake", "application/pdf")},
        )

    assert response.status_code == 403


def test_upload_document_as_student_is_forbidden(client):
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student

    col = _col_with_docs([])
    with patch("app.api.documents.get_collection", return_value=col):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/documents",
            files={"file": ("study.pdf", b"%PDF-1.4 fake", "application/pdf")},
        )

    assert response.status_code == 403


def test_upload_document_unsupported_type_returns_422(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    response = client.post(
        "/api/v1/workspaces/wsp_test001/documents",
        files={"file": ("evil.exe", b"MZ binary", "application/x-msdownload")},
    )

    assert response.status_code == 422
    assert "Unsupported file type" in response.json()["detail"]


def test_upload_document_empty_file_returns_422(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    response = client.post(
        "/api/v1/workspaces/wsp_test001/documents",
        files={"file": ("empty.pdf", b"", "application/pdf")},
    )

    assert response.status_code == 422
    assert "empty" in response.json()["detail"].lower()


def test_upload_document_oversized_returns_422(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    # Patch the limit to 10 bytes so we don't have to send 50 MB.
    with patch("app.api.documents._MAX_FILE_BYTES", 10):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/documents",
            files={"file": ("big.pdf", b"x" * 100, "application/pdf")},
        )

    assert response.status_code == 422
    assert "size limit" in response.json()["detail"].lower()


def test_upload_marks_document_failed_when_publish_raises(client):
    """If Service Bus publish fails, the doc is marked failed and the API 422s.

    Without this, a publish outage would leave docs stuck in 'pending' forever
    with the admin none the wiser.
    """
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    doc_col = _col_with_docs([])
    wsp_col = MagicMock()
    wsp_col.update_one = AsyncMock()

    def get_collection_mock(tenant_id, collection_name):
        if collection_name == "workspaces":
            return wsp_col
        return doc_col

    with (
        patch("app.api.documents.get_collection", side_effect=get_collection_mock),
        patch(
            "app.api.documents.blob_storage.upload_document",
            AsyncMock(return_value="https://x.blob/study.pdf"),
        ),
        patch(
            "app.api.documents.document_queue.publish_extraction_message",
            AsyncMock(side_effect=RuntimeError("service bus down")),
        ),
    ):
        response = client.post(
            "/api/v1/workspaces/wsp_test001/documents",
            files={"file": ("study.pdf", b"%PDF-1.4 fake", "application/pdf")},
        )

    assert response.status_code == 422
    # insert_one ran (doc was created); update_one ran (doc was marked failed).
    doc_col.insert_one.assert_awaited_once()
    doc_col.update_one.assert_awaited_once()
    update_call = doc_col.update_one.await_args
    assert update_call.args[1]["$set"]["status"] == "failed"
    wsp_col.update_one.assert_awaited_once()
    assert "could not be queued" in response.json()["detail"]


# ── GET /api/v1/workspaces/{ws}/documents ─────────────────────────────────────


def test_list_documents_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_docs([_document_doc(), _document_doc(document_id="doc_test002")])

    with patch("app.api.documents.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/documents")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert {d["id"] for d in data} == {"doc_test001", "doc_test002"}


def test_list_documents_empty_workspace_returns_empty_list(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = _col_with_docs([])

    with patch("app.api.documents.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/documents")

    assert response.status_code == 200
    assert response.json() == []


def test_list_documents_as_member_student_succeeds(client):
    """Students who belong to a workspace can list its documents (read-only)."""
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student
    col = _col_with_docs([_document_doc()])

    with patch("app.api.documents.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/documents")

    assert response.status_code == 200
    assert len(response.json()) == 1


def test_list_documents_as_non_member_student_is_forbidden(client):
    student = make_user(role=UserRole.student, workspace_ids=[])  # not a member
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.get("/api/v1/workspaces/wsp_test001/documents")

    assert response.status_code == 403


# ── GET /api/v1/workspaces/{ws}/documents/{id} ───────────────────────────────


def test_get_document_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = MagicMock()
    col.find_one = AsyncMock(return_value=_document_doc(status_=DocumentStatus.vectorizing))

    with patch("app.api.documents.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/documents/doc_test001")

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "doc_test001"
    assert data["status"] == "vectorizing"
    # Filter scopes to id + workspace + tenant + soft-delete guard.
    find_filter = col.find_one.await_args.args[0]
    assert find_filter["_id"] == "doc_test001"
    assert find_filter["workspace_id"] == "wsp_test001"
    assert find_filter["tenant_id"] == admin.tenant_id
    assert find_filter["deleted_at"] is None


def test_get_document_not_found_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)

    with patch("app.api.documents.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/documents/doc_missing")

    assert response.status_code == 404


def test_get_document_soft_deleted_returns_404(client):
    """Soft-deleted docs should not be visible to the polling UI."""
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = MagicMock()
    # The find filter includes deleted_at: None, so the DB returns None for
    # soft-deleted rows. We assert the same shape as missing.
    col.find_one = AsyncMock(return_value=None)

    with patch("app.api.documents.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/documents/doc_test001")

    assert response.status_code == 404


def test_get_document_as_member_student_succeeds(client):
    """Students who belong to the workspace can poll docs (read-only)."""
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student
    col = MagicMock()
    col.find_one = AsyncMock(return_value=_document_doc())

    with patch("app.api.documents.get_collection", return_value=col):
        response = client.get("/api/v1/workspaces/wsp_test001/documents/doc_test001")

    assert response.status_code == 200


def test_get_document_as_non_member_student_is_forbidden(client):
    student = make_user(role=UserRole.student, workspace_ids=[])
    app.dependency_overrides[get_current_user] = lambda: student

    response = client.get("/api/v1/workspaces/wsp_test001/documents/doc_test001")

    assert response.status_code == 403


# ── DELETE /api/v1/workspaces/{ws}/documents/{id} ────────────────────────────


def test_delete_document_happy_path(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    doc_col = MagicMock()
    doc_col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    wsp_col = MagicMock()
    wsp_col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    def get_collection_mock(tenant_id, collection_name):
        if collection_name == "workspaces":
            return wsp_col
        return doc_col

    with patch("app.api.documents.get_collection", side_effect=get_collection_mock):
        response = client.delete("/api/v1/workspaces/wsp_test001/documents/doc_test001")

    assert response.status_code == 204
    doc_col.update_one.assert_awaited_once()
    wsp_col.update_one.assert_awaited_once()


def test_delete_document_not_found_returns_404(client):
    admin = make_user(role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    col = MagicMock()
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=0))

    with patch("app.api.documents.get_collection", return_value=col):
        response = client.delete("/api/v1/workspaces/wsp_test001/documents/doc_missing")

    assert response.status_code == 404


def test_delete_document_as_student_is_forbidden(client):
    student = make_user(role=UserRole.student, workspace_ids=["wsp_test001"])
    app.dependency_overrides[get_current_user] = lambda: student

    col = _col_with_docs([])
    with patch("app.api.documents.get_collection", return_value=col):
        response = client.delete("/api/v1/workspaces/wsp_test001/documents/doc_test001")

    assert response.status_code == 403


def test_delete_document_as_workspace_admin_non_member_is_forbidden(client):
    ws_admin = make_user(
        role=UserRole.workspace_admin,
        workspace_ids=["wsp_other"],
    )
    app.dependency_overrides[get_current_user] = lambda: ws_admin

    col = _col_with_docs([])
    with patch("app.api.documents.get_collection", return_value=col):
        response = client.delete("/api/v1/workspaces/wsp_test001/documents/doc_test001")

    assert response.status_code == 403
