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

    # 1. Ensure you are an ADMIN so you can trigger the API
    await db["users"].update_one(
        {"_id": "usr_seed_001"},
        {"$set": {"role": "tenant_admin"}}
    )
    print("User usr_seed_001 is now a tenant_admin (to trigger API).")

    # 2. Create a dummy student user that points to YOUR phone
    # This installation ID comes from your registered token
    installation_id = "94858b87-fc91-4092-afa8-a5ffdcb2673d"
    token = "dweTZSZ1S1eXI3ba4MbTNd:APA91bE3Jytee8Zc6dPOMeciQmDvGBehMPauTD1Wq15YJMe1SlDfCfcp1p6Uz6H6VGwwTtMYBc53Ym636pH45EToPodEA27APcTKjXgXhWEQ6omm1_lpBto"

    workspace_id = "wsp_test_001"
    # Ensure workspace exists
    await db["workspaces"].replace_one(
        {"_id": workspace_id},
        {
            "_id": workspace_id,
            "tenant_id": tenant_id,
            "name": "Notification Test",
            "settings": {"questions_per_day": 5},
            "student_ids": ["usr_test_student"],
            "deleted_at": None
        },
        upsert=True
    )

    test_student = {
        "_id": "usr_test_student",
        "tenant_id": tenant_id,
        "email": "test-student@example.com",
        "display_name": "Test Student",
        "role": "student",
        "workspace_memberships": [
            {"workspace_id": workspace_id, "role": "student", "joined_at": now}
        ],
        "deleted_at": None,
        "is_active": True
    }
    await db["users"].replace_one({"_id": "usr_test_student"}, test_student, upsert=True)
    print("Created dummy student usr_test_student.")

    # 3. Register YOUR phone to this dummy student
    token_doc = {
        "_id": "ntk_test_push",
        "tenant_id": tenant_id,
        "user_id": "usr_test_student",
        "installation_id": installation_id,
        "token": token,
        "platform": "android",
        "registered_at": now,
        "last_seen_at": now,
        "deleted_at": None
    }
    await db["notification_tokens"].replace_one({"_id": "ntk_test_push"}, token_doc, upsert=True)
    print("Linked your phone (installation_id) to the dummy student.")

    # 4. Clear logs so it fires
    today_iso = datetime.now(timezone.utc).date().isoformat()
    await db["notification_dispatches"].delete_many({"dispatched_at": {"$regex": f"^{today_iso}"}})
    print("Ready! Now run the trigger script.")

if __name__ == "__main__":
    asyncio.run(main())
