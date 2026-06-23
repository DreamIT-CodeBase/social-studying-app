import asyncio
import os
import sys

# Add backend to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.mongodb import get_collection

async def main():
    col = get_collection("93e3ce50-a29e-462b-8956-85674a34d167", "workspace_messages")
    cursor = col.find({"workspace_id": "wsp_f8421df408ed422e81e8c191d65f1c1a", "deleted_at": None}).sort("created_at", -1).limit(100)
    messages = [doc async for doc in cursor]
    print(messages)

if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    asyncio.run(main())
