"""Endpoint contract for self-study session capping, idempotency, and warm-up.

These exercise ``prepare_adaptive_session`` / ``complete_adaptive_session`` as
plain async handlers (the established pattern in this package), patching the
module-level collaborators so each branch of the self-study contract is covered:

* a fixed number of non-repeating sessions per material snapshot, then a
  "upload more material" call-to-action rather than an error;
* idempotent retries (a tab switch never burns a slot or regenerates content);
* transient emptiness surfaced as a retryable 503, never a 500;
* background pool warm-up scheduled on both prepare and complete;
* completion that survives a failing closing-signal lookup without stranding XP.
"""

from contextlib import ExitStack, contextmanager
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import BackgroundTasks

from app.api.adaptive_sessions import (
    _MAX_SELF_STUDY_SESSIONS,
    _topup_flashcard_pool,
    _topup_question_pool,
    complete_adaptive_session,
    prepare_adaptive_session,
)
from app.core.exceptions import ConflictError, ServiceUnavailableError
from app.models.adaptive_session import (
    AdaptiveLevel,
    AdaptiveSessionMode,
    AdaptiveSessionPlan,
    CompleteAdaptiveSessionRequest,
    PrepareAdaptiveSessionRequest,
    PreparedFlashcard,
    PreparedQuestion,
    SessionCompletionReason,
)
from app.models.question import DifficultyLevel, QuestionType
from app.models.user import UserRole
from app.services.study_sources import CurrentStudySources
from tests.unit.conftest import make_user

SELF_WS = "wsp_self_stu_a"
STUDENT = make_user(user_id="stu_a", role=UserRole.student, workspace_ids=[SELF_WS])
_READY_SOURCES = CurrentStudySources(document_ids=frozenset({"doc_a"}), topic_names=("Biology",))


def _question(question_id: str = "qst_1") -> PreparedQuestion:
    """A minimal valid prepared question for plan assembly."""
    return PreparedQuestion(
        id=question_id,
        topic="Biology",
        question_type=QuestionType.short_answer,
        difficulty=DifficultyLevel.beginner,
        body="What is photosynthesis?",
        answer="Conversion of light to chemical energy",
    )


@contextmanager
def _prepare_env(
    *,
    mastery: float = 0.0,
    sources: CurrentStudySources | None = None,
    existing: dict | None = None,
    used: int = 0,
    prepared: list | None = None,
    prepare_error: BaseException | None = None,
    pool_has_content: bool = True,
):
    """Patch every collaborator of ``prepare_adaptive_session`` for one scenario.

    Yields a namespace of the mocks that individual tests assert on (whether a
    slot was counted, generation ran, or the session was persisted).
    """
    sources = _READY_SOURCES if sources is None else sources
    prepared = prepared or []
    gen_kwargs: dict = (
        {"side_effect": prepare_error} if prepare_error is not None else {"return_value": prepared}
    )
    existing_mock = AsyncMock(return_value=existing)
    count_mock = AsyncMock(return_value=used)
    questions_mock = AsyncMock(**gen_kwargs)
    flashcards_mock = AsyncMock(**gen_kwargs)
    persist_mock = AsyncMock()
    with ExitStack() as stack:
        stack.enter_context(
            patch("app.api.adaptive_sessions._mastery_assessment", AsyncMock(return_value=mastery))
        )
        stack.enter_context(
            patch(
                "app.api.adaptive_sessions.study_sources.current_study_sources",
                AsyncMock(return_value=sources),
            )
        )
        stack.enter_context(
            patch("app.api.adaptive_sessions._existing_open_session", existing_mock)
        )
        stack.enter_context(patch("app.api.adaptive_sessions._snapshot_session_count", count_mock))
        stack.enter_context(patch("app.api.adaptive_sessions._prepare_questions", questions_mock))
        stack.enter_context(patch("app.api.adaptive_sessions._prepare_flashcards", flashcards_mock))
        stack.enter_context(
            patch(
                "app.api.adaptive_sessions._pool_has_content",
                AsyncMock(return_value=pool_has_content),
            )
        )
        stack.enter_context(
            patch("app.api.adaptive_sessions._persist_prepared_session", persist_mock)
        )
        yield SimpleNamespace(
            existing=existing_mock,
            count=count_mock,
            questions=questions_mock,
            flashcards=flashcards_mock,
            persist=persist_mock,
        )


async def _prepare(mode: AdaptiveSessionMode, background_tasks: BackgroundTasks):
    """Invoke the prepare handler for the self-study student."""
    return await prepare_adaptive_session(
        workspace_id=SELF_WS,
        request=PrepareAdaptiveSessionRequest(mode=mode),
        background_tasks=background_tasks,
        current_user=STUDENT,
    )


