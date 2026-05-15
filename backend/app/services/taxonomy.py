"""Taxonomy service — merge per-document topics into the workspace canon.

Sprint 2.6. The topic extraction worker calls :func:`merge_into_workspace`
once per document after :func:`app.services.topic_extraction.extract_topics`
succeeds. The service either:

1. **Seeds** the workspace's empty taxonomy directly from the document's
   topics (no AI call — first-doc fast path).
2. **Merges** the new topics into the existing canonical taxonomy via a
   single GPT-4o call (``app/prompts/taxonomy_merge_v1.txt``), resolving
   overlaps and naming differences, then persists the result under
   optimistic concurrency control.

Concurrency model
-----------------
Multiple documents in the same workspace can finish topic extraction at
the same time (admin uploads two PDFs in a row → two parallel topic
workers). Each one wants to merge into the same workspace taxonomy. We
use compare-and-swap on ``taxonomy_version``:

1. Read workspace including ``taxonomy_version``.
2. Compute merged taxonomy.
3. ``update_one({_id, taxonomy_version: N}, {$set: {taxonomy_version: N+1, ...}})``.
4. If ``matched_count == 0`` someone else won. Re-read and retry.

Bounded retries — after 3 conflicts we give up and let the document
advance to ``topics_extracted`` anyway. The per-doc TopicTags are still
useful for Sprint 2.8 chunking, and the admin "regenerate taxonomy"
endpoint (2.11) can rebuild from scratch.

Why no separate worker / queue
------------------------------
Per the Sprint 2.3 memo, 2.5/2.8/2.9 are separate workers but 2.6 stays
inline. Merge is one GPT-4o call comparable to topic extraction's call —
no reason to round-trip through Service Bus for it.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any
from uuid import uuid4

from app.core.database import WORKSPACES, get_collection
from app.models.base import utc_now
from app.models.document import TopicTag
from app.models.workspace import CanonicalTopic, Taxonomy, Workspace
from app.prompts import load_prompt, render, split_system_user
from app.services import azure_openai

logger = logging.getLogger(__name__)

TAXONOMY_MERGE_PROMPT_VERSION = "taxonomy_merge_v1"

# Bounded retries on optimistic-concurrency conflict. Three is enough — if
# we lose three races in a row, something pathological is happening.
_MAX_MERGE_RETRIES = 3

# Tokens budget for the merge response. ~3K topics worth of JSON fits in 8K
# tokens comfortably; we cap at 6K to leave headroom for very long taxonomies.
_MERGE_MAX_OUTPUT_TOKENS = 6_000


class TaxonomyMergeError(RuntimeError):
    """Raised when the merge AI call returns an unusable response.

    Worker treats this as a soft failure — log + advance the doc anyway.
    """


@dataclass(frozen=True, slots=True)
class MergeOutcome:
    """Result handed back to the worker for logging / observability."""

    taxonomy_version: int          # the version we wrote
    topics_total: int              # canonical topics after the merge
    topics_added: int              # how many new canonical topics this doc added
    seeded: bool                   # True if this was the first-doc seed path


# ── Public entry point ───────────────────────────────────────────────────────


async def merge_into_workspace(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    new_topics: list[TopicTag],
) -> MergeOutcome:
    """Merge ``new_topics`` into the workspace's canonical taxonomy.

    Raises:
        TaxonomyMergeError: if the merge AI call returned an unparseable
            shape after retries OR if optimistic-concurrency retries were
            exhausted. Worker should log and advance the doc anyway.
    """
    if not new_topics:
        # Doc had no extractable topics (cover page, admin upload, etc.) —
        # there's nothing to merge in. Read current version so the caller
        # can log a coherent number.
        workspace = await _read_workspace(tenant_id, workspace_id)
        logger.info(
            "Taxonomy merge skipped (no topics) doc=%s workspace=%s",
            document_id,
            workspace_id,
        )
        return MergeOutcome(
            taxonomy_version=workspace.taxonomy_version if workspace else 0,
            topics_total=len(workspace.taxonomy.topics) if workspace else 0,
            topics_added=0,
            seeded=False,
        )

    for attempt in range(1, _MAX_MERGE_RETRIES + 1):
        workspace = await _read_workspace(tenant_id, workspace_id)
        if workspace is None:
            raise TaxonomyMergeError(
                f"Workspace {workspace_id} not found in tenant {tenant_id}"
            )

        if not workspace.taxonomy.topics:
            # Seed path — first doc to land for this workspace.
            merged = _seed_from_topics(new_topics, document_id)
            seeded = True
            topics_added = len(merged.topics)
        else:
            merged = await _ai_merge(
                existing=workspace.taxonomy,
                new_topics=new_topics,
                document_id=document_id,
            )
            seeded = False
            before = {t.id for t in workspace.taxonomy.topics}
            topics_added = sum(1 for t in merged.topics if t.id not in before)

        merged.last_merged_at = utc_now()
        wrote = await _conditional_write(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            expected_version=workspace.taxonomy_version,
            new_taxonomy=merged,
        )
        if wrote:
            logger.info(
                "Taxonomy merge committed doc=%s workspace=%s version=%d "
                "topics_total=%d topics_added=%d seeded=%s attempt=%d",
                document_id,
                workspace_id,
                workspace.taxonomy_version + 1,
                len(merged.topics),
                topics_added,
                seeded,
                attempt,
            )
            return MergeOutcome(
                taxonomy_version=workspace.taxonomy_version + 1,
                topics_total=len(merged.topics),
                topics_added=topics_added,
                seeded=seeded,
            )

        # Compare-and-swap lost — another worker bumped the version. Retry.
        logger.info(
            "Taxonomy merge CAS conflict doc=%s workspace=%s attempt=%d/%d",
            document_id,
            workspace_id,
            attempt,
            _MAX_MERGE_RETRIES,
        )

    raise TaxonomyMergeError(
        f"Could not commit taxonomy merge for {workspace_id} "
        f"after {_MAX_MERGE_RETRIES} attempts"
    )


# ── Seed path: first document in a workspace ─────────────────────────────────


def _seed_from_topics(new_topics: list[TopicTag], document_id: str) -> Taxonomy:
    """Build a fresh canonical taxonomy from a single document's topics.

    No AI call — every per-doc topic becomes a canonical topic 1:1. Aliases
    stay empty because there's nothing to alias against yet.
    """
    canonical: list[CanonicalTopic] = []
    for t in new_topics:
        canonical.append(
            CanonicalTopic(
                id=f"tpc_{uuid4().hex}",
                name=t.name,
                aliases=[],
                description=t.description,
                complexity_level=(
                    float(t.complexity_level) if t.complexity_level is not None else None
                ),
                parent_id=None,
                source_document_ids=[document_id],
            )
        )
    return Taxonomy(topics=canonical)


# ── AI merge path: subsequent documents ──────────────────────────────────────


async def _ai_merge(
    *,
    existing: Taxonomy,
    new_topics: list[TopicTag],
    document_id: str,
) -> Taxonomy:
    """Call GPT-4o to merge new_topics into the existing taxonomy.

    Raises:
        TaxonomyMergeError: on unparseable output.
    """
    template = load_prompt(TAXONOMY_MERGE_PROMPT_VERSION)
    system_prompt, user_prompt_tpl = split_system_user(template)
    user_prompt = render(
        user_prompt_tpl,
        existing_taxonomy=json.dumps(
            [_topic_to_prompt_json(t) for t in existing.topics],
            indent=2,
        ),
        new_document_id=document_id,
        new_topics=json.dumps(
            [_new_topic_to_prompt_json(t) for t in new_topics],
            indent=2,
        ),
    )

    response = await azure_openai.chat_json(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_output_tokens=_MERGE_MAX_OUTPUT_TOKENS,
    )

    raw_topics = response.get("merged_topics")
    if not isinstance(raw_topics, list):
        raise TaxonomyMergeError(
            f"Merge response missing 'merged_topics' array; keys={list(response)}"
        )

    return _parse_merged(raw_topics, document_id=document_id, existing=existing)


def _topic_to_prompt_json(t: CanonicalTopic) -> dict[str, Any]:
    """Project a CanonicalTopic to the JSON shape the prompt expects."""
    return {
        "id": t.id,
        "name": t.name,
        "aliases": t.aliases,
        "description": t.description,
        "complexity_level": t.complexity_level,
        "source_document_ids": t.source_document_ids,
    }


def _new_topic_to_prompt_json(t: TopicTag) -> dict[str, Any]:
    return {
        "name": t.name,
        "description": t.description,
        "complexity_level": t.complexity_level,
        "page_refs": t.page_refs,
    }


def _parse_merged(
    raw: list[Any],
    *,
    document_id: str,
    existing: Taxonomy,
) -> Taxonomy:
    """Turn the model's merged_topics array into a Taxonomy.

    Replaces literal ``"NEW"`` ids with freshly-generated ``tpc_<uuid>``,
    and resolves any ``"NEW"`` entries in source_document_ids to the
    real ``document_id`` of the doc that triggered this merge.

    Drops malformed rows but never raises on a single bad row — the
    contract with the worker is that merge succeeds whenever the response
    is even approximately right.
    """
    existing_ids = {t.id for t in existing.topics}
    out: list[CanonicalTopic] = []
    for row in raw:
        if not isinstance(row, dict):
            continue
        name = row.get("name")
        if not isinstance(name, str) or not name.strip():
            continue

        raw_id = row.get("id")
        topic_id: str
        if isinstance(raw_id, str) and raw_id in existing_ids:
            topic_id = raw_id
        else:
            topic_id = f"tpc_{uuid4().hex}"

        aliases_raw = row.get("aliases") or []
        aliases = [a for a in aliases_raw if isinstance(a, str) and a.strip()]

        description = row.get("description")
        if description is not None and not isinstance(description, str):
            description = None

        complexity_raw = row.get("complexity_level")
        complexity: float | None = None
        if isinstance(complexity_raw, int | float) and 1 <= complexity_raw <= 5:
            complexity = float(complexity_raw)

        source_raw = row.get("source_document_ids") or []
        source_ids: list[str] = []
        for sid in source_raw:
            if not isinstance(sid, str):
                continue
            resolved = document_id if sid == "NEW" else sid
            if resolved not in source_ids:
                source_ids.append(resolved)
        # Safety net: if the model forgot to attach the new doc to a topic
        # it visibly added/touched, we'll attach it ourselves when the
        # canonical topic didn't previously exist.
        if topic_id not in existing_ids and document_id not in source_ids:
            source_ids.append(document_id)

        out.append(
            CanonicalTopic(
                id=topic_id,
                name=name.strip(),
                aliases=aliases,
                description=description.strip() if description else None,
                complexity_level=complexity,
                parent_id=None,
                source_document_ids=source_ids,
            )
        )

    if not out:
        raise TaxonomyMergeError("Merge response had no valid topic rows")

    return Taxonomy(topics=out)


# ── Persistence ──────────────────────────────────────────────────────────────


async def _read_workspace(tenant_id: str, workspace_id: str) -> Workspace | None:
    """Load the workspace document fresh — never cached.

    Caching would defeat the compare-and-swap loop: stale reads → guaranteed
    version mismatch on every write attempt.
    """
    col = get_collection(tenant_id, WORKSPACES)
    raw = await col.find_one({"_id": workspace_id})
    if raw is None:
        return None
    # Cosmos stores _id but our model uses `id` with alias; Pydantic handles
    # this via populate_by_name=True on CosmosDocument.
    return Workspace.model_validate(raw)


async def _conditional_write(
    *,
    tenant_id: str,
    workspace_id: str,
    expected_version: int,
    new_taxonomy: Taxonomy,
) -> bool:
    """Compare-and-swap the workspace's taxonomy.

    Returns True if the write succeeded, False if another writer beat us
    (the version in the filter didn't match the document's current state).
    """
    col = get_collection(tenant_id, WORKSPACES)
    result = await col.update_one(
        {"_id": workspace_id, "taxonomy_version": expected_version},
        {
            "$set": {
                "taxonomy": new_taxonomy.model_dump(),
                "taxonomy_version": expected_version + 1,
                "updated_at": utc_now(),
            }
        },
    )
    return result.matched_count == 1
