import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings

async def run():
    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    
    # Check all known tenant databases
    tenant_ids = ["93e3ce50-a29e-462b-8956-85674a34d167", "ten_demo_001", "ten_smoke001"]
    
    for tid in tenant_ids:
        db_name = settings.get_db_name(tid)
        db = client[db_name]
        docs = await db["documents"].find().to_list(20)
        if docs:
            print(f"\n=== Tenant: {tid} => DB: {db_name} ===")
            for d in docs:
                print(f"  ID: {d.get('_id')}")
                print(f"  File: {d.get('filename')}")
                print(f"  Status: {d.get('status')}")
                print(f"  Error: {d.get('processing_error')}")
                print(f"  Created: {d.get('created_at')}")
                print()

asyncio.run(run())
