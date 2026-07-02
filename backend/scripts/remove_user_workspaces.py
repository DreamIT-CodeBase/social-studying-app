"""
One-shot cleanup script: remove tarunjuneja471@gmail.com from all workspace
memberships and remove them from each workspace's student_ids / admin_ids lists.

Run from the backend root:
    python scripts/remove_user_workspaces.py
"""
import asyncio
import logging

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

TARGET_EMAIL = "tarunjuneja471@gmail.com"


async def main() -> None:
    # Local imports so the script only loads what it needs.
    from app.core.database import get_collection, USERS, WORKSPACES
    from app.models.user import User
    from app.models.base import utc_now

    # ── 1. Find the user ──────────────────────────────────────────────────────
    # We don't know the tenant_id up front so scan a few known tenants.
    # Adjust this list if your tenant IDs differ.
    from app.core.config import settings

    candidate_tenant_ids = [
        settings.b2c_client_id or "ten_demo_001",
        "ten_demo_001",
    ]

    user = None
    tenant_id = None
    user_col = None

    for tid in candidate_tenant_ids:
        col = get_collection(tid, USERS)
        doc = await col.find_one({"email": TARGET_EMAIL, "deleted_at": None})
        if doc:
            user = User.model_validate(doc)
            tenant_id = tid
            user_col = col
            log.info("Found user %s in tenant %s", user.id, tenant_id)
            break

    if user is None:
        log.error("User %s not found in any candidate tenant.", TARGET_EMAIL)
        return

    # ── 2. Collect workspace IDs the user is a member of ────────────────────
    membership_ws_ids = [m.workspace_id for m in user.workspace_memberships]
    log.info("Current workspace memberships: %s", membership_ws_ids)

    if not membership_ws_ids:
        log.info("No memberships to remove.")
        return

    wsp_col = get_collection(tenant_id, WORKSPACES)

    # ── 3. Remove user from each workspace document ──────────────────────────
    for ws_id in membership_ws_ids:
        result = await wsp_col.update_one(
            {"_id": ws_id},
            {"$pull": {"student_ids": user.id, "admin_ids": user.id}},
        )
        log.info(
            "Workspace %s — matched=%d modified=%d",
            ws_id,
            result.matched_count,
            result.modified_count,
        )

    # ── 4. Clear the user's workspace_memberships list ───────────────────────
    user.workspace_memberships = []
    user.touch()
    replace_result = await user_col.replace_one(
        {"_id": user.id}, user.model_dump(by_alias=True)
    )
    log.info(
        "User document updated — matched=%d modified=%d",
        replace_result.matched_count,
        replace_result.modified_count,
    )

    # ── 5. Bust Redis cache so the next login reflects the clean state ────────
    try:
        from app.core.redis_client import get_redis
        redis = await get_redis()
        if user.b2c_object_id:
            cache_key = f"user:{tenant_id}:{user.b2c_object_id}"
            await redis.delete(cache_key)
            log.info("Redis cache key %s deleted.", cache_key)
    except Exception as exc:
        log.warning("Could not bust Redis cache: %s", exc)

    log.info(
        "Done. User %s removed from %d workspaces.",
        TARGET_EMAIL,
        len(membership_ws_ids),
    )


if __name__ == "__main__":
    asyncio.run(main())
