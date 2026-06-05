import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    db = client[tenant_id]

    cursor = db["notification_tokens"].find({"deleted_at": None})
    async for token in cursor:
        print(f"Token for User: {token.get('user_id')}")
        print(f"  Installation ID: {token.get('installation_id')}")
        print(f"  Token Snippet:   {token.get('token')[:20]}...")

if __name__ == "__main__":
    asyncio.run(main())
