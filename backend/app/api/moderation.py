"""Admin moderation dashboard — Sprint 6 (plan §5.8).

Backs the Flutter admin moderation screen (queue + audit log + resolve).
The Flutter contract lives in
``flutter_app/lib/features/admin/moderation/data/real_moderation_repository.dart``
and the ``FlaggedItem`` wire model in
``flutter_app/lib/shared/models/moderation.dart``:

- ``GET    /workspaces/{ws}/moderation/flagged``        — pending queue
- ``GET    /workspaces/{ws}/moderation/log``            — audit log (decisions)
- ``PUT    /workspaces/{ws}/moderation/{item_id}/resolve`` {approved} — decide

Source of truth is the per-tenant ``moderation_log`` collection, written by
the ingestion worker (``app/workers/document_ingestion.py``): every document
gets a ``flagged`` (needs review) or ``auto_approved`` (clean) entry. We
project those records into the dashboard's ``FlaggedItem`` shape.

Resolving a *document*:
- approve → clear the flag, set status back to ``text_extracted`` and
  re-enqueue it to the topic-extraction worker so the rest of the pipeline
  (topics → chunks → vectors) actually runs. Without this, "approve" would be
  a no-op and the document would stay parked forever.
- reject → soft-delete the document (disallowed content shouldn't linger).

Either way the ``moderation_log`` entry transitions ``flagged`` →
``approved``/``rejected`` with ``performed_by`` set to the admin, so the audit
log reflects who decided what.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.auth import get_current_user
from app.core.database import DOCUMENTS, FLASHCARDS, MODERATION_LOG, QUESTION_QUEUE, get_collection
from app.core.exceptions import ForbiddenError, NotFoundError
from app.models.base import utc_now
from app.models.document import DocumentStatus
from app.models.moderation import ModerationAction, ModerationLog, ModerationTarget
from app.models.user import User, UserRole

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/workspaces/{workspace_id}/moderation", tags=["moderation"])


# ── Wire model ────────────────────────────────────────────────────────────────


class ResolveRequest(BaseModel):
    approved: bool


class FlaggedItemResponse(BaseModel):
    """Matches the Flutter ``FlaggedItem`` (snake_case JSON keys)."""

    id: str
    content_kind: str  # "document" | "question" | "flashcard"
    topic: str
    excerpt: str
    reason: str
    severity: int  # raw Azure severity 0–6
    flagged_at: str
    verdict: str  # "pending" | "approved" | "rejected"


# ── Helpers ───────────────────────────────────────────────────────────────────


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    """Tenant admin sees any workspace; workspace admin only their own."""
    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")


def _assert_admin(user: User, workspace_id: str) -> None:
    """Raise ForbiddenError if the user is not an admin of this workspace."""
    if user.role == UserRole.tenant_admin:
        return
    admin_memberships = {
        m.workspace_id
        for m in user.workspace_memberships
        if m.role in (UserRole.workspace_admin, UserRole.tenant_admin)
    }
    if workspace_id not in admin_memberships:
        raise ForbiddenError("You do not have admin access to this workspace")


_VERDICT_FOR_ACTION: dict[ModerationAction, str] = {
    ModerationAction.flagged: "pending",
    ModerationAction.approved: "approved",
    ModerationAction.auto_approved: "approved",
    ModerationAction.rejected: "rejected",
}


def _severity(entry: ModerationLog) -> int:
    """Highest raw category severity (0–6); 0 for non-content-safety entries."""
    return max(entry.severities.values(), default=0)


async def _project(
    entry: ModerationLog,
    *,
    tenant_id: str,
    doc_cache: dict[str, dict | None],
) -> FlaggedItemResponse:
    """Render one moderation_log entry as a dashboard FlaggedItem.

    ``doc_cache`` memoizes document lookups so a list of N entries pointing at
    the same document only hits Cosmos once.
    """
    topic = entry.target_type.value.capitalize()
    excerpt = entry.reason or "Flagged content"

    if entry.target_type == ModerationTarget.document:
        if entry.target_id not in doc_cache:
            doc_cache[entry.target_id] = await get_collection(tenant_id, DOCUMENTS).find_one(
                {"_id": entry.target_id}
            )
        doc = doc_cache[entry.target_id]
        if doc is not None:
            topic = doc.get("filename", topic)
            pages = doc.get("page_count")
            page_str = f"{pages} page(s)" if pages else "document"
            if entry.flagged_categories:
                detail = f"flagged for {', '.join(entry.flagged_categories)} during ingestion"
            else:
                detail = "passed content safety during ingestion"
            excerpt = f"{doc.get('filename', topic)} — {page_str}; {detail}"
    elif entry.target_type == ModerationTarget.question:
        qst = await get_collection(tenant_id, QUESTION_QUEUE).find_one({"_id": entry.target_id})
        if qst is not None:
            topic = qst.get("topic", topic)
            excerpt = qst.get("body", excerpt)
    elif entry.target_type == ModerationTarget.flashcard:
        fc = await get_collection(tenant_id, FLASHCARDS).find_one({"_id": entry.target_id})
        if fc is not None:
            topic = fc.get("topic", topic)
            excerpt = fc.get("front", excerpt)

    return FlaggedItemResponse(
        id=entry.id,
        content_kind=entry.target_type.value,
        topic=topic,
        excerpt=excerpt,
        reason=entry.reason or ", ".join(entry.flagged_categories) or "Flagged",
        severity=_severity(entry),
        flagged_at=entry.created_at,
        verdict=_VERDICT_FOR_ACTION.get(entry.action, "pending"),
    )


async def _list_by_actions(
    *, tenant_id: str, workspace_id: str, actions: list[ModerationAction]
) -> list[FlaggedItemResponse]:
    col = get_collection(tenant_id, MODERATION_LOG)
    cursor = col.find(
        {
            "workspace_id": workspace_id,
            "tenant_id": tenant_id,
            "action": {"$in": [a.value for a in actions]},
        }
    )
    entries = [ModerationLog.model_validate(d) async for d in cursor]
    # Cosmos rejects ORDER BY on un-indexed paths (created_at is excluded from
    # the default indexing policy), so sort in-process. Newest first.
    entries.sort(key=lambda e: e.created_at, reverse=True)
    doc_cache: dict[str, dict | None] = {}
    return [await _project(e, tenant_id=tenant_id, doc_cache=doc_cache) for e in entries]


# ── Routes ────────────────────────────────────────────────────────────────────


@router.get("/flagged", response_model=list[FlaggedItemResponse])
async def list_flagged(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> list[FlaggedItemResponse]:
    """The review queue — content awaiting an admin decision."""
    _assert_admin(current_user, workspace_id)
    return await _list_by_actions(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        actions=[ModerationAction.flagged],
    )


@router.get("/log", response_model=list[FlaggedItemResponse])
async def list_log(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> list[FlaggedItemResponse]:
    """The audit log — everything content safety has already decided.

    Includes ``auto_approved`` (clean content that passed automatically) so the
    admin can see the full trail, not just human overrides.
    """
    _assert_admin(current_user, workspace_id)
    return await _list_by_actions(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        actions=[
            ModerationAction.approved,
            ModerationAction.rejected,
            ModerationAction.auto_approved,
        ],
    )


@router.put("/{item_id}/resolve", response_model=FlaggedItemResponse)
async def resolve(
    workspace_id: str,
    item_id: str,
    body: ResolveRequest,
    current_user: User = Depends(get_current_user),
) -> FlaggedItemResponse:
    """Approve or reject a flagged item.

    404 if the item doesn't exist or was already resolved (matches the
    Flutter ``FlaggedItemNotFoundException`` contract).
    """
    _assert_admin(current_user, workspace_id)
    tenant_id = current_user.tenant_id

    mod_col = get_collection(tenant_id, MODERATION_LOG)
    raw = await mod_col.find_one(
        {"_id": item_id, "workspace_id": workspace_id, "tenant_id": tenant_id}
    )
    if raw is None:
        raise NotFoundError("Flagged item", item_id)
    entry = ModerationLog.model_validate(raw)
    if entry.action != ModerationAction.flagged:
        # Already resolved (or was auto-approved) — nothing pending to decide.
        raise NotFoundError("Flagged item", item_id)

    new_action = ModerationAction.approved if body.approved else ModerationAction.rejected

    # Act on the underlying target before recording the decision, so a failure
    # to (re)enqueue doesn't leave the log saying "approved" while the document
    # stays parked.
    if entry.target_type == ModerationTarget.document:
        await _apply_document_decision(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            document_id=entry.target_id,
            approved=body.approved,
        )
    elif entry.target_type == ModerationTarget.question:
        await _apply_question_decision(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            question_id=entry.target_id,
            approved=body.approved,
        )
    elif entry.target_type == ModerationTarget.flashcard:
        await _apply_flashcard_decision(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            flashcard_id=entry.target_id,
            approved=body.approved,
        )

    await mod_col.update_one(
        {"_id": item_id},
        {
            "$set": {
                "action": new_action.value,
                "performed_by": current_user.id,
                "updated_at": utc_now(),
            }
        },
    )
    entry.action = new_action
    entry.performed_by = current_user.id

    logger.info(
        "Moderation %s by user=%s workspace=%s item=%s target=%s",
        new_action.value,
        current_user.id,
        workspace_id,
        item_id,
        entry.target_id,
    )
    doc_cache: dict[str, dict | None] = {}
    return await _project(entry, tenant_id=tenant_id, doc_cache=doc_cache)


async def _apply_document_decision(
    *, tenant_id: str, workspace_id: str, document_id: str, approved: bool
) -> None:
    """Approve → clear flag + resume ingestion; reject → soft-delete."""
    doc_col = get_collection(tenant_id, DOCUMENTS)
    doc = await doc_col.find_one(
        {"_id": document_id, "workspace_id": workspace_id, "deleted_at": None}
    )
    if doc is None:
        raise NotFoundError("Document", document_id)

    if not approved:
        await doc_col.update_one(
            {"_id": document_id},
            {"$set": {"deleted_at": utc_now(), "updated_at": utc_now()}},
        )
        # Update workspace document count
        from app.core.database import WORKSPACES

        wsp_col = get_collection(tenant_id, WORKSPACES)
        await wsp_col.update_one({"_id": workspace_id}, {"$inc": {"document_count": -1}})
        return

    # Approved: clear the flag, rewind to text_extracted, and re-enqueue the
    # topic-extraction handoff so the rest of the pipeline runs. The extracted
    # text was persisted to blob before flagging, so we can resume from there.
    await doc_col.update_one(
        {"_id": document_id},
        {
            "$set": {
                "status": DocumentStatus.text_extracted.value,
                "moderation_flagged": False,
                "processing_error": None,
                "updated_at": utc_now(),
            }
        },
    )

    blob_path = doc.get("extracted_text_blob_path")
    if not blob_path:
        logger.warning(
            "Approved doc=%s has no extracted_text_blob_path — cannot resume "
            "ingestion automatically; admin should re-upload.",
            document_id,
        )
        return

    # Import lazily so the API doesn't pull in Service Bus at module load (and
    # tests can patch it without a live connection).
    from app.services.topic_queue import TopicExtractionMessage, publish_topic_message

    try:
        await publish_topic_message(
            TopicExtractionMessage(
                document_id=document_id,
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                extracted_text_blob_path=blob_path,
            )
        )
    except Exception:
        logger.exception(
            "Approved doc=%s but failed to re-enqueue topic extraction — "
            "it will stay at text_extracted until re-triggered.",
            document_id,
        )


async def _apply_question_decision(
    *, tenant_id: str, workspace_id: str, question_id: str, approved: bool
) -> None:
    qst_col = get_collection(tenant_id, QUESTION_QUEUE)
    qst = await qst_col.find_one({"_id": question_id, "workspace_id": workspace_id})
    if qst is None:
        raise NotFoundError("Question", question_id)

    status = "approved" if approved else "rejected"
    await qst_col.update_one(
        {"_id": question_id},
        {
            "$set": {
                "status": status,
                "moderation_flagged": False,
                "updated_at": utc_now(),
            }
        },
    )


async def _apply_flashcard_decision(
    *, tenant_id: str, workspace_id: str, flashcard_id: str, approved: bool
) -> None:
    fc_col = get_collection(tenant_id, FLASHCARDS)
    fc = await fc_col.find_one({"_id": flashcard_id, "workspace_id": workspace_id})
    if fc is None:
        raise NotFoundError("Flashcard", flashcard_id)

    status = "approved" if approved else "rejected"
    await fc_col.update_one(
        {"_id": flashcard_id},
        {
            "$set": {
                "status": status,
                "moderation_flagged": False,
                "updated_at": utc_now(),
            }
        },
    )
