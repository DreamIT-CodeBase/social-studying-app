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
    user_id = "usr_seed_001"

    db = client[tenant_id]
    users_col = db["users"]

    now = datetime.now(timezone.utc).isoformat()

    result = await users_col.update_one(
        {"_id": user_id},
        {"$set": {
            "deleted_at": now,
            "updated_at": now,
            "is_active": False
        }}
    )

    if result.modified_count > 0:
        print(f"Successfully deleted (deactivated) account {user_id} in tenant {tenant_id}")
    else:
        print(f"Account {user_id} not found or already deleted.")

if __name__ == "__main__":
    asyncio.run(main())
