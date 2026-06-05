import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    db = client["ten_smoke001"]
    users_col = db["users"]
    user = await users_col.find_one({"deleted_at": None})
    if user:
        print(f"User found: {user}")
    else:
        print("No user found in ten_smoke001")

if __name__ == "__main__":
    asyncio.run(main())
