"""Unit tests for the Learning Path Engine (Sprint 3.3).

Each test pins one branch of the scoring algorithm so a regression in
weights / thresholds / tiebreakers surfaces here instead of in
production telemetry. The Cosmos workspace read + the
retrieve_student_context MCP tool are both mocked.

The scoring math is deterministic given fixed inputs. Whenever a test
hard-codes a score, the value reflects the v1 default weights —
re-tune the defaults and the test will break loudly, which is the
intended forcing function for keeping calibration deliberate.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.mcp_tools.retrieve_student_context import (
    InteractionSummary,
    RetrieveStudentContextOutput,
    TopicMasteryView,
)
from app.models.workspace import CanonicalTopic, Taxonomy, Workspace
from app.services import learning_path
from app.services.learning_path import (
    NoTopicsAvailable,
    SelectionConfig,
    SelectionWeights,
    WorkspaceNotFound,
    select_next_topic,
)

# ── Fixtures + helpers ──────────────────────────────────────────────────────


def _topic(
    id_: str,
    name: str,
    *,
    parent_id: str | None = None,
    complexity: float | None = None,
    aliases: list[str] | None = None,
) -> CanonicalTopic:
    return CanonicalTopic(
        id=id_,
        name=name,
        aliases=aliases or [],
        parent_id=parent_id,
        complexity_level=complexity,
    )


def _workspace(*, topics: list[CanonicalTopic]) -> Workspace:
    return Workspace(
        **{"_id": "wsp_a"},
        tenant_id="ten_a",
        name="Test Workspace",
        taxonomy=Taxonomy(topics=topics),
    )


def _student_context(
    *,
    mastery: dict[str, float] | None = None,
    recent_topics: list[str] | None = None,
    overall: float = 0.0,
) -> RetrieveStudentContextOutput:
    """Build a fake student context.

    ``mastery`` is name → mastery_score; ``recent_topics`` is a list of
    topic names ordered most-recent-first that becomes the recent
    interactions tail. ``last_seen_at`` isn't read by the engine today
    (it uses the recent_interactions list directly) so it's left null.
    """
    mastery = mastery or {}
    topic_views = [
        TopicMasteryView(
            topic=name,
            mastery_score=score,
            accuracy=score,  # cosmetic — engine doesn't read accuracy v1
            questions_attempted=4,
            questions_correct=int(score * 4),
            last_seen_at=None,
        )
        for name, score in mastery.items()
    ]
    interactions = [
        InteractionSummary(
            question_id=f"qst_{i}",
            topic=t,
            is_correct=True,
            answered_at=f"2026-05-0{i + 1}T00:00:00+00:00",
        )
        for i, t in enumerate(recent_topics or [])
    ]
    return RetrieveStudentContextOutput(
        student_id="stu_a",
        workspace_id="wsp_a",
        overall_mastery=overall,
        last_recalculated_at=None,
        topic_mastery=topic_views,
        recent_interactions=interactions,
        seen_question_ids=[ix.question_id for ix in interactions],
    )


def _patched_run(workspace: Workspace, context: RetrieveStudentContextOutput):
    """Patch the two seams the engine reads: workspace doc + MCP tool."""
    raw = workspace.model_dump(by_alias=True)
    col = AsyncMock()
    col.find_one = AsyncMock(return_value=raw)
    return (
        patch.object(learning_path, "get_collection", return_value=col),
        patch.object(learning_path, "invoke", AsyncMock(return_value=context)),
    )


# ── Cold start ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_cold_start_picks_lowest_complexity_root():
    """Brand-new student, multiple roots → engine picks the simplest one.

    Cold start collapses the score to just prereq_readiness + complexity
    tiebreak. All roots get readiness=1.0 so the tiebreaker (complexity
    asc) decides.
    """
    topics = [
        _topic("tpc_root_hard", "Calculus", complexity=4),
        _topic("tpc_root_easy", "Counting", complexity=1),
        _topic("tpc_root_mid", "Algebra", complexity=2),
        _topic("tpc_child", "Limits", parent_id="tpc_root_hard", complexity=4),
    ]
    workspace = _workspace(topics=topics)
    context = _student_context()  # no mastery, no recent interactions

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    assert result.selected.topic_name == "Counting"
    # Rationale should call out the cold-start branch.
    assert "Cold start" in result.rationale
    # All four topics ranked.
    assert len(result.candidates) == 4
    # Child topic with unmastered parent ranks behind every root.
    last = result.candidates[-1]
    assert last.topic_name == "Limits"


# ── Mastery dominates once interactions exist ───────────────────────────────


@pytest.mark.asyncio
async def test_mastery_deficit_dominates_when_student_has_interactions():
    """Two roots: one mastered, one not. Engine picks the unmastered one
    even though both have prereqs clear.
    """
    topics = [
        _topic("tpc_a", "Photosynthesis", complexity=2),
        _topic("tpc_b", "Mitosis", complexity=2),
    ]
    workspace = _workspace(topics=topics)
    context = _student_context(
        mastery={"Photosynthesis": 0.9, "Mitosis": 0.2},
        recent_topics=["Algebra"],  # different topic — no recency penalty
        overall=0.55,
    )

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    assert result.selected.topic_name == "Mitosis"
    # Mastery deficit shows in the components.
    assert result.selected.components["mastery_deficit"] == pytest.approx(0.8)


# ── Recency penalty ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_recently_seen_topic_is_deprioritised_within_short_window():
    """Two equally-unmastered topics; one was the most recent interaction.
    Engine picks the other.
    """
    topics = [
        _topic("tpc_a", "Photosynthesis", complexity=2),
        _topic("tpc_b", "Mitosis", complexity=2),
    ]
    workspace = _workspace(topics=topics)
    context = _student_context(
        mastery={"Photosynthesis": 0.2, "Mitosis": 0.2},
        recent_topics=["Photosynthesis"],  # most recent
        overall=0.2,
    )

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    assert result.selected.topic_name == "Mitosis"
    # The losing topic's recency component is the maxed-out -1.0.
    photo = next(c for c in result.candidates if c.topic_name == "Photosynthesis")
    assert photo.components["recency_factor"] == -1.0


@pytest.mark.asyncio
async def test_recency_penalty_tapers_past_short_window():
    """A topic seen 5 turns ago (between short=3 and long=10) gets a
    partial penalty, not the full -1.0.
    """
    topics = [_topic("tpc_a", "Algebra", complexity=2)]
    workspace = _workspace(topics=topics)
    # Pad the recent list so Algebra is at position 5 (within taper band).
    recent = ["Other1", "Other2", "Other3", "Other4", "Other5", "Algebra"]
    context = _student_context(mastery={"Algebra": 0.0}, recent_topics=recent)

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    rf = result.selected.components["recency_factor"]
    # Between -1.0 (short window) and 0.0 (long window) — should be -1 +
    # (5-3)/(10-3) = -1 + 2/7 ≈ -0.71.
    assert -1.0 < rf < 0.0
    assert rf == pytest.approx(-1.0 + 2 / 7)


# ── Prereq gating ───────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_child_with_unmastered_parent_is_demoted_vs_a_ready_sibling():
    """Two unmastered topics: one's a root (prereq clear), one's a child
    of a not-yet-mastered parent. Root should win.
    """
    topics = [
        _topic("tpc_parent", "Algebra", complexity=2),
        _topic("tpc_child", "Calculus", parent_id="tpc_parent", complexity=4),
        _topic("tpc_root", "Geometry", complexity=2),
    ]
    workspace = _workspace(topics=topics)
    # Algebra is below the prereq floor (0.7), so Calculus is "blocked".
    # Algebra and Geometry are equally unmastered; tie-break by
    # complexity (both 2) then name → Algebra wins ('A' < 'G' casefold).
    context = _student_context(
        mastery={"Algebra": 0.3, "Calculus": 0.0, "Geometry": 0.3},
    )

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    # Calculus ranks last because its prereq_readiness is -1.0 (parent
    # below floor) → its total score is lower than either root.
    assert result.candidates[-1].topic_name == "Calculus"
    assert result.candidates[-1].components["prereq_readiness"] == -1.0
    # Algebra wins the root tiebreak (name ASC).
    assert result.selected.topic_name == "Algebra"


@pytest.mark.asyncio
async def test_child_with_mastered_parent_unlocks_full_readiness():
    """When the parent is at or above the floor, the child's prereq
    readiness equals the parent's mastery (no -1 penalty).
    """
    topics = [
        _topic("tpc_parent", "Algebra"),
        _topic("tpc_child", "Calculus", parent_id="tpc_parent", complexity=4),
    ]
    workspace = _workspace(topics=topics)
    context = _student_context(
        mastery={"Algebra": 0.85, "Calculus": 0.1},
    )

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    # Calculus has the higher mastery deficit, and parent is now ready,
    # so it should win.
    assert result.selected.topic_name == "Calculus"
    assert result.selected.components["prereq_readiness"] == pytest.approx(0.85)


# ── Variety ─────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_variety_factor_penalises_topic_in_recent_short_window():
    """Variety is a sharp short-horizon -1 penalty that smooths
    alternation. Two topics, both unmastered, one is in the variety
    window → the other wins.
    """
    topics = [
        _topic("tpc_a", "A", complexity=1),
        _topic("tpc_b", "B", complexity=1),
    ]
    workspace = _workspace(topics=topics)
    context = _student_context(
        mastery={"A": 0.3, "B": 0.3},
        recent_topics=["A", "Other", "Other"],  # A within variety_window=3
    )

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    assert result.selected.topic_name == "B"
    a = next(c for c in result.candidates if c.topic_name == "A")
    assert a.components["variety_factor"] == -1.0


# ── Curriculum priorities ───────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_curriculum_priority_boost_overrides_a_smaller_mastery_deficit():
    """Admin priority is weighted = 1.0 in v1 — a +0.5 boost outranks a
    moderate mastery-deficit gap. Confirms the hook works once admin
    UI wires it up.
    """
    topics = [
        _topic("tpc_a", "Featured", complexity=2),
        _topic("tpc_b", "Unfeatured", complexity=2),
    ]
    workspace = _workspace(topics=topics)
    # Featured has LESS mastery deficit (0.4) than Unfeatured (0.7),
    # so without the boost Unfeatured would win.
    context = _student_context(mastery={"Featured": 0.6, "Unfeatured": 0.3})

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            curriculum_priorities={"tpc_a": 0.5},
        )

    assert result.selected.topic_name == "Featured"
    assert result.selected.components["curriculum_priority"] == 0.5


# ── Alias resolution ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_alias_matching_resolves_student_mastery_to_canonical_topic():
    """Sprint 2.6's merge can collapse 'Photo Synthesis' (alias) and
    'Photosynthesis' (canonical) into one topic. The engine must match
    the student's mastery row (keyed by display name) through aliases.
    """
    topics = [
        _topic("tpc_a", "Photosynthesis", aliases=["Photo Synthesis"]),
    ]
    workspace = _workspace(topics=topics)
    # Student answered questions tagged with the alias form.
    context = _student_context(mastery={"Photo Synthesis": 0.9})

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    # Mastery resolves through the alias — deficit should be 0.1, not 1.0.
    assert result.selected.components["mastery_deficit"] == pytest.approx(0.1)


# ── Custom weights ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_custom_weights_zero_out_a_component():
    """Passing ``weights.recency=0`` removes recency from the score.
    Useful for prompt-eval experiments and admin overrides.
    """
    topics = [
        _topic("tpc_a", "A", complexity=1),
        _topic("tpc_b", "B", complexity=1),
    ]
    workspace = _workspace(topics=topics)
    context = _student_context(
        mastery={"A": 0.2, "B": 0.2},
        recent_topics=["A"],
    )

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            weights=SelectionWeights(recency=0.0, variety=0.0),
        )

    # With recency + variety zeroed, mastery + prereq tie A and B exactly.
    # Tiebreak goes to complexity (both 1) then name → A.
    assert result.selected.topic_name == "A"


# ── Determinism ─────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_selection_is_deterministic_across_runs():
    """Same student state must always yield the same selection — the
    question-generation tests downstream depend on this for stable
    fixtures.
    """
    topics = [
        _topic("tpc_a", "Alpha", complexity=2),
        _topic("tpc_b", "Beta", complexity=2),
        _topic("tpc_c", "Gamma", complexity=2),
    ]
    workspace = _workspace(topics=topics)
    context = _student_context(
        mastery={"Alpha": 0.5, "Beta": 0.5, "Gamma": 0.5},
    )

    seen = set()
    for _ in range(5):
        ws_patch, mcp_patch = _patched_run(workspace, context)
        with ws_patch, mcp_patch:
            result = await select_next_topic(
                tenant_id="ten_a",
                workspace_id="wsp_a",
                student_id="stu_a",
            )
        seen.add(result.selected.topic_name)

    assert len(seen) == 1, f"selection drifted across runs: {seen}"


# ── Edge cases ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_empty_taxonomy_raises_no_topics_available():
    workspace = _workspace(topics=[])
    context = _student_context()

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch, pytest.raises(NoTopicsAvailable, match="no canonical topics"):
        await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )


@pytest.mark.asyncio
async def test_workspace_not_found_raises():
    col = AsyncMock()
    col.find_one = AsyncMock(return_value=None)
    with (
        patch.object(learning_path, "get_collection", return_value=col),
        pytest.raises(WorkspaceNotFound),
    ):
        await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_ghost",
            student_id="stu_a",
        )


@pytest.mark.asyncio
async def test_candidates_limit_truncates_returned_list():
    """The ``candidates_limit`` knob is for observability — admin UIs
    don't need 50 candidates in a tooltip. Selected topic still appears
    plus ``limit`` of its runners-up.
    """
    topics = [_topic(f"tpc_{i}", f"T{i}") for i in range(8)]
    workspace = _workspace(topics=topics)
    context = _student_context()

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
            config=SelectionConfig(candidates_limit=3),
        )

    # selected + 3 runners-up = 4 entries
    assert len(result.candidates) == 4
    assert result.candidates[0].topic_name == result.selected.topic_name


@pytest.mark.asyncio
async def test_orphaned_parent_id_falls_back_to_full_readiness_not_error():
    """A parent_id pointing at a non-existent topic shouldn't penalise
    the child — that would be punishing a kid for a stale Sprint 2.7
    edge. Treat as no-prereq, readiness = 1.0.
    """
    topics = [
        _topic("tpc_a", "Solo", parent_id="tpc_ghost", complexity=2),
    ]
    workspace = _workspace(topics=topics)
    context = _student_context(mastery={"Solo": 0.4})

    ws_patch, mcp_patch = _patched_run(workspace, context)
    with ws_patch, mcp_patch:
        result = await select_next_topic(
            tenant_id="ten_a",
            workspace_id="wsp_a",
            student_id="stu_a",
        )

    assert result.selected.components["prereq_readiness"] == 1.0
