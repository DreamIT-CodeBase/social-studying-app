import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    db_names = await client.list_database_names()
    print("Databases in cluster:", db_names)

    for db_name in db_names:
        if db_name in ["admin", "local", "config"]:
            continue
        db = client[db_name]
        collections = await db.list_collection_names()
        print(f"\nDatabase: {db_name}")
        print(f"Collections: {collections}")
        for col_name in collections:
            count = await db[col_name].count_documents({})
            print(f"  {col_name}: {count} documents")
            if count > 0:
                sample = await db[col_name].find_one()
                # print a subset of fields for sample
                print(f"    Sample _id: {sample.get('_id')}")
                if "workspace_id" in sample:
                    print(f"    Sample workspace_id: {sample.get('workspace_id')}")

if __name__ == "__main__":
    asyncio.run(main())
