"""Flashcard endpoints — Sprint 3.12.

Two endpoints:

- ``POST /workspaces/{ws}/flashcards/next``: generate + persist + serve
  the next flashcard for the calling student.
- ``POST /workspaces/{ws}/flashcards/{fc_id}/rate``: record a student's
  self-rating (easy / medium / hard).

Smaller surface than the question pipeline — flashcards skip:
- Difficulty calibration (the student self-rates, no system grading)
- Answer evaluation (no canonical "correct" answer)
- Knowledge state updates (Sprint 5/6 SRS reads rating events directly)

Same shape elsewhere:
- Learning Path Engine drives topic selection (3.3)
- retrieve_content provides grounding (3.5)
- Content Safety + structural checks gate output (3.8 pattern, inlined)
- 3-attempt retry across candidate topics, 503 with Retry-After on
  exhaustion (3.9 pattern)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends

from app.core.auth import get_current_user
from app.core.database import (
    FLASHCARD_RATINGS,
    FLASHCARDS,
    WORKSPACES,
    get_collection,
)
from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ServiceUnavailableError,
)
from app.mcp_tools import invoke
from app.mcp_tools.retrieve_content import (
    RetrieveContentInput,
    RetrieveContentOutput,
)
from app.models.base import utc_now
from app.models.flashcard import (
    Flashcard,
    FlashcardForStudent,
    FlashcardRatingBadgeUnlock,
    FlashcardRatingEvent,
    FlashcardRatingResponse,
    FlashcardRatingSubmission,
    FlashcardStatus,
)
from app.models.user import User
from app.models.workspace import Workspace
from app.services import content_safety, flashcard_generation
from app.services import gamification as gamification_service
from app.services import notifications as notification_service
from app.services.flashcard_generation import (
    FlashcardShapeError,
    GeneratedFlashcard,
    InsufficientFlashcardSource,
)
from app.services.learning_path import (
    NoTopicsAvailable,
    TopicScore,
    WorkspaceNotFound,
    select_next_topic,
)

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/workspaces/{workspace_id}/flashcards",
    tags=["flashcards"],
)


# Mirrors the question orchestrator's retry budget — same UX
# trade-off (~3-6s total wait vs. tolerating one bad GPT-4o roll).
_MAX_ATTEMPTS = 3
_GROUNDING_CHUNK_LIMIT = 5
# Sanity floor / ceiling for the structural check on generated cards.
_MIN_FRONT_CHARS = 3
_MAX_FRONT_CHARS = 300
_MIN_BACK_CHARS = 3
_MAX_BACK_CHARS = 500


# ── POST /flashcards/next ───────────────────────────────────────────────────


@router.post("/next", response_model=FlashcardForStudent)
async def next_flashcard(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> FlashcardForStudent:
    """Generate and return a flashcard for the calling student.

    Returns the FULL flashcard (front + back + explanation) — unlike
    /questions/next which withholds the answer. Flashcards are
    self-rated, so revealing the back is the whole point.

    Raises:
        404: Workspace not found (or caller has no access).
        409: Workspace has no canonical topics yet.
        503: All retry attempts produced unservable results.
    """
    _assert_workspace_access(current_user, workspace_id)
    workspace = await _read_workspace(current_user.tenant_id, workspace_id)
    _ = workspace  # not used directly today, but the read enforces existence

    try:
        selection = await select_next_topic(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            student_id=current_user.id,
        )
    except NoTopicsAvailable as exc:
        raise ConflictError(
            "This workspace has no topics yet. Ask an admin to upload "
            "study material before requesting flashcards."
        ) from exc
    except WorkspaceNotFound as exc:
        raise NotFoundError("Workspace", workspace_id) from exc

    candidates = selection.candidates[:_MAX_ATTEMPTS]
    attempt_log: list[str] = []

    for attempt_index, candidate in enumerate(candidates, start=1):
        outcome = await _try_candidate(
            current_user=current_user,
            workspace_id=workspace_id,
            candidate=candidate,
        )
        if isinstance(outcome, _Persisted):
            return outcome.for_student
        attempt_log.append(
            f"attempt={attempt_index} topic={candidate.topic_name!r} → "
            f"{outcome.reason}"
        )

    logger.warning(
        "next_flashcard exhausted attempts workspace=%s student=%s log=%s",
        workspace_id,
        current_user.id,
        " | ".join(attempt_log),
    )
    raise ServiceUnavailableError(
        "Couldn't generate a clean flashcard right now after "
        f"{len(candidates)} attempts. Please retry in a moment.",
        headers={"Retry-After": "30"},
    )


# ── POST /flashcards/{flashcard_id}/rate ───────────────────────────────────


@router.post(
    "/{flashcard_id}/rate",
    response_model=FlashcardRatingResponse,
)
async def rate_flashcard(
    workspace_id: str,
    flashcard_id: str,
    submission: FlashcardRatingSubmission,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
) -> FlashcardRatingResponse:
    """Record a student's self-rating for a flashcard.

    Validates that the flashcard exists in this workspace and is in
    an approvable state. Persists the rating to the
    ``flashcard_ratings`` append-only collection. Returns the stored
    rating + timestamp.

    Raises:
        404: Flashcard not found in this workspace.
        409: Flashcard is in pending_review / rejected / flagged state.
        403: Caller is not a member of the workspace.
    """
    _assert_workspace_access(current_user, workspace_id)

    flashcard = await _load_flashcard(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        flashcard_id=flashcard_id,
    )
    if flashcard.status != FlashcardStatus.approved:
        raise ConflictError(
            f"Flashcard {flashcard_id} is not in an answerable state "
            f"(status={flashcard.status.value})."
        )

    timestamp = utc_now()
    event = FlashcardRatingEvent(
        **{"_id": f"rat_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        flashcard_id=flashcard_id,
        topic=flashcard.topic,
        rating=submission.rating,
        rated_at=timestamp,
    )
    col = get_collection(current_user.tenant_id, FLASHCARD_RATINGS)
    await col.insert_one(event.model_dump(by_alias=True))

    # Gamification: bump XP / streak / flashcards_reviewed and pick up
    # any badge unlocks. Mirrors the answer endpoint — rating event is
    # the source of truth (append-only), gamification is the summary.
    delta = await gamification_service.record_flashcard_rating(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        student_id=current_user.id,
        topic=flashcard.topic,
        rating=submission.rating,
        now=timestamp,
    )

    logger.info(
        "Flashcard rated flashcard=%s student=%s rating=%s "
        "xp=%d level=%d streak=%d badges=%d",
        flashcard_id,
        current_user.id,
        submission.rating.value,
        delta.xp_earned,
        delta.new_level,
        delta.streak_days,
        len(delta.badges_unlocked),
    )

    # Sprint 5.7c — same milestone push fan-out as the answer endpoint.
    if delta.leveled_up or delta.badges_unlocked:
        background_tasks.add_task(
            notification_service.dispatch_gamification_milestones,
            tenant_id=current_user.tenant_id,
            user_id=current_user.id,
            workspace_id=workspace_id,
            leveled_up=delta.leveled_up,
            new_level=delta.new_level,
            badges_unlocked=list(delta.badges_unlocked),
        )

    return FlashcardRatingResponse(
        flashcard_id=flashcard_id,
        rating=submission.rating,
        rated_at=timestamp,
        xp_earned=delta.xp_earned,
        new_level=delta.new_level,
        leveled_up=delta.leveled_up,
        streak_days=delta.streak_days,
        streak_extended=delta.streak_extended,
        badges_unlocked=[
            FlashcardRatingBadgeUnlock(
                badge_id=b.badge_id,
                name=b.name,
                description=b.description,
                icon=b.icon,
            )
            for b in delta.badges_unlocked
        ],
    )


# ── Inner per-candidate loop (Sprint 3.9 pattern) ──────────────────────────


@dataclass(frozen=True, slots=True)
class _Persisted:
    for_student: FlashcardForStudent


@dataclass(frozen=True, slots=True)
class _Skip:
    reason: str


async def _try_candidate(
    *,
    current_user: User,
    workspace_id: str,
    candidate: TopicScore,
) -> _Persisted | _Skip:
    retrieved = await invoke(
        "retrieve_content",
        RetrieveContentInput(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            topic_ids=[candidate.topic_id],
            query_text=candidate.topic_name,
            top_k=_GROUNDING_CHUNK_LIMIT,
        ),
    )
    assert isinstance(retrieved, RetrieveContentOutput)
    if not retrieved.chunks:
        return _Skip(f"no grounding chunks (mode={retrieved.mode})")

    try:
        generated = await flashcard_generation.generate_flashcard(
            topic=candidate.topic_name,
            grounding_chunks=retrieved.chunks,
            seen_card_fronts=None,  # Sprint 5/6 polish: query flashcard_ratings
        )
    except InsufficientFlashcardSource as exc:
        return _Skip(f"generator: insufficient_source ({exc})")
    except FlashcardShapeError as exc:
        return _Skip(f"generator: shape error ({exc})")

    verdict = await _review(generated)
    persisted = await _persist_flashcard(
        current_user=current_user,
        workspace_id=workspace_id,
        candidate=candidate,
        retrieved=retrieved,
        generated=generated,
        verdict=verdict,
    )

    if verdict.status == FlashcardStatus.approved:
        return _Persisted(for_student=FlashcardForStudent.from_doc(persisted))
    if verdict.status == FlashcardStatus.flagged:
        # Persisted for admin review; don't serve.
        return _Skip(f"safety flagged ({verdict.reason})")
    # Rejected — not persisted (see _persist_flashcard).
    return _Skip(f"review rejected: {verdict.reason}")


# ── Output safety (inline) ─────────────────────────────────────────────────


@dataclass(frozen=True, slots=True)
class _FlashcardVerdict:
    """Outcome of the safety + structural review."""

    status: FlashcardStatus
    reason: str


async def _review(generated: GeneratedFlashcard) -> _FlashcardVerdict:
    """Run Content Safety + slim structural checks on a generated card.

    Inlined rather than abstracted into a shared service today: the
    flashcard rules are short, the question safety reviewer's shape
    doesn't fit (different types, different leakage patterns), and
    Sprint 5 polish may add SRS-aware ranking that wants to live next
    to the rest of the flashcard logic anyway. Extract if a third
    consumer appears.
    """
    # Structural: cheap, fail-fast.
    structural = _structural_check(generated)
    if structural is not None:
        return _FlashcardVerdict(
            status=FlashcardStatus.rejected,
            reason=f"structural: {structural}",
        )

    # Content safety on the combined text.
    combined = "\n\n".join(
        s for s in (generated.front, generated.back, generated.explanation) if s
    )
    safety = await content_safety.analyze_extracted_text(combined)
    if safety.flagged:
        return _FlashcardVerdict(
            status=FlashcardStatus.flagged,
            reason=(
                "Content Safety flagged "
                f"{', '.join(safety.flagged_categories)} "
                f"(max severity {max(safety.severities.values())}/6)."
            ),
        )

    return _FlashcardVerdict(
        status=FlashcardStatus.approved,
        reason="Approved.",
    )


def _structural_check(generated: GeneratedFlashcard) -> str | None:
    """Return a failure reason or None when the card passes.

    The two checks worth doing:
    1. Length sanity — a runaway front (model hallucinated the second
       question on the same line) is unrecoverable.
    2. Front ≠ back — a flashcard whose front equals its back is
       useless and reflects a prompt-following failure.
    """
    front = generated.front
    back = generated.back
    if not (_MIN_FRONT_CHARS <= len(front) <= _MAX_FRONT_CHARS):
        return (
            f"front length {len(front)} outside "
            f"[{_MIN_FRONT_CHARS},{_MAX_FRONT_CHARS}]"
        )
    if not (_MIN_BACK_CHARS <= len(back) <= _MAX_BACK_CHARS):
        return (
            f"back length {len(back)} outside "
            f"[{_MIN_BACK_CHARS},{_MAX_BACK_CHARS}]"
        )
    if front.strip().casefold() == back.strip().casefold():
        return "front equals back (no recall value)"
    return None


# ── Persistence ─────────────────────────────────────────────────────────────


async def _persist_flashcard(
    *,
    current_user: User,
    workspace_id: str,
    candidate: TopicScore,
    retrieved: RetrieveContentOutput,
    generated: GeneratedFlashcard,
    verdict: _FlashcardVerdict,
) -> Flashcard:
    """Write the flashcard to Cosmos if the verdict allows.

    Rejected verdicts are NOT persisted — same policy as question
    rejection in Sprint 3.9. Flagged ones get stored with
    moderation_flagged=True for the admin moderation dashboard.
    """
    document_id = (
        retrieved.chunks[0].document_id if retrieved.chunks else "unknown"
    )
    flashcard = Flashcard(
        **{"_id": f"fc_{uuid4().hex}"},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        document_id=document_id,
        topic=candidate.topic_name,
        front=generated.front,
        back=generated.back,
        explanation=generated.explanation,
        source_chunk_ids=[c.chunk_id for c in retrieved.chunks],
        status=verdict.status,
        prompt_version=generated.prompt_version,
        moderation_flagged=verdict.status == FlashcardStatus.flagged,
    )

    if verdict.status == FlashcardStatus.rejected:
        logger.warning(
            "Discarding rejected flashcard topic=%s reason=%s",
            candidate.topic_name,
            verdict.reason,
        )
        return flashcard

    col = get_collection(current_user.tenant_id, FLASHCARDS)
    await col.insert_one(flashcard.model_dump(by_alias=True))
    return flashcard


# ── Cosmos reads ────────────────────────────────────────────────────────────


async def _read_workspace(tenant_id: str, workspace_id: str) -> Workspace:
    col = get_collection(tenant_id, WORKSPACES)
    raw = await col.find_one({"_id": workspace_id, "deleted_at": None})
    if raw is None:
        raise NotFoundError("Workspace", workspace_id)
    return Workspace.model_validate(raw)


async def _load_flashcard(
    *,
    tenant_id: str,
    workspace_id: str,
    flashcard_id: str,
) -> Flashcard:
    """Read flashcard, enforcing workspace scope at the DB filter layer.

    Same defence-in-depth as the question loader: the workspace_id
    filter prevents a student from workspace A rating a flashcard from
    workspace B even if the route's access check were buggy.
    """
    col = get_collection(tenant_id, FLASHCARDS)
    raw = await col.find_one(
        {
            "_id": flashcard_id,
            "workspace_id": workspace_id,
            "deleted_at": None,
        }
    )
    if raw is None:
        raise NotFoundError("Flashcard", flashcard_id)
    return Flashcard.model_validate(raw)


# ── Auth helper ─────────────────────────────────────────────────────────────


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    """Mirror :mod:`app.api.documents` and :mod:`app.api.questions`."""
    from app.models.user import UserRole

    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")