@pytest.mark.asyncio
async def test_prepare_warm_pool_builds_session_persists_and_schedules_topup():
    background = BackgroundTasks()
    with _prepare_env(used=0, prepared=[_question("qst_1")]) as env:
        plan = await _prepare(AdaptiveSessionMode.study, background)

    assert plan.exhausted is False
    assert plan.item_count == 1
    env.questions.assert_awaited_once()
    env.persist.assert_awaited_once()
    # Exactly one background top-up (questions) is scheduled to warm the pool.
    assert [task.func for task in background.tasks] == [_topup_question_pool]


@pytest.mark.asyncio
async def test_prepare_reuses_open_session_without_burning_a_slot():
    reused = AdaptiveSessionPlan(
        session_id="ses_reused",
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery_score=0.1,
        duration_minutes=5,
        item_count=2,
        estimated_xp_min=1,
        estimated_xp_max=9,
        questions=[_question("qst_1"), _question("qst_2")],
    )
    background = BackgroundTasks()
    with _prepare_env(existing={"plan": reused.model_dump(mode="json")}) as env:
        plan = await _prepare(AdaptiveSessionMode.study, background)

    assert plan.session_id == "ses_reused"
    # Reuse short-circuits before counting, generating, or persisting anything.
    env.count.assert_not_awaited()
    env.questions.assert_not_awaited()
    env.persist.assert_not_awaited()
    assert background.tasks == []


@pytest.mark.asyncio
async def test_prepare_returns_exhausted_cta_once_cap_reached():
    background = BackgroundTasks()
    with _prepare_env(used=_MAX_SELF_STUDY_SESSIONS) as env:
        plan = await _prepare(AdaptiveSessionMode.study, background)

    assert plan.exhausted is True
    assert plan.item_count == 0
    assert plan.questions == []
    # The cap is honoured before any generation or persistence occurs.
    env.questions.assert_not_awaited()
    env.persist.assert_not_awaited()
    assert background.tasks == []


@pytest.mark.asyncio
async def test_prepare_thin_material_exhausts_after_first_session():
    """A later session that yields nothing new is exhaustion, not an error."""
    background = BackgroundTasks()
    with _prepare_env(used=1, prepared=[]) as env:
        plan = await _prepare(AdaptiveSessionMode.study, background)

    assert plan.exhausted is True
    assert plan.item_count == 0
    env.persist.assert_not_awaited()


@pytest.mark.asyncio
async def test_prepare_first_session_empty_with_content_is_retryable_503():
    background = BackgroundTasks()
    with _prepare_env(used=0, prepared=[], pool_has_content=True):
        with pytest.raises(ServiceUnavailableError) as exc_info:
            await _prepare(AdaptiveSessionMode.study, background)

    assert exc_info.value.status_code == 503
    assert "being generated" in exc_info.value.detail


@pytest.mark.asyncio
async def test_prepare_first_session_empty_without_content_reports_processing():
    background = BackgroundTasks()
    with _prepare_env(used=0, prepared=[], pool_has_content=False):
        with pytest.raises(ServiceUnavailableError) as exc_info:
            await _prepare(AdaptiveSessionMode.study, background)

    assert exc_info.value.status_code == 503
    assert "still being processed" in exc_info.value.detail


@pytest.mark.asyncio
async def test_prepare_unexpected_generation_error_becomes_retryable_503():
    background = BackgroundTasks()
    with _prepare_env(used=0, prepare_error=RuntimeError("foundry timeout")):
        with pytest.raises(ServiceUnavailableError) as exc_info:
            await _prepare(AdaptiveSessionMode.study, background)

    assert exc_info.value.status_code == 503
    assert "being prepared" in exc_info.value.detail


@pytest.mark.asyncio
async def test_prepare_typed_client_error_is_surfaced_verbatim():
    background = BackgroundTasks()
    with _prepare_env(used=0, prepare_error=ConflictError("no ready material")):
        with pytest.raises(ConflictError) as exc_info:
            await _prepare(AdaptiveSessionMode.study, background)

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail == "no ready material"


@pytest.mark.asyncio
async def test_prepare_without_ready_material_raises_conflict():
    background = BackgroundTasks()
    empty_sources = CurrentStudySources(document_ids=frozenset(), topic_names=())
    with _prepare_env(sources=empty_sources) as env:
        with pytest.raises(ConflictError) as exc_info:
            await _prepare(AdaptiveSessionMode.study, background)

    assert exc_info.value.status_code == 409
    env.count.assert_not_awaited()
    env.questions.assert_not_awaited()


