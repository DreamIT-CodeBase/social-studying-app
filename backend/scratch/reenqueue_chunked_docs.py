"""
Re-enqueue docs stuck at 'chunked' status onto the vectorization queue.
Run this once to un-stick documents that completed chunking but never got vectorized.
"""
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings
from app.services.vectorization_queue import VectorizationMessage, publish_vectorization_message


async def run():
    client = AsyncIOMotorClient(settings.cosmos_connection_string)

    tenant_ids = [
        "93e3ce50-a29e-462b-8956-85674a34d167",
        "ten_demo_001",
        "ten_smoke001",
    ]

    re_enqueued = 0
    for tid in tenant_ids:
        db_name = settings.get_db_name(tid)
        db = client[db_name]
        stuck_docs = await db["documents"].find({"status": "chunked"}).to_list(100)
        if not stuck_docs:
            print(f"[{tid}] No docs stuck at chunked.")
            continue

        print(f"\n[{tid}] Found {len(stuck_docs)} docs stuck at chunked -> re-enqueuing to vectorization...")
        for d in stuck_docs:
            doc_id = d["_id"]
            workspace_id = d.get("workspace_id", "")
            chunk_count = d.get("chunk_count", 0)
            filename = d.get("filename", "")

            msg = VectorizationMessage(
                document_id=doc_id,
                tenant_id=tid,
                workspace_id=workspace_id,
                chunk_count=chunk_count,
            )

            try:
                await publish_vectorization_message(msg)
                print(f"  [OK] Re-enqueued to vectorization: {doc_id} ({filename})")
                re_enqueued += 1
            except Exception as e:
                print(f"  [FAIL] {doc_id}: {e}")

    print(f"\nDone. Re-enqueued {re_enqueued} document(s) to vectorization.")


asyncio.run(run())
