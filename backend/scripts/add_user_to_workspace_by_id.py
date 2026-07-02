"""
Add tarunjuneja471@gmail.com to 'Social Study workspace' by ID.

Run from the backend root:
    python scripts/add_user_to_workspace_by_id.py
"""
import asyncio
import logging

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

TARGET_EMAIL = "tarunjuneja471@gmail.com"
# The workspace shown as "Study Workspace / Classroom" in the app screenshot
TARGET_WORKSPACE_ID = "wsp_a7404cb7c9c448699fc328c242afb230"


async def main() -> None:
    from app.core.database import get_collection, USERS, WORKSPACES
    from app.core.config import settings
    from app.models.user import User, WorkspaceMembership, UserRole
    from app.models.base import utc_now

    tenant_id = settings.b2c_client_id or "ten_demo_001"

    # ── 1. Find the user ──────────────────────────────────────────────────────
    user_col = get_collection(tenant_id, USERS)
    doc = await user_col.find_one({"email": TARGET_EMAIL, "deleted_at": None})
    if doc is None:
        log.error("User %s not found.", TARGET_EMAIL)
        return
    user = User.model_validate(doc)
    log.info("Found user %s (id=%s)", TARGET_EMAIL, user.id)

    # ── 2. Fetch workspace ────────────────────────────────────────────────────
    wsp_col = get_collection(tenant_id, WORKSPACES)
    ws_doc = await wsp_col.find_one({"_id": TARGET_WORKSPACE_ID, "deleted_at": None})
    if ws_doc is None:
        log.error("Workspace %s not found.", TARGET_WORKSPACE_ID)
        return
    log.info("Found workspace '%s' (id=%s)", ws_doc.get("name"), TARGET_WORKSPACE_ID)

    # ── 3. Guard: already a member? ───────────────────────────────────────────
    already = any(m.workspace_id == TARGET_WORKSPACE_ID for m in user.workspace_memberships)
    if already:
        log.info("User is already a member. Nothing to do.")
        return

    # ── 4. Add user to workspace student_ids ─────────────────────────────────
    result = await wsp_col.update_one(
        {"_id": TARGET_WORKSPACE_ID},
        {"$addToSet": {"student_ids": user.id}},
    )
    log.info("Workspace update — matched=%d modified=%d", result.matched_count, result.modified_count)

    # ── 5. Append membership to user ─────────────────────────────────────────
    user.workspace_memberships.append(
        WorkspaceMembership(
            workspace_id=TARGET_WORKSPACE_ID,
            role=UserRole.student,
            joined_at=utc_now(),
        )
    )
    user.touch()
    replace = await user_col.replace_one({"_id": user.id}, user.model_dump(by_alias=True))
    log.info("User document updated — matched=%d modified=%d", replace.matched_count, replace.modified_count)

    # ── 6. Bust Redis cache ───────────────────────────────────────────────────
    try:
        from app.core.redis_client import get_redis
        redis = await get_redis()
        if user.b2c_object_id:
            cache_key = f"user:{tenant_id}:{user.b2c_object_id}"
            await redis.delete(cache_key)
            log.info("Redis cache busted: %s", cache_key)
    except Exception as exc:
        log.warning("Could not bust Redis cache: %s", exc)

    log.info("Done. %s added to workspace '%s' as student.", TARGET_EMAIL, ws_doc.get("name"))


if __name__ == "__main__":
    asyncio.run(main())
