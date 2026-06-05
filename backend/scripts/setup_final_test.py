import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
from datetime import datetime, timezone

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    db = client[tenant_id]

    # YOUR PHYSICAL PHONE ID
    installation_id = "36f3f6f7-f6f2-420d-8e0f-0e1213121617"
    user_id = "usr_seed_002"
    now = datetime.now(timezone.utc).isoformat()

    # Ensure you are admin
    await db["users"].update_one({"_id": user_id}, {"$set": {"role": "tenant_admin"}})

    # Find the token for the physical phone
    token_doc = await db["notification_tokens"].find_one({"installation_id": installation_id})
    if not token_doc:
        print(f"Error: No token found for physical phone {installation_id}")
        return

    token = token_doc["token"]

    # Target this phone with a student account
    workspace_id = "wsp_test_001"
    await db["users"].update_one(
        {"_id": "usr_test_student"},
        {"$set": {"role": "student", "workspace_memberships": [{"workspace_id": workspace_id, "role": "student", "joined_at": now}]}},
        upsert=True
    )

    token_doc_new = {
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
    await db["notification_tokens"].replace_one({"_id": "ntk_test_push"}, token_doc_new, upsert=True)

    # Clear logs
    today_iso = datetime.now(timezone.utc).date().isoformat()
    await db["notification_dispatches"].delete_many({"dispatched_at": {"$regex": f"^{today_iso}"}})

    print(f"Targeting PHYSICAL PHONE: {installation_id}")
    print("Ready!")

if __name__ == "__main__":
    asyncio.run(main())
