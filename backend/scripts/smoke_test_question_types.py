"""Generate one question of EACH type from the indexed document — Sprint 3.7.

Walks the five prompt registry entries (mcq, short_answer, long_answer,
true_false, mathematical) and runs the full per-candidate pipeline for
each:

    select_next_topic  →  retrieve_content  →  generate_question  →
    question_safety.review_question

Bypasses the orchestrator's workspace ``settings.question_types`` gate
on purpose — the gate exists to constrain what STUDENTS get; the smoke
test exists to exercise every generator prompt against real grounding.

The selected topic comes from the Learning Path Engine on each iteration
so we exercise the full topic-selection signal too. Difficulty is
calibrated from current mastery on that topic (cold start = beginner).

Usage::

    cd backend
    python scripts/smoke_test_question_types.py
    python scripts/smoke_test_question_types.py --types mcq,mathematical
    python scripts/smoke_test_question_types.py \\
        --difficulty intermediate --tenant ten_smoke001

Exits 0 if every requested type produced an approved + structurally
valid question. Exits 1 on the first failure with the failing type
named.
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


def _hr() -> None:
    print("-" * 72)


@dataclass
class SmokeTarget:
    tenant_id: str
    workspace_id: str
    student_user_id: str


async def _resolve_target(
    *,
    tenant_arg: str | None,
    workspace_arg: str | None,
) -> SmokeTarget:
    """Same target-discovery rules as the full Sprint 3 smoke test."""
    from motor.motor_asyncio import AsyncIOMotorClient

    from app.core.config import settings

    client: AsyncIOMotorClient = AsyncIOMotorClient(  # type: ignore[type-arg]
        settings.cosmos_connection_string
    )
    candidates: list[str]
    if tenant_arg:
        candidates = [tenant_arg]
    else:
        candidates = [
            d for d in await client.list_database_names() if d.startswith("ten_")
        ]

    for tenant_id in candidates:
        db = client[tenant_id]
        ws_filter: dict = {"deleted_at": None}
        if workspace_arg:
            ws_filter["_id"] = workspace_arg
        ws = await db["workspaces"].find_one(ws_filter)
        if ws is None:
            continue
        topics = (ws.get("taxonomy") or {}).get("topics") or []
        if not topics:
            continue
        ready = await db["documents"].find_one(
            {"status": "ready", "workspace_id": ws["_id"]}
        )
        if ready is None:
            continue
        user = await db["users"].find_one(
            {"is_active": True, "deleted_at": None}
        )
        if user is None:
            continue
        return SmokeTarget(
            tenant_id=tenant_id,
            workspace_id=ws["_id"],
            student_user_id=user["_id"],
        )

    raise RuntimeError(
        "Could not find a tenant with both a 'ready' document and a "
        "non-empty workspace taxonomy."
    )


# ── Rendering ──────────────────────────────────────────────────────────────


def _print_question(
    *,
    qtype_value: str,
    topic: str,
    difficulty_value: str,
    generated,
    verdict_value: str,
    safety_summary: str,
) -> None:
    """Compact, type-aware rendering of one generated question."""
    print(f"  topic:       {topic!r}")
    print(f"  difficulty:  {difficulty_value}")
    print(f"  prompt:      {generated.prompt_version}")
    print(f"  verdict:     {verdict_value}  ({safety_summary})")
    body_oneline = generated.body.replace("\n", " ")
    print(f"  body:        {body_oneline}")
    if generated.options:
        for o in generated.options:
            marker = "*" if o.is_correct else " "
            text_oneline = o.text.replace("\n", " ")
            print(f"    {marker} ({o.key}) {text_oneline}")
    print(f"  answer:      {generated.answer!r}")
    if generated.grading_hints:
        print(f"  grading_hints ({len(generated.grading_hints)}):")
        for h in generated.grading_hints:
            h_oneline = h.replace("\n", " ")
            print(f"    - {h_oneline}")
    expl_oneline = generated.explanation.replace("\n", " ")
    if len(expl_oneline) > 280:
        expl_oneline = expl_oneline[:280] + "…"
    print(f"  explanation: {expl_oneline}")


# ── Driver ─────────────────────────────────────────────────────────────────


async def _generate_one(
    *,
    target: SmokeTarget,
    qtype_value: str,
    difficulty_override: str | None,
) -> bool:
    """Run learning-path → retrieve → generate → review for one type.

    Returns True on success (approved or flagged but generated cleanly),
    False if generation failed in a way that should fail the run.
    """
    from app.mcp_tools import invoke
    from app.mcp_tools.retrieve_content import (
        RetrieveContentInput,
        RetrieveContentOutput,
    )
    from app.models.question import DifficultyLevel, QuestionType
    from app.services import question_generation, question_safety
    from app.services.difficulty import calibrate_difficulty
    from app.services.learning_path import select_next_topic

    qtype = QuestionType(qtype_value)

    selection = await select_next_topic(
        tenant_id=target.tenant_id,
        workspace_id=target.workspace_id,
        student_id=target.student_user_id,
    )
    candidate = selection.candidates[0]

    if difficulty_override:
        difficulty = DifficultyLevel(difficulty_override)
    else:
        # Cold-start mastery = 0.0 (we're not deriving it here; the
        # learning_path call would, but for this script the calibrator
        # against 0.0 always yields ``beginner``, which is fine — the
        # point is to vary type, not difficulty).
        difficulty = calibrate_difficulty(mastery=0.0).difficulty

    retrieved = await invoke(
        "retrieve_content",
        RetrieveContentInput(
            tenant_id=target.tenant_id,
            workspace_id=target.workspace_id,
            topic_ids=[candidate.topic_id],
            query_text=candidate.topic_name,
            top_k=5,
        ),
    )
    assert isinstance(retrieved, RetrieveContentOutput)
    if not retrieved.chunks:
        print(f"  [skip] no grounding chunks for topic {candidate.topic_name!r}")
        return False

    try:
        generated = await question_generation.generate_question(
            topic=candidate.topic_name,
            difficulty=difficulty,
            question_type=qtype,
            grounding_chunks=retrieved.chunks,
            seen_question_bodies=None,
        )
    except question_generation.InsufficientSource as exc:
        print(f"  [skip] insufficient_source: {exc}")
        return False
    except question_generation.QuestionShapeError as exc:
        print(f"  [FAIL] shape error from generator: {exc}")
        return False

    review = await question_safety.review_question(generated)
    safety = review.safety
    safety_summary = (
        f"safety_flagged={safety.flagged} "
        f"max_severity={max(safety.severities.values()) if safety.severities else 0}"
    )
    _print_question(
        qtype_value=qtype.value,
        topic=candidate.topic_name,
        difficulty_value=difficulty.value,
        generated=generated,
        verdict_value=review.verdict.value,
        safety_summary=safety_summary,
    )

    # Approved = ship. Flagged = generated cleanly but blocked. Rejected
    # = generator output failed structural review — that's a real bug
    # we want to surface as a non-zero exit.
    from app.services.question_safety import ReviewVerdict

    if review.verdict == ReviewVerdict.rejected:
        print(f"  [FAIL] reviewer rejected: {review.reason}")
        return False
    return True


# ── Entry ──────────────────────────────────────────────────────────────────


async def _main(args: argparse.Namespace) -> int:
    logging.basicConfig(
        level=logging.WARNING,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    logging.getLogger("azure").setLevel(logging.WARNING)
    logging.getLogger("app").setLevel(logging.INFO)

    target = await _resolve_target(
        tenant_arg=args.tenant, workspace_arg=args.workspace
    )
    _section("Multi-type generation smoke test — target")
    print(f"  tenant:    {target.tenant_id}")
    print(f"  workspace: {target.workspace_id}")
    print(f"  user:      {target.student_user_id}")
    print(f"  types:     {','.join(args.types)}")
    if args.difficulty:
        print(f"  difficulty override: {args.difficulty}")

    failures: list[str] = []
    for qtype_value in args.types:
        _section(f"Generating: {qtype_value}")
        ok = await _generate_one(
            target=target,
            qtype_value=qtype_value,
            difficulty_override=args.difficulty,
        )
        if not ok:
            failures.append(qtype_value)
        _hr()

    _section("Summary")
    if failures:
        print(f"  {len(failures)} type(s) failed: {', '.join(failures)}")
        return 1
    print(f"  All {len(args.types)} type(s) produced valid questions.")
    return 0


_ALL_TYPES = ["mcq", "short_answer", "long_answer", "true_false", "mathematical"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tenant", help="Tenant DB id (defaults to first ten_* DB)")
    parser.add_argument("--workspace", help="Workspace id within the tenant")
    parser.add_argument(
        "--types",
        type=lambda s: [t.strip() for t in s.split(",") if t.strip()],
        default=_ALL_TYPES,
        help=(
            "Comma-separated subset of "
            f"{','.join(_ALL_TYPES)} (default: all five)"
        ),
    )
    parser.add_argument(
        "--difficulty",
        choices=["beginner", "intermediate", "advanced"],
        default=None,
        help="Force a difficulty; defaults to the calibrator's cold-start pick (beginner)",
    )
    args = parser.parse_args()

    backend_dir = Path(__file__).resolve().parent.parent
    for fname in (".env", ".env.dev"):
        _load_env_file(backend_dir / fname)
    sys.path.insert(0, str(backend_dir))

    return asyncio.run(_main(args))


if __name__ == "__main__":
    sys.exit(main())
