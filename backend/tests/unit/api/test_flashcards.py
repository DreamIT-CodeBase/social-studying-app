"""Unit tests for the flashcard endpoints (Sprint 3.12).

Covers:
- POST /flashcards/next happy path → persisted approved card +
  full-content student response (front + back + explanation).
- Flagged path: persist with pending_review + skip + try next candidate.
- Rejected (structural fail): don't persist, try next candidate.
- InsufficientSource → try next candidate.
- Exhausted candidates → 503 with Retry-After.
- NoTopicsAvailable → 409.
- POST /flashcards/{id}/rate: writes a rating event; status-gated;
  workspace-scoped; non-member 403; missing card 404.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.main import app
from app.mcp_tools.retrieve_content import RetrieveContentOutput
from app.mcp_tools.retrieve_content import RetrievedChunk as ToolChunk
from app.models.flashcard import Flashcard, FlashcardStatus
from app.models.user import UserRole
from app.models.workspace import Taxonomy, Workspace, WorkspaceSettings
from app.services.content_safety import SafetyVerdict
from app.services.flashcard_generation import (
    GeneratedFlashcard,
    InsufficientFlashcardSource,
)
from app.services.learning_path import (
    NoTopicsAvailable,
    TopicScore,
    TopicSelection,
)
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


def _workspace() -> Workspace:
    return Workspace(
        **{"_id": "wsp_a"},
        tenant_id="ten_test001",
        name="Test Workspace",
        settings=WorkspaceSettings(),
        taxonomy=Taxonomy(topics=[]),
    )


def _topic_score(*, id_: str = "tpc_a", name: str = "Photosynthesis") -> TopicScore:
    return TopicScore(
        topic_id=id_,
        topic_name=name,
        score=1.0,
        components={},
        complexity_level=2,
    )


def _selection(*candidates: TopicScore) -> TopicSelection:
    return TopicSelection(
        selected=candidates[0],
        candidates=list(candidates),
        rationale="(test)",
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
        for i, t in enumerate(texts or ["source text"])
    ]
    return RetrieveContentOutput(chunks=chunks, mode="hybrid")


def _generated(
    *,
    front: str = "What is photosynthesis?",
    back: str = "The process by which plants convert sunlight to chemical energy.",
    explanation: str = "Occurs in chloroplasts.",
) -> GeneratedFlashcard:
    return GeneratedFlashcard(
        front=front,
        back=back,
        explanation=explanation,
        prompt_version="flashcard_v1",
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


def _next_patches(
    *,
    selection: TopicSelection,
    retrieved: RetrieveContentOutput,
    generate_side_effect=None,
    safety: SafetyVerdict | None = None,
):
    """Patch the seams /flashcards/next reaches.

    Returns the context manager list + the captured persisted docs +
    the safety mock (so tests with multi-attempt scenarios can inspect
    its call count).
    """
    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(
        return_value=_workspace().model_dump(by_alias=True)
    )

    persisted: list[dict] = []
    flashcards_col = MagicMock()
    flashcards_col.insert_one = AsyncMock(
        side_effect=lambda d: persisted.append(d) or MagicMock(inserted_id=d["_id"])
    )

    def _factory(_tid, collection):
        from app.core.database import FLASHCARDS, WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        if collection == FLASHCARDS:
            return flashcards_col
        raise AssertionError(f"unexpected collection: {collection}")

    async def _invoke_router(name, params):
        if name == "retrieve_content":
            return retrieved
        raise AssertionError(f"unexpected MCP tool: {name}")

    generate_mock = (
        AsyncMock(side_effect=generate_side_effect)
        if generate_side_effect is not None
        else AsyncMock(return_value=_generated())
    )
    safety_mock = AsyncMock(return_value=safety or _clean_safety())

    mocks = [
        patch("app.api.flashcards.get_collection", side_effect=_factory),
        patch(
            "app.api.flashcards.select_next_topic",
            AsyncMock(return_value=selection),
        ),
        patch("app.api.flashcards.invoke", _invoke_router),
        patch(
            "app.api.flashcards.flashcard_generation.generate_flashcard",
            generate_mock,
        ),
        patch(
            "app.api.flashcards.content_safety.analyze_extracted_text",
            safety_mock,
        ),
    ]
    return mocks, persisted, safety_mock, generate_mock


def _enter(mocks):
    from contextlib import ExitStack

    stack = ExitStack()
    for m in mocks:
        stack.enter_context(m)
    return stack


# ── /flashcards/next: happy path ───────────────────────────────────────────


def test_next_happy_path_returns_full_flashcard(client, student):
    mocks, persisted, *_ = _next_patches(
        selection=_selection(_topic_score()),
        retrieved=_retrieved("Plants use chlorophyll."),
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/flashcards/next")

    assert response.status_code == 200
    body = response.json()
    # Student view includes the FULL card (unlike questions/next which
    # withholds the answer).
    assert body["topic"] == "Photosynthesis"
    assert body["front"] == "What is photosynthesis?"
    assert body["back"].startswith("The process")
    assert body["explanation"] == "Occurs in chloroplasts."
    assert "id" in body
    assert body["id"].startswith("fc_")
    # Persisted approved + moderation_flagged=False.
    assert len(persisted) == 1
    saved = persisted[0]
    assert saved["status"] == "approved"
    assert saved["moderation_flagged"] is False
    assert saved["source_chunk_ids"] == ["chk_0"]


def test_next_persisted_records_all_audit_fields(client, student):
    mocks, persisted, *_ = _next_patches(
        selection=_selection(_topic_score()),
        retrieved=_retrieved("source text"),
    )
    with _enter(mocks):
        client.post("/api/v1/workspaces/wsp_a/flashcards/next")
    saved = persisted[0]
    assert saved["topic"] == "Photosynthesis"
    assert saved["prompt_version"] == "flashcard_v1"
    assert saved["document_id"] == "doc_a"
    assert saved["workspace_id"] == "wsp_a"


# ── /flashcards/next: flagged path ─────────────────────────────────────────


def test_next_flagged_first_candidate_persists_and_tries_next(client, student):
    """Flagged card → persisted with pending_review + skip + serve the
    second candidate's clean card.
    """
    cand1 = _topic_score(id_="tpc_1", name="FirstTopic")
    cand2 = _topic_score(id_="tpc_2", name="SecondTopic")

    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(
        return_value=_workspace().model_dump(by_alias=True)
    )
    persisted: list[dict] = []
    flashcards_col = MagicMock()
    flashcards_col.insert_one = AsyncMock(
        side_effect=lambda d: persisted.append(d) or MagicMock(inserted_id=d["_id"])
    )

    def _factory(_tid, collection):
        from app.core.database import FLASHCARDS, WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        if collection == FLASHCARDS:
            return flashcards_col
        raise AssertionError(collection)

    async def _invoke_router(name, params):
        return _retrieved("source")

    safety_results = iter([_flagged_safety(), _clean_safety()])

    async def _safety(text):
        return next(safety_results)

    with (
        patch("app.api.flashcards.get_collection", side_effect=_factory),
        patch(
            "app.api.flashcards.select_next_topic",
            AsyncMock(return_value=_selection(cand1, cand2)),
        ),
        patch("app.api.flashcards.invoke", _invoke_router),
        patch(
            "app.api.flashcards.flashcard_generation.generate_flashcard",
            AsyncMock(return_value=_generated()),
        ),
        patch(
            "app.api.flashcards.content_safety.analyze_extracted_text",
            _safety,
        ),
    ):
        response = client.post("/api/v1/workspaces/wsp_a/flashcards/next")

    assert response.status_code == 200
    # Served the SECOND candidate's card since the first one was flagged.
    assert response.json()["topic"] == "SecondTopic"
    # Two persisted: first flagged, second approved.
    assert len(persisted) == 2
    assert persisted[0]["status"] == "flagged"
    assert persisted[0]["moderation_flagged"] is True
    assert persisted[0]["topic"] == "FirstTopic"
    assert persisted[1]["status"] == "approved"
    assert persisted[1]["topic"] == "SecondTopic"


# ── /flashcards/next: rejected path ────────────────────────────────────────


def test_next_rejected_first_candidate_not_persisted(client, student):
    """A flashcard whose front equals its back (no recall value) is
    rejected by the structural check. NOT persisted. Skip to next.
    """
    cand1 = _topic_score(id_="tpc_1", name="FirstTopic")
    cand2 = _topic_score(id_="tpc_2", name="SecondTopic")
    # First generation produces front==back; second is clean.
    generated_iter = iter([
        _generated(front="Glucose", back="Glucose"),  # structural fail
        _generated(),
    ])

    async def _generate(*, topic, grounding_chunks, seen_card_fronts=None):
        return next(generated_iter)

    mocks, persisted, *_ = _next_patches(
        selection=_selection(cand1, cand2),
        retrieved=_retrieved("source"),
        generate_side_effect=_generate,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/flashcards/next")

    assert response.status_code == 200
    # Only the second (clean) card persisted; rejected dropped on floor.
    assert len(persisted) == 1
    assert persisted[0]["status"] == "approved"


# ── /flashcards/next: InsufficientSource ───────────────────────────────────


def test_next_insufficient_source_skips_to_next_candidate(client, student):
    cand1 = _topic_score(id_="tpc_1", name="DenseTopic")
    cand2 = _topic_score(id_="tpc_2", name="GoodTopic")
    generated_iter = iter([
        InsufficientFlashcardSource("nothing in source"),
        _generated(),
    ])

    async def _generate(*, topic, grounding_chunks, seen_card_fronts=None):
        item = next(generated_iter)
        if isinstance(item, Exception):
            raise item
        return item

    mocks, persisted, *_ = _next_patches(
        selection=_selection(cand1, cand2),
        retrieved=_retrieved("source"),
        generate_side_effect=_generate,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/flashcards/next")

    assert response.status_code == 200
    assert len(persisted) == 1


def test_next_empty_retrieval_skips_candidate_without_calling_generator(
    client, student
):
    cand1 = _topic_score(id_="tpc_empty", name="EmptyTopic")
    cand2 = _topic_score(id_="tpc_good", name="GoodTopic")
    retrieval_iter = iter([
        RetrieveContentOutput(chunks=[], mode="empty"),
        _retrieved("real source"),
    ])

    async def _invoke_router(name, params):
        return next(retrieval_iter)

    workspaces_col = MagicMock()
    workspaces_col.find_one = AsyncMock(
        return_value=_workspace().model_dump(by_alias=True)
    )
    persisted: list[dict] = []
    flashcards_col = MagicMock()
    flashcards_col.insert_one = AsyncMock(
        side_effect=lambda d: persisted.append(d) or MagicMock(inserted_id=d["_id"])
    )

    def _factory(_tid, collection):
        from app.core.database import FLASHCARDS, WORKSPACES

        if collection == WORKSPACES:
            return workspaces_col
        if collection == FLASHCARDS:
            return flashcards_col
        raise AssertionError(collection)

    generate_mock = AsyncMock(return_value=_generated())
    with (
        patch("app.api.flashcards.get_collection", side_effect=_factory),
        patch(
            "app.api.flashcards.select_next_topic",
            AsyncMock(return_value=_selection(cand1, cand2)),
        ),
        patch("app.api.flashcards.invoke", _invoke_router),
        patch(
            "app.api.flashcards.flashcard_generation.generate_flashcard",
            generate_mock,
        ),
        patch(
            "app.api.flashcards.content_safety.analyze_extracted_text",
            AsyncMock(return_value=_clean_safety()),
        ),
    ):
        response = client.post("/api/v1/workspaces/wsp_a/flashcards/next")

    assert response.status_code == 200
    # Generator was called exactly once (for GoodTopic).
    assert generate_mock.await_count == 1
    assert len(persisted) == 1


# ── /flashcards/next: exhausted candidates ─────────────────────────────────


def test_next_all_candidates_fail_returns_503_with_retry_after(client, student):
    cands = [_topic_score(id_=f"tpc_{i}", name=f"T{i}") for i in range(3)]

    async def _generate(*, topic, grounding_chunks, seen_card_fronts=None):
        # Front==back structural failure → all rejected.
        return _generated(front="X", back="X")

    mocks, persisted, *_ = _next_patches(
        selection=_selection(*cands),
        retrieved=_retrieved("source"),
        generate_side_effect=_generate,
    )
    with _enter(mocks):
        response = client.post("/api/v1/workspaces/wsp_a/flashcards/next")

    assert response.status_code == 503
    assert response.headers.get("Retry-After") == "30"
    assert persisted == []


# ── /flashcards/next: error surface ────────────────────────────────────────


def test_next_no_topics_available_returns_409(client, student):
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
        patch("app.api.flashcards.get_collection", side_effect=_factory),
        patch(
            "app.api.flashcards.select_next_topic",
            AsyncMock(side_effect=NoTopicsAvailable("empty")),
        ),
    ):
        response = client.post("/api/v1/workspaces/wsp_a/flashcards/next")
    assert response.status_code == 409
    assert "upload study material" in response.json()["detail"].lower()


def test_next_non_member_student_gets_403(client):
    """Student isn't a member of wsp_b — access check refuses."""
    user = make_user(
        user_id="stu_x",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: user
    response = client.post("/api/v1/workspaces/wsp_b/flashcards/next")
    assert response.status_code == 403


# ── /flashcards/{id}/rate ──────────────────────────────────────────────────


def _flashcard_doc(
    *,
    id_: str = "fc_target",
    workspace_id: str = "wsp_a",
    status_: FlashcardStatus = FlashcardStatus.approved,
) -> dict:
    return Flashcard(
        **{"_id": id_},
        tenant_id="ten_test001",
        workspace_id=workspace_id,
        document_id="doc_a",
        topic="Photosynthesis",
        front="What is photosynthesis?",
        back="The process by which plants convert sunlight to chemical energy.",
        explanation="Occurs in chloroplasts.",
        status=status_,
    ).model_dump(by_alias=True)


def _rate_patches(flashcard: dict | None):
    """Patch loaders + the rating-events writer + the gamification engine.

    The gamification mock returns a zero-state delta so the rate-flow
    tests don't double-test the engine math (it has its own tests in
    ``tests/unit/services/test_gamification.py``).
    """
    from app.services.gamification import GamificationDelta

    flashcards_col = MagicMock()
    flashcards_col.find_one = AsyncMock(return_value=flashcard)
    ratings_col = MagicMock()
    captured: list[dict] = []
    ratings_col.insert_one = AsyncMock(
        side_effect=lambda d: captured.append(d) or MagicMock(inserted_id=d["_id"])
    )

    def _factory(_tid, collection):
        from app.core.database import FLASHCARD_RATINGS, FLASHCARDS

        if collection == FLASHCARDS:
            return flashcards_col
        if collection == FLASHCARD_RATINGS:
            return ratings_col
        raise AssertionError(collection)

    gamification_mock = AsyncMock(
        return_value=GamificationDelta(
            xp_earned=5,
            new_level=1,
            leveled_up=False,
            streak_days=1,
            streak_extended=True,
            badges_unlocked=[],
            state=None,
        )
    )

    return (
        [
            patch("app.api.flashcards.get_collection", side_effect=_factory),
            patch(
                "app.api.flashcards.gamification_service.record_flashcard_rating",
                gamification_mock,
            ),
        ],
        captured,
    )


def test_rate_happy_path_records_event(client, student):
    mocks, captured = _rate_patches(_flashcard_doc())
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/flashcards/fc_target/rate",
            json={"rating": "easy"},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["flashcard_id"] == "fc_target"
    assert body["rating"] == "easy"
    assert "rated_at" in body
    # One rating event written.
    assert len(captured) == 1
    event = captured[0]
    assert event["flashcard_id"] == "fc_target"
    assert event["student_id"] == "stu_a"
    assert event["rating"] == "easy"
    assert event["topic"] == "Photosynthesis"


@pytest.mark.parametrize("rating", ["easy", "medium", "hard"])
def test_rate_accepts_all_three_buckets(client, student, rating):
    mocks, _ = _rate_patches(_flashcard_doc())
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/flashcards/fc_target/rate",
            json={"rating": rating},
        )
    assert response.status_code == 200
    assert response.json()["rating"] == rating


