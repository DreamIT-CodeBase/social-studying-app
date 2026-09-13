"""Unit tests for app.services.taxonomy.

Cosmos and Azure OpenAI are mocked. We test:
- The seed-path (first doc, no AI call)
- The AI merge path (parses model output, preserves existing ids, assigns
  new tpc_ ids to NEW entries, resolves "NEW" doc refs)
- Compare-and-swap retry loop on version conflicts
- Empty new-topics short-circuit
- TaxonomyMergeError on malformed model output and CAS exhaustion
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.document import TopicTag
from app.models.workspace import CanonicalTopic, Taxonomy, Workspace, WorkspaceSettings
from app.services import taxonomy
from app.services.taxonomy import (
    DependencyInferenceError,
    TaxonomyMergeError,
    TaxonomyValidationError,
    TaxonomyVersionConflict,
)

# ── Helpers ──────────────────────────────────────────────────────────────────


def _ws(*, version: int = 0, topics: list[CanonicalTopic] | None = None) -> Workspace:
    return Workspace(
        id="wsp_abc",
        tenant_id="ten_abc",
        name="Biology 101",
        description="",
        admin_ids=[],
        student_ids=[],
        settings=WorkspaceSettings(),
        invite_codes=[],
        document_count=0,
        is_active=True,
        taxonomy=Taxonomy(topics=topics or []),
        taxonomy_version=version,
    )


def _topic_tag(
    name: str,
    *,
    description: str | None = "summary",
    complexity: int | None = 3,
    pages: list[int] | None = None,
) -> TopicTag:
    return TopicTag(
        name=name,
        confidence=1.0,
        source="ai",
        description=description,
        complexity_level=complexity,
        page_refs=pages or [],
    )


def _mock_collection(workspace_doc: dict | None) -> MagicMock:
    """Build a Cosmos collection mock that returns ``workspace_doc`` on find_one
    and records update_one calls. update_one defaults to matched_count=1.
    """
    col = MagicMock()
    col.find_one = AsyncMock(return_value=workspace_doc)
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))
    return col


# ── Empty new-topics short-circuit ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_merge_with_no_new_topics_short_circuits():
    """A doc with zero extracted topics should NOT call OpenAI or write."""
    workspace = _ws(
        version=2,
        topics=[
            CanonicalTopic(id="tpc_x", name="Cells", source_document_ids=["doc_old"]),
        ],
    )
    col = _mock_collection(workspace.model_dump(by_alias=True))

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch("app.services.taxonomy.azure_openai.chat_json", AsyncMock()) as openai,
    ):
        outcome = await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=[],
        )

    openai.assert_not_awaited()
    col.update_one.assert_not_awaited()
    assert outcome.topics_total == 1
    assert outcome.topics_added == 0
    assert outcome.seeded is False
    assert outcome.taxonomy_version == 2


# ── Seed path: empty workspace ───────────────────────────────────────────────


@pytest.mark.asyncio
async def test_seed_path_skips_ai_and_assigns_fresh_topic_ids():
    """First doc in a workspace seeds the taxonomy 1:1 without an AI call."""
    workspace = _ws(version=0, topics=[])
    col = _mock_collection(workspace.model_dump(by_alias=True))

    topics = [
        _topic_tag("Photosynthesis", complexity=3),
        _topic_tag("Mitochondria", complexity=4),
    ]

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch("app.services.taxonomy.azure_openai.chat_json", AsyncMock()) as openai,
    ):
        outcome = await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=topics,
        )

    openai.assert_not_awaited()
    assert outcome.seeded is True
    assert outcome.topics_added == 2
    assert outcome.topics_total == 2
    assert outcome.taxonomy_version == 1

    col.update_one.assert_awaited_once()
    args, _ = col.update_one.await_args
    filter_, update = args
    assert filter_ == {"_id": "wsp_abc", "taxonomy_version": 0}
    written = update["$set"]["taxonomy"]
    assert len(written["topics"]) == 2
    for row in written["topics"]:
        assert row["id"].startswith("tpc_")
        assert row["source_document_ids"] == ["doc_new"]
    assert update["$set"]["taxonomy_version"] == 1


# ── AI merge path ────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_ai_merge_keeps_existing_topic_ids_and_appends_new_ones():
    existing = [
        CanonicalTopic(
            id="tpc_keep_me",
            name="Photosynthesis",
            aliases=[],
            description="how plants make food",
            complexity_level=3.0,
            source_document_ids=["doc_old"],
        ),
    ]
    workspace = _ws(version=5, topics=existing)
    col = _mock_collection(workspace.model_dump(by_alias=True))

    new_topics = [
        _topic_tag("Plant Energy", complexity=3),  # matches existing
        _topic_tag("Cellular Respiration", complexity=4),  # new
    ]

    openai_response = {
        "merged_topics": [
            {
                "id": "tpc_keep_me",
                "name": "Photosynthesis",
                "aliases": ["Plant Energy"],
                "description": "how plants make food",
                "complexity_level": 3,
                "source_document_ids": ["doc_old", "NEW"],
            },
            {
                "id": "NEW",
                "name": "Cellular Respiration",
                "aliases": [],
                "description": "how cells release energy from glucose",
                "complexity_level": 4,
                "source_document_ids": ["NEW"],
            },
        ],
        "mapping": [
            {"new_topic_name": "Plant Energy", "canonical_id": "tpc_keep_me"},
            {"new_topic_name": "Cellular Respiration", "canonical_id": "NEW"},
        ],
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=openai_response),
        ) as openai,
    ):
        outcome = await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=new_topics,
        )

    openai.assert_awaited_once()
    assert outcome.seeded is False
    assert outcome.topics_total == 2
    assert outcome.topics_added == 1  # only Cellular Respiration is new
    assert outcome.taxonomy_version == 6  # bumped from 5

    written_topics = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    assert len(written_topics) == 2
    by_name = {t["name"]: t for t in written_topics}

    photo = by_name["Photosynthesis"]
    assert photo["id"] == "tpc_keep_me"  # preserved
    assert "Plant Energy" in photo["aliases"]
    # "NEW" resolved to doc_new + dedupe preserved doc_old
    assert "doc_new" in photo["source_document_ids"]
    assert "doc_old" in photo["source_document_ids"]

    resp = by_name["Cellular Respiration"]
    assert resp["id"].startswith("tpc_")
    assert resp["id"] != "NEW"  # fresh id assigned
    assert resp["source_document_ids"] == ["doc_new"]


# ── CAS retry on conflict ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_optimistic_concurrency_retries_on_version_conflict():
    """First update_one returns matched_count=0 (someone else won), second
    succeeds. The service must re-read and retry transparently.
    """
    workspace_v0 = _ws(version=0, topics=[]).model_dump(by_alias=True)
    workspace_v1 = _ws(
        version=1,
        topics=[CanonicalTopic(id="tpc_other", name="Bones")],
    ).model_dump(by_alias=True)

    col = MagicMock()
    # Two find_one calls: first read sees v0, second read sees v1 (after we lost).
    col.find_one = AsyncMock(side_effect=[workspace_v0, workspace_v1])
    # First update_one returns matched_count=0, second returns matched_count=1.
    col.update_one = AsyncMock(
        side_effect=[
            MagicMock(matched_count=0),
            MagicMock(matched_count=1),
        ]
    )

    openai_response = {
        "merged_topics": [
            {
                "id": "tpc_other",
                "name": "Bones",
                "aliases": [],
                "description": None,
                "complexity_level": None,
                "source_document_ids": ["NEW"],
            },
            {
                "id": "NEW",
                "name": "Photosynthesis",
                "aliases": [],
                "description": "x",
                "complexity_level": 3,
                "source_document_ids": ["NEW"],
            },
        ],
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=openai_response),
        ),
    ):
        outcome = await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=[_topic_tag("Photosynthesis", complexity=3)],
        )

    assert col.find_one.await_count == 2
    assert col.update_one.await_count == 2
    # First attempt filtered on v0 (seed path), second on v1 (AI merge path).
    assert col.update_one.await_args_list[0].args[0]["taxonomy_version"] == 0
    assert col.update_one.await_args_list[1].args[0]["taxonomy_version"] == 1
    assert outcome.taxonomy_version == 2


@pytest.mark.asyncio
async def test_cas_exhaustion_raises_merge_error():
    """Three conflicts in a row → TaxonomyMergeError so worker logs + advances."""
    workspace = _ws(version=0, topics=[]).model_dump(by_alias=True)
    col = MagicMock()
    col.find_one = AsyncMock(return_value=workspace)
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=0))

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        pytest.raises(TaxonomyMergeError),
    ):
        await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=[_topic_tag("Photosynthesis")],
        )

    assert col.update_one.await_count == 3  # _MAX_MERGE_RETRIES


# ── Missing workspace ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_missing_workspace_raises_merge_error():
    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)
    col.update_one = AsyncMock()

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        pytest.raises(TaxonomyMergeError),
    ):
        await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_nope",
            document_id="doc_new",
            new_topics=[_topic_tag("X")],
        )

    col.update_one.assert_not_awaited()


# ── Malformed AI response ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_malformed_ai_response_missing_topics_array_raises():
    """Model returned an object without merged_topics — treat as merge error."""
    existing = [CanonicalTopic(id="tpc_x", name="Existing")]
    workspace = _ws(version=0, topics=existing).model_dump(by_alias=True)
    col = MagicMock()
    col.find_one = AsyncMock(return_value=workspace)
    col.update_one = AsyncMock()

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value={"oops": "no merged_topics here"}),
        ),
        pytest.raises(TaxonomyMergeError),
    ):
        await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=[_topic_tag("New Topic")],
        )

    col.update_one.assert_not_awaited()


@pytest.mark.asyncio
async def test_all_rows_malformed_raises():
    existing = [CanonicalTopic(id="tpc_x", name="Existing")]
    workspace = _ws(version=0, topics=existing).model_dump(by_alias=True)
    col = MagicMock()
    col.find_one = AsyncMock(return_value=workspace)
    col.update_one = AsyncMock()

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(
                return_value={
                    "merged_topics": [
                        {"id": "tpc_x", "name": ""},  # empty name → dropped
                        "not a dict",  # bad row → dropped
                        {"id": "tpc_x"},  # no name → dropped
                    ]
                }
            ),
        ),
        pytest.raises(TaxonomyMergeError),
    ):
        await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=[_topic_tag("Anything")],
        )


# ── Safety nets in _parse_merged ─────────────────────────────────────────────


@pytest.mark.asyncio
async def test_new_topic_without_doc_ref_still_attaches_current_doc():
    """If the model forgets to mark a brand-new topic with the source doc, we
    still attach the current document_id so attribution is preserved.
    """
    workspace = _ws(
        version=0,
        topics=[
            CanonicalTopic(id="tpc_old", name="Old", source_document_ids=["doc_old"]),
        ],
    ).model_dump(by_alias=True)
    col = _mock_collection(workspace)

    response = {
        "merged_topics": [
            {
                "id": "tpc_old",
                "name": "Old",
                "aliases": [],
                "description": None,
                "complexity_level": None,
                "source_document_ids": ["doc_old"],
            },
            # Brand-new canonical, but model didn't include doc_new in sources.
            {
                "id": "NEW",
                "name": "Brand New Topic",
                "aliases": [],
                "description": "x",
                "complexity_level": 2,
                "source_document_ids": [],
            },
        ],
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
    ):
        await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=[_topic_tag("Brand New Topic")],
        )

    written = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    by_name = {t["name"]: t for t in written}
    assert by_name["Brand New Topic"]["source_document_ids"] == ["doc_new"]


@pytest.mark.asyncio
async def test_out_of_range_complexity_dropped_to_none():
    """Complexity >5 or <1 is dropped silently (not clamped)."""
    workspace = _ws(
        version=0,
        topics=[
            CanonicalTopic(id="tpc_x", name="X"),
        ],
    ).model_dump(by_alias=True)
    col = _mock_collection(workspace)

    response = {
        "merged_topics": [
            {
                "id": "tpc_x",
                "name": "X",
                "aliases": [],
                "complexity_level": 99,
                "source_document_ids": ["doc_old"],
            },
        ],
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
    ):
        await taxonomy.merge_into_workspace(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            document_id="doc_new",
            new_topics=[_topic_tag("X")],
        )

    written = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    assert written[0]["complexity_level"] is None


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 2.7 — Dependency inference tests
# ─────────────────────────────────────────────────────────────────────────────


def _ws_with(*, version: int = 0, topics: list[CanonicalTopic]) -> Workspace:
    """Same as _ws but topics is mandatory — used by deps tests."""
    return _ws(version=version, topics=topics)


# ── Skip path: <2 topics ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_infer_deps_skipped_on_empty_taxonomy():
    workspace = _ws_with(version=3, topics=[])
    col = _mock_collection(workspace.model_dump(by_alias=True))

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch("app.services.taxonomy.azure_openai.chat_json", AsyncMock()) as openai,
    ):
        outcome = await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    openai.assert_not_awaited()
    col.update_one.assert_not_awaited()
    assert outcome.skipped is True
    assert outcome.topics_total == 0
    assert outcome.taxonomy_version == 3


@pytest.mark.asyncio
async def test_infer_deps_skipped_on_single_topic():
    workspace = _ws_with(
        version=5,
        topics=[
            CanonicalTopic(id="tpc_a", name="Only"),
        ],
    )
    col = _mock_collection(workspace.model_dump(by_alias=True))

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch("app.services.taxonomy.azure_openai.chat_json", AsyncMock()) as openai,
    ):
        outcome = await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    openai.assert_not_awaited()
    col.update_one.assert_not_awaited()
    assert outcome.skipped is True
    assert outcome.topics_total == 1


# ── Happy path: edges set on multi-topic taxonomy ────────────────────────────


@pytest.mark.asyncio
async def test_infer_deps_happy_path_writes_parent_ids():
    topics = [
        CanonicalTopic(id="tpc_root", name="Cells", complexity_level=1.0),
        CanonicalTopic(
            id="tpc_mid",
            name="Photosynthesis",
            complexity_level=3.0,
        ),
        CanonicalTopic(
            id="tpc_top",
            name="Plant Biology",
            complexity_level=5.0,
        ),
    ]
    workspace = _ws_with(version=2, topics=topics)
    col = _mock_collection(workspace.model_dump(by_alias=True))

    response = {
        "edges": [
            {"topic_id": "tpc_root", "parent_id": None},
            {"topic_id": "tpc_mid", "parent_id": "tpc_root"},
            {"topic_id": "tpc_top", "parent_id": "tpc_mid"},
        ]
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ) as openai,
    ):
        outcome = await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    openai.assert_awaited_once()
    assert outcome.skipped is False
    assert outcome.topics_total == 3
    assert outcome.edges_set == 2  # tpc_mid, tpc_top
    assert outcome.edges_changed == 2  # both went None → real id
    assert outcome.edges_dropped_invalid == 0
    assert outcome.taxonomy_version == 3  # bumped from 2

    written = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    by_id = {t["id"]: t for t in written}
    assert by_id["tpc_root"]["parent_id"] is None
    assert by_id["tpc_mid"]["parent_id"] == "tpc_root"
    assert by_id["tpc_top"]["parent_id"] == "tpc_mid"


# ── Sanitization: unknown ids dropped ────────────────────────────────────────


@pytest.mark.asyncio
async def test_infer_deps_drops_unknown_parent_id():
    topics = [
        CanonicalTopic(id="tpc_a", name="A"),
        CanonicalTopic(id="tpc_b", name="B"),
    ]
    workspace = _ws_with(version=0, topics=topics)
    col = _mock_collection(workspace.model_dump(by_alias=True))

    response = {
        "edges": [
            {"topic_id": "tpc_a", "parent_id": None},
            # Model hallucinated a parent that isn't in the taxonomy.
            {"topic_id": "tpc_b", "parent_id": "tpc_hallucinated"},
        ]
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
    ):
        outcome = await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    written = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    by_id = {t["id"]: t for t in written}
    assert by_id["tpc_a"]["parent_id"] is None
    assert by_id["tpc_b"]["parent_id"] is None  # hallucination scrubbed
    assert outcome.edges_set == 0
    assert outcome.edges_dropped_invalid == 1


@pytest.mark.asyncio
async def test_infer_deps_drops_self_reference():
    topics = [
        CanonicalTopic(id="tpc_a", name="A"),
        CanonicalTopic(id="tpc_b", name="B"),
    ]
    workspace = _ws_with(version=0, topics=topics)
    col = _mock_collection(workspace.model_dump(by_alias=True))

    response = {
        "edges": [
            {"topic_id": "tpc_a", "parent_id": "tpc_a"},  # self-loop
            {"topic_id": "tpc_b", "parent_id": "tpc_a"},
        ]
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
    ):
        outcome = await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    written = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    by_id = {t["id"]: t for t in written}
    assert by_id["tpc_a"]["parent_id"] is None  # self-ref dropped
    assert by_id["tpc_b"]["parent_id"] == "tpc_a"  # valid edge kept
    assert outcome.edges_dropped_invalid == 1


# ── Cycle detection ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_infer_deps_breaks_two_node_cycle():
    """A ↔ B is a cycle. Stable processing order (sorted ids) means we drop
    the edge from the alphabetically-first node (tpc_a → tpc_b)."""
    topics = [
        CanonicalTopic(id="tpc_a", name="A"),
        CanonicalTopic(id="tpc_b", name="B"),
    ]
    workspace = _ws_with(version=0, topics=topics)
    col = _mock_collection(workspace.model_dump(by_alias=True))

    response = {
        "edges": [
            {"topic_id": "tpc_a", "parent_id": "tpc_b"},
            {"topic_id": "tpc_b", "parent_id": "tpc_a"},
        ]
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
    ):
        outcome = await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    written = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    by_id = {t["id"]: t for t in written}
    # We process topics in sorted order, so tpc_a is examined first. At that
    # point tpc_b→tpc_a is still in place, and walking tpc_a→tpc_b→tpc_a
    # detects the cycle. tpc_a's edge is dropped.
    assert by_id["tpc_a"]["parent_id"] is None
    assert by_id["tpc_b"]["parent_id"] == "tpc_a"
    assert outcome.edges_dropped_invalid == 1


@pytest.mark.asyncio
async def test_infer_deps_breaks_three_node_cycle():
    """A → B → C → A. One edge must be dropped; the tree must be valid after."""
    topics = [
        CanonicalTopic(id="tpc_a", name="A"),
        CanonicalTopic(id="tpc_b", name="B"),
        CanonicalTopic(id="tpc_c", name="C"),
    ]
    workspace = _ws_with(version=0, topics=topics)
    col = _mock_collection(workspace.model_dump(by_alias=True))

    response = {
        "edges": [
            {"topic_id": "tpc_a", "parent_id": "tpc_b"},
            {"topic_id": "tpc_b", "parent_id": "tpc_c"},
            {"topic_id": "tpc_c", "parent_id": "tpc_a"},
        ]
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
    ):
        outcome = await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    written = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    parents = {t["id"]: t["parent_id"] for t in written}
    # Exactly one edge dropped; the other two form a valid chain.
    none_count = sum(1 for v in parents.values() if v is None)
    assert none_count == 1
    assert outcome.edges_dropped_invalid == 1

    # Final state must be acyclic — walk every chain and confirm no revisit.
    for topic_id in parents:
        seen = {topic_id}
        cursor = parents[topic_id]
        while cursor is not None:
            assert cursor not in seen, f"cycle through {topic_id}"
            seen.add(cursor)
            cursor = parents.get(cursor)


# ── CAS retry on conflict ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_infer_deps_retries_on_version_conflict():
    topics = [
        CanonicalTopic(id="tpc_a", name="A"),
        CanonicalTopic(id="tpc_b", name="B"),
    ]
    workspace_v0 = _ws_with(version=0, topics=topics).model_dump(by_alias=True)
    workspace_v1 = _ws_with(version=1, topics=topics).model_dump(by_alias=True)
    col = MagicMock()
    col.find_one = AsyncMock(side_effect=[workspace_v0, workspace_v1])
    col.update_one = AsyncMock(
        side_effect=[
            MagicMock(matched_count=0),  # lost the race
            MagicMock(matched_count=1),  # won on retry
        ]
    )

    response = {
        "edges": [
            {"topic_id": "tpc_a", "parent_id": None},
            {"topic_id": "tpc_b", "parent_id": "tpc_a"},
        ]
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
    ):
        outcome = await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    assert col.find_one.await_count == 2
    assert col.update_one.await_count == 2
    assert outcome.taxonomy_version == 2  # 1 + 1


# ── CAS exhaustion ───────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_infer_deps_cas_exhaustion_raises():
    topics = [
        CanonicalTopic(id="tpc_a", name="A"),
        CanonicalTopic(id="tpc_b", name="B"),
    ]
    workspace = _ws_with(version=0, topics=topics).model_dump(by_alias=True)
    col = MagicMock()
    col.find_one = AsyncMock(return_value=workspace)
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=0))

    response = {
        "edges": [
            {"topic_id": "tpc_a", "parent_id": None},
            {"topic_id": "tpc_b", "parent_id": "tpc_a"},
        ]
    }

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value=response),
        ),
        pytest.raises(DependencyInferenceError),
    ):
        await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    assert col.update_one.await_count == 3


# ── Malformed response ───────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_infer_deps_missing_edges_array_raises():
    topics = [
        CanonicalTopic(id="tpc_a", name="A"),
        CanonicalTopic(id="tpc_b", name="B"),
    ]
    workspace = _ws_with(version=0, topics=topics).model_dump(by_alias=True)
    col = MagicMock()
    col.find_one = AsyncMock(return_value=workspace)
    col.update_one = AsyncMock()

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        patch(
            "app.services.taxonomy.azure_openai.chat_json",
            AsyncMock(return_value={"oops": "no edges here"}),
        ),
        pytest.raises(DependencyInferenceError),
    ):
        await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_abc")

    col.update_one.assert_not_awaited()


# ── Missing workspace ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_infer_deps_missing_workspace_raises():
    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)
    col.update_one = AsyncMock()

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        pytest.raises(DependencyInferenceError),
    ):
        await taxonomy.infer_dependencies(tenant_id="ten_abc", workspace_id="wsp_nope")

    col.update_one.assert_not_awaited()


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 2.11 — validate_taxonomy_shape
# ─────────────────────────────────────────────────────────────────────────────


def test_validate_empty_taxonomy_is_allowed():
    # POST /regenerate resets to empty before replay — must not throw.
    taxonomy.validate_taxonomy_shape([])


def test_validate_happy_path():
    taxonomy.validate_taxonomy_shape(
        [
            CanonicalTopic(id="tpc_a", name="Cells"),
            CanonicalTopic(id="tpc_b", name="Photosynthesis", parent_id="tpc_a"),
            CanonicalTopic(id="tpc_c", name="Mitosis", parent_id="tpc_a"),
        ]
    )


def test_validate_rejects_duplicate_ids():
    with pytest.raises(TaxonomyValidationError, match="Duplicate topic id"):
        taxonomy.validate_taxonomy_shape(
            [
                CanonicalTopic(id="tpc_a", name="One"),
                CanonicalTopic(id="tpc_a", name="Two"),  # same id
            ]
        )


def test_validate_rejects_dangling_parent_id():
    with pytest.raises(TaxonomyValidationError, match="unknown parent_id"):
        taxonomy.validate_taxonomy_shape(
            [
                CanonicalTopic(id="tpc_a", name="One", parent_id="tpc_ghost"),
            ]
        )


def test_validate_rejects_self_parent():
    with pytest.raises(TaxonomyValidationError, match="cannot be its own parent"):
        taxonomy.validate_taxonomy_shape(
            [
                CanonicalTopic(id="tpc_a", name="One", parent_id="tpc_a"),
            ]
        )


def test_validate_rejects_two_node_cycle():
    with pytest.raises(TaxonomyValidationError, match="Cycle"):
        taxonomy.validate_taxonomy_shape(
            [
                CanonicalTopic(id="tpc_a", name="A", parent_id="tpc_b"),
                CanonicalTopic(id="tpc_b", name="B", parent_id="tpc_a"),
            ]
        )


def test_validate_rejects_three_node_cycle():
    with pytest.raises(TaxonomyValidationError, match="Cycle"):
        taxonomy.validate_taxonomy_shape(
            [
                CanonicalTopic(id="tpc_a", name="A", parent_id="tpc_b"),
                CanonicalTopic(id="tpc_b", name="B", parent_id="tpc_c"),
                CanonicalTopic(id="tpc_c", name="C", parent_id="tpc_a"),
            ]
        )


def test_validate_rejects_case_insensitive_duplicate_names():
    with pytest.raises(TaxonomyValidationError, match="Duplicate topic name"):
        taxonomy.validate_taxonomy_shape(
            [
                CanonicalTopic(id="tpc_a", name="Photosynthesis"),
                CanonicalTopic(id="tpc_b", name="photosynthesis"),  # case differs
            ]
        )


def test_validate_rejects_empty_name():
    with pytest.raises(TaxonomyValidationError, match="empty name"):
        taxonomy.validate_taxonomy_shape(
            [
                CanonicalTopic(id="tpc_a", name="   "),  # whitespace only
            ]
        )


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 2.11 — replace_taxonomy (PUT seam)
# ─────────────────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_replace_taxonomy_happy_path_writes_and_returns_refreshed():
    initial = _ws(
        version=4,
        topics=[
            CanonicalTopic(id="tpc_old", name="Old"),
        ],
    )
    refreshed = _ws(
        version=5,
        topics=[
            CanonicalTopic(id="tpc_new", name="Renamed"),
        ],
    )
    col = MagicMock()
    col.find_one = AsyncMock(
        side_effect=[
            initial.model_dump(by_alias=True),  # initial read
            refreshed.model_dump(by_alias=True),  # post-write re-read
        ]
    )
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    with patch("app.services.taxonomy.get_collection", return_value=col):
        result = await taxonomy.replace_taxonomy(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            expected_version=4,
            topics=[CanonicalTopic(id="tpc_new", name="Renamed")],
        )

    assert result.taxonomy_version == 5
    assert result.taxonomy.topics[0].name == "Renamed"
    # CAS filter must include the expected version.
    update_args = col.update_one.await_args.args
    assert update_args[0]["taxonomy_version"] == 4


@pytest.mark.asyncio
async def test_replace_taxonomy_propagates_validation_error_before_read():
    """Validation must run BEFORE Cosmos reads to avoid a wasted round trip."""
    col = MagicMock()
    col.find_one = AsyncMock()
    col.update_one = AsyncMock()

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        pytest.raises(TaxonomyValidationError),
    ):
        await taxonomy.replace_taxonomy(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            expected_version=0,
            topics=[
                CanonicalTopic(id="tpc_a", name="A", parent_id="tpc_a"),  # self-loop
            ],
        )

    col.find_one.assert_not_awaited()
    col.update_one.assert_not_awaited()


@pytest.mark.asyncio
async def test_replace_taxonomy_version_conflict_raises():
    initial = _ws(version=4, topics=[])
    col = MagicMock()
    col.find_one = AsyncMock(return_value=initial.model_dump(by_alias=True))
    col.update_one = AsyncMock(return_value=MagicMock(matched_count=0))

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        pytest.raises(TaxonomyVersionConflict),
    ):
        await taxonomy.replace_taxonomy(
            tenant_id="ten_abc",
            workspace_id="wsp_abc",
            expected_version=4,
            topics=[CanonicalTopic(id="tpc_a", name="A")],
        )


@pytest.mark.asyncio
async def test_replace_taxonomy_missing_workspace_raises():
    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)
    col.update_one = AsyncMock()

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        pytest.raises(RuntimeError, match="not found"),
    ):
        await taxonomy.replace_taxonomy(
            tenant_id="ten_abc",
            workspace_id="wsp_missing",
            expected_version=0,
            topics=[CanonicalTopic(id="tpc_a", name="A")],
        )

    col.update_one.assert_not_awaited()


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 2.11 — regenerate_from_documents
# ─────────────────────────────────────────────────────────────────────────────


def _doc_row(doc_id: str, *, created_at: str, topic_names: list[str]) -> dict:
    """Stub the Cosmos document row shape with topic_tags populated."""
    return {
        "_id": doc_id,
        "tenant_id": "ten_abc",
        "workspace_id": "wsp_abc",
        "uploaded_by": "usr_abc",
        "filename": f"{doc_id}.pdf",
        "blob_url": "https://blob/x",
        "file_size_bytes": 100,
        "doc_type": "pdf",
        "status": "ready",
        "chunk_count": 0,
        "moderation_flagged": False,
        "topic_tags": [{"name": n, "confidence": 1.0, "source": "ai"} for n in topic_names],
        "created_at": created_at,
        "updated_at": created_at,
    }


def _cursor(rows: list[dict]) -> MagicMock:
    """Pseudo-cursor with chained .sort().to_list() like Motor."""
    cursor = MagicMock()
    cursor.sort = MagicMock(return_value=cursor)
    cursor.to_list = AsyncMock(return_value=rows)
    return cursor


def _route_collections(
    *,
    workspace_states: list[dict],
    doc_rows: list[dict],
):
    """Build a get_collection side_effect that returns separate mocks for
    DOCUMENTS (chunk find for topic resolution) vs WORKSPACES (taxonomy
    state). Workspaces' find_one cycles through ``workspace_states`` so
    the test can simulate the rolling state machine across writes.
    """
    from app.core.database import DOCUMENTS, WORKSPACES

    docs_col = MagicMock()
    docs_col.find = MagicMock(return_value=_cursor(doc_rows))
    docs_col.find_one = AsyncMock(return_value=doc_rows[0] if doc_rows else None)

    ws_col = MagicMock()
    ws_col.find_one = AsyncMock(side_effect=list(workspace_states))
    ws_col.update_one = AsyncMock(return_value=MagicMock(matched_count=1))

    def _route(_tenant_id, collection):
        if collection == DOCUMENTS:
            return docs_col
        if collection == WORKSPACES:
            return ws_col
        raise AssertionError(f"Unexpected collection: {collection}")

    return docs_col, ws_col, _route


@pytest.mark.asyncio
async def test_regenerate_with_no_docs_clears_taxonomy_and_skips_replay():
    """Workspace with zero documents → taxonomy reset only, no merge calls."""
    initial = _ws(
        version=4,
        topics=[
            CanonicalTopic(id="tpc_old", name="Stale"),
        ],
    )
    reset = _ws(version=5, topics=[])
    _docs_col, ws_col, route = _route_collections(
        workspace_states=[
            initial.model_dump(by_alias=True),  # initial read
            reset.model_dump(by_alias=True),  # final read
        ],
        doc_rows=[],
    )

    with (
        patch("app.services.taxonomy.get_collection", side_effect=route),
        patch("app.services.taxonomy.merge_into_workspace", AsyncMock()) as mock_merge,
        patch("app.services.taxonomy.infer_dependencies", AsyncMock()) as mock_deps,
    ):
        outcome = await taxonomy.regenerate_from_documents(
            tenant_id="ten_abc", workspace_id="wsp_abc"
        )

    # Taxonomy was wiped via update_one with the existing version filter.
    ws_col.update_one.assert_awaited_once()
    update_args = ws_col.update_one.await_args.args
    assert update_args[0]["taxonomy_version"] == 4
    assert update_args[1]["$set"]["taxonomy_version"] == 5
    assert update_args[1]["$set"]["taxonomy"]["topics"] == []

    # Empty workspace: no merges happen, but deps still runs (it'll
    # short-circuit on <2 topics internally — tested elsewhere).
    mock_merge.assert_not_awaited()
    mock_deps.assert_awaited_once()

    assert outcome.documents_merged == 0
    assert outcome.topics_total == 0
    assert outcome.final_version == 5


@pytest.mark.asyncio
async def test_regenerate_replays_docs_in_upload_order():
    """Each doc's topic_tags should get merged exactly once, in created_at
    order, before final dep inference."""
    initial = _ws(version=2, topics=[CanonicalTopic(id="tpc_old", name="Stale")])
    final = _ws(
        version=5,
        topics=[
            CanonicalTopic(id="tpc_new1", name="Cells"),
            CanonicalTopic(id="tpc_new2", name="Photosynthesis"),
        ],
    )

    docs = [
        _doc_row("doc_a", created_at="2026-05-01T00:00:00+00:00", topic_names=["Cells"]),
        _doc_row("doc_b", created_at="2026-05-02T00:00:00+00:00", topic_names=["Photosynthesis"]),
    ]
    # regenerate_from_documents reads workspace twice: once at start
    # (initial), once at the end after merge+deps (final). Merges + deps
    # are mocked so they don't trigger their own workspace reads.
    _docs_col, _ws_col, route = _route_collections(
        workspace_states=[
            initial.model_dump(by_alias=True),
            final.model_dump(by_alias=True),
        ],
        doc_rows=docs,
    )

    with (
        patch("app.services.taxonomy.get_collection", side_effect=route),
        patch("app.services.taxonomy.merge_into_workspace", AsyncMock()) as mock_merge,
        patch("app.services.taxonomy.infer_dependencies", AsyncMock()) as mock_deps,
    ):
        outcome = await taxonomy.regenerate_from_documents(
            tenant_id="ten_abc", workspace_id="wsp_abc"
        )

    # Exactly two merge calls in the docs' created_at order.
    assert mock_merge.await_count == 2
    first_call_doc = mock_merge.await_args_list[0].kwargs["document_id"]
    second_call_doc = mock_merge.await_args_list[1].kwargs["document_id"]
    assert first_call_doc == "doc_a"
    assert second_call_doc == "doc_b"
    # Dep inference runs once, after all merges.
    mock_deps.assert_awaited_once()

    assert outcome.documents_merged == 2
    assert outcome.topics_total == 2
    assert outcome.final_version == 5


@pytest.mark.asyncio
async def test_regenerate_continues_when_one_docs_merge_fails():
    """A bad merge response for ONE doc should not abort the whole regen."""
    initial = _ws(version=0, topics=[])
    final = _ws(version=2, topics=[CanonicalTopic(id="tpc_only", name="Cells")])
    docs = [
        _doc_row("doc_a", created_at="2026-05-01T00:00:00+00:00", topic_names=["Cells"]),
        _doc_row("doc_b", created_at="2026-05-02T00:00:00+00:00", topic_names=["Bogus"]),
    ]
    _docs_col, _ws_col, route = _route_collections(
        workspace_states=[
            initial.model_dump(by_alias=True),
            final.model_dump(by_alias=True),
        ],
        doc_rows=docs,
    )

    merge_results = [None, TaxonomyMergeError("model glitch")]

    async def _merge_side(*args, **kwargs):
        r = merge_results.pop(0)
        if isinstance(r, Exception):
            raise r
        return r

    with (
        patch("app.services.taxonomy.get_collection", side_effect=route),
        patch(
            "app.services.taxonomy.merge_into_workspace",
            AsyncMock(side_effect=_merge_side),
        ) as mock_merge,
        patch("app.services.taxonomy.infer_dependencies", AsyncMock()) as mock_deps,
    ):
        outcome = await taxonomy.regenerate_from_documents(
            tenant_id="ten_abc", workspace_id="wsp_abc"
        )

    # Both merge attempts ran; deps inference still ran at the end.
    assert mock_merge.await_count == 2
    mock_deps.assert_awaited_once()
    # Only the successful doc counted toward documents_merged.
    assert outcome.documents_merged == 1


@pytest.mark.asyncio
async def test_regenerate_continues_when_dep_inference_fails():
    """A deps inference failure leaves the taxonomy intact (parent-less)."""
    initial = _ws(version=0, topics=[])
    final = _ws(version=2, topics=[CanonicalTopic(id="tpc_only", name="X")])
    docs = [
        _doc_row("doc_a", created_at="2026-05-01T00:00:00+00:00", topic_names=["X"]),
    ]
    _docs_col, _ws_col, route = _route_collections(
        workspace_states=[
            initial.model_dump(by_alias=True),
            final.model_dump(by_alias=True),
        ],
        doc_rows=docs,
    )

    with (
        patch("app.services.taxonomy.get_collection", side_effect=route),
        patch("app.services.taxonomy.merge_into_workspace", AsyncMock()),
        patch(
            "app.services.taxonomy.infer_dependencies",
            AsyncMock(side_effect=DependencyInferenceError("model glitch")),
        ),
    ):
        outcome = await taxonomy.regenerate_from_documents(
            tenant_id="ten_abc", workspace_id="wsp_abc"
        )

    assert outcome.documents_merged == 1
    assert outcome.topics_total == 1


@pytest.mark.asyncio
async def test_regenerate_missing_workspace_raises():
    col = MagicMock()
    col.find_one = AsyncMock(return_value=None)

    with (
        patch("app.services.taxonomy.get_collection", return_value=col),
        pytest.raises(RuntimeError, match="not found"),
    ):
        await taxonomy.regenerate_from_documents(tenant_id="ten_abc", workspace_id="wsp_missing")
