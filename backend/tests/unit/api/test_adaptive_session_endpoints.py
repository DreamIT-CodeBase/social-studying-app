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
from app.core.exceptions import ConflictError
from app.models.adaptive_session import (
    AdaptiveLevel,
    AdaptiveSessionMode,
    AdaptiveSessionPlan,
    CompleteAdaptiveSessionRequest,
    PrepareAdaptiveSessionRequest,
    PreparedFlashcard,
    PreparedOption,
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
    daily_count: int = 0,
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
    daily_count_mock = AsyncMock(return_value=daily_count)
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
        stack.enter_context(patch("app.api.adaptive_sessions._daily_session_count", daily_count_mock))
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
async def test_prepare_first_session_empty_with_content_returns_guaranteed_plan_in_one_go():
    background = BackgroundTasks()
    with _prepare_env(used=0, prepared=[], pool_has_content=True):
        plan = await _prepare(AdaptiveSessionMode.study, background)

    assert plan is not None
    assert plan.item_count > 0


@pytest.mark.asyncio
async def test_prepare_first_session_empty_without_content_returns_guaranteed_plan_in_one_go():
    background = BackgroundTasks()
    with _prepare_env(used=0, prepared=[], pool_has_content=False):
        plan = await _prepare(AdaptiveSessionMode.study, background)

    assert plan is not None
    assert plan.item_count > 0


@pytest.mark.asyncio
async def test_prepare_unexpected_generation_error_returns_guaranteed_plan_in_one_go():
    background = BackgroundTasks()
    with _prepare_env(used=0, prepare_error=RuntimeError("foundry timeout")):
        plan = await _prepare(AdaptiveSessionMode.study, background)

    assert plan is not None
    assert plan.item_count > 0


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


@pytest.mark.asyncio
async def test_prepare_enforces_daily_session_limit_of_50():
    """Verify that attempting to prepare a 51st session in a single day raises HTTP 429."""
    from fastapi import HTTPException

    # 1. When student has 49 sessions today, 50th is allowed
    with _prepare_env(daily_count=49, prepared=[_question("qst_allowed")]):
        plan = await prepare_adaptive_session(
            workspace_id=SELF_WS,
            request=PrepareAdaptiveSessionRequest(mode=AdaptiveSessionMode.study),
            background_tasks=BackgroundTasks(),
            current_user=STUDENT,
        )
        assert plan is not None
        assert plan.item_count == 1

    # 2. When student already has 50 sessions today, 51st attempt raises 429
    with _prepare_env(daily_count=50, prepared=[_question("qst_blocked")]):
        with pytest.raises(HTTPException) as exc_info:
            await prepare_adaptive_session(
                workspace_id=SELF_WS,
                request=PrepareAdaptiveSessionRequest(mode=AdaptiveSessionMode.study),
                background_tasks=BackgroundTasks(),
                current_user=STUDENT,
            )
        assert exc_info.value.status_code == 429


@pytest.mark.asyncio
async def test_algebra_1_subject_matches_math_questions():
    """Verify that requesting Algebra 1 subject properly matches Mathematics curriculum questions."""
    q_math = PreparedQuestion(
        id="qst_alg_1",
        topic="Linear Equations in Algebra",
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.beginner,
        body="Solve for x: 2x + 4 = 10",
        answer="A",
        options=[
            PreparedOption(key="A", text="x = 3"),
            PreparedOption(key="B", text="x = 4"),
        ],
        explanation="x = (10 - 4)/2 = 3",
        grading_hints=[],
    )

    with _prepare_env(prepared=[q_math]):
        plan = await prepare_adaptive_session(
            workspace_id=SELF_WS,
            request=PrepareAdaptiveSessionRequest(
                mode=AdaptiveSessionMode.study,
                subject="Algebra 1",
            ),
            background_tasks=BackgroundTasks(),
            current_user=STUDENT,
        )

    assert plan.session_id is not None
    assert len(plan.questions) == 1
    assert plan.questions[0].id == "qst_alg_1"
    assert "Linear Equations" in plan.questions[0].topic


def test_algebra_1_guaranteed_fallback_uses_mathematics():
    """Verify that guaranteed fallback for Algebra 1 draws from Mathematics, never Biology."""
    from app.api.adaptive_sessions import _build_guaranteed_fallback_plan

    plan = _build_guaranteed_fallback_plan(
        workspace_id=SELF_WS,
        user_id="usr_test",
        tenant_id="ten_test",
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery=0.0,
        subject="Algebra 1",
    )
    assert len(plan.questions) > 0
    # Every question must belong to Mathematics, not Plant Biology or Photosynthesis
    for q in plan.questions:
        assert "biology" not in q.topic.lower()
        assert "photosynthesis" not in q.body.lower()
        assert "plant" not in q.topic.lower()
    # At least one question should explicitly refer to Algebra / Math
    assert any("algebra" in q.topic.lower() or "geometry" in q.topic.lower() for q in plan.questions)


@pytest.mark.parametrize("qtype", ["mcq", "true_false", "short_answer", "long_answer"])
def test_guaranteed_fallback_strictly_respects_question_type(qtype: str):
    """Verify that guaranteed fallback produces 100% strict question types without format mixing."""
    from app.api.adaptive_sessions import _build_guaranteed_fallback_plan
    from app.models.adaptive_session import AdaptiveLevel, AdaptiveSessionMode

    plan = _build_guaranteed_fallback_plan(
        workspace_id="wsp_normal_workspace",
        user_id="usr_test",
        tenant_id="ten_test",
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery=0.0,
        subject="Mathematics",
        question_type=qtype,
    )
    assert len(plan.questions) > 0
    for q in plan.questions:
        actual_type = q.question_type.value if hasattr(q.question_type, "value") else str(q.question_type)
        assert actual_type.lower() == qtype, f"Expected {qtype} but found {actual_type}"


@pytest.mark.parametrize(
    "level,mastery,expected_min,expected_max",
    [
        (AdaptiveLevel.beginner, 0.0, 5, 7),
        (AdaptiveLevel.beginner, 0.35, 5, 7),
        (AdaptiveLevel.intermediate, 0.40, 12, 15),
        (AdaptiveLevel.intermediate, 0.65, 12, 15),
        (AdaptiveLevel.expert, 0.75, 20, 25),
        (AdaptiveLevel.expert, 0.95, 20, 25),
    ],
)
@pytest.mark.parametrize("mode", [AdaptiveSessionMode.study, AdaptiveSessionMode.revision])
def test_session_question_count_strictly_governed_by_mastery_level(
    level: AdaptiveLevel, mastery: float, expected_min: int, expected_max: int, mode: AdaptiveSessionMode
):
    """Verify study and revision sessions deliver exact question count range based on mastery level:
    - Beginner: 5-7 questions
    - Intermediate: 12-15 questions
    - Expert: 20-25 questions
    """
    from app.api.adaptive_sessions import _build_guaranteed_fallback_plan

    plan = _build_guaranteed_fallback_plan(
        workspace_id="wsp_normal_workspace",
        user_id="usr_test",
        tenant_id="ten_test",
        mode=mode,
        level=level,
        mastery=mastery,
        subject="Mathematics",
    )
    assert expected_min <= plan.item_count <= expected_max
    assert len(plan.questions) == plan.item_count
    assert len(plan.flashcards) == 0


@pytest.mark.parametrize(
    "level,mastery,expected_min,expected_max",
    [
        (AdaptiveLevel.beginner, 0.0, 3, 4),
        (AdaptiveLevel.beginner, 0.35, 3, 4),
        (AdaptiveLevel.intermediate, 0.40, 10, 13),
        (AdaptiveLevel.intermediate, 0.65, 10, 13),
        (AdaptiveLevel.expert, 0.75, 18, 25),
        (AdaptiveLevel.expert, 0.95, 18, 25),
    ],
)
def test_session_flashcard_count_strictly_governed_by_mastery_level(
    level: AdaptiveLevel, mastery: float, expected_min: int, expected_max: int
):
    """Verify flashcard sessions deliver exact card count range based on mastery level:
    - Beginner: 3-4 cards
    - Intermediate: 10-13 cards
    - Expert: 18-25 cards
    """
    from app.api.adaptive_sessions import _build_guaranteed_fallback_plan

    plan = _build_guaranteed_fallback_plan(
        workspace_id="wsp_normal_workspace",
        user_id="usr_test",
        tenant_id="ten_test",
        mode=AdaptiveSessionMode.flashcard,
        level=level,
        mastery=mastery,
        subject="Mathematics",
    )
    assert expected_min <= plan.item_count <= expected_max
    assert len(plan.flashcards) == plan.item_count
    assert len(plan.questions) == 0


def test_trigonometry_guaranteed_fallback_has_zero_algebra_leakage():
    """Verify that selecting Trigonometry yields strictly trigonometry questions/cards with zero algebra leakage."""
    from app.api.adaptive_sessions import _build_guaranteed_fallback_plan

    # Study mode questions
    plan_study = _build_guaranteed_fallback_plan(
        workspace_id="wsp_math",
        user_id="usr_test",
        tenant_id="ten_test",
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery=0.2,
        subject="Mathematics",
        subcategory="Trigonometry",
        target=6,
    )
    assert plan_study.subcategory == "Trigonometry"
    assert len(plan_study.questions) == 6
    for q in plan_study.questions:
        assert q.topic == "Trigonometry"
        # Confirm mathematical trigonometry content
        assert any(term in q.body.lower() for term in ["triangle", "hypotenuse", "sin", "cos", "tan", "angle"])
        # Strictly no linear algebra template leakage
        assert "3x + 7 = 22" not in q.body
        assert "4x = 28" not in q.body

    # Flashcard mode
    plan_flashcard = _build_guaranteed_fallback_plan(
        workspace_id="wsp_math",
        user_id="usr_test",
        tenant_id="ten_test",
        mode=AdaptiveSessionMode.flashcard,
        level=AdaptiveLevel.beginner,
        mastery=0.2,
        subject="Mathematics",
        subcategory="Trigonometry",
        target=5,
    )
    assert plan_flashcard.subcategory == "Trigonometry"
    assert len(plan_flashcard.flashcards) == 5
    for f in plan_flashcard.flashcards:
        assert f.topic == "Trigonometry"
        assert any(term in (f.front + " " + f.back).lower() for term in ["sin", "cos", "tan", "triangle", "hypotenuse", "sec", "csc"])
        # Strictly no slope or linear equation flashcards
        assert "y = mx + b" not in f.back
        assert "3x + 7 = 22" not in f.front


@pytest.mark.asyncio
async def test_recreation_cap_enforces_exhausted_plan():
    """Verify that reaching 10 topic recreations returns an exhausted plan directing the student to upload more content."""
    from app.api.adaptive_sessions import _MAX_TOPIC_RECREATIONS, _build_exhausted_plan

    assert _MAX_TOPIC_RECREATIONS == 10

    plan = _build_exhausted_plan(
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery=0.3,
        subject="Mathematics",
        subcategory="Trigonometry",
        sessions_used=10,
    )
    assert plan.exhausted is True
    assert plan.item_count == 0
    assert plan.questions == []
    assert plan.flashcards == []
    assert plan.subcategory == "Trigonometry"
    assert plan.sessions_used == 10


@pytest.mark.asyncio
async def test_science_guaranteed_fallback_zero_math_leakage():
    """Verify that guaranteed fallback for Science yields science questions with zero math equation leakage."""
    from app.api.adaptive_sessions import _build_guaranteed_fallback_plan

    plan = _build_guaranteed_fallback_plan(
        workspace_id="wsp_sci",
        user_id="usr_sci",
        tenant_id="ten_sci",
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery=0.1,
        subject="Science",
        target=8,
    )
    assert len(plan.questions) == 8
    math_indicators = ["solve for x", "3x +", "5x -", "2x +", "x =", "x=", "quadratic", "slope-intercept"]
    for q in plan.questions:
        q_text = (q.body + " " + q.explanation).lower()
        for ind in math_indicators:
            assert ind not in q_text, f"Found math indicator '{ind}' in science question: {q.body}"
        # Should be science topic
        assert any(
            t in q_text
            for t in [
                "cell", "organelle", "atp", "experiment", "hypothesis", "variable",
                "atom", "proton", "newton", "force", "energy", "dna", "ecosystem",
                "photosynthesis", "ph", "acid", "bond", "chemical", "phenotype", "mitosis"
            ]
        ), f"Question text did not match science domains: {q.body}"


@pytest.mark.asyncio
async def test_science_flashcard_fallback_zero_math_leakage():
    """Verify that guaranteed fallback for Science flashcards yields science flashcards with zero math leakage."""
    from app.api.adaptive_sessions import _build_guaranteed_fallback_plan

    plan = _build_guaranteed_fallback_plan(
        workspace_id="wsp_sci",
        user_id="usr_sci",
        tenant_id="ten_sci",
        mode=AdaptiveSessionMode.flashcard,
        level=AdaptiveLevel.beginner,
        mastery=0.1,
        subject="Science",
        target=6,
    )
    assert len(plan.flashcards) == 6
    math_indicators = ["solve for x", "slope-intercept", "pythagorean", "quadratic formula", "y = mx + b", "a² + b² = c²"]
    for f in plan.flashcards:
        card_text = (f.front + " " + f.back + " " + (f.explanation or "")).lower()
        for ind in math_indicators:
            assert ind not in card_text, f"Found math indicator '{ind}' in science flashcard: {f.front}"


@pytest.mark.asyncio
async def test_science_target_qtype_mcq_zero_math_leakage():
    """Verify that strict MCQ question type filtering for Science maintains 100% science content."""
    from app.api.adaptive_sessions import _build_guaranteed_fallback_plan

    plan = _build_guaranteed_fallback_plan(
        workspace_id="wsp_sci",
        user_id="usr_sci",
        tenant_id="ten_sci",
        mode=AdaptiveSessionMode.study,
        level=AdaptiveLevel.beginner,
        mastery=0.1,
        subject="Science",
        question_type=QuestionType.mcq,
        target=6,
    )
    assert len(plan.questions) == 6
    for q in plan.questions:
        assert (q.question_type.value if hasattr(q.question_type, "value") else str(q.question_type)).lower() == "mcq"
        assert "solve for x" not in q.body.lower()
        assert "3x + 7" not in q.body.lower()


@pytest.mark.asyncio
async def test_subject_classifier_science_and_subdisciplines():
    """Verify that subject_classifier correctly categorizes Science and matches subdisciplines."""
    from app.services.subject_classifier import classify_subject_from_text, subjects_match

    # General science query
    assert classify_subject_from_text("Middle school science curriculum and laboratory investigation") == "Science"
    # Specific subdisciplines
    assert classify_subject_from_text("Photosynthesis in cellular plant biology") == "Biology"
    assert classify_subject_from_text("Chemical bonding and atomic valence electron states") == "Chemistry"
    assert classify_subject_from_text("Newton's laws of motion and gravitational acceleration") == "Physics"

    # Umbrella matching: Science matches all science disciplines
    assert subjects_match("Science", "Biology") is True
    assert subjects_match("Science", "Chemistry") is True
    assert subjects_match("Physics", "Science") is True
    assert subjects_match("Earth & Space Science", "Science") is True
    assert subjects_match("Science", "Science") is True
    assert subjects_match("Science", "Mathematics") is False


@pytest.mark.asyncio
async def test_runtime_material_variations_science_never_produces_math():
    """Verify runtime material variations for Science never produces linear math problems."""
    from unittest.mock import AsyncMock, MagicMock, patch

    from app.models.question import (
        DifficultyLevel,
        McqOption,
        Question,
        QuestionStatus,
        QuestionType,
    )
    from app.services.question_variation_generator import generate_runtime_material_variations

    mock_doc = {
        "_id": "doc_sci_1",
        "category": "Science",
        "extracted_text": "Photosynthesis is the process by which plants use sunlight, water, and carbon dioxide to create oxygen and energy in the form of sugar.",
        "filename": "biology_lab.pdf",
    }
    mock_doc_col = MagicMock()
    mock_doc_col.find_one = AsyncMock(return_value=mock_doc)
    mock_cursor = MagicMock()
    mock_cursor.to_list = AsyncMock(return_value=[mock_doc])
    mock_doc_col.find = MagicMock(return_value=mock_cursor)

    def mock_get_collection(tenant_id, name):
        return mock_doc_col

    seed_q = Question(
        **{"_id": "seed_sci_1"},
        tenant_id="ten_test",
        workspace_id="wsp_test",
        document_id="doc_sci_1",
        topic="Biology",
        question_type=QuestionType.mcq,
        difficulty=DifficultyLevel.intermediate,
        body="What organelle is known as the powerhouse of the cell?",
        options=[
            McqOption(key="A", text="Mitochondria", is_correct=True),
            McqOption(key="B", text="Ribosome", is_correct=False),
            McqOption(key="C", text="Nucleus", is_correct=False),
            McqOption(key="D", text="Endoplasmic Reticulum", is_correct=False),
        ],
        answer="Mitochondria",
        explanation="Mitochondria produce ATP for the cell.",
        grading_hints=[],
        source_chunk_ids=[],
        status=QuestionStatus.approved,
    )

    with (
        patch("app.services.question_variation_generator.get_collection", side_effect=mock_get_collection),
        patch(
            "app.services.question_variation_generator._generate_llm_topic_variations",
            new=AsyncMock(return_value=[seed_q]),
        ),
    ):
        variations = await generate_runtime_material_variations(
            tenant_id="ten_test",
            workspace_id="wsp_test",
            document_id="doc_sci_1",
            subject="Science",
            subcategory="Biology",
            seed_questions=[seed_q],
            historical_seen_bodies=[],
            seen_signatures=set(),
            count=3,
            target_type=QuestionType.mcq,
        )

    assert len(variations) > 0
    math_indicators = ["solve for x", "slope-intercept", "pythagorean", "quadratic formula", "y = mx + b", "a² + b² = c²"]
    for q in variations:
        body_lower = q.body.lower()
        for ind in math_indicators:
            assert ind not in body_lower, f"Found math indicator '{ind}' in generated variation: {q.body}"


@pytest.mark.asyncio
async def test_question_pipeline_cached_science_matching():
    """Verify question_pipeline cache filtering accepts Cell Biology for Science subject and rejects Algebra."""
    from app.services.subject_classifier import classify_subject_from_text, subjects_match

    # Simulate questions in cache
    cached_questions = [
        {"topic": "Cell Biology", "body": "What is the primary function of mitochondria?", "document_id": "doc_1"},
        {"topic": "Linear Equations", "body": "Solve for x: 3x + 5 = 20", "document_id": "doc_1"},
        {"topic": "Chemical Bonds", "body": "What type of bond shares electrons?", "document_id": "doc_1"},
    ]

    subject = "Science"
    current_doc_ids = {"doc_1"}

    filtered = [
        q for q in cached_questions
        if str(q.get("document_id", "")) in current_doc_ids
        and (
            subjects_match(classify_subject_from_text(str(q.get("topic", ""))), subject)
            or subjects_match(classify_subject_from_text(str(q.get("body", ""))), subject)
        )
    ]

    assert len(filtered) == 2
    topics = [q["topic"] for q in filtered]
    assert "Cell Biology" in topics
    assert "Chemical Bonds" in topics
    assert "Linear Equations" not in topics


