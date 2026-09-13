import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

WORKSPACE_ID = "wsp_e83875ecf8a748bda10fd88ba4623e6a"

async def main():
    from app.core.config import settings
    from motor.motor_asyncio import AsyncIOMotorClient

    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    db = client["93e3ce50-a29e-462b-8956-85674a34d167_shared"]

    # Inspect all flashcards in MongoDB
    fcs = await db["flashcards"].find({"workspace_id": WORKSPACE_ID}).to_list(100)
    print(f"Total flashcards in database: {len(fcs)}")
    for i, fc in enumerate(fcs):
        print(f"  * Card {i+1}: Topic={fc.get('topic')!r} Status={fc.get('status')!r} Front={fc.get('front')!r}")

    # Check ratings
    ratings = await db["flashcard_ratings"].find({"workspace_id": WORKSPACE_ID}).to_list(100)
    print(f"\nTotal ratings in database: {len(ratings)}")
    for i, r in enumerate(ratings[:10]):
        print(f"  * Rating {i+1}: Topic={r.get('topic')!r} Rating={r.get('rating')!r} Selected={r.get('selected_option')!r}")

if __name__ == "__main__":
    asyncio.run(main())
