import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings

async def main():
    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    
    old_db_name = "93e3ce50-a29e-462b-8956-85674a34d167"
    new_db_name = "93e3ce50-a29e-462b-8956-85674a34d167_shared"
    
    doc_id_1 = "doc_a6984049506c4f3a952d3811c8c91147"
    doc_id_2 = "doc_8fecbf594feb4951910dd93ef09d8514"
    
    for db_name in (old_db_name, new_db_name):
        print(f"\n--- Checking Database: {db_name} ---")
        db = client[db_name]
        for doc_id in (doc_id_1, doc_id_2):
            doc = await db["documents"].find_one({"_id": doc_id})
            if doc:
                print(f"Document {doc_id} found! Status: {doc.get('status')}")
            else:
                print(f"Document {doc_id} NOT found.")

if __name__ == "__main__":
    from pathlib import Path
    backend_dir = Path(__file__).resolve().parent.parent
    for fname in (".env", ".env.dev"):
        path = backend_dir / fname
        if not path.exists():
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

    asyncio.run(main())
