import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

async def inspect():
    from motor.motor_asyncio import AsyncIOMotorClient
    from app.core.config import settings

    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    
    # Let's inspect all databases first to find the tenant database
    dbs = await client.list_database_names()
    print("Databases found:", dbs)
    
    # We will find the tenant db or just use the one from config
    tenant_db_name = settings.get_db_name("93e3ce50-a29e-462b-8956-85674a34d167")
    print("Default Tenant DB Name:", tenant_db_name)
    
    for db_name in dbs:
        if db_name.startswith("tenant_") or db_name.startswith("ten_") or db_name == tenant_db_name:
            print(f"\n--- Database: {db_name} ---")
            db = client[db_name]
            collections = await db.list_collection_names()
            print("Collections:", collections)
            if "workspaces" in collections:
                print("WORKSPACES in", db_name)
                async for ws in db["workspaces"].find():
                    print(f"ID: {ws.get('_id')}, Name: {ws.get('name')}, Type: {ws.get('type')}, Owner: {ws.get('owner_id')}")

if __name__ == "__main__":
    asyncio.run(inspect())
