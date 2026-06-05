import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
from datetime import datetime, timezone
from uuid import uuid4

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    db = client[tenant_id]

    now = datetime.now(timezone.utc).isoformat()
    workspace_id = f"wsp_{uuid4().hex}"

    # 1. Create a Workspace
    workspace_doc = {
        "_id": workspace_id,
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
        "tenant_id": tenant_id,
        "name": "Notification Test Class",
        "description": "Used to test push notifications",
        "settings": {
            "questions_per_day": 3,
            "reminder_time_utc": "12:00"
        },
        "student_ids": ["usr_seed_001"],
        "admin_ids": []
    }
    await db["workspaces"].insert_one(workspace_doc)
    print(f"Created workspace: {workspace_id}")

    # 2. Update User to be a Student in this workspace
    user_updates = {
        "role": "student",
        "workspace_memberships": [
            {
                "workspace_id": workspace_id,
                "role": "student",
                "joined_at": now
            }
        ]
    }
    await db["users"].update_one({"_id": "usr_seed_001"}, {"$set": user_updates})
    print(f"Updated user usr_seed_001 to student role in {workspace_id}")

    # 3. Ensure no dispatch log exists for today to allow the scheduler to fire
    today_iso = datetime.now(timezone.utc).date().isoformat()
    await db["notification_dispatches"].delete_many({
        "user_id": "usr_seed_001",
        "dispatched_at": {"$regex": f"^{today_iso}"}
    })
    print("Cleared any existing notification dispatches for today.")

if __name__ == "__main__":
    asyncio.run(main())
