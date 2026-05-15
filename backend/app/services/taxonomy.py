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

from app.core.database import DOCUMENTS, WORKSPACES, get_collection
from app.models.base import utc_now
from app.models.document import Document, TopicTag
from app.models.workspace import CanonicalTopic, Taxonomy, Workspace
from app.prompts import load_prompt, render, split_system_user
from app.services import azure_openai

logger = logging.getLogger(__name__)

TAXONOMY_MERGE_PROMPT_VERSION = "taxonomy_merge_v1"
DEPENDENCY_INFERENCE_PROMPT_VERSION = "dependency_inference_v1"

# Bounded retries on optimistic-concurrency conflict. Three is enough — if
# we lose three races in a row, something pathological is happening.
_MAX_MERGE_RETRIES = 3

# Tokens budget for the merge response. ~3K topics worth of JSON fits in 8K
# tokens comfortably; we cap at 6K to leave headroom for very long taxonomies.
_MERGE_MAX_OUTPUT_TOKENS = 6_000

# Tokens budget for the dependency inference response. Smaller than merge —
# each row is just {topic_id, parent_id}, much tighter than full topic JSON.
_INFER_DEPS_MAX_OUTPUT_TOKENS = 3_000


class TaxonomyMergeError(RuntimeError):
    """Raised when the merge AI call returns an unusable response.

    Worker treats this as a soft failure — log + advance the doc anyway.
    """


