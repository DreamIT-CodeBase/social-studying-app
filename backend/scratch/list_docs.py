import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings

async def main():
    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    db_name = settings.get_db_name("93e3ce50-a29e-462b-8956-85674a34d167")
    db = client[db_name]
    
    print(f"\n=== Documents in {db_name} ===")
    cursor = db["documents"].find()
    docs = await cursor.to_list(length=100)
    for d in docs:
        print(f"File: {d.get('filename')} | Status: {d.get('status')}")
    print("===============================\n")

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
