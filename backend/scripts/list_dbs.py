import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)
    db_names = await client.list_database_names()
    print(f"Databases: {db_names}")

if __name__ == "__main__":
    asyncio.run(main())