class DependencyInferenceError(RuntimeError):
    """Raised when the dep-inference AI call returns an unusable response.

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


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 2.7 — Dependency Graph Inference
# ─────────────────────────────────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class InferDepsOutcome:
    """Result of running the dep-inference pass."""

    taxonomy_version: int
    topics_total: int
    edges_set: int             # canonical topics with a non-None parent_id after the pass
    edges_changed: int         # rows whose parent_id differs from before the pass
    edges_dropped_invalid: int # rows the validator threw out (self-ref, unknown id, cycle)
    skipped: bool              # True when taxonomy had <2 topics → no AI call


async def infer_dependencies(
    *,
    tenant_id: str,
    workspace_id: str,
) -> InferDepsOutcome:
    """Infer single-parent prerequisite edges for every topic in a workspace.

    Reads the current canonical taxonomy, calls GPT-4o with the dependency
    inference prompt, validates the response (drops self-refs / unknown ids
    / cycles), and writes the new ``parent_id`` values back under
    optimistic-concurrency control.

    The worker calls this AFTER ``merge_into_workspace``. We don't take a
    Workspace argument because we need a fresh read inside the CAS loop —
    a stale workspace passed in from the caller would race against any
    sibling worker that also bumped the version between merge and deps.

    Raises:
        DependencyInferenceError: model returned an unparseable shape OR
            CAS retries exhausted. Worker logs and advances doc anyway.
    """
    for attempt in range(1, _MAX_MERGE_RETRIES + 1):
        workspace = await _read_workspace(tenant_id, workspace_id)
        if workspace is None:
            raise DependencyInferenceError(
                f"Workspace {workspace_id} not found in tenant {tenant_id}"
            )

        topics = workspace.taxonomy.topics
        # No edges are possible with <2 topics. Skip the AI call entirely —
        # saves money on workspaces that have only one document with one topic.
        if len(topics) < 2:
            logger.info(
                "Dep inference skipped (taxonomy size=%d) workspace=%s",
                len(topics),
                workspace_id,
            )
            return InferDepsOutcome(
                taxonomy_version=workspace.taxonomy_version,
                topics_total=len(topics),
                edges_set=sum(1 for t in topics if t.parent_id is not None),
                edges_changed=0,
                edges_dropped_invalid=0,
                skipped=True,
            )

        edges = await _ai_infer_dependencies(
            topics=topics,
            workspace_id=workspace_id,
        )

        # Validate against the actual id set + drop self-refs + drop cycles.
        valid_ids = {t.id for t in topics}
        clean_edges, dropped = _sanitize_edges(edges, valid_ids=valid_ids)

        # Build new topic list with parent_id filled in.
        before_parents = {t.id: t.parent_id for t in topics}
        new_topics: list[CanonicalTopic] = []
        for t in topics:
            new_parent = clean_edges.get(t.id)
            new_topics.append(t.model_copy(update={"parent_id": new_parent}))
        new_taxonomy = Taxonomy(
            topics=new_topics,
            last_merged_at=workspace.taxonomy.last_merged_at,
        )
        edges_set = sum(1 for t in new_topics if t.parent_id is not None)
        edges_changed = sum(
            1 for t in new_topics
            if t.parent_id != before_parents.get(t.id)
        )

        wrote = await _conditional_write(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            expected_version=workspace.taxonomy_version,
            new_taxonomy=new_taxonomy,
        )
        if wrote:
            logger.info(
                "Dep inference committed workspace=%s version=%d "
                "topics=%d edges_set=%d edges_changed=%d dropped=%d attempt=%d",
                workspace_id,
                workspace.taxonomy_version + 1,
                len(new_topics),
                edges_set,
                edges_changed,
                dropped,
                attempt,
            )
            return InferDepsOutcome(
                taxonomy_version=workspace.taxonomy_version + 1,
                topics_total=len(new_topics),
                edges_set=edges_set,
                edges_changed=edges_changed,
                edges_dropped_invalid=dropped,
                skipped=False,
            )

        logger.info(
            "Dep inference CAS conflict workspace=%s attempt=%d/%d",
            workspace_id,
            attempt,
            _MAX_MERGE_RETRIES,
        )

    raise DependencyInferenceError(
        f"Could not commit dep inference for {workspace_id} "
        f"after {_MAX_MERGE_RETRIES} attempts"
    )


async def _ai_infer_dependencies(
    *,
    topics: list[CanonicalTopic],
    workspace_id: str,
) -> dict[str, str | None]:
    """Call GPT-4o to infer parent_id for each topic.

    Returns a dict mapping topic_id → parent_id (or None). May include
    bogus entries — caller MUST run :func:`_sanitize_edges` before trusting
    the result.

    Raises:
        DependencyInferenceError: if the response is unparseable.
    """
    template = load_prompt(DEPENDENCY_INFERENCE_PROMPT_VERSION)
    system_prompt, user_prompt_tpl = split_system_user(template)
    user_prompt = render(
        user_prompt_tpl,
        workspace_id=workspace_id,
        taxonomy_topics=json.dumps(
            [
                {
                    "id": t.id,
                    "name": t.name,
                    "description": t.description,
                    "complexity_level": t.complexity_level,
                }
                for t in topics
            ],
            indent=2,
        ),
    )

    response = await azure_openai.chat_json(
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        max_output_tokens=_INFER_DEPS_MAX_OUTPUT_TOKENS,
    )

    raw_edges = response.get("edges")
    if not isinstance(raw_edges, list):
        raise DependencyInferenceError(
            f"Dep inference response missing 'edges' array; keys={list(response)}"
        )

    out: dict[str, str | None] = {}
    for row in raw_edges:
        if not isinstance(row, dict):
            continue
        topic_id = row.get("topic_id")
        parent_id = row.get("parent_id")
        if not isinstance(topic_id, str) or not topic_id:
            continue
        # parent_id can be None or a string. Anything else (int, dict, etc.) is bad.
        if parent_id is not None and not isinstance(parent_id, str):
            continue
        out[topic_id] = parent_id or None  # collapse empty-string to None
    return out


def _sanitize_edges(
    proposed: dict[str, str | None],
    *,
    valid_ids: set[str],
) -> tuple[dict[str, str | None], int]:
    """Filter a proposed parent-edge map down to the trustworthy subset.

    Drops:
    - Edges whose topic_id isn't in the current taxonomy (model hallucination).
    - Edges whose parent_id isn't in the current taxonomy.
    - Self-loops (topic_id == parent_id).
    - Edges that would create a cycle (DFS check below).

    Returns ``(clean_edges, dropped_count)``. Edges where the proposed
    parent is None pass through unchanged (None is always valid).
    """
    candidates: dict[str, str | None] = {}
    dropped = 0

    for topic_id, parent_id in proposed.items():
        if topic_id not in valid_ids:
            logger.debug("Dep inference: dropping unknown topic_id=%s", topic_id)
            dropped += 1
            continue
        if parent_id is None:
            candidates[topic_id] = None
            continue
        if parent_id == topic_id:
            logger.debug("Dep inference: dropping self-ref topic_id=%s", topic_id)
            dropped += 1
            continue
        if parent_id not in valid_ids:
            logger.debug(
                "Dep inference: dropping unknown parent_id=%s for topic=%s",
                parent_id,
                topic_id,
            )
            dropped += 1
            continue
        candidates[topic_id] = parent_id

    # Cycle detection. Walk each topic's parent chain; if we revisit any
    # node, the edge that closed the cycle is dropped. We process topics
    # in a stable order (sorted by id) so the same cycle drops the same
    # edge on every run — important for idempotency across worker retries.
    final: dict[str, str | None] = dict(candidates)
    for topic_id in sorted(candidates):
        parent = final.get(topic_id)
        if parent is None:
            continue
        seen = {topic_id}
        cursor = parent
        while cursor is not None:
            if cursor in seen:
                # Cycle. Drop the edge from `topic_id` to break it.
                logger.debug(
                    "Dep inference: dropping edge topic=%s parent=%s "
                    "(would close cycle through %s)",
                    topic_id,
                    parent,
                    cursor,
                )
                final[topic_id] = None
                dropped += 1
                break
            seen.add(cursor)
            cursor = final.get(cursor)

    return final, dropped


# ─────────────────────────────────────────────────────────────────────────────
# Sprint 2.11 — Admin CRUD + regenerate
# ─────────────────────────────────────────────────────────────────────────────


class TaxonomyValidationError(ValueError):
    """Admin's PUT payload failed shape validation.

    Raised by :func:`validate_taxonomy_shape`. API layer maps to HTTP 422.
    """


class TaxonomyVersionConflict(RuntimeError):
    """Admin's PUT lost the CAS race against another writer.

    Caller (API layer) maps to HTTP 409 so the UI can re-fetch and merge.
    """


def validate_taxonomy_shape(topics: list[CanonicalTopic]) -> None:
    """Reject taxonomies the admin shouldn't be allowed to save.

    Cheaper than letting Cosmos accept a broken graph that then poisons
    every downstream Sprint 3 retrieval. Four checks:

    1. Every topic id is unique (no Cosmos confusion on $set).
    2. parent_id, if set, points to a topic in the same payload (no
       dangling refs that would orphan-render in the Flutter tree view).
    3. No cycles. DFS up the parent chain from each node; revisit = cycle.
       Catches both 2-node and N-node cycles.
    4. Names are case-insensitively unique. Two topics named "Photosynthesis"
       and "photosynthesis" would both be valid distinct rows in Cosmos
       but the alias map in 2.9 would collapse them, so we block at write.

    Empty taxonomy (zero topics) is legal — used by ``POST /regenerate``
    as the first step before replay.
    """
    if not topics:
        return

    # 1. Unique ids
    ids = [t.id for t in topics]
    if len(ids) != len(set(ids)):
        seen: set[str] = set()
        for tid in ids:
            if tid in seen:
                raise TaxonomyValidationError(f"Duplicate topic id: {tid}")
            seen.add(tid)

    # 2. parent_id refs exist
    id_set = set(ids)
    for t in topics:
        if t.parent_id is not None and t.parent_id not in id_set:
            raise TaxonomyValidationError(
                f"Topic {t.id} references unknown parent_id {t.parent_id}"
            )
        if t.parent_id == t.id:
            raise TaxonomyValidationError(
                f"Topic {t.id} cannot be its own parent"
            )

    # 3. No cycles. Walk up from each node.
    parent_map = {t.id: t.parent_id for t in topics}
    for start in topics:
        visited = {start.id}
        cursor = parent_map.get(start.id)
        while cursor is not None:
            if cursor in visited:
                raise TaxonomyValidationError(
                    f"Cycle detected starting at {start.id} (through {cursor})"
                )
            visited.add(cursor)
            cursor = parent_map.get(cursor)

    # 4. Case-insensitive name uniqueness
    name_lookup: dict[str, str] = {}
    for t in topics:
        if not t.name.strip():
            raise TaxonomyValidationError(f"Topic {t.id} has empty name")
        key = t.name.casefold()
        if key in name_lookup:
            raise TaxonomyValidationError(
                f"Duplicate topic name {t.name!r} on {t.id} and {name_lookup[key]}"
            )
        name_lookup[key] = t.id


async def replace_taxonomy(
    *,
    tenant_id: str,
    workspace_id: str,
    expected_version: int,
    topics: list[CanonicalTopic],
) -> Workspace:
    """Admin-driven full replacement of a workspace's taxonomy.

    Validates the payload, runs the CAS write, returns the refreshed
    Workspace on success. Caller (API layer) is responsible for auth.

    Raises:
        TaxonomyValidationError: payload shape rejected.
        TaxonomyVersionConflict: another writer bumped the version
            between admin's GET and PUT.
        RuntimeError: workspace_id not found in tenant.
    """
    validate_taxonomy_shape(topics)

    workspace = await _read_workspace(tenant_id, workspace_id)
    if workspace is None:
        raise RuntimeError(
            f"Workspace {workspace_id} not found in tenant {tenant_id}"
        )

    new_taxonomy = Taxonomy(
        topics=topics,
        # Reuse the existing timestamp — admin's PUT isn't a merge, but
        # blanking it would lose audit info. Sprint 2.11 leaves this as
        # "last time the system updated the taxonomy."
        last_merged_at=workspace.taxonomy.last_merged_at,
    )

    wrote = await _conditional_write(
        tenant_id=tenant_id,
        workspace_id=workspace_id,
        expected_version=expected_version,
        new_taxonomy=new_taxonomy,
    )
    if not wrote:
        raise TaxonomyVersionConflict(
            f"taxonomy_version conflict on {workspace_id}: "
            f"client sent {expected_version}, server has different value"
        )
    # Re-read so the caller sees the bumped version + persisted state.
    refreshed = await _read_workspace(tenant_id, workspace_id)
    assert refreshed is not None, "workspace vanished mid-write"
    return refreshed


@dataclass(frozen=True, slots=True)
class RegenerateOutcome:
    """Telemetry from a regenerate run, surfaced via the API's 202 body."""

    documents_merged: int      # how many docs replayed through merge
    topics_total: int          # canonical topics after replay
    final_version: int         # taxonomy_version on disk after replay


