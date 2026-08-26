"""Freshness guarantees for prepared adaptive question sessions."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.api.adaptive_sessions import (
    _current_grounding_chunks,
    _flashcard_fingerprint,
    _generate_fresh_flashcards,
    _prepare_flashcards,
    _prepare_questions,
    _question_fingerprint,
    _unique_flashcards,
    _unique_questions,
)
from app.mcp_tools.retrieve_content import RetrieveContentOutput, RetrievedChunk
from app.models.adaptive_session import AdaptiveLevel, PreparedFlashcard
from app.models.flashcard import Flashcard, FlashcardStatus
from app.models.question import DifficultyLevel, Question, QuestionStatus, QuestionType
from app.models.user import UserRole
from app.services.flashcard_generation import GeneratedFlashcard
from app.services.study_sources import CurrentStudySources
from tests.unit.conftest import make_user


class _Cursor:
    def __init__(self, rows: list[dict]) -> None:
        self._rows = rows

    async def to_list(self, *, length: int | None) -> list[dict]:
        return list(self._rows[:length] if length is not None else self._rows)


def _question(question_id: str, body: str) -> Question:
    return Question(
        **{"_id": question_id},
        tenant_id="ten_test001",
        workspace_id="wsp_a",
        document_id="doc_a",
        topic="Biology",
        question_type=QuestionType.short_answer,
        difficulty=DifficultyLevel.beginner,
        body=body,
        answer="answer",
        status=QuestionStatus.approved,
    )


def _raw(question_id: str, body: str) -> dict:
    return _question(question_id, body).model_dump(by_alias=True)


def _flashcard(card_id: str, front: str, back: str) -> Flashcard:
    return Flashcard(
        **{"_id": card_id},
        tenant_id="ten_test001",
        workspace_id="wsp_a",
        document_id="doc_a",
        topic="Biology",
        front=front,
        back=back,
        status=FlashcardStatus.approved,
    )


def _raw_flashcard(card_id: str, front: str, back: str) -> dict:
    return _flashcard(card_id, front, back).model_dump(by_alias=True)


def test_fingerprint_and_unique_questions_ignore_cosmetic_body_differences():
    first = _question("qst_1", "What is Photosynthesis?")
    duplicate = _question("qst_2", "  WHAT is photosynthesis!!! ")
    distinct = _question("qst_3", "Where does photosynthesis occur?")

    assert _question_fingerprint(first.body) == _question_fingerprint(duplicate.body)
    assert [question.id for question in _unique_questions([first, duplicate, distinct])] == [
        "qst_1",
        "qst_3",
    ]


def test_unique_flashcards_compare_the_complete_question_answer_pair():
    first = PreparedFlashcard(
        id="fc_1", topic="Biology", front="What is ATP?", back="Cellular energy"
    )
    duplicate = PreparedFlashcard(
        id="fc_2", topic="Biology", front="WHAT is ATP!!!", back="cellular ENERGY."
    )
    distinct_answer = PreparedFlashcard(
        id="fc_3", topic="Biology", front="What is ATP?", back="A nucleotide"
    )

    assert _flashcard_fingerprint(first.front, first.back) == _flashcard_fingerprint(
        duplicate.front, duplicate.back
    )
    assert [card.id for card in _unique_flashcards([first, duplicate, distinct_answer])] == [
        "fc_1",
        "fc_3",
    ]


@pytest.mark.asyncio
async def test_flashcard_session_excludes_all_previously_appeared_pairs():
    student = make_user(user_id="stu_a", role=UserRole.student, workspace_ids=["wsp_a"])
    card_collection = MagicMock()
    card_collection.find.return_value = _Cursor(
        [
            _raw_flashcard("fc_seen", "Seen front?", "Seen back"),
            _raw_flashcard("fc_seen_copy", "SEEN front!!!", "seen BACK."),
            _raw_flashcard("fc_reserved", "Reserved front?", "Reserved back"),
            _raw_flashcard("fc_fresh", "Fresh front?", "Fresh back"),
            _raw_flashcard("fc_fresh_copy", "FRESH front!", "fresh back."),
        ]
    )
    question_collection = MagicMock()
    question_collection.find.return_value = _Cursor(
        [
            _raw("qst_seen_pair", "Seen front?"),
            _raw("qst_new_pair", "Derived fresh front?"),
        ]
    )

    with (
        patch("app.api.adaptive_sessions._history", AsyncMock(return_value=([], {}))),
        patch(
            "app.api.adaptive_sessions._flashcard_history",
            AsyncMock(
                return_value=(
                    {"fc_seen"},
                    {
                        _flashcard_fingerprint("Seen front?", "Seen back"),
                        _flashcard_fingerprint("Seen front?", "answer"),
                    },
                    ["Seen front?"],
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions._reserved_flashcards",
            AsyncMock(
                return_value=(
                    {"fc_reserved"},
                    {_flashcard_fingerprint("Reserved front?", "Reserved back")},
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions.study_sources.current_study_sources",
            AsyncMock(
                return_value=CurrentStudySources(
                    document_ids=frozenset({"doc_a"}),
                    topic_names=("Biology",),
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions._generate_fresh_flashcards",
            AsyncMock(return_value=[]),
        ),
        patch(
            "app.api.adaptive_sessions.get_collection",
            side_effect=[card_collection, question_collection],
        ),
    ):
        prepared = await _prepare_flashcards(
            user=student,
            workspace_id="wsp_a",
            target=3,
        )

    assert [card.id for card in prepared] == ["fc_fresh", "derived_qst_new_pair"]


@pytest.mark.asyncio
async def test_flashcard_session_ignores_placeholder_questions_and_uses_fresh_generation():
    student = make_user(user_id="stu_a", role=UserRole.student, workspace_ids=["wsp_a"])
    card_collection = MagicMock()
    card_collection.find.return_value = _Cursor([])
    placeholder = _question("qst_placeholder", "Old generated question?")
    placeholder.document_id = "batch_source"
    question_collection = MagicMock()
    question_collection.find.return_value = _Cursor([placeholder.model_dump(by_alias=True)])
    fresh = PreparedFlashcard(
        id="fc_fresh",
        topic="Biology",
        front="What is new?",
        back="Fresh source content",
    )

    with (
        patch("app.api.adaptive_sessions._history", AsyncMock(return_value=([], {}))),
        patch(
            "app.api.adaptive_sessions._flashcard_history",
            AsyncMock(return_value=(set(), set(), [])),
        ),
        patch(
            "app.api.adaptive_sessions._reserved_flashcards",
            AsyncMock(return_value=(set(), set())),
        ),
        patch(
            "app.api.adaptive_sessions.study_sources.current_study_sources",
            AsyncMock(
                return_value=CurrentStudySources(
                    document_ids=frozenset({"doc_current"}),
                    topic_names=("Biology",),
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions._generate_fresh_flashcards",
            AsyncMock(return_value=[fresh]),
        ) as generate,
        patch(
            "app.api.adaptive_sessions.get_collection",
            side_effect=[card_collection, question_collection],
        ),
    ):
        prepared = await _prepare_flashcards(
            user=student,
            workspace_id="wsp_a",
            target=1,
        )

    assert prepared == [fresh]
    generate.assert_awaited_once()


@pytest.mark.asyncio
async def test_current_grounding_discards_search_hits_from_superseded_documents():
    current_chunks = [
        RetrievedChunk(
            chunk_id=f"chk_current_{index}",
            chunk_index=index,
            document_id="doc_current",
            text=f"Current material {index}",
            topic_ids=[],
            score=1.0,
        )
        for index in range(5)
    ]
    old_chunk = RetrievedChunk(
        chunk_id="chk_old",
        chunk_index=0,
        document_id="doc_old",
        text="Superseded material",
        topic_ids=[],
        score=2.0,
    )
    with patch(
        "app.api.adaptive_sessions.retrieve_content",
        AsyncMock(
            return_value=RetrieveContentOutput(
                chunks=[old_chunk, *current_chunks],
                mode="hybrid",
            )
        ),
    ):
        chunks = await _current_grounding_chunks(
            tenant_id="ten_test001",
            workspace_id="wsp_a",
            topic="Biology",
            current_document_ids=frozenset({"doc_current"}),
        )

    assert [chunk.chunk_id for chunk in chunks] == [f"chk_current_{index}" for index in range(5)]


@pytest.mark.asyncio
async def test_fresh_generation_retries_duplicate_content_before_persisting():
    student = make_user(user_id="stu_a", role=UserRole.student, workspace_ids=["wsp_a"])
    chunk = RetrievedChunk(
        chunk_id="chk_current",
        chunk_index=0,
        document_id="doc_current",
        text="Current biology material",
        topic_ids=[],
        score=1.0,
    )
    duplicate = GeneratedFlashcard(
        front="Already seen?",
        back="Old answer",
        explanation="",
        prompt_version="test",
    )
    new = GeneratedFlashcard(
        front="A fresh question?",
        back="A fresh answer",
        explanation="Grounded",
        prompt_version="test",
    )
    persisted = _flashcard("fc_new", new.front, new.back)

    with (
        patch(
            "app.api.adaptive_sessions._current_grounding_chunks",
            AsyncMock(return_value=[chunk]),
        ),
        patch(
            "app.api.adaptive_sessions.flashcard_generation.generate_flashcard",
            AsyncMock(side_effect=[duplicate, new]),
        ) as generate,
        patch("app.api.adaptive_sessions.flashcards_api._review", AsyncMock()) as review,
        patch(
            "app.api.adaptive_sessions.flashcards_api._persist_grounded_flashcard",
            AsyncMock(return_value=persisted),
        ) as persist,
    ):
        prepared = await _generate_fresh_flashcards(
            user=student,
            workspace_id="wsp_a",
            target=1,
            level=AdaptiveLevel.beginner,
            current_sources=CurrentStudySources(
                document_ids=frozenset({"doc_current"}),
                topic_names=("Biology",),
            ),
            weak_topics={},
            historical_fronts=["Already seen?"],
            blocked_fingerprints={_flashcard_fingerprint(duplicate.front, duplicate.back)},
        )

    assert [card.id for card in prepared] == ["fc_new"]
    assert generate.await_count == 2
    review.assert_awaited_once_with(new)
    persist.assert_awaited_once()


@pytest.mark.asyncio
async def test_study_session_excludes_answered_and_reserved_questions():
    student = make_user(user_id="stu_a", role=UserRole.student, workspace_ids=["wsp_a"])
    queue = MagicMock()
    queue.find.return_value = _Cursor(
        [
            _raw("qst_answered", "Already answered?"),
            _raw("qst_answered_copy", "ALREADY answered!!!"),
            _raw("qst_reserved", "Already reserved?"),
            _raw("qst_reserved_copy", "Already RESERVED."),
            _raw("qst_fresh", "A fresh question?"),
        ]
    )
    generated = _question("qst_generated", "A newly generated question?")

    with (
        patch(
            "app.api.adaptive_sessions._history",
            AsyncMock(
                return_value=(
                    [{"question_id": "qst_answered", "is_correct": True}],
                    {},
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions._reserved_questions",
            AsyncMock(
                return_value=(
                    {"qst_reserved"},
                    {_question_fingerprint("Already reserved?")},
                )
            ),
        ),
        patch("app.api.adaptive_sessions.get_collection", return_value=queue),
        patch(
            "app.api.adaptive_sessions.study_sources.current_study_sources",
            AsyncMock(
                return_value=CurrentStudySources(
                    document_ids=frozenset({"doc_a"}), topic_names=("Biology",)
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions.question_pipeline._generate_and_persist_batch",
            AsyncMock(return_value=[generated]),
        ) as generate,
    ):
        prepared = await _prepare_questions(
            user=student,
            workspace_id="wsp_a",
            target=2,
            level=AdaptiveLevel.beginner,
            revision=False,
        )

    assert [question.id for question in prepared] == ["qst_fresh", "qst_generated"]
    generate.assert_awaited_once()


@pytest.mark.asyncio
async def test_study_session_is_not_padded_with_old_questions_when_generation_is_short():
    student = make_user(user_id="stu_a", role=UserRole.student, workspace_ids=["wsp_a"])
    queue = MagicMock()
    queue.find.return_value = _Cursor(
        [
            _raw("qst_answered", "Already answered?"),
            _raw("qst_fresh", "Only fresh question?"),
        ]
    )

    with (
        patch(
            "app.api.adaptive_sessions._history",
            AsyncMock(
                return_value=(
                    [{"question_id": "qst_answered", "is_correct": True}],
                    {},
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions._reserved_questions",
            AsyncMock(return_value=(set(), set())),
        ),
        patch("app.api.adaptive_sessions.get_collection", return_value=queue),
        patch(
            "app.api.adaptive_sessions.study_sources.current_study_sources",
            AsyncMock(
                return_value=CurrentStudySources(
                    document_ids=frozenset({"doc_a"}), topic_names=("Biology",)
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions.question_pipeline._generate_and_persist_batch",
            AsyncMock(return_value=[]),
        ),
    ):
        prepared = await _prepare_questions(
            user=student,
            workspace_id="wsp_a",
            target=3,
            level=AdaptiveLevel.beginner,
            revision=False,
        )

    assert [question.id for question in prepared] == ["qst_fresh"]


@pytest.mark.asyncio
async def test_study_session_excludes_questions_from_deleted_documents():
    student = make_user(user_id="stu_a", role=UserRole.student, workspace_ids=["wsp_a"])
    stale = _question("qst_chemistry", "What is an ionic bond?")
    stale.document_id = "doc_deleted_chemistry"
    current = _question("qst_foundry", "What is a model deployment?")
    current.document_id = "doc_current_foundry"
    queue = MagicMock()
    queue.find.return_value = _Cursor(
        [stale.model_dump(by_alias=True), current.model_dump(by_alias=True)]
    )

    with (
        patch("app.api.adaptive_sessions._history", AsyncMock(return_value=([], {}))),
        patch(
            "app.api.adaptive_sessions._reserved_questions",
            AsyncMock(return_value=(set(), set())),
        ),
        patch("app.api.adaptive_sessions.get_collection", return_value=queue),
        patch(
            "app.api.adaptive_sessions.study_sources.current_study_sources",
            AsyncMock(
                return_value=CurrentStudySources(
                    document_ids=frozenset({"doc_current_foundry"}),
                    topic_names=("Microsoft Foundry",),
                )
            ),
        ),
    ):
        prepared = await _prepare_questions(
            user=student,
            workspace_id="wsp_a",
            target=1,
            level=AdaptiveLevel.beginner,
            revision=False,
        )

    assert [question.id for question in prepared] == ["qst_foundry"]


@pytest.mark.asyncio
async def test_revision_session_can_repeat_an_incorrect_question():
    student = make_user(user_id="stu_a", role=UserRole.student, workspace_ids=["wsp_a"])
    queue = MagicMock()
    queue.find.return_value = _Cursor([_raw("qst_wrong", "Previously incorrect?")])

    with (
        patch(
            "app.api.adaptive_sessions._history",
            AsyncMock(
                return_value=(
                    [{"question_id": "qst_wrong", "is_correct": False}],
                    {},
                )
            ),
        ),
        patch(
            "app.api.adaptive_sessions._reserved_questions",
            AsyncMock(return_value=(set(), set())),
        ),
        patch("app.api.adaptive_sessions.get_collection", return_value=queue),
        patch(
            "app.api.adaptive_sessions.study_sources.current_study_sources",
            AsyncMock(
                return_value=CurrentStudySources(
                    document_ids=frozenset({"doc_a"}), topic_names=("Biology",)
                )
            ),
        ),
    ):
        prepared = await _prepare_questions(
            user=student,
            workspace_id="wsp_a",
            target=1,
            level=AdaptiveLevel.beginner,
            revision=True,
        )

    assert [question.id for question in prepared] == ["qst_wrong"]


def test_mastery_level_count_ranges_match_specification():
    from app.api.adaptive_sessions import (
        _FLASHCARD_RANGES,
        _QUESTION_RANGES,
        _adaptive_count,
        _level_for_mastery,
    )

    # Beginner (score < 0.40): 5-7 questions, 3-4 flashcards
    beg_level = _level_for_mastery(0.0)
    assert beg_level == AdaptiveLevel.beginner
    beg_q_count = _adaptive_count(0.0, beg_level, _QUESTION_RANGES[beg_level])
    assert 5 <= beg_q_count <= 7
    beg_f_count = _adaptive_count(0.0, beg_level, _FLASHCARD_RANGES[beg_level])
    assert 3 <= beg_f_count <= 4

    # Intermediate (score 0.40 - 0.75): 12-15 questions, 10-13 flashcards
    inter_level = _level_for_mastery(0.55)
    assert inter_level == AdaptiveLevel.intermediate
    inter_q_count = _adaptive_count(0.55, inter_level, _QUESTION_RANGES[inter_level])
    assert 12 <= inter_q_count <= 15
    inter_f_count = _adaptive_count(0.55, inter_level, _FLASHCARD_RANGES[inter_level])
    assert 10 <= inter_f_count <= 13

    # Expert (score > 0.75): 20-25 questions, 18-25 flashcards
    exp_level = _level_for_mastery(0.90)
    assert exp_level == AdaptiveLevel.expert
    exp_q_count = _adaptive_count(0.90, exp_level, _QUESTION_RANGES[exp_level])
    assert 20 <= exp_q_count <= 25
    exp_f_count = _adaptive_count(0.90, exp_level, _FLASHCARD_RANGES[exp_level])
    assert 18 <= exp_f_count <= 25