@pytest.mark.asyncio
async def test_prepare_flashcard_mode_schedules_flashcard_topup():
    background = BackgroundTasks()
    with _prepare_env(
        used=0,
        prepared=[PreparedFlashcard(id="fc_1", topic="Biology", front="F?", back="B")],
    ) as env:
        plan = await _prepare(AdaptiveSessionMode.flashcard, background)

    assert plan.item_count == 1
    env.flashcards.assert_awaited_once()
    env.questions.assert_not_awaited()
    assert [task.func for task in background.tasks] == [_topup_flashcard_pool]


@pytest.mark.asyncio
async def test_prepare_non_self_study_falls_back_to_guaranteed_plan_on_error():
    """Admin-provisioned workspaces keep the guaranteed-filler contract."""
    admin_ws = "wsp_shared"
    teacher = make_user(user_id="usr_t", role=UserRole.tenant_admin)
    fallback = AdaptiveSessionPlan(
        session_id="ses_fallback",
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery_score=0.0,
        duration_minutes=2,
        item_count=1,
        estimated_xp_min=1,
        estimated_xp_max=9,
        questions=[_question("qst_filler")],
    )
    background = BackgroundTasks()
    persist_mock = AsyncMock()
    with (
        patch("app.api.adaptive_sessions._mastery_assessment", AsyncMock(return_value=0.0)),
        patch(
            "app.api.adaptive_sessions._prepare_questions",
            AsyncMock(side_effect=RuntimeError("generation down")),
        ),
        patch(
            "app.api.adaptive_sessions._build_guaranteed_fallback_plan",
            return_value=fallback,
        ),
        patch("app.api.adaptive_sessions._persist_prepared_session", persist_mock),
    ):
        plan = await prepare_adaptive_session(
            workspace_id=admin_ws,
            request=PrepareAdaptiveSessionRequest(mode=AdaptiveSessionMode.study),
            background_tasks=background,
            current_user=teacher,
        )

    assert plan.session_id == "ses_fallback"
    persist_mock.assert_awaited_once()


@pytest.mark.asyncio
async def test_complete_survives_closing_signal_failure_and_schedules_topup():
    plan = AdaptiveSessionPlan(
        session_id="ses_done",
        mode=AdaptiveSessionMode.flashcard,
        level=AdaptiveLevel.beginner,
        mastery_score=0.2,
        duration_minutes=2,
        item_count=2,
        estimated_xp_min=0,
        estimated_xp_max=10,
        flashcards=[
            PreparedFlashcard(id="fc_1", topic="Biology", front="F1?", back="B1"),
            PreparedFlashcard(id="fc_2", topic="Biology", front="F2?", back="B2"),
        ],
    )
    raw = {
        "_id": "ses_done",
        "workspace_id": SELF_WS,
        "student_id": "stu_a",
        "mastery_before": 0.2,
        "status": "prepared",
        "plan": plan.model_dump(mode="json"),
    }
    sessions = MagicMock()
    sessions.find_one = AsyncMock(return_value=raw)
    sessions.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    background = BackgroundTasks()
    with (
        patch("app.api.adaptive_sessions.get_collection", return_value=sessions),
        patch(
            "app.api.adaptive_sessions._mastery_assessment",
            AsyncMock(side_effect=RuntimeError("knowledge model unavailable")),
        ),
        patch(
            "app.api.adaptive_sessions._current_game_level",
            AsyncMock(side_effect=RuntimeError("gamification unavailable")),
        ),
    ):
        summary = await complete_adaptive_session(
            workspace_id=SELF_WS,
            session_id="ses_done",
            request=CompleteAdaptiveSessionRequest(
                completion_reason=SessionCompletionReason.exited,
                flashcard_attempts=[],
            ),
            background_tasks=background,
            current_user=STUDENT,
        )

    # Closing-signal failures fall back to entry mastery / level 1 instead of 500.
    assert summary.mastery_after == 0.2
    assert summary.gamification_level == 1
    assert summary.completed_count == 0
    # The final session row is still written and the next pool is warmed.
    sessions.update_one.assert_awaited()
    assert [task.func for task in background.tasks] == [_topup_flashcard_pool]


@pytest.mark.asyncio
async def test_prepare_self_study_with_subject():
    """Verify that prepare_adaptive_session forwards subject to questions and returns plan with subject."""
    q_physics = PreparedQuestion(
        id="qst_phys_1",
        topic="Kinematics",
        question_type=QuestionType.short_answer,
        difficulty=DifficultyLevel.beginner,
        body="What is acceleration?",
        answer="Rate of change of velocity",
    )
    with _prepare_env(prepared=[q_physics]) as env:
        plan = await prepare_adaptive_session(
            workspace_id=SELF_WS,
            request=PrepareAdaptiveSessionRequest(
                mode=AdaptiveSessionMode.study,
                subject="Physics",
            ),
            background_tasks=BackgroundTasks(),
            current_user=STUDENT,
        )

    assert plan.subject == "Physics"
    assert len(plan.questions) == 1
    assert plan.questions[0].id == "qst_phys_1"
    # Verify subject, subcategory, and question_type were passed to _prepare_questions
    env.questions.assert_awaited_once_with(
        user=STUDENT,
        workspace_id=SELF_WS,
        target=5,
        level=AdaptiveLevel.beginner,
        revision=False,
        subject="Physics",
        subcategory=None,
        question_type=None,
    )


