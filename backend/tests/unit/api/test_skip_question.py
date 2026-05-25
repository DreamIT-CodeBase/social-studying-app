"""Unit tests for POST /questions/{question_id}/skip (Sprint 5.12).

Pins:

* Happy path: skip sets ``deferred_for`` to the caller, sets
  ``deferred_until`` to ~4h out, increments ``defer_count``, returns 204.
* Reaching the skip cap (3) clears ``deferred_until`` permanently — the
  question drops out of the rotation for this student.
* Status gating: only approved questions are skippable.
* Workspace scoping: a question in workspace B can't be skipped from
  a workspace A request.
* Access control: non-member students get 403.
"""

from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.question import (
    DifficultyLevel,
    McqOption,
    Question,
    QuestionStatus,
    QuestionType,
)
from app.models.user import UserRole
from tests.unit.conftest import make_user


@pytest.fixture
def client() -> TestClient:
    yield TestClient(app, raise_server_exceptions=True)
    app.dependency_overrides.clear()


@pytest.fixture
def student():
    user = make_user(
        user_id="stu_a",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: user
    return user


def _question(
    *,
    workspace_id: str = "wsp_a",
    status_: QuestionStatus = QuestionStatus.approved,
    defer_count: int = 0,
) -> dict:
    return Question(
        **{"_id": "qst_target"},
        tenant_id="ten_test001",
        workspace_id=workspace_id,
        document_id="doc_a",
        topic="Photosynthesis",
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.beginner,
        body="Which organelle performs photosynthesis?",
        options=[
            McqOption(key="A", text="Mitochondria", is_correct=False),
            McqOption(key="B", text="Chloroplast", is_correct=True),
        ],
        answer="B",
        explanation="Chloroplasts contain chlorophyll.",
        status=status_,
        defer_count=defer_count,
    ).model_dump(by_alias=True)


def _factory_for(question_doc: dict | None) -> tuple[MagicMock, list[dict]]:
    """Returns the get_collection factory + a capture list. The
    factory yields a single MagicMock for the QUESTION_QUEUE
    collection; find_one returns the seeded doc, update_one captures
    its $set payload for inspection.
    """
    captured: list[dict] = []
    questions_col = MagicMock()
    questions_col.find_one = AsyncMock(return_value=question_doc)

    async def _update_one(_filter, update):
        captured.append(update)
        return MagicMock(modified_count=1)

    questions_col.update_one = _update_one

    def _factory(_tid, collection):
        from app.core.database import QUESTION_QUEUE

        if collection == QUESTION_QUEUE:
            return questions_col
        raise AssertionError(collection)

    return _factory, captured


# ── Happy path ──────────────────────────────────────────────────────────


def test_skip_returns_204_and_persists_defer(client, student):
    factory, captured = _factory_for(_question())
    with patch("app.api.questions.get_collection", side_effect=factory):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/skip"
        )
    assert response.status_code == 204
    assert response.content == b""
    # Exactly one update with the defer payload.
    assert len(captured) == 1
    set_payload = captured[0]["$set"]
    assert set_payload["deferred_for"] == "stu_a"
    assert set_payload["defer_count"] == 1
    # deferred_until is ~4 hours out — give a generous tolerance for
    # wall-clock latency between the test setup and the call.
    assert set_payload["deferred_until"] is not None
    parsed = datetime.fromisoformat(set_payload["deferred_until"])
    delta_seconds = (parsed - datetime.now(UTC)).total_seconds()
    assert 3.5 * 3600 < delta_seconds < 4.5 * 3600


def test_skip_increments_existing_defer_count(client, student):
    factory, captured = _factory_for(_question(defer_count=1))
    with patch("app.api.questions.get_collection", side_effect=factory):
        client.post("/api/v1/workspaces/wsp_a/questions/qst_target/skip")
    assert captured[0]["$set"]["defer_count"] == 2


def test_third_skip_marks_question_as_permanently_deferred(client, student):
    """Three skips ⇒ ``deferred_until`` is set to None so the
    scheduler never re-prompts; ``defer_count`` is still recorded for
    admin analytics."""
    factory, captured = _factory_for(_question(defer_count=2))
    with patch("app.api.questions.get_collection", side_effect=factory):
        client.post("/api/v1/workspaces/wsp_a/questions/qst_target/skip")
    set_payload = captured[0]["$set"]
    assert set_payload["defer_count"] == 3
    assert set_payload["deferred_until"] is None


# ── Status gating ───────────────────────────────────────────────────────


def test_skip_pending_review_returns_409(client, student):
    factory, _ = _factory_for(_question(status_=QuestionStatus.pending_review))
    with patch("app.api.questions.get_collection", side_effect=factory):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/skip"
        )
    assert response.status_code == 409


def test_skip_rejected_returns_409(client, student):
    factory, _ = _factory_for(_question(status_=QuestionStatus.rejected))
    with patch("app.api.questions.get_collection", side_effect=factory):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/skip"
        )
    assert response.status_code == 409


# ── Missing / scoped-out ─────────────────────────────────────────────────


def test_skip_missing_question_returns_404(client, student):
    factory, _ = _factory_for(None)
    with patch("app.api.questions.get_collection", side_effect=factory):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_ghost/skip"
        )
    assert response.status_code == 404


def test_skip_question_from_other_workspace_returns_404(client, student):
    """The load filter is keyed on (id, workspace_id) so a question in
    wsp_b can't be skipped from a wsp_a request — find_one returns None."""
    factory, _ = _factory_for(None)  # workspace mismatch ⇒ None
    with patch("app.api.questions.get_collection", side_effect=factory):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_in_b/skip"
        )
    assert response.status_code == 404


# ── Access control ──────────────────────────────────────────────────────


def test_non_member_student_gets_403(client):
    user = make_user(
        user_id="stu_outsider",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: user
    response = client.post(
        "/api/v1/workspaces/wsp_b/questions/qst_x/skip"
    )
    assert response.status_code == 403
