"""
Add tarunjuneja471@gmail.com back to the 'Study Workspace' (Classroom type).

Run from the backend root:
    python scripts/add_user_to_study_workspace.py
"""
import asyncio
import logging

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

TARGET_EMAIL = "tarunjuneja471@gmail.com"
TARGET_WORKSPACE_NAME = "Study Workspace"


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

    # ── 2. Find the Study Workspace ───────────────────────────────────────────
    wsp_col = get_collection(tenant_id, WORKSPACES)
    ws_doc = await wsp_col.find_one({"name": TARGET_WORKSPACE_NAME, "deleted_at": None})
    if ws_doc is None:
        log.error("Workspace '%s' not found. Listing all workspaces:", TARGET_WORKSPACE_NAME)
        async for w in wsp_col.find({"deleted_at": None}, {"_id": 1, "name": 1}):
            log.info("  id=%s  name=%s", w["_id"], w.get("name"))
        return

    ws_id = ws_doc["_id"]
    log.info("Found workspace '%s' (id=%s)", TARGET_WORKSPACE_NAME, ws_id)

    # ── 3. Check if already a member ─────────────────────────────────────────
    already = any(m.workspace_id == ws_id for m in user.workspace_memberships)
    if already:
        log.info("User is already a member of '%s'. Nothing to do.", TARGET_WORKSPACE_NAME)
        return

    # ── 4. Add user to workspace student_ids ─────────────────────────────────
    result = await wsp_col.update_one(
        {"_id": ws_id},
        {"$addToSet": {"student_ids": user.id}},
    )
    log.info("Workspace update — matched=%d modified=%d", result.matched_count, result.modified_count)

    # ── 5. Add membership to user document ───────────────────────────────────
    user.workspace_memberships.append(
        WorkspaceMembership(
            workspace_id=ws_id,
            role=UserRole.student,
            joined_at=utc_now(),
        )
    )
    user.touch()
    replace_result = await user_col.replace_one({"_id": user.id}, user.model_dump(by_alias=True))
    log.info("User document updated — matched=%d modified=%d", replace_result.matched_count, replace_result.modified_count)

    # ── 6. Bust Redis cache ───────────────────────────────────────────────────
    try:
        from app.core.redis_client import get_redis
        redis = await get_redis()
        if user.b2c_object_id:
            cache_key = f"user:{tenant_id}:{user.b2c_object_id}"
            await redis.delete(cache_key)
            log.info("Redis cache key %s deleted.", cache_key)
    except Exception as exc:
        log.warning("Could not bust Redis cache: %s", exc)

    log.info("Done. %s added to '%s' as student.", TARGET_EMAIL, TARGET_WORKSPACE_NAME)


if __name__ == "__main__":
    asyncio.run(main())