async def regenerate_from_documents(
    *,
    tenant_id: str,
    workspace_id: str,
) -> RegenerateOutcome:
    """Rebuild a workspace's canonical taxonomy by replaying each document's
    persisted ``TopicTag`` list through the merge + dep-inference pipeline.

    Triggered by ``POST /workspaces/{id}/taxonomy/regenerate``. Use cases:
    - Admin manually edited the taxonomy badly and wants a clean rebuild.
    - The merge prompt was updated and existing taxonomies are stale.
    - A workspace's docs were re-uploaded out of order and aliases drifted.

    Reuses per-doc ``TopicTag`` lists (already populated by 2.5). Does
    NOT re-run topic extraction — that would re-pay for GPT-4o and 2.5's
    output is the ground truth per document. Only the cross-doc merge +
    dep inference happen here.

    Replay order is by ``created_at`` ascending so the same set of
    documents always produces the same canonical taxonomy on rebuild —
    important for idempotency under retry.

    Note: This is a long-running operation (one GPT-4o merge per
    document + one dep inference at the end). API layer schedules it as
    a BackgroundTask and returns 202; this function logs progress so an
    operator can tail the worker logs to watch it run.
    """
    workspace = await _read_workspace(tenant_id, workspace_id)
    if workspace is None:
        raise RuntimeError(
            f"Workspace {workspace_id} not found in tenant {tenant_id}"
        )

    # Wipe the existing taxonomy under CAS so no concurrent merge can
    # interleave with the replay. Retry once on conflict — concurrent
    # extraction workers should be rare relative to admin actions.
    reset_attempts = 0
    while True:
        wrote = await _conditional_write(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            expected_version=workspace.taxonomy_version,
            new_taxonomy=Taxonomy(),
        )
        if wrote:
            break
        reset_attempts += 1
        if reset_attempts >= _MAX_MERGE_RETRIES:
            raise RuntimeError(
                f"regenerate could not reset taxonomy for {workspace_id} "
                f"after {_MAX_MERGE_RETRIES} attempts"
            )
        workspace = await _read_workspace(tenant_id, workspace_id)
        if workspace is None:
            raise RuntimeError(
                f"Workspace {workspace_id} vanished during regenerate"
            )

    logger.info(
        "Regenerate: reset taxonomy on workspace=%s (was version=%d)",
        workspace_id,
        workspace.taxonomy_version,
    )

    # Pull docs that have made it to at least topics_extracted — they have
    # the topic_tags we need to replay. Sort by upload order for
    # deterministic alias resolution.
    docs = await _docs_with_topics(tenant_id=tenant_id, workspace_id=workspace_id)
    logger.info(
        "Regenerate: replaying %d documents for workspace=%s",
        len(docs),
        workspace_id,
    )

    merged_count = 0
    for doc in docs:
        if not doc.topic_tags:
            continue
        try:
            await merge_into_workspace(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=doc.id,
                new_topics=doc.topic_tags,
            )
            merged_count += 1
        except TaxonomyMergeError:
            # A bad merge prompt response for one doc shouldn't kill the
            # whole regen. Log and continue — the operator will see the
            # error and can manually edit the taxonomy after.
            logger.exception(
                "Regenerate: merge failed for doc=%s, continuing",
                doc.id,
            )

    # Final dep inference. Best-effort, same as the worker path — a deps
    # failure leaves a parent-less but otherwise valid taxonomy.
    try:
        await infer_dependencies(
            tenant_id=tenant_id, workspace_id=workspace_id
        )
    except DependencyInferenceError:
        logger.exception(
            "Regenerate: dep inference failed for workspace=%s, "
            "taxonomy persists without parent edges",
            workspace_id,
        )

    final = await _read_workspace(tenant_id, workspace_id)
    assert final is not None, "workspace vanished mid-regenerate"
    return RegenerateOutcome(
        documents_merged=merged_count,
        topics_total=len(final.taxonomy.topics),
        final_version=final.taxonomy_version,
    )


async def _docs_with_topics(
    *,
    tenant_id: str,
    workspace_id: str,
) -> list[Document]:
    """Return non-deleted docs that have ``topic_tags`` populated.

    Filter is intentionally loose on status: any doc past ``topics_extracted``
    has tags. Docs in ``failed`` may still have partial tags if extraction
    succeeded before downstream failure, and including them helps admins
    rebuild over flaky historical data.
    """
    col = get_collection(tenant_id, DOCUMENTS)
    cursor = col.find(
        {
            "workspace_id": workspace_id,
            "tenant_id": tenant_id,
            "deleted_at": None,
            "topic_tags.0": {"$exists": True},
        }
    ).sort("created_at", 1)
    rows = await cursor.to_list(length=None)
    return [Document.model_validate(r) for r in rows]
