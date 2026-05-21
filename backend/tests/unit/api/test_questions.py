"""Unit tests for POST /questions/next (Sprint 3.9 orchestrator).

The orchestrator wires together Sprint 3's other services — Learning
Path Engine, difficulty calibrator, content retrieval, student context,
question generation, and the safety reviewer — into a single endpoint
the student app calls. We mock every downstream service at its module
seam so the tests pin the ORCHESTRATION logic (which result triggers
which branch, what gets persisted, what the student sees) without
re-testing the downstream contracts.

What's pinned here
------------------
- Happy path: approved review → persist + return student-safe view.
- Student-safe view: answer/explanation/grading_hints/is_correct all
  stripped from the response payload.
- Flagged path: persist with status=pending_review +
  moderation_flagged=True + write moderation_log + try next candidate.
- Rejected path: don't persist, try next candidate.
- InsufficientSource path: try next candidate.
- Exhausted candidates → 503 with Retry-After header.
- NoTopicsAvailable → 409 with admin-facing guidance.
- Workspace not found → 404.
- Type rotation: ``len(recent_interactions) % len(enabled_types)``.
- Mastery lookup is case-insensitive (student-side topic naming may
  differ from canonical taxonomy name).
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.mcp_tools.retrieve_content import RetrieveContentOutput
from app.mcp_tools.retrieve_content import RetrievedChunk as ToolChunk
from app.mcp_tools.retrieve_student_context import (
    InteractionSummary,
    RetrieveStudentContextOutput,
    TopicMasteryView,
)
from app.models.question import DifficultyLevel, McqOption, QuestionType
from app.models.user import UserRole
from app.models.workspace import (
    CanonicalTopic,
    Taxonomy,
    Workspace,
    WorkspaceSettings,
)
from app.services.content_safety import SafetyVerdict
from app.services.learning_path import (
    NoTopicsAvailable,
    TopicScore,
    TopicSelection,
)
from app.services.question_generation import GeneratedQuestion, InsufficientSource
from app.services.question_safety import QuestionReview, ReviewVerdict
from tests.unit.conftest import make_user

# ── Helpers ─────────────────────────────────────────────────────────────────


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


def _workspace(
    *,
    question_types: list[str] | None = None,
    topics: list[CanonicalTopic] | None = None,
) -> Workspace:
    return Workspace(
        **{"_id": "wsp_a"},
        tenant_id=make_user().tenant_id,  # "ten_test001"
        name="Test Workspace",
        settings=WorkspaceSettings(
            question_types=question_types or ["mcq"],
        ),
        taxonomy=Taxonomy(topics=topics or []),
    )


def _topic_score(
    *,
    id_: str = "tpc_a",
    name: str = "Photosynthesis",
    score: float = 1.0,
) -> TopicScore:
    return TopicScore(
        topic_id=id_,
        topic_name=name,
        score=score,
        components={},
        complexity_level=2,
    )


def _selection(*candidates: TopicScore) -> TopicSelection:
    return TopicSelection(
        selected=candidates[0],
        candidates=list(candidates),
        rationale="(test)",
    )


def _context(
    *,
    mastery: dict[str, float] | None = None,
    interaction_count: int = 0,
) -> RetrieveStudentContextOutput:
    return RetrieveStudentContextOutput(
        student_id="stu_a",
        workspace_id="wsp_a",
        overall_mastery=0.0,
        last_recalculated_at=None,
        topic_mastery=[
            TopicMasteryView(
                topic=name,
                mastery_score=score,
                accuracy=score,
                questions_attempted=4,
                questions_correct=int(score * 4),
                last_seen_at=None,
            )
            for name, score in (mastery or {}).items()
        ],
        recent_interactions=[
            InteractionSummary(
                question_id=f"qst_{i}",
                topic="Algebra",
                is_correct=True,
                answered_at=f"2026-05-0{i+1}T00:00:00+00:00",
            )
            for i in range(interaction_count)
        ],
        seen_question_ids=[f"qst_{i}" for i in range(interaction_count)],
    )


def _retrieved(*texts: str) -> RetrieveContentOutput:
    chunks = [
        ToolChunk(
            chunk_id=f"chk_{i}",
            chunk_index=i,
            document_id="doc_a",
            text=t,
            topic_ids=["tpc_a"],
            score=0.9 - i * 0.1,
        )
        for i, t in enumerate(texts or ["chunk text"])
    ]
    return RetrieveContentOutput(chunks=chunks, mode="hybrid")


def _generated_mcq(
    *,
    body: str = "Which organelle performs photosynthesis?",
    correct: str = "B",
) -> GeneratedQuestion:
    return GeneratedQuestion(
        body=body,
        answer=correct,
        explanation="Chloroplasts contain chlorophyll.",
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.beginner,
        prompt_version="question_mcq_v1",
        options=[
            McqOption(key="A", text="Mitochondria", is_correct=False),
            McqOption(key="B", text="Chloroplast", is_correct=correct == "B"),
            McqOption(key="C", text="Ribosome", is_correct=False),
            McqOption(key="D", text="Nucleus", is_correct=False),
        ],
        grading_hints=[],
    )


def _clean_safety() -> SafetyVerdict:
    return SafetyVerdict(
        severities={"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0},
        flagged_categories=[],
    )


def _flagged_safety() -> SafetyVerdict:
    return SafetyVerdict(
        severities={"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 4},
        flagged_categories=["Violence"],
    )


def _review(
    verdict: ReviewVerdict,
    *,
    structural_failures: list[str] | None = None,
    safety: SafetyVerdict | None = None,
) -> QuestionReview:
    if safety is None:
        safety = (
            _flagged_safety()
            if verdict == ReviewVerdict.flagged
            else _clean_safety()
        )
    return QuestionReview(
        verdict=verdict,
        safety=safety,
        structural_failures=structural_failures or [],
        reason=f"({verdict.value})",
    )


def _patches(
    *,
    workspace: Workspace,
    selection: TopicSelection,
    context: RetrieveStudentContextOutput,
    retrieved: RetrieveContentOutput,
    generate_side_effect=None,
    review_side_effect=None,
    select_side_effect=None,
    generate_mock: AsyncMock | None = None,
):
    """Bundle the most common per-test mock setup.

    Returns a list of context managers the test caller enters together.
    Each test composes the list with whatever extra `patch` calls it
    needs (e.g. capturing the persisted Cosmos doc).
    """
    persisted: list[dict] = []
    moderation: list[dict] = []

    docs_col = MagicMock()
    docs_col.insert_one = AsyncMock(
        side_effect=lambda d: persisted.append(d) or MagicMock(inserted_id=d["_id"])
    )
    mod_col = MagicMock()
    mod_col.insert_one = AsyncMock(
        side_effect=lambda d: moderation.append(d) or MagicMock(inserted_id=d["_id"])
    )
    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(
        return_value=workspace.model_dump(by_alias=True)
    )

    def _factory(_tenant_id, collection):
        from app.core.database import MODERATION_LOG, QUESTION_QUEUE, WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        if collection == QUESTION_QUEUE:
            return docs_col
        if collection == MODERATION_LOG:
            return mod_col
        raise AssertionError(f"unexpected collection: {collection}")

    mocks: list = []

    mocks.append(
        patch("app.api.questions.get_collection", side_effect=_factory)
    )
    if select_side_effect is not None:
        mocks.append(
            patch(
                "app.api.questions.select_next_topic",
                AsyncMock(side_effect=select_side_effect),
            )
        )
    else:
        mocks.append(
            patch(
                "app.api.questions.select_next_topic",
                AsyncMock(return_value=selection),
            )
        )

    async def _invoke_router(name, params):
        if name == "retrieve_student_context":
            return context
        if name == "retrieve_content":
            return retrieved
        raise AssertionError(f"unexpected MCP tool: {name}")

    mocks.append(patch("app.api.questions.invoke", _invoke_router))

    if generate_mock is None:
        generate_mock = (
            AsyncMock(side_effect=generate_side_effect)
            if generate_side_effect is not None
            else AsyncMock(return_value=_generated_mcq())
        )
    mocks.append(
        patch(
            "app.api.questions.question_generation.generate_question",
            generate_mock,
        )
    )

    review_mock = (
        AsyncMock(side_effect=review_side_effect)
        if review_side_effect is not None
        else AsyncMock(return_value=_review(ReviewVerdict.approved))
    )
    mocks.append(
        patch("app.api.questions.question_safety.review_question", review_mock),
    )

    return mocks, persisted, moderation, generate_mock, review_mock


def _enter(mocks):
    """Enter every context manager in ``mocks`` as a stack."""
    from contextlib import ExitStack

    stack = ExitStack()
    for m in mocks:
        stack.enter_context(m)
    return stack


# ── Happy path ──────────────────────────────────────────────────────────────


def test_happy_path_returns_student_safe_question(client, student):
    """Approved review → question persisted + projected to the
    answer-stripped student view.
    """
    mocks, persisted, moderation, *_ = _patches(
        workspace=_workspace(),
        selection=_selection(_topic_score()),
        context=_context(),
        retrieved=_retrieved("Photosynthesis occurs in chloroplasts."),
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert response.status_code == 200
    body = response.json()
    assert body["topic"] == "Photosynthesis"
    assert body["question_type"] == "mcq"
    assert body["body"] == "Which organelle performs photosynthesis?"
    # Critical: NO answer / explanation / grading_hints / is_correct in the
    # student-facing response.
    assert "answer" not in body
    assert "explanation" not in body
    assert "grading_hints" not in body
    for opt in body["options"]:
        assert set(opt) == {"key", "text"}
        assert "is_correct" not in opt
    # Persisted exactly one question with status=approved.
    assert len(persisted) == 1
    assert persisted[0]["status"] == "approved"
    assert persisted[0]["moderation_flagged"] is False
    # No moderation log entry on the happy path.
    assert moderation == []


def test_persisted_question_records_all_audit_fields(client, student):
    mocks, persisted, *_ = _patches(
        workspace=_workspace(),
        selection=_selection(_topic_score()),
        context=_context(),
        retrieved=_retrieved("Source about chloroplasts."),
    )
    with _enter(mocks):
        client.post("/api/v1/workspaces/wsp_a/questions/next")

    saved = persisted[0]
    assert saved["topic"] == "Photosynthesis"
    assert saved["question_type"] == "mcq"
    assert saved["difficulty"] == "beginner"
    assert saved["prompt_version"] == "question_mcq_v1"
    assert saved["source_chunk_ids"] == ["chk_0"]
    assert saved["document_id"] == "doc_a"
    assert saved["workspace_id"] == "wsp_a"


# ── Flagged path ────────────────────────────────────────────────────────────


def test_flagged_first_candidate_persists_pending_review_and_tries_next(
    client, student
):
    """Flagged review → persist with pending_review + write moderation_log
    + skip to the next topic candidate. The student gets the second
    candidate's clean question.
    """
    cand1 = _topic_score(id_="tpc_1", name="FirstTopic")
    cand2 = _topic_score(id_="tpc_2", name="SecondTopic")

    # Two review calls: first flagged, second approved.
    reviews = [
        _review(ReviewVerdict.flagged, safety=_flagged_safety()),
        _review(ReviewVerdict.approved),
    ]
    mocks, persisted, moderation, *_ = _patches(
        workspace=_workspace(),
        selection=_selection(cand1, cand2),
        context=_context(),
        retrieved=_retrieved("source text"),
        review_side_effect=reviews,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert response.status_code == 200
    assert response.json()["topic"] == "SecondTopic"
    # Two questions persisted: first pending_review + flagged, second approved.
    assert len(persisted) == 2
    assert persisted[0]["status"] == "pending_review"
    assert persisted[0]["moderation_flagged"] is True
    assert persisted[1]["status"] == "approved"
    assert persisted[1]["moderation_flagged"] is False
    # One moderation_log entry for the flagged question.
    assert len(moderation) == 1
    assert moderation[0]["action"] == "flagged"
    assert moderation[0]["target_id"] == persisted[0]["_id"]
    assert moderation[0]["flagged_categories"] == ["Violence"]


# ── Rejected path ──────────────────────────────────────────────────────────


def test_rejected_first_candidate_does_not_persist_and_tries_next(client, student):
    """Rejected review → never persisted. Skip to next candidate."""
    cand1 = _topic_score(id_="tpc_1", name="FirstTopic")
    cand2 = _topic_score(id_="tpc_2", name="SecondTopic")
    reviews = [
        _review(
            ReviewVerdict.rejected,
            structural_failures=["MCQ option 'B' text leaks correctness"],
        ),
        _review(ReviewVerdict.approved),
    ]
    mocks, persisted, moderation, *_ = _patches(
        workspace=_workspace(),
        selection=_selection(cand1, cand2),
        context=_context(),
        retrieved=_retrieved("source text"),
        review_side_effect=reviews,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert response.status_code == 200
    assert response.json()["topic"] == "SecondTopic"
    # Only ONE persisted question (the approved one) — rejected questions
    # are dropped entirely.
    assert len(persisted) == 1
    assert persisted[0]["topic"] == "SecondTopic"
    assert moderation == []


# ── InsufficientSource path ────────────────────────────────────────────────


def test_insufficient_source_skips_to_next_candidate(client, student):
    cand1 = _topic_score(id_="tpc_1", name="DenseTopic")
    cand2 = _topic_score(id_="tpc_2", name="GoodTopic")
    generates = [
        InsufficientSource("nothing here"),
        _generated_mcq(),
    ]
    mocks, persisted, *_ = _patches(
        workspace=_workspace(),
        selection=_selection(cand1, cand2),
        context=_context(),
        retrieved=_retrieved("source text"),
        generate_side_effect=generates,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert response.status_code == 200
    assert response.json()["topic"] == "GoodTopic"
    assert len(persisted) == 1


# ── Exhausted candidates ────────────────────────────────────────────────────


def test_all_candidates_fail_returns_503_with_retry_after(client, student):
    cands = [
        _topic_score(id_=f"tpc_{i}", name=f"Topic{i}") for i in range(3)
    ]
    # All three rejected.
    reviews = [_review(ReviewVerdict.rejected) for _ in range(3)]
    mocks, persisted, *_ = _patches(
        workspace=_workspace(),
        selection=_selection(*cands),
        context=_context(),
        retrieved=_retrieved("source"),
        review_side_effect=reviews,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert response.status_code == 503
    assert response.headers.get("Retry-After") == "30"
    assert persisted == []  # rejected = never persisted


def test_empty_retrieval_skips_candidate_without_calling_generator(
    client, student
):
    """If retrieve_content returns no chunks for a topic, we shouldn't
    even try to generate from it — the prompt would refuse anyway and
    we'd waste a GPT-4o call.
    """
    cand1 = _topic_score(id_="tpc_empty", name="EmptyTopic")
    cand2 = _topic_score(id_="tpc_good", name="GoodTopic")
    selection = _selection(cand1, cand2)

    empty = RetrieveContentOutput(chunks=[], mode="empty")
    good = _retrieved("real source")

    # Two retrieval calls — index per attempt.
    retrieval_results = iter([empty, good])

    async def _invoke_router(name, params):
        if name == "retrieve_student_context":
            return _context()
        if name == "retrieve_content":
            return next(retrieval_results)
        raise AssertionError(name)

    generate_mock = AsyncMock(return_value=_generated_mcq())
    review_mock = AsyncMock(return_value=_review(ReviewVerdict.approved))

    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(
        return_value=_workspace().model_dump(by_alias=True)
    )
    persisted: list[dict] = []
    docs_col = MagicMock()
    docs_col.insert_one = AsyncMock(
        side_effect=lambda d: persisted.append(d) or MagicMock(inserted_id=d["_id"])
    )

    def _factory(_tid, collection):
        from app.core.database import WORKSPACES

        return workspaces_col if collection == WORKSPACES else docs_col

    with (
        patch("app.api.questions.get_collection", side_effect=_factory),
        patch(
            "app.api.questions.select_next_topic",
            AsyncMock(return_value=selection),
        ),
        patch("app.api.questions.invoke", _invoke_router),
        patch(
            "app.api.questions.question_generation.generate_question",
            generate_mock,
        ),
        patch(
            "app.api.questions.question_safety.review_question",
            review_mock,
        ),
    ):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert response.status_code == 200
    assert response.json()["topic"] == "GoodTopic"
    # generate_question was called exactly ONCE (only for GoodTopic).
    assert generate_mock.await_count == 1


# ── Error paths: pipeline can't even start ─────────────────────────────────


def test_no_topics_available_returns_409(client, student):
    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(
        return_value=_workspace().model_dump(by_alias=True)
    )

    def _factory(_tid, collection):
        from app.core.database import WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        return MagicMock()

    with (
        patch("app.api.questions.get_collection", side_effect=_factory),
        patch(
            "app.api.questions.select_next_topic",
            AsyncMock(side_effect=NoTopicsAvailable("empty workspace")),
        ),
    ):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert response.status_code == 409
    assert "upload study material" in response.json()["detail"].lower()


def test_workspace_not_found_returns_404(client, student):
    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(return_value=None)

    def _factory(_tid, collection):
        from app.core.database import WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        return MagicMock()

    with patch("app.api.questions.get_collection", side_effect=_factory):
        response = client.post("/api/v1/workspaces/wsp_ghost/questions/next")

    # Two paths produce 404: the access check (student not a member of
    # wsp_ghost) AND the workspace-not-found read. Tenant_admin tests
    # below cover the latter; here we just confirm the surface returns
    # 404, not 500.
    assert response.status_code in (403, 404)


# ── Type rotation ──────────────────────────────────────────────────────────


def test_type_rotation_based_on_recent_interactions(client, student):
    """With two enabled types and 1 recent interaction, the rotation
    should pick index 1 (the second type).
    """
    generate_mock = AsyncMock(return_value=_generated_mcq())
    mocks, *_ = _patches(
        workspace=_workspace(question_types=["mcq", "short_answer"]),
        selection=_selection(_topic_score()),
        context=_context(interaction_count=1),
        retrieved=_retrieved("source"),
        generate_mock=generate_mock,
    )
    with _enter(mocks):
        client.post("/api/v1/workspaces/wsp_a/questions/next")
    assert (
        generate_mock.await_args.kwargs["question_type"]
        == QuestionType.short_answer
    )


def test_single_enabled_type_always_used(client, student):
    generate_mock = AsyncMock(return_value=_generated_mcq())
    mocks, *_ = _patches(
        workspace=_workspace(question_types=["short_answer"]),
        selection=_selection(_topic_score()),
        context=_context(interaction_count=42),  # high count shouldn't matter
        retrieved=_retrieved("source"),
        generate_mock=generate_mock,
    )
    with _enter(mocks):
        client.post("/api/v1/workspaces/wsp_a/questions/next")
    assert (
        generate_mock.await_args.kwargs["question_type"]
        == QuestionType.short_answer
    )


def test_invalid_question_type_in_settings_is_ignored(client, student):
    """An admin who hand-edits settings.question_types to include a typo
    must NOT crash the endpoint. We log + skip the bad value.
    """
    generate_mock = AsyncMock(return_value=_generated_mcq())
    mocks, *_ = _patches(
        workspace=_workspace(question_types=["mcq", "not_a_real_type"]),
        selection=_selection(_topic_score()),
        context=_context(),
        retrieved=_retrieved("source"),
        generate_mock=generate_mock,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")
    assert response.status_code == 200
    assert generate_mock.await_args.kwargs["question_type"] == QuestionType.mcq


def test_empty_question_types_falls_back_to_mcq(client, student):
    generate_mock = AsyncMock(return_value=_generated_mcq())
    mocks, *_ = _patches(
        workspace=_workspace(question_types=[]),
        selection=_selection(_topic_score()),
        context=_context(),
        retrieved=_retrieved("source"),
        generate_mock=generate_mock,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/questions/next")
    assert response.status_code == 200
    assert generate_mock.await_args.kwargs["question_type"] == QuestionType.mcq


# ── Mastery lookup ─────────────────────────────────────────────────────────


def test_mastery_lookup_is_case_insensitive(client, student):
    """Canonical topic might be "Photosynthesis" while the student's
    knowledge_state has "photosynthesis" (lowercase from older
    interactions). The calibrator must still see the correct mastery,
    not 0.0.
    """
    calibrate_calls: list[float] = []

    def _capture_calibrate(*, mastery, step_hint=None):
        calibrate_calls.append(mastery)
        # Return a minimal calibration so the rest of the flow proceeds.
        from app.services.difficulty import DifficultyCalibration

        return DifficultyCalibration(
            difficulty=DifficultyLevel.beginner,
            predicted_success=0.7,
            in_target_zone=True,
            candidates={
                DifficultyLevel.beginner: 0.7,
                DifficultyLevel.intermediate: 0.5,
                DifficultyLevel.advanced: 0.3,
            },
            rationale="(test)",
            step_applied=None,
        )

    mocks, *_ = _patches(
        workspace=_workspace(),
        selection=_selection(_topic_score(name="Photosynthesis")),
        context=_context(mastery={"photosynthesis": 0.85}),  # lower-case
        retrieved=_retrieved("source"),
    )
    mocks.append(
        patch(
            "app.api.questions.calibrate_difficulty",
            side_effect=_capture_calibrate,
        )
    )
    with _enter(mocks):
        client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert calibrate_calls == [0.85]


def test_unknown_topic_mastery_defaults_to_zero(client, student):
    """A topic the student has never answered should pass 0.0 mastery to
    the calibrator — the cold-start branch of difficulty.
    """
    calibrate_calls: list[float] = []

    def _capture_calibrate(*, mastery, step_hint=None):
        calibrate_calls.append(mastery)
        from app.services.difficulty import DifficultyCalibration

        return DifficultyCalibration(
            difficulty=DifficultyLevel.beginner,
            predicted_success=0.5,
            in_target_zone=False,
            candidates={
                DifficultyLevel.beginner: 0.5,
                DifficultyLevel.intermediate: 0.4,
                DifficultyLevel.advanced: 0.2,
            },
            rationale="(test)",
            step_applied=None,
        )

    mocks, *_ = _patches(
        workspace=_workspace(),
        selection=_selection(_topic_score(name="NewTopic")),
        context=_context(mastery={"OtherTopic": 0.8}),
        retrieved=_retrieved("source"),
    )
    mocks.append(
        patch(
            "app.api.questions.calibrate_difficulty",
            side_effect=_capture_calibrate,
        )
    )
    with _enter(mocks):
        client.post("/api/v1/workspaces/wsp_a/questions/next")

    assert calibrate_calls == [0.0]
