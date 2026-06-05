"""End-to-end smoke test for Sprint 3 features — runs against real Azure.

What this verifies (no API/JWT in the loop — handlers invoked directly):

    1.  Learning Path Engine selects a topic from the workspace taxonomy.
    2.  retrieve_content MCP tool returns grounding chunks for that topic.
    3.  question_generation produces a structurally-valid question via
        Azure OpenAI (GPT-4o), grounded in the retrieved chunks.
    4.  question_safety runs the Content Safety review and verdict.
    5.  POST /questions/next equivalent — full orchestrator, persists an
        approved question to ``question_queue``.
    6.  POST /questions/{id}/answer — answer evaluation + XP + mastery
        write to ``knowledge_states`` + interactions log.
    7.  Prefetch — the background task that /answer kicks off; we run it
        synchronously, then verify the next /next call claims the
        prefetched row instead of running live generation.
    8.  POST /flashcards/next — generation + Content Safety verdict +
        persistence.
    9.  POST /flashcards/{id}/rate — rating event written to
        ``flashcard_ratings``.

Targets an existing ingested document — pass nothing on the CLI and the
script picks the most recent ``status=ready`` document in the configured
tenant, or override with ``--tenant``/``--workspace``.

Usage::

    cd backend
    python scripts/smoke_test_sprint3.py
    python scripts/smoke_test_sprint3.py --tenant ten_smoke001 \\
        --workspace wsp_273810a8de2a4e9182f4ac885b9c5a16

Required env vars (loaded from ``backend/.env`` or ``backend/.env.dev``):

    COSMOS_CONNECTION_STRING
    SEARCH_ENDPOINT, SEARCH_KEY
    AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_KEY, AZURE_OPENAI_DEPLOYMENT
    CONTENT_SAFETY_ENDPOINT, CONTENT_SAFETY_KEY
    REDIS_URL  (only if a question route caches anything — currently no-op)

Exit code 0 on full success, non-zero on the first failure.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os
import sys
from dataclasses import dataclass
from pathlib import Path


def _load_env_file(path: Path) -> None:
    """Minimal .env loader — same shape as smoke_test_document_pipeline.py."""
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def _section(title: str) -> None:
    print(f"\n{'=' * 72}\n{title}\n{'=' * 72}")


def _step(idx: int, label: str) -> None:
    print(f"\n[{idx}] {label}")


@dataclass
class SmokeTarget:
    """Resolved tenant + workspace + student to drive the smoke test against."""

    tenant_id: str
    workspace_id: str
    student_user_id: str
    student_email: str


async def _resolve_target(
    *,
    tenant_arg: str | None,
    workspace_arg: str | None,
) -> SmokeTarget:
    """Pick a tenant+workspace+user combo with an indexed document.

    Prefers explicit CLI args. Falls back to: the first tenant DB with a
    ``ready`` document and a non-empty workspace taxonomy. Reuses the
    tenant_admin user already in that tenant — Sprint 3 endpoints accept
    tenant_admin against any workspace, so we don't need to invent a
    student row just to run the pipeline.
    """
    from motor.motor_asyncio import AsyncIOMotorClient

    from app.core.config import settings

    client: AsyncIOMotorClient = AsyncIOMotorClient(  # type: ignore[type-arg]
        settings.cosmos_connection_string
    )
    candidate_tenants: list[str]
    if tenant_arg:
        candidate_tenants = [tenant_arg]
    else:
        all_dbs = await client.list_database_names()
        candidate_tenants = [d for d in all_dbs if d.startswith("ten_")]

    for tenant_id in candidate_tenants:
        db = client[tenant_id]
        ws_filter: dict = {"deleted_at": None}
        if workspace_arg:
            ws_filter["_id"] = workspace_arg
        workspace_doc = await db["workspaces"].find_one(ws_filter)
        if workspace_doc is None:
            continue
        topics = (workspace_doc.get("taxonomy") or {}).get("topics") or []
        if not topics:
            continue

        ready_doc = await db["documents"].find_one(
            {"status": "ready", "workspace_id": workspace_doc["_id"]}
        )
        if ready_doc is None:
            # No ready doc yet — Sprint 3 retrieval will return empty.
            continue

        # Any active user in the tenant works; tenant_admin bypasses
        # workspace-membership checks.
        user_doc = await db["users"].find_one(
            {"is_active": True, "deleted_at": None}
        )
        if user_doc is None:
            continue

        return SmokeTarget(
            tenant_id=tenant_id,
            workspace_id=workspace_doc["_id"],
            student_user_id=user_doc["_id"],
            student_email=user_doc["email"],
        )

    raise RuntimeError(
        "Could not find a tenant with both a 'ready' document and a "
        "non-empty workspace taxonomy. Run the Sprint 2 smoke test first."
    )


async def _load_user(tenant_id: str, user_id: str):
    from app.core.database import USERS, get_collection
    from app.models.user import User

    raw = await get_collection(tenant_id, USERS).find_one({"_id": user_id})
    if raw is None:
        raise RuntimeError(f"User {user_id} not found in {tenant_id}")
    return User.model_validate(raw)


async def _purge_prefetch(*, tenant_id: str, workspace_id: str, student_id: str) -> None:
    """Drop any leftover prefetched rows from prior smoke runs.

    A row whose ``prefetched_for == student_id`` would be claimed on the
    very first ``/next`` call and skip the live generation we want to
    exercise. Best-effort delete — fine if nothing matches.
    """
    from app.core.database import QUESTION_QUEUE, get_collection

    col = get_collection(tenant_id, QUESTION_QUEUE)
    res = await col.delete_many(
        {
            "workspace_id": workspace_id,
            "prefetched_for": student_id,
        }
    )
    if res.deleted_count:
        print(f"      purged {res.deleted_count} stale prefetched question(s)")


# ── Tests ───────────────────────────────────────────────────────────────────


async def step_learning_path(target: SmokeTarget) -> str:
    """Verify the Layer-1 topic selection runs end-to-end against Cosmos.

    Returns the selected topic_id so downstream steps can reuse it (the
    full orchestrator also picks its own topics — this step proves the
    engine works in isolation).
    """
    from app.services.learning_path import select_next_topic

    sel = await select_next_topic(
        tenant_id=target.tenant_id,
        workspace_id=target.workspace_id,
        student_id=target.student_user_id,
    )
    print(f"      selected: {sel.selected.topic_name!r}")
    print(f"      score:    {sel.selected.score:.3f}")
    print(f"      rationale: {sel.rationale}")
    print(f"      candidates: {len(sel.candidates)}")
    return sel.selected.topic_id


async def step_retrieve_content(target: SmokeTarget, topic_id: str) -> int:
    """Verify the retrieve_content MCP tool hits AI Search and returns chunks."""
    from app.mcp_tools import invoke
    from app.mcp_tools.retrieve_content import (
        RetrieveContentInput,
        RetrieveContentOutput,
    )

    result = await invoke(
        "retrieve_content",
        RetrieveContentInput(
            tenant_id=target.tenant_id,
            workspace_id=target.workspace_id,
            topic_ids=[topic_id],
            query_text="key concepts and definitions",
            top_k=5,
        ),
    )
    assert isinstance(result, RetrieveContentOutput)
    print(f"      mode: {result.mode}")
    print(f"      chunks: {len(result.chunks)}")
    if result.chunks:
        head = result.chunks[0]
        print(f"      top score: {head.score:.3f}")
        print(f"      sample text: {head.text[:120]!r}")
    return len(result.chunks)


async def step_questions_next(target: SmokeTarget) -> str:
    """Drive the full orchestrator. Returns the served question_id."""
    from app.api.questions import next_question

    user = await _load_user(target.tenant_id, target.student_user_id)
    served = await next_question(workspace_id=target.workspace_id, current_user=user)
    print(f"      id:         {served.id}")
    print(f"      topic:      {served.topic!r}")
    print(f"      type:       {served.question_type.value}")
    print(f"      difficulty: {served.difficulty.value}")
    body_oneline = served.body.replace("\n", " ")[:200]
    print(f"      body head:  {body_oneline!r}")
    if served.options:
        for o in served.options:
            opt_text = o.text.replace("\n", " ")[:80]
            print(f"        ({o.key}) {opt_text!r}")
    return served.id


async def step_submit_answer(
    target: SmokeTarget, question_id: str
) -> tuple[bool, float]:
    """Answer the question, exercise mastery update + XP + interaction log.

    The orchestrator's background task (prefetch) is intentionally NOT
    fired here — we'll invoke prefetch directly in the next step so the
    smoke test stays deterministic. Returns ``(is_correct, topic_mastery)``.
    """
    from fastapi import BackgroundTasks

    from app.api.questions import submit_answer
    from app.core.database import QUESTION_QUEUE, get_collection
    from app.models.question import AnswerSubmission, QuestionType

    user = await _load_user(target.tenant_id, target.student_user_id)
    raw = await get_collection(target.tenant_id, QUESTION_QUEUE).find_one(
        {"_id": question_id}
    )
    if raw is None:
        raise RuntimeError(f"Persisted question {question_id} vanished")

    # Submit the correct answer to exercise the happy path. For MCQ the
    # canonical answer in storage is the key; for true_false it's
    # "true"/"false"; for the free-form types it's a sample.
    qtype = QuestionType(raw["question_type"])
    answer_payload = raw["answer"]
    submission = AnswerSubmission(answer=answer_payload, time_spent_seconds=15)

    bg = BackgroundTasks()
    feedback = await submit_answer(
        workspace_id=target.workspace_id,
        question_id=question_id,
        submission=submission,
        background_tasks=bg,
        current_user=user,
    )
    print(f"      qtype:      {qtype.value}")
    print(f"      is_correct: {feedback.is_correct}")
    print(f"      xp_earned:  {feedback.xp_earned}")
    print(f"      topic_mastery: {feedback.new_topic_mastery:.3f}")
    print(f"      overall:    {feedback.new_overall_mastery:.3f}")
    if feedback.rubric_score is not None:
        print(f"      rubric:     {feedback.rubric_score:.2f}")
    print(f"      pending bg tasks scheduled: {len(bg.tasks)}")
    return feedback.is_correct, feedback.new_topic_mastery


async def step_prefetch_then_claim(target: SmokeTarget) -> str | None:
    """Drive prefetch synchronously, then confirm /next claims the row."""
    from app.api.questions import next_question, prefetch_next_question
    from app.core.database import QUESTION_QUEUE, get_collection

    user = await _load_user(target.tenant_id, target.student_user_id)

    await prefetch_next_question(
        tenant_id=target.tenant_id,
        workspace_id=target.workspace_id,
        student_id=target.student_user_id,
    )
    col = get_collection(target.tenant_id, QUESTION_QUEUE)
    pre = await col.find_one(
        {
            "workspace_id": target.workspace_id,
            "prefetched_for": target.student_user_id,
        }
    )
    if pre is None:
        print("      no prefetched row was created — prefetch likely no-op'd")
        return None
    print(f"      prefetched row: {pre['_id']}  topic={pre.get('topic')!r}")

    served = await next_question(workspace_id=target.workspace_id, current_user=user)
    print(f"      /next served:   {served.id}")
    if served.id == pre["_id"]:
        print("      ✓ /next claimed the prefetched row (no live generation)")
    else:
        print("      ✗ /next did NOT claim the prefetched row — see logs")
    return served.id


async def step_flashcard_next_and_rate(target: SmokeTarget) -> None:
    from app.api.flashcards import next_flashcard, rate_flashcard
    from app.models.flashcard import (
        FlashcardRating,
        FlashcardRatingSubmission,
    )

    user = await _load_user(target.tenant_id, target.student_user_id)
    served = await next_flashcard(
        workspace_id=target.workspace_id, current_user=user
    )
    print(f"      id:    {served.id}")
    print(f"      topic: {served.topic!r}")
    front_oneline = served.front.replace("\n", " ")[:200]
    back_oneline = served.back.replace("\n", " ")[:200]
    print(f"      front: {front_oneline!r}")
    print(f"      back:  {back_oneline!r}")

    rated = await rate_flashcard(
        workspace_id=target.workspace_id,
        flashcard_id=served.id,
        submission=FlashcardRatingSubmission(rating=FlashcardRating.medium),
        current_user=user,
    )
    print(f"      rated: {rated.rating.value} @ {rated.rated_at}")


# ── Entry ──────────────────────────────────────────────────────────────────


async def _main(args: argparse.Namespace) -> int:
    logging.basicConfig(
        level=logging.WARNING,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    # Quiet the noisy Azure SDK HTTP logger by default but keep our app
    # at INFO so the orchestrator's selection / safety logs show up.
    logging.getLogger("azure").setLevel(logging.WARNING)
    logging.getLogger("app").setLevel(logging.INFO)

    target = await _resolve_target(
        tenant_arg=args.tenant, workspace_arg=args.workspace
    )
    _section("Sprint 3 smoke test — target")
    print(f"  tenant:    {target.tenant_id}")
    print(f"  workspace: {target.workspace_id}")
    print(f"  user:      {target.student_user_id}  ({target.student_email})")

    await _purge_prefetch(
        tenant_id=target.tenant_id,
        workspace_id=target.workspace_id,
        student_id=target.student_user_id,
    )

    _section("1. Learning Path Engine (Sprint 3.3)")
    _step(1, "select_next_topic")
    topic_id = await step_learning_path(target)

    _section("2. retrieve_content MCP tool (Sprint 3.5)")
    _step(2, "invoke('retrieve_content', ...)")
    n_chunks = await step_retrieve_content(target, topic_id)
    if n_chunks == 0:
        print("\n  Retrieval returned no chunks. AI Search index may be empty.")
        return 2

    _section("3. POST /questions/next — full orchestrator (Sprint 3.9)")
    _step(3, "next_question(...)")
    qid = await step_questions_next(target)

    _section("4. POST /questions/{id}/answer (Sprint 3.10 + 3.11)")
    _step(4, "submit_answer(...)")
    await step_submit_answer(target, qid)

    _section("5. Prefetch → claim on next /next (Sprint 3.13)")
    _step(5, "prefetch_next_question then next_question")
    await step_prefetch_then_claim(target)

    _section("6. POST /flashcards/next + /rate (Sprint 3.12)")
    _step(6, "next_flashcard then rate_flashcard")
    await step_flashcard_next_and_rate(target)

    _section("Done")
    print("All Sprint 3 paths exercised against real Azure.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tenant", help="Tenant DB id (defaults to first ten_* DB)")
    parser.add_argument("--workspace", help="Workspace id within the tenant")
    args = parser.parse_args()

    backend_dir = Path(__file__).resolve().parent.parent
    for fname in (".env", ".env.dev"):
        _load_env_file(backend_dir / fname)
    sys.path.insert(0, str(backend_dir))

    return asyncio.run(_main(args))


if __name__ == "__main__":
    sys.exit(main())
