"""Seed the demo tenant so the dev-auth bypass has an identity to resolve.

The Flutter app's login is still mocked (auth_repository.dart) and signs in
as a fixed demo identity. To let that demo login drive the *real* backend
via the dev-auth bypass (see app/core/auth.py + settings.dev_auth_token),
the backend needs the matching identity to exist in Cosmos:

    tenant    ten_demo_001   (platform/tenants)
    user      usr_demo_001   (ten_demo_001/users)        — tenant_admin
    workspace wsp_demo_001   (ten_demo_001/workspaces)   — empty taxonomy

These ids mirror the demo `User` built in
``flutter_app/lib/features/auth/data/auth_repository.dart`` and the active
workspace it exposes (``workspaceMemberships.first.workspaceId``).

Idempotent: every upsert uses ``$setOnInsert`` keyed on ``_id``, so re-running
is a no-op for documents that already exist — it will NOT clobber a workspace
whose taxonomy has since been populated by the ingestion pipeline.

Run from the backend/ directory::

    python scripts/seed_demo_tenant.py                 # uses .env.dev
    python scripts/seed_demo_tenant.py --env-file .env # pick a different env file

Reads ``COSMOS_CONNECTION_STRING`` from the chosen env file (or the process
environment). Connects straight to Cosmos with motor — the same driver the
app uses.
"""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
from pathlib import Path

from motor.motor_asyncio import AsyncIOMotorClient

from app.models.base import utc_now
from app.models.tenant import Tenant, TenantStatus, TenantType
from app.models.user import User, UserRole, WorkspaceMembership
from app.models.workspace import Workspace

# Platform-level DB that holds tenant records (mirrors api/tenants.py _PLATFORM_DB).
_PLATFORM_DB = "platform"
_TENANTS = "tenants"
_USERS = "users"
_WORKSPACES = "workspaces"

# Demo identity — keep in lockstep with the Flutter mock auth + dev-auth settings.
_TENANT_ID = "ten_demo_001"
_USER_ID = "usr_demo_001"
_WORKSPACE_ID = "wsp_demo_001"
_DEMO_EMAIL = "demo@socialstudyapp.com"


def _load_env_file(path: Path) -> None:
    """Minimal .env loader (avoids a hard python-dotenv dependency for a script)."""
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


def _build_documents() -> tuple[Tenant, Workspace, User]:
    """Construct the three demo documents with correct, validated shapes."""
    now = utc_now()
    tenant = Tenant(
        **{"_id": _TENANT_ID},
        name="Demo Tenant",
        type=TenantType.school,
        status=TenantStatus.active,
        admin_email=_DEMO_EMAIL,
    )
    workspace = Workspace(
        **{"_id": _WORKSPACE_ID},
        tenant_id=_TENANT_ID,
        name="Demo Classroom",
        description="Seeded workspace for the dev-auth demo identity.",
        admin_ids=[_USER_ID],
    )
    user = User(
        **{"_id": _USER_ID},
        tenant_id=_TENANT_ID,
        email=_DEMO_EMAIL,
        display_name="Alex Rivera",
        role=UserRole.tenant_admin,
        workspace_memberships=[
            WorkspaceMembership(
                workspace_id=_WORKSPACE_ID,
                role=UserRole.workspace_admin,
                joined_at=now,
            )
        ],
        is_active=True,
    )
    return tenant, workspace, user


async def _upsert(client: AsyncIOMotorClient, db: str, collection: str, doc_id: str, doc: dict) -> bool:
    """Create the document if absent; never overwrite an existing one.

    Returns True when a new document was inserted, False when it already existed.
    """
    result = await client[db][collection].update_one(
        {"_id": doc_id},
        {"$setOnInsert": doc},
        upsert=True,
    )
    return result.upserted_id is not None


async def _seed(connection_string: str) -> None:
    from app.core.config import settings
    tenant, workspace, user = _build_documents()
    client: AsyncIOMotorClient = AsyncIOMotorClient(connection_string)
    db_name = settings.get_db_name(_TENANT_ID)
    try:
        await client.admin.command("ping")
        plan = [
            (_PLATFORM_DB, _TENANTS, _TENANT_ID, tenant),
            (db_name, _WORKSPACES, _WORKSPACE_ID, workspace),
            (db_name, _USERS, _USER_ID, user),
        ]
        for db, collection, doc_id, model in plan:
            inserted = await _upsert(
                client, db, collection, doc_id, model.model_dump(by_alias=True)
            )
            verb = "inserted" if inserted else "already present"
            print(f"  {db}/{collection}/{doc_id}: {verb}")
    finally:
        client.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed the demo tenant for dev-auth.")
    parser.add_argument(
        "--env-file",
        default=".env.dev",
        help="Env file to load COSMOS_CONNECTION_STRING from (default: .env.dev).",
    )
    args = parser.parse_args()

    backend_dir = Path(__file__).resolve().parent.parent
    _load_env_file(backend_dir / args.env_file)

    connection_string = os.environ.get("COSMOS_CONNECTION_STRING", "")
    if not connection_string or connection_string.startswith("mongodb://localhost"):
        sys.exit(
            "COSMOS_CONNECTION_STRING is not set to a real Cosmos endpoint.\n"
            f"Checked env file: {backend_dir / args.env_file}\n"
            "Set it (or pass --env-file) before seeding."
        )

    print(f"Seeding demo tenant '{_TENANT_ID}' ...")
    asyncio.run(_seed(connection_string))
    print("Done. Dev-auth can now resolve usr_demo_001 in ten_demo_001.")


if __name__ == "__main__":
    main()
