"""Unit tests for the admin moderation dashboard endpoints."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.document import Document, DocumentStatus, DocumentType
from app.models.moderation import ModerationAction, ModerationLog, ModerationTarget
from app.models.user import UserRole
from tests.unit.conftest import make_user


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


class _AsyncCursor:
    def __init__(self, items):
        self._items = list(items)
        self._idx = 0

    def __aiter__(self):
        return self

    async def __anext__(self):
        if self._idx >= len(self._items):
            raise StopAsyncIteration
        item = self._items[self._idx]
        self._idx += 1
        return item


def _mod_entry(
    *,
    entry_id: str = "mod_001",
    action: ModerationAction = ModerationAction.flagged,
    target_id: str = "doc_001",
    target_type: ModerationTarget = ModerationTarget.document,
    reason: str = "Hate",
    severities: dict[str, int] | None = None,
) -> dict:
    return ModerationLog(
        id=entry_id,
        tenant_id="ten_test001",
        workspace_id="wsp_test001",
        target_type=target_type,
        target_id=target_id,
        action=action,
        performed_by="system",
        reason=reason,
        severities=severities or {"Hate": 2, "SelfHarm": 0, "Sexual": 0, "Violence": 0},
        flagged_categories=["Hate"] if action == ModerationAction.flagged else [],
    ).model_dump(by_alias=True)


def _doc(
    *,
    document_id: str = "doc_001",
    status_: DocumentStatus = DocumentStatus.flagged,
    blob_path: str | None = "ten_test001/wsp_test001/text/doc_001.txt",
) -> dict:
    return Document(
        **{"_id": document_id},
        tenant_id="ten_test001",
        workspace_id="wsp_test001",
        uploaded_by="usr_test001",
        filename="biology.pdf",
        blob_url="https://x.blob/biology.pdf",
        file_size_bytes=2048,
        doc_type=DocumentType.pdf,
        status=status_,
        page_count=12,
        moderation_flagged=True,
        extracted_text_blob_path=blob_path,
    ).model_dump(by_alias=True)


def _collections(*, mod_find=None, mod_find_one=None, document=None):
    """Return a get_collection stub that routes by collection name."""
    mod = MagicMock()
    mod.find = MagicMock(return_value=_AsyncCursor(mod_find or []))
    mod.find_one = AsyncMock(return_value=mod_find_one)
    mod.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    docs = MagicMock()
    docs.find_one = AsyncMock(return_value=document)
    docs.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    wsp = MagicMock()
    wsp.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    def _get(_tenant_id, name):
        if name == "moderation_log":
            return mod
        if name == "documents":
            return docs
        if name == "workspaces":
            return wsp
        return MagicMock()

    return _get, mod, docs


# ── GET /flagged ──────────────────────────────────────────────────────────────


def test_list_flagged_projects_document_filename_and_severity(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    get_col, _, _ = _collections(mod_find=[_mod_entry()], document=_doc())
    with patch("app.api.moderation.get_collection", side_effect=get_col):
        resp = client.get("/api/v1/workspaces/wsp_test001/moderation/flagged")

    assert resp.status_code == 200
    items = resp.json()
    assert len(items) == 1
    item = items[0]
    assert item["id"] == "mod_001"
    assert item["content_kind"] == "document"
    assert item["topic"] == "biology.pdf"
    assert item["reason"] == "Hate"
    assert item["severity"] == 2
    assert item["verdict"] == "pending"
    assert "flagged for Hate" in item["excerpt"]


def test_list_flagged_filters_to_flagged_action(client):
    """The query must scope to action=flagged only."""
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    get_col, mod, _ = _collections(mod_find=[], document=None)
    with patch("app.api.moderation.get_collection", side_effect=get_col):
        client.get("/api/v1/workspaces/wsp_test001/moderation/flagged")

    query = mod.find.call_args.args[0]
    assert query["action"] == {"$in": ["flagged"]}
    assert query["workspace_id"] == "wsp_test001"


# ── GET /log ──────────────────────────────────────────────────────────────────


def test_list_log_includes_resolved_and_auto_approved(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    entries = [
        _mod_entry(entry_id="mod_a", action=ModerationAction.auto_approved, reason="clean"),
        _mod_entry(entry_id="mod_b", action=ModerationAction.rejected),
    ]
    get_col, mod, _ = _collections(mod_find=entries, document=_doc())
    with patch("app.api.moderation.get_collection", side_effect=get_col):
        resp = client.get("/api/v1/workspaces/wsp_test001/moderation/log")

    assert resp.status_code == 200
    verdicts = {i["id"]: i["verdict"] for i in resp.json()}
    assert verdicts == {"mod_a": "approved", "mod_b": "rejected"}
    assert set(mod.find.call_args.args[0]["action"]["$in"]) == {
        "approved",
        "rejected",
        "auto_approved",
    }


# ── PUT /resolve ──────────────────────────────────────────────────────────────


def test_resolve_approve_resumes_ingestion(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    get_col, mod, docs = _collections(mod_find_one=_mod_entry(), document=_doc())
    with (
        patch("app.api.moderation.get_collection", side_effect=get_col),
        patch(
            "app.services.topic_queue.publish_topic_message",
            AsyncMock(return_value=None),
        ) as mock_publish,
    ):
        resp = client.put(
            "/api/v1/workspaces/wsp_test001/moderation/mod_001/resolve",
            json={"approved": True},
        )

    assert resp.status_code == 200
    assert resp.json()["verdict"] == "approved"
    # Document rewound to text_extracted + flag cleared.
    doc_update = docs.update_one.call_args.args[1]["$set"]
    assert doc_update["status"] == DocumentStatus.text_extracted.value
    assert doc_update["moderation_flagged"] is False
    # Re-enqueued to the topic worker with the persisted blob path.
    mock_publish.assert_awaited_once()
    sent = mock_publish.await_args.args[0]
    assert sent.document_id == "doc_001"
    assert sent.extracted_text_blob_path == "ten_test001/wsp_test001/text/doc_001.txt"
    # Log entry transitioned to approved by the admin.
    mod_update = mod.update_one.call_args.args[1]["$set"]
    assert mod_update["action"] == "approved"
    assert mod_update["performed_by"] == "usr_test001"


def test_resolve_reject_soft_deletes_document(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    get_col, mod, docs = _collections(mod_find_one=_mod_entry(), document=_doc())
    with (
        patch("app.api.moderation.get_collection", side_effect=get_col),
        patch(
            "app.services.topic_queue.publish_topic_message",
            AsyncMock(return_value=None),
        ) as mock_publish,
    ):
        resp = client.put(
            "/api/v1/workspaces/wsp_test001/moderation/mod_001/resolve",
            json={"approved": False},
        )

    assert resp.status_code == 200
    assert resp.json()["verdict"] == "rejected"
    assert "deleted_at" in docs.update_one.call_args.args[1]["$set"]
    mock_publish.assert_not_called()  # rejected content is not reprocessed


def test_resolve_missing_item_returns_404(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    get_col, _, _ = _collections(mod_find_one=None)
    with patch("app.api.moderation.get_collection", side_effect=get_col):
        resp = client.put(
            "/api/v1/workspaces/wsp_test001/moderation/mod_x/resolve",
            json={"approved": True},
        )
    assert resp.status_code == 404


def test_resolve_already_resolved_returns_404(client):
    """An auto_approved (non-pending) entry has nothing to decide."""
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    get_col, _, _ = _collections(
        mod_find_one=_mod_entry(action=ModerationAction.auto_approved)
    )
    with patch("app.api.moderation.get_collection", side_effect=get_col):
        resp = client.put(
            "/api/v1/workspaces/wsp_test001/moderation/mod_001/resolve",
            json={"approved": True},
        )
    assert resp.status_code == 404


# ── Access control ────────────────────────────────────────────────────────────


def test_workspace_admin_non_member_forbidden(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.workspace_admin, workspace_ids=["wsp_other"]
    )
    get_col, _, _ = _collections(mod_find=[])
    with patch("app.api.moderation.get_collection", side_effect=get_col):
        resp = client.get("/api/v1/workspaces/wsp_test001/moderation/flagged")
    assert resp.status_code == 403


def test_student_role_forbidden(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        user_id="usr_student", role=UserRole.student, workspace_ids=["wsp_test001"]
    )
    resp = client.get("/api/v1/workspaces/wsp_test001/moderation/flagged")
    assert resp.status_code == 403


# ── Question & Flashcard moderation tests ─────────────────────────────────────


def test_resolve_question_approved(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    mod_entry = _mod_entry(
        entry_id="mod_q",
        action=ModerationAction.flagged,
        target_id="qst_001",
        target_type=ModerationTarget.question,
    )
    
    mod_col = MagicMock()
    mod_col.find_one = AsyncMock(return_value=mod_entry)
    mod_col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    
    qst_col = MagicMock()
    qst_col.find_one = AsyncMock(return_value={"_id": "qst_001", "workspace_id": "wsp_test001", "status": "pending_review"})
    qst_col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    
    def get_col_side_effect(tenant_id, collection):
        if collection == "moderation_log":
            return mod_col
        elif collection == "question_queue":
            return qst_col
        return MagicMock()

    with patch("app.api.moderation.get_collection", side_effect=get_col_side_effect):
        resp = client.put(
            "/api/v1/workspaces/wsp_test001/moderation/mod_q/resolve",
            json={"approved": True},
        )
        
    assert resp.status_code == 200
    assert resp.json()["verdict"] == "approved"
    
    qst_update = qst_col.update_one.call_args.args[1]["$set"]
    assert qst_update["status"] == "approved"
    assert qst_update["moderation_flagged"] is False


def test_resolve_flashcard_rejected(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    mod_entry = _mod_entry(
        entry_id="mod_fc",
        action=ModerationAction.flagged,
        target_id="fc_001",
        target_type=ModerationTarget.flashcard,
    )
    
    mod_col = MagicMock()
    mod_col.find_one = AsyncMock(return_value=mod_entry)
    mod_col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    
    fc_col = MagicMock()
    fc_col.find_one = AsyncMock(return_value={"_id": "fc_001", "workspace_id": "wsp_test001", "status": "pending_review"})
    fc_col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    
    def get_col_side_effect(tenant_id, collection):
        if collection == "moderation_log":
            return mod_col
        elif collection == "flashcards":
            return fc_col
        return MagicMock()

    with patch("app.api.moderation.get_collection", side_effect=get_col_side_effect):
        resp = client.put(
            "/api/v1/workspaces/wsp_test001/moderation/mod_fc/resolve",
            json={"approved": False},
        )
        
    assert resp.status_code == 200
    assert resp.json()["verdict"] == "rejected"
    
    fc_update = fc_col.update_one.call_args.args[1]["$set"]
    assert fc_update["status"] == "rejected"
    assert fc_update["moderation_flagged"] is False


def test_resolve_reject_decrements_workspace_document_count(client):
    app.dependency_overrides[get_current_user] = lambda: make_user(
        role=UserRole.tenant_admin
    )
    get_col, mod, docs = _collections(mod_find_one=_mod_entry(), document=_doc())
    
    workspace_col = MagicMock()
    workspace_col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    
    def get_col_side_effect(tenant_id, collection):
        if collection == "moderation_log":
            return mod
        elif collection == "documents":
            return docs
        elif collection == "workspaces":
            return workspace_col
        return MagicMock()

    with (
        patch("app.api.moderation.get_collection", side_effect=get_col_side_effect),
        patch(
            "app.services.topic_queue.publish_topic_message",
            AsyncMock(return_value=None),
        ),
    ):
        resp = client.put(
            "/api/v1/workspaces/wsp_test001/moderation/mod_001/resolve",
            json={"approved": False},
        )
        
    assert resp.status_code == 200
    workspace_col.update_one.assert_called_once()
    ws_update = workspace_col.update_one.call_args.args[1]
    assert ws_update == {"$inc": {"document_count": -1}}
