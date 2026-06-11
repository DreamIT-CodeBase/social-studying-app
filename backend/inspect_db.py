import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

async def inspect():
    from motor.motor_asyncio import AsyncIOMotorClient
    from app.core.config import settings

    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    db = client["93e3ce50-a29e-462b-8956-85674a34d167"]
    
    print("ALL USERS:")
    async for user in db["users"].find():
        print(user)

if __name__ == "__main__":
    asyncio.run(inspect())