@pytest.mark.asyncio
async def test_prepare_self_study_with_subject_and_subcategory():
    """Verify that prepare_adaptive_session forwards both subject and subcategory."""
    q_chem = PreparedQuestion(
        id="qst_chem_1",
        topic="Organic Chemistry",
        question_type=QuestionType.short_answer,
        difficulty=DifficultyLevel.beginner,
        body="What is an alkane?",
        answer="A saturated hydrocarbon",
    )
    with _prepare_env(prepared=[q_chem]) as env:
        plan = await prepare_adaptive_session(
            workspace_id=SELF_WS,
            request=PrepareAdaptiveSessionRequest(
                mode=AdaptiveSessionMode.study,
                subject="Chemistry",
                subcategory="Organic Chemistry",
            ),
            background_tasks=BackgroundTasks(),
            current_user=STUDENT,
        )

    assert plan.subject == "Chemistry"
    assert plan.subcategory == "Organic Chemistry"
    assert len(plan.questions) == 1
    assert plan.questions[0].id == "qst_chem_1"
    env.questions.assert_awaited_once_with(
        user=STUDENT,
        workspace_id=SELF_WS,
        target=5,
        level=AdaptiveLevel.beginner,
        revision=False,
        subject="Chemistry",
        subcategory="Organic Chemistry",
        question_type=None,
    )


@pytest.mark.asyncio
async def test_prepare_self_study_with_question_type():
    """Verify that prepare_adaptive_session forwards question_type."""
    q_mcq = PreparedQuestion(
        id="qst_mcq_1",
        topic="Physics",
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.beginner,
        body="Which quantity is scalar?",
        answer="Speed",
    )
    with _prepare_env(prepared=[q_mcq]) as env:
        plan = await prepare_adaptive_session(
            workspace_id=SELF_WS,
            request=PrepareAdaptiveSessionRequest(
                mode=AdaptiveSessionMode.study,
                subject="Physics",
                question_type=QuestionType.mcq,
            ),
            background_tasks=BackgroundTasks(),
            current_user=STUDENT,
        )

    assert plan.subject == "Physics"
    assert plan.question_type == QuestionType.mcq
    assert len(plan.questions) == 1
    assert plan.questions[0].id == "qst_mcq_1"
    env.questions.assert_awaited_once_with(
        user=STUDENT,
        workspace_id=SELF_WS,
        target=5,
        level=AdaptiveLevel.beginner,
        revision=False,
        subject="Physics",
        subcategory=None,
        question_type=QuestionType.mcq,
    )


@pytest.mark.asyncio
async def test_prepare_self_study_custom_selection_bypasses_cached_open_session():
    """Verify that when a student selects subject/topic/type, an existing cached open session is bypassed."""
    old_plan = AdaptiveSessionPlan(
        session_id="ses_old_cached",
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery_score=0.0,
        duration_minutes=5,
        item_count=1,
        estimated_xp_min=10,
        estimated_xp_max=20,
        questions=[
            PreparedQuestion(
                id="qst_old",
                topic="Old Topic",
                question_type=QuestionType.short_answer,
                difficulty=DifficultyLevel.beginner,
                body="Old question",
                answer="Old answer",
            )
        ],
        flashcards=[],
    )
    cached_session_doc = {"plan": old_plan.model_dump(mode="json")}

    new_q = PreparedQuestion(
        id="qst_fresh_new",
        topic="Modern Physics",
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.beginner,
        body="Fresh physics question",
        answer="A",
    )

    with _prepare_env(existing=cached_session_doc, prepared=[new_q]) as env:
        plan = await prepare_adaptive_session(
            workspace_id=SELF_WS,
            request=PrepareAdaptiveSessionRequest(
                mode=AdaptiveSessionMode.study,
                subject="Physics",
                subcategory="Modern Physics",
                question_type=QuestionType.mcq,
            ),
            background_tasks=BackgroundTasks(),
            current_user=STUDENT,
        )

    # Must NOT return old cached session
    assert plan.session_id != "ses_old_cached"
    assert len(plan.questions) == 1
    assert plan.questions[0].id == "qst_fresh_new"
    env.questions.assert_awaited_once()


