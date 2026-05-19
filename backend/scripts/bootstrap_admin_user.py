"""Dev-only bootstrap — provision a tenant + tenant_admin User row.

Until ``POST /auth/register-completion`` ships (Sprint 3 cleanup), every
authenticated endpoint requires a User row in Cosmos that matches the
JWT's ``sub`` claim against ``users.b2c_object_id``. A fresh sign-in
through Entra External ID can't bootstrap itself — this script closes
the gap for dev/testing.

Usage::

    python scripts/bootstrap_admin_user.py \\
        --tenant-id ten_smoke001 \\
        --b2c-object-id <sub from JWT> \\
        --email user@example.com \\
        --display-name "Chirag Test User"

What it writes
--------------
1. ``platform.tenants`` — Tenant row with the given tenant_id, so a
   later ``GET /tenants/{id}`` resolves.
2. ``{tenant_id}.users`` — User row with role=tenant_admin and
   b2c_object_id matching the JWT sub. Idempotent on re-run: if the
   user already exists, the b2c_object_id is updated and a warning logs.

Notes
-----
- Hits the real Cosmos endpoint configured in backend/.env.dev. Never
  run this against a production tenant.
- The Redis user cache (5-min TTL) is invalidated so the next request
  sees the freshly-inserted row.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path
from uuid import uuid4


def _load_env() -> None:
    """Load backend/.env.dev so the script picks up real Cosmos creds.

    Mirrors the worker bootstrap pattern — must run before any app
    module imports settings.
    """
    backend_dir = Path(__file__).resolve().parent.parent
    for fname in (".env", ".env.dev"):
        path = backend_dir / fname
        if not path.exists():
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_env()

# Late imports — settings instantiated only after env is loaded.
from app.core.database import USERS, get_collection  # noqa: E402
from app.core.redis_client import get_redis, close_redis  # noqa: E402
from app.models.tenant import Tenant, TenantType  # noqa: E402
from app.models.user import User, UserRole  # noqa: E402


_PLATFORM_DB = "platform"
_TENANTS = "tenants"


async def _upsert_tenant(tenant_id: str, name: str, admin_email: str) -> None:
    col = get_collection(_PLATFORM_DB, _TENANTS)
    existing = await col.find_one({"_id": tenant_id})
    if existing:
        print(f"[tenant] already exists: {tenant_id} ({existing.get('name')!r})")
        return
    tenant = Tenant(
        **{"_id": tenant_id},
        name=name,
        type=TenantType.family,
        admin_email=admin_email,
    )
    await col.insert_one(tenant.model_dump(by_alias=True))
    print(f"[tenant] created: {tenant_id}")


async def _upsert_user(
    *,
    tenant_id: str,
    b2c_object_id: str,
    email: str,
    display_name: str,
) -> str:
    """Create or update a tenant_admin User row keyed by b2c_object_id.

    Returns the user_id (``usr_<uuid hex>``).
    """
    col = get_collection(tenant_id, USERS)
    existing = await col.find_one({"b2c_object_id": b2c_object_id})
    if existing:
        existing_id = existing["_id"]
        await col.update_one(
            {"_id": existing_id},
            {
                "$set": {
                    "email": email,
                    "display_name": display_name,
                    "role": UserRole.tenant_admin.value,
                    "is_active": True,
                    "deleted_at": None,
                }
            },
        )
        print(f"[user] updated existing: {existing_id}")
        return existing_id

    user_id = f"usr_{uuid4().hex}"
    user = User(
        **{"_id": user_id},
        tenant_id=tenant_id,
        email=email,
        display_name=display_name,
        b2c_object_id=b2c_object_id,
        role=UserRole.tenant_admin,
    )
    await col.insert_one(user.model_dump(by_alias=True))
    print(f"[user] created: {user_id} (b2c_object_id={b2c_object_id[:12]}…)")
    return user_id


async def _bust_user_cache(tenant_id: str, b2c_object_id: str) -> None:
    """Invalidate the auth middleware's Redis cache for this user."""
    try:
        redis = await get_redis()
        cache_key = f"user:{tenant_id}:{b2c_object_id}"
        deleted = await redis.delete(cache_key)
        print(f"[cache] invalidated {cache_key} (deleted={deleted})")
    finally:
        await close_redis()


async def main_async(args: argparse.Namespace) -> int:
    await _upsert_tenant(
        tenant_id=args.tenant_id,
        name=args.tenant_name,
        admin_email=args.email,
    )
    user_id = await _upsert_user(
        tenant_id=args.tenant_id,
        b2c_object_id=args.b2c_object_id,
        email=args.email,
        display_name=args.display_name,
    )
    await _bust_user_cache(args.tenant_id, args.b2c_object_id)
    print(f"\nDone. user_id={user_id} tenant_id={args.tenant_id}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--tenant-id", required=True)
    parser.add_argument("--b2c-object-id", required=True, help="JWT 'sub' claim")
    parser.add_argument("--email", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument(
        "--tenant-name",
        default="Smoke Test Tenant",
        help="Human-readable tenant name (used on first creation only).",
    )
    args = parser.parse_args()
    return asyncio.run(main_async(args))


if __name__ == "__main__":
    sys.exit(main())
