"""Dev-only helper — promote an existing user to tenant_admin by email.

Use this after the user has signed in at least once, so the backend has
created a User row for their Microsoft account.

Usage::

    python scripts/promote_admin_by_email.py --email Tarun@dreamitcs.com

By default this checks the demo tenant (``ten_demo_001``), which is also
the fallback tenant used by the auth middleware when the token has no
``extension_TenantId`` claim. Pass ``--tenant-id`` if your token maps to
a different tenant, or ``--all-tenants`` to scan every tenant row.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import re
import sys
from pathlib import Path
from typing import Any


def _load_env() -> None:
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
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.database import USERS, get_collection  # noqa: E402
from app.core.redis_client import close_redis, get_redis  # noqa: E402
from app.models.base import utc_now  # noqa: E402
from app.models.user import UserRole  # noqa: E402


async def _tenant_ids(args: argparse.Namespace) -> list[str]:
    if not args.all_tenants:
        return [args.tenant_id]

    tenants_col = get_collection("platform", "tenants")
    tenants: list[str] = []
    async for doc in tenants_col.find({"deleted_at": None}):
        tenant_id = doc.get("_id")
        if isinstance(tenant_id, str) and tenant_id:
            tenants.append(tenant_id)
    return tenants


async def _find_user(tenant_id: str, email: str) -> dict[str, Any] | None:
    users_col = get_collection(tenant_id, USERS)
    normalized = email.strip().lower()

    doc = await users_col.find_one({"email": normalized, "deleted_at": None})
    if doc is not None:
        return doc

    return await users_col.find_one(
        {
            "email": {
                "$regex": f"^{re.escape(email.strip())}$",
                "$options": "i",
            },
            "deleted_at": None,
        }
    )


async def _invalidate_cache(tenant_id: str, user_doc: dict[str, Any]) -> None:
    b2c_object_id = user_doc.get("b2c_object_id")
    if not b2c_object_id:
        print("[cache] no b2c_object_id on user; nothing to invalidate")
        return

    try:
        redis = await get_redis()
        cache_key = f"user:{tenant_id}:{b2c_object_id}"
        deleted = await redis.delete(cache_key)
        print(f"[cache] invalidated {cache_key} (deleted={deleted})")
    finally:
        await close_redis()


async def main_async(args: argparse.Namespace) -> int:
    checked = await _tenant_ids(args)
    if not checked:
        print("No tenants found to scan.")
        return 1

    for tenant_id in checked:
        user_doc = await _find_user(tenant_id, args.email)
        if user_doc is None:
            continue

        users_col = get_collection(tenant_id, USERS)
        user_id = user_doc["_id"]
        await users_col.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "email": args.email.strip().lower(),
                    "role": UserRole.tenant_admin.value,
                    "is_active": True,
                    "deleted_at": None,
                    "updated_at": utc_now(),
                }
            },
        )
        print(
            f"[user] promoted {args.email.strip().lower()} "
            f"to tenant_admin in tenant={tenant_id} user_id={user_id}"
        )
        await _invalidate_cache(tenant_id, user_doc)
        return 0

    print(
        f"No active user found for {args.email!r} in "
        f"{', '.join(checked)}. Sign in once, then run this again."
    )
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--email", default="Tarun@dreamitcs.com")
    parser.add_argument("--tenant-id", default="ten_demo_001")
    parser.add_argument(
        "--all-tenants",
        action="store_true",
        help="Scan every tenant in platform.tenants instead of one tenant.",
    )
    args = parser.parse_args()
    return asyncio.run(main_async(args))


if __name__ == "__main__":
    raise SystemExit(main())
