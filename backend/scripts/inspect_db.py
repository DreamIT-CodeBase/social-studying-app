import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    db_name = "93e3ce50-a29e-462b-8956-85674a34d167"
    db = client[db_name]
    collections = await db.list_collection_names()
    print(f"Collections in {db_name}: {collections}")

    for col_name in collections:
        count = await db[col_name].count_documents({})
        print(f"  {col_name}: {count} documents")
        if count > 0:
            sample = await db[col_name].find_one()
            print(f"    Sample: {sample}")

if __name__ == "__main__":
    asyncio.run(main())
