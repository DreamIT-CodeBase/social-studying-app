"""Question batches remain tied to the currently active study sources."""

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.question import DifficultyLevel, Question, QuestionStatus, QuestionType
from app.services.question_pipeline import get_next_question, invalidate_workspace_cache
from app.services.study_sources import CurrentStudySources


def _question(document_id: str, body: str) -> Question:
    return Question(
        **{"_id": f"qst_{document_id}"},
        tenant_id="ten_a",
        workspace_id="wsp_a",
        document_id=document_id,
        topic="Study material",
        question_type=QuestionType.short_answer,
        difficulty=DifficultyLevel.beginner,
        body=body,
        answer="answer",
        status=QuestionStatus.approved,
    )


@pytest.mark.asyncio
async def test_cached_question_from_deleted_document_is_never_served():
    redis = MagicMock()
    redis.get = AsyncMock(
        return_value=json.dumps(
            [_question("doc_deleted", "Old chemistry question?").model_dump(by_alias=True)]
        )
    )
    redis.set = AsyncMock()
    current = _question("doc_current", "Current Foundry question?")

    with (
        patch("app.services.question_pipeline.get_redis", AsyncMock(return_value=redis)),
        patch(
            "app.services.question_pipeline.study_sources.current_study_sources",
            AsyncMock(
                return_value=CurrentStudySources(
                    document_ids=frozenset({"doc_current"}),
                    topic_names=("Microsoft Foundry",),
                )
            ),
        ),
        patch(
            "app.services.question_pipeline._generate_and_persist_batch",
            AsyncMock(return_value=[current]),
        ),
    ):
        result = await get_next_question(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            user_obj=MagicMock(),
            background_tasks=MagicMock(),
        )

    assert result.id == "qst_doc_current"
    assert result.document_id == "doc_current"


@pytest.mark.asyncio
async def test_invalidate_workspace_cache_removes_all_student_buffers():
    redis = MagicMock()

    async def scan_iter(*, match: str):
        if "question_cache" in match:
            yield "telemetry:question_cache:wsp_a:stu_1"
        else:
            yield "telemetry:seen_questions:wsp_a:stu_1"

    redis.scan_iter = scan_iter
    redis.delete = AsyncMock(return_value=2)

    with patch("app.services.question_pipeline.get_redis", AsyncMock(return_value=redis)):
        count = await invalidate_workspace_cache(workspace_id="wsp_a")

    assert count == 2
    redis.delete.assert_awaited_once_with(
        "telemetry:question_cache:wsp_a:stu_1",
        "telemetry:seen_questions:wsp_a:stu_1",
    )
