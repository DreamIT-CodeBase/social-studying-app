"""Unit tests for POST /questions/{question_id}/answer (Sprint 3.10).

Pins:
- Happy path (correct + wrong) → feedback shape + XP + persisted state.
- Status gating: only ``approved`` questions are answerable.
- Workspace scoping: a question in workspace X can't be answered from
  workspace Y (even if the route would otherwise let the request
  through).
- Interaction row written to ``interactions`` for every attempt.
- knowledge_state.record_attempt called with the right args.
- AnswerFeedback echoes the post-update mastery scores.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.models.knowledge_state import KnowledgeState, TopicMastery
from app.models.question import (
    DifficultyLevel,
    McqOption,
    Question,
    QuestionStatus,
    QuestionType,
)
from app.models.user import UserRole
from tests.unit.conftest import make_user

# ── Fixtures ────────────────────────────────────────────────────────────────


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


def _mcq_question(
    *,
    answer: str = "B",
    workspace_id: str = "wsp_a",
    status_: QuestionStatus = QuestionStatus.approved,
    difficulty: DifficultyLevel = DifficultyLevel.beginner,
) -> dict:
    return Question(
        **{"_id": "qst_target"},
        tenant_id="ten_test001",
        workspace_id=workspace_id,
        document_id="doc_a",
        topic="Photosynthesis",
        question_type=QuestionType.mcq,
        difficulty=difficulty,
        body="Which organelle performs photosynthesis?",
        options=[
            McqOption(key="A", text="Mitochondria", is_correct=False),
            McqOption(key="B", text="Chloroplast", is_correct=answer == "B"),
            McqOption(key="C", text="Ribosome", is_correct=False),
            McqOption(key="D", text="Nucleus", is_correct=False),
        ],
        answer=answer,
        explanation="Chloroplasts contain chlorophyll.",
        status=status_,
    ).model_dump(by_alias=True)


def _state_after(
    *,
    topic: str = "Photosynthesis",
    topic_mastery: float = 0.1,
    overall: float = 0.1,
) -> KnowledgeState:
    """Post-update knowledge state the orchestrator will receive from
    ``knowledge_state.record_attempt``. We fake the service rather
    than re-test its math.
    """
    return KnowledgeState(
        **{"_id": "ks_a"},
        tenant_id="ten_test001",
        workspace_id="wsp_a",
        student_id="stu_a",
        topics=[
            TopicMastery(
                topic=topic,
                mastery_score=topic_mastery,
                questions_attempted=1,
                questions_correct=1 if topic_mastery > 0 else 0,
                last_seen_at="2026-06-01T00:00:00+00:00",
            )
        ],
        overall_mastery=overall,
        last_recalculated_at="2026-06-01T00:00:00+00:00",
    )


def _patches(*, question_doc: dict, record_attempt_state: KnowledgeState):
    """Bundle the standard mock setup.

    Returns context managers + captures so tests can inspect what was
    persisted.
    """
    questions_col = MagicMock()
    questions_col.find_one = AsyncMock(return_value=question_doc)

    interactions_col = MagicMock()
    persisted_interactions: list[dict] = []
    interactions_col.insert_one = AsyncMock(
        side_effect=lambda d: (
            persisted_interactions.append(d) or MagicMock(inserted_id=d["_id"])
        )
    )

    def _factory(_tid, collection):
        from app.core.database import INTERACTIONS, QUESTION_QUEUE

        if collection == QUESTION_QUEUE:
            return questions_col
        if collection == INTERACTIONS:
            return interactions_col
        raise AssertionError(f"unexpected collection: {collection}")

    record_attempt_mock = AsyncMock(return_value=record_attempt_state)

    return (
        [
            patch("app.api.questions.get_collection", side_effect=_factory),
            patch(
                "app.api.questions.knowledge_state_service.record_attempt",
                record_attempt_mock,
            ),
        ],
        persisted_interactions,
        record_attempt_mock,
    )


def _enter(mocks):
    from contextlib import ExitStack

    stack = ExitStack()
    for m in mocks:
        stack.enter_context(m)
    return stack


# ── Happy path: correct + wrong ────────────────────────────────────────────


def test_correct_answer_returns_full_feedback(client, student):
    mocks, persisted, record_mock = _patches(
        question_doc=_mcq_question(answer="B"),
        record_attempt_state=_state_after(topic_mastery=0.1, overall=0.1),
    )
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/answer",
            json={"answer": "B", "time_spent_seconds": 12},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["question_id"] == "qst_target"
    assert body["is_correct"] is True
    assert body["canonical_answer"] == "B"
    assert body["explanation"] == "Chloroplasts contain chlorophyll."
    # Attempt XP (10) + correct beginner bonus (5) = 15.
    assert body["xp_earned"] == 15
    assert body["new_topic_mastery"] == pytest.approx(0.1)
    assert body["new_overall_mastery"] == pytest.approx(0.1)

    # Interaction row persisted with the correct fields.
    assert len(persisted) == 1
    ix = persisted[0]
    assert ix["question_id"] == "qst_target"
    assert ix["topic"] == "Photosynthesis"
    assert ix["is_correct"] is True
    assert ix["answer_given"] == "B"
    assert ix["time_spent_seconds"] == 12
    assert ix["xp_earned"] == 15

    # Mastery update service called with the right args.
    record_mock.assert_awaited_once()
    kwargs = record_mock.await_args.kwargs
    assert kwargs["topic"] == "Photosynthesis"
    assert kwargs["difficulty"] == DifficultyLevel.beginner
    assert kwargs["is_correct"] is True


def test_wrong_answer_returns_attempt_xp_only(client, student):
    mocks, persisted, _ = _patches(
        question_doc=_mcq_question(answer="B", difficulty=DifficultyLevel.advanced),
        record_attempt_state=_state_after(topic_mastery=0.0, overall=0.0),
    )
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/answer",
            json={"answer": "A"},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["is_correct"] is False
    # Wrong answer → attempt XP only, no correct-bonus.
    assert body["xp_earned"] == 10
    assert persisted[0]["is_correct"] is False


def test_correct_advanced_question_awards_max_bonus(client, student):
    mocks, _, _ = _patches(
        question_doc=_mcq_question(answer="B", difficulty=DifficultyLevel.advanced),
        record_attempt_state=_state_after(topic_mastery=0.3, overall=0.3),
    )
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/answer",
            json={"answer": "B"},
        )
    # Attempt (10) + advanced bonus (20) = 30.
    assert response.json()["xp_earned"] == 30


def test_correct_intermediate_question_awards_mid_bonus(client, student):
    mocks, _, _ = _patches(
        question_doc=_mcq_question(
            answer="B", difficulty=DifficultyLevel.intermediate
        ),
        record_attempt_state=_state_after(topic_mastery=0.2, overall=0.2),
    )
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/answer",
            json={"answer": "B"},
        )
    # Attempt (10) + intermediate bonus (10) = 20.
    assert response.json()["xp_earned"] == 20


# ── Status gating ──────────────────────────────────────────────────────────


def test_pending_review_question_returns_409(client, student):
    """A flagged question persisted with status=pending_review must
    NOT be answerable — a probing client that scraped its id from the
    moderation dashboard should hit a hard refusal.
    """
    mocks, _, _ = _patches(
        question_doc=_mcq_question(status_=QuestionStatus.pending_review),
        record_attempt_state=_state_after(),
    )
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/answer",
            json={"answer": "B"},
        )
    assert response.status_code == 409
    assert "pending_review" in response.json()["detail"]


def test_rejected_question_returns_409(client, student):
    """Rejected questions shouldn't exist in Cosmos per the 3.9
    orchestrator's policy, but a hand-crafted doc would still be
    refused at this layer.
    """
    mocks, _, _ = _patches(
        question_doc=_mcq_question(status_=QuestionStatus.rejected),
        record_attempt_state=_state_after(),
    )
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_target/answer",
            json={"answer": "B"},
        )
    assert response.status_code == 409


# ── Missing / scoped-out question ──────────────────────────────────────────


def test_missing_question_returns_404(client, student):
    questions_col = MagicMock()
    questions_col.find_one = AsyncMock(return_value=None)

    def _factory(_tid, collection):
        from app.core.database import QUESTION_QUEUE

        return questions_col if collection == QUESTION_QUEUE else MagicMock()

    with patch("app.api.questions.get_collection", side_effect=_factory):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_ghost/answer",
            json={"answer": "B"},
        )
    assert response.status_code == 404


def test_question_from_other_workspace_returns_404(client, student):
    """The find_one filter includes ``workspace_id`` — a question that
    exists but in workspace B can't be loaded from a workspace A
    request. We verify by returning None when the workspace_id doesn't
    match.
    """
    questions_col = MagicMock()
    questions_col.find_one = AsyncMock(return_value=None)  # filter mismatch

    def _factory(_tid, collection):
        from app.core.database import QUESTION_QUEUE

        return questions_col if collection == QUESTION_QUEUE else MagicMock()

    with patch("app.api.questions.get_collection", side_effect=_factory):
        response = client.post(
            "/api/v1/workspaces/wsp_a/questions/qst_in_b/answer",
            json={"answer": "B"},
        )
    assert response.status_code == 404
    # The find_one call must have included workspace_id in its filter.
    call_filter = questions_col.find_one.await_args.args[0]
    assert call_filter["workspace_id"] == "wsp_a"


# ── Access control ─────────────────────────────────────────────────────────


def test_non_member_student_gets_403(client):
    """Student isn't a member of wsp_b — even with a real question in
    wsp_b they should be refused at the access check.
    """
    user = make_user(
        user_id="stu_outsider",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: user

    response = client.post(
        "/api/v1/workspaces/wsp_b/questions/qst_x/answer",
        json={"answer": "B"},
    )
    assert response.status_code == 403


def test_tenant_admin_can_answer_in_any_workspace(client):
    """Tenant admins have full visibility — they should be able to
    test-answer questions in any workspace within the tenant.
    """
    admin = make_user(user_id="usr_admin", role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin

    mocks, _, _ = _patches(
        question_doc=_mcq_question(workspace_id="wsp_other"),
        record_attempt_state=_state_after(),
    )
    # Override the workspace_id in the question doc to match the URL.
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_other/questions/qst_target/answer",
            json={"answer": "B"},
        )
    assert response.status_code == 200


# ── Validation ─────────────────────────────────────────────────────────────


def test_empty_answer_is_rejected_at_validation(client, student):
    """min_length=1 on AnswerSubmission.answer — an empty submission
    should be rejected by FastAPI before reaching the handler.
    """
    response = client.post(
        "/api/v1/workspaces/wsp_a/questions/qst_target/answer",
        json={"answer": ""},
    )
    assert response.status_code == 422
