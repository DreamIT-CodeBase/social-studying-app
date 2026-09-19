"""
Strip tarunjuneja471@gmail.com from ALL workspaces EXCEPT their self-learning workspace.

Run from the backend root:
    python scripts/keep_only_self_workspace.py
"""
import asyncio
import logging

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

TARGET_EMAIL = "tarunjuneja471@gmail.com"


async def main() -> None:
    from app.core.database import get_collection, USERS, WORKSPACES
    from app.core.config import settings
    from app.models.user import User

    tenant_id = settings.b2c_client_id or "ten_demo_001"

    # ── 1. Find the user ──────────────────────────────────────────────────────
    user_col = get_collection(tenant_id, USERS)
    doc = await user_col.find_one({"email": TARGET_EMAIL, "deleted_at": None})
    if doc is None:
        log.error("User %s not found.", TARGET_EMAIL)
        return

    user = User.model_validate(doc)
    log.info("Found user %s (id=%s)", TARGET_EMAIL, user.id)

    self_ws_id = f"wsp_self_{user.id}"
    log.info("Self workspace ID: %s", self_ws_id)

    wsp_col = get_collection(tenant_id, WORKSPACES)

    # ── 2. Remove user from every workspace except self workspace ─────────────
    to_remove = [m.workspace_id for m in user.workspace_memberships if m.workspace_id != self_ws_id]
    log.info("Workspaces to remove: %s", to_remove)

    for ws_id in to_remove:
        result = await wsp_col.update_one(
            {"_id": ws_id},
            {"$pull": {"student_ids": user.id, "admin_ids": user.id}},
        )
        log.info("  Workspace %s — matched=%d modified=%d", ws_id, result.matched_count, result.modified_count)

    # ── 3. Keep only self workspace membership on user ────────────────────────
    user.workspace_memberships = [m for m in user.workspace_memberships if m.workspace_id == self_ws_id]
    user.touch()
    replace = await user_col.replace_one({"_id": user.id}, user.model_dump(by_alias=True))
    log.info("User document updated — matched=%d modified=%d", replace.matched_count, replace.modified_count)
    log.info("Remaining memberships: %s", [m.workspace_id for m in user.workspace_memberships])

    # ── 4. Bust Redis cache ───────────────────────────────────────────────────
    try:
        from app.core.redis_client import get_redis
        redis = await get_redis()
        if user.b2c_object_id:
            cache_key = f"user:{tenant_id}:{user.b2c_object_id}"
            await redis.delete(cache_key)
            log.info("Redis cache busted: %s", cache_key)
    except Exception as exc:
        log.warning("Could not bust Redis cache: %s", exc)

    log.info("Done. %s now only has self-learning workspace.", TARGET_EMAIL)


if __name__ == "__main__":
    asyncio.run(main())
