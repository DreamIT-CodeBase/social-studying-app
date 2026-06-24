import asyncio
import os
import sys

# Add the backend directory to sys.path so we can import app modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.database import get_collection
from app.models.user import UserRole, WorkspaceMembership
from app.models.base import utc_now

async def fix():
    from motor.motor_asyncio import AsyncIOMotorClient
    from app.core.config import settings

    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    db_names = await client.list_database_names()
    for db_name in db_names:
        if db_name in ("admin", "local", "config"): continue
        db = client[db_name]
        workspaces_col = db["workspaces"]
        users_col = db["users"]
        async for workspace in workspaces_col.find({"deleted_at": None}):
            for admin_id in workspace.get("admin_ids", []):
                user = await users_col.find_one({"_id": admin_id})
                if user:
                    memberships = user.get("workspace_memberships", [])
                    has_membership = any(m.get("workspace_id") == workspace["_id"] for m in memberships)
                    if not has_membership:
                        print(f"Fixing user {admin_id} in tenant {db_name} for workspace {workspace['_id']}")
                        memberships.append({
                            "workspace_id": workspace["_id"],
                            "role": "workspace_admin",
                            "joined_at": utc_now()
                        })
                        await users_col.update_one({"_id": admin_id}, {"$set": {"workspace_memberships": memberships}})
                        print(f"Fixed user {admin_id}")

    print("Done fixing users!")

if __name__ == "__main__":
    asyncio.run(fix())
