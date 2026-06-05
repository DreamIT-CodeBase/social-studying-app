import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    user_id = "usr_seed_001"

    db = client[tenant_id]

    # Remove from all relevant collections for a truly fresh start
    await db["users"].delete_one({"_id": user_id})
    await db["notification_tokens"].delete_many({"user_id": user_id})
    await db["notification_dispatches"].delete_many({"user_id": user_id})
    await db["gamification"].delete_many({"student_id": user_id})

    print(f"HARD DELETE COMPLETE: All data for {user_id} has been wiped.")

if __name__ == "__main__":
    asyncio.run(main())