def test_rate_invalid_rating_returns_422(client, student):
    mocks, _ = _rate_patches(_flashcard_doc())
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/flashcards/fc_target/rate",
            json={"rating": "very_easy"},  # not in the enum
        )
    assert response.status_code == 422


def test_rate_pending_review_card_returns_409(client, student):
    mocks, captured = _rate_patches(
        _flashcard_doc(status_=FlashcardStatus.pending_review)
    )
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/flashcards/fc_target/rate",
            json={"rating": "easy"},
        )
    assert response.status_code == 409
    assert "pending_review" in response.json()["detail"]
    # No rating event written.
    assert captured == []


def test_rate_missing_flashcard_returns_404(client, student):
    mocks, captured = _rate_patches(None)
    with _enter(mocks):
        response = client.post(
            "/api/v1/workspaces/wsp_a/flashcards/fc_ghost/rate",
            json={"rating": "easy"},
        )
    assert response.status_code == 404
    assert captured == []


def test_rate_flashcard_from_other_workspace_returns_404(client, student):
    """find_one filter scopes on workspace_id — a card in wsp_b can't
    be rated through a wsp_a URL.
    """
    flashcards_col = MagicMock()
    flashcards_col.find_one = AsyncMock(return_value=None)  # filter mismatch

    def _factory(_tid, collection):
        from app.core.database import FLASHCARDS

        return flashcards_col if collection == FLASHCARDS else MagicMock()

    with patch("app.api.flashcards.get_collection", side_effect=_factory):
        response = client.post(
            "/api/v1/workspaces/wsp_a/flashcards/fc_in_b/rate",
            json={"rating": "easy"},
        )
    assert response.status_code == 404
    # Filter must have included workspace_id.
    call_filter = flashcards_col.find_one.await_args.args[0]
    assert call_filter["workspace_id"] == "wsp_a"


def test_rate_non_member_gets_403(client):
    user = make_user(
        user_id="stu_x",
        role=UserRole.student,
        workspace_ids=["wsp_a"],
    )
    app.dependency_overrides[get_current_user] = lambda: user
    response = client.post(
        "/api/v1/workspaces/wsp_b/flashcards/fc_x/rate",
        json={"rating": "easy"},
    )
    assert response.status_code == 403
