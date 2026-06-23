"""
Re-enqueue stuck 'pending' documents back onto the Service Bus queue.
This is safe to run multiple times - Service Bus deduplication (by message_id=doc_id)
prevents double-processing if the message already exists.
"""
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings
from app.services.document_queue import ExtractionMessage, publish_extraction_message


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
        stuck_docs = await db["documents"].find({"status": "pending"}).to_list(100)
        if not stuck_docs:
            print(f"[{tid}] No stuck documents.")
            continue

        print(f"\n[{tid}] Found {len(stuck_docs)} stuck docs — re-enqueuing...")
        for d in stuck_docs:
            doc_id = d["_id"]
            workspace_id = d.get("workspace_id", "")
            blob_url = d.get("blob_url", "")
            filename = d.get("filename", "")
            doc_type = d.get("doc_type", "image")
            uploaded_by = d.get("uploaded_by", "")
            created_at = d.get("created_at", "")

            # Reconstruct blob_path from blob_url
            # blob_url looks like: https://<account>.blob.core.windows.net/<container>/<path>
            blob_path = ""
            if blob_url:
                try:
                    from urllib.parse import urlparse
                    parsed = urlparse(blob_url)
                    # path = /<container>/<rest>
                    # strip leading slash and container prefix
                    path_parts = parsed.path.lstrip("/").split("/", 1)
                    if len(path_parts) == 2:
                        blob_path = path_parts[1]  # everything after container/
                except Exception as e:
                    print(f"  WARNING: could not parse blob_url for {doc_id}: {e}")

            # Determine content_type from doc_type
            content_type_map = {
                "pdf": "application/pdf",
                "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                "image": "image/jpeg",
                "text": "text/plain",
            }
            content_type = content_type_map.get(doc_type, "application/octet-stream")

            msg = ExtractionMessage(
                document_id=doc_id,
                tenant_id=tid,
                workspace_id=workspace_id,
                blob_path=blob_path,
                content_type=content_type,
                uploaded_by=uploaded_by,
                uploaded_at=str(created_at),
            )

            try:
                await publish_extraction_message(msg)
                print(f"  [OK] Re-enqueued: {doc_id} ({filename})")
                re_enqueued += 1
            except Exception as e:
                print(f"  [FAIL] FAILED to re-enqueue {doc_id}: {e}")

    print(f"\nDone. Re-enqueued {re_enqueued} document(s).")


asyncio.run(run())
