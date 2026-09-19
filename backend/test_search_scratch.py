import asyncio
import os
import dotenv
from motor.motor_asyncio import AsyncIOMotorClient

async def main():
    dotenv.load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)
    db = client['93e3ce50-a29e-462b-8956-85674a34d167_shared']
    
    print("Sample Document in Cosmos DB:")
    doc = await db['documents'].find_one()
    print(doc)

if __name__ == "__main__":
    asyncio.run(main())
