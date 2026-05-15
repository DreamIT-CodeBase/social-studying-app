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
from app.services.taxonomy import TaxonomyMergeError

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
    workspace = _ws(version=2, topics=[
        CanonicalTopic(id="tpc_x", name="Cells", source_document_ids=["doc_old"]),
    ])
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
        _topic_tag("Plant Energy", complexity=3),     # matches existing
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
    assert outcome.topics_added == 1     # only Cellular Respiration is new
    assert outcome.taxonomy_version == 6  # bumped from 5

    written_topics = col.update_one.await_args.args[1]["$set"]["taxonomy"]["topics"]
    assert len(written_topics) == 2
    by_name = {t["name"]: t for t in written_topics}

    photo = by_name["Photosynthesis"]
    assert photo["id"] == "tpc_keep_me"          # preserved
    assert "Plant Energy" in photo["aliases"]
    # "NEW" resolved to doc_new + dedupe preserved doc_old
    assert "doc_new" in photo["source_document_ids"]
    assert "doc_old" in photo["source_document_ids"]

    resp = by_name["Cellular Respiration"]
    assert resp["id"].startswith("tpc_")
    assert resp["id"] != "NEW"                   # fresh id assigned
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
            AsyncMock(return_value={
                "merged_topics": [
                    {"id": "tpc_x", "name": ""},     # empty name → dropped
                    "not a dict",                     # bad row → dropped
                    {"id": "tpc_x"},                  # no name → dropped
                ]
            }),
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
    workspace = _ws(version=0, topics=[
        CanonicalTopic(id="tpc_old", name="Old", source_document_ids=["doc_old"]),
    ]).model_dump(by_alias=True)
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
    workspace = _ws(version=0, topics=[
        CanonicalTopic(id="tpc_x", name="X"),
    ]).model_dump(by_alias=True)
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
