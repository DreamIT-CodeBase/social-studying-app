"""End-to-end smoke test for the document ingestion pipeline — Sprint 2.3.

What this verifies (without going through the API):

    1. Upload a sample file to blob storage.
    2. Insert a fake Cosmos `documents` record with status=pending.
    3. Publish an extraction message to the document-ingestion queue.
    4. Poll the Cosmos record until status transitions to text_extracted
       (success) or failed (DI error). Times out after 90 seconds.

Run this from a host that can reach Azure (laptop with .env.dev) AFTER the
worker Container App is deployed and running. If the worker is not running,
the message will sit on the queue and this script times out.

Usage::

    python scripts/smoke_test_document_pipeline.py path/to/sample.pdf

Required env vars (loaded from backend/.env or backend/.env.dev):

    COSMOS_CONNECTION_STRING
    STORAGE_CONNECTION_STRING
    SERVICE_BUS_CONNECTION
    DOCUMENT_INTELLIGENCE_ENDPOINT  (only needed if you run the worker locally)
    DOCUMENT_INTELLIGENCE_KEY       (only needed if you run the worker locally)
"""

from __future__ import annotations

import asyncio
import mimetypes
import os
import sys
import uuid
from pathlib import Path

mimetypes.add_type(
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document", ".docx"
)


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_TENANT_ID = "ten_smoke"
_WORKSPACE_ID = "wsp_smoke"
_USER_ID = "usr_smoke"


async def _run(file_path: Path, *, timeout_seconds: int = 90) -> int:
    from app.core.database import DOCUMENTS, get_collection
    from app.models.base import utc_now
    from app.models.document import Document, DocumentStatus, DocumentType
    from app.services import blob_storage, document_queue
    from app.services.document_queue import ExtractionMessage

    document_id = f"doc_smoke_{uuid.uuid4().hex[:8]}"
    filename = file_path.name
    content = file_path.read_bytes()
    content_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"

    print(f"Smoke test: doc_id={document_id} file={filename} ({len(content):,} bytes)")
    print(f"            tenant={_TENANT_ID} workspace={_WORKSPACE_ID}")

    # Step 1: blob upload
    print("\n[1/4] Uploading blob...")
    blob_url = await blob_storage.upload_document(
        tenant_id=_TENANT_ID,
        workspace_id=_WORKSPACE_ID,
        user_id=_USER_ID,
        document_id=document_id,
        filename=filename,
        content=content,
        content_type=content_type,
    )
    blob_path = f"{_TENANT_ID}/{_WORKSPACE_ID}/{_USER_ID}/{document_id}/{filename}"
    print(f"      blob: {blob_url}")

    # Step 2: Cosmos insert
    print("\n[2/4] Inserting Cosmos document record...")
    doc_type = (
        DocumentType.pdf if content_type == "application/pdf"
        else DocumentType.docx if "wordprocessingml" in content_type
        else DocumentType.image if content_type.startswith("image/")
        else DocumentType.text
    )
    doc = Document(
        **{"_id": document_id},
        tenant_id=_TENANT_ID,
        workspace_id=_WORKSPACE_ID,
        uploaded_by=_USER_ID,
        filename=filename,
        blob_url=blob_url,
        file_size_bytes=len(content),
        doc_type=doc_type,
    )
    col = get_collection(_TENANT_ID, DOCUMENTS)
    await col.insert_one(doc.model_dump(by_alias=True))
    print(f"      status=pending @ {doc.created_at}")

    # Step 3: Publish to queue
    print("\n[3/4] Publishing extraction message to document-ingestion...")
    await document_queue.publish_extraction_message(
        ExtractionMessage(
            document_id=document_id,
            tenant_id=_TENANT_ID,
            workspace_id=_WORKSPACE_ID,
            blob_path=blob_path,
            content_type=content_type,
            uploaded_by=_USER_ID,
            uploaded_at=doc.created_at,
        )
    )
    print("      message published")

    # Step 4: Poll Cosmos until terminal status or timeout
    print(f"\n[4/4] Polling Cosmos for status transition (timeout {timeout_seconds}s)...")
    deadline = asyncio.get_event_loop().time() + timeout_seconds
    last_status: str | None = None
    while asyncio.get_event_loop().time() < deadline:
        record = await col.find_one({"_id": document_id})
        if record is None:
            print("      record vanished?!")
            return 1
        status = record.get("status")
        if status != last_status:
            elapsed = int(timeout_seconds - (deadline - asyncio.get_event_loop().time()))
            print(f"      [+{elapsed:>3}s]  status={status}")
            last_status = status
        if status == DocumentStatus.text_extracted.value:
            print("\n  RESULT: text_extracted")
            print(f"    page_count        = {record.get('page_count')}")
            print(f"    text_char_count   = {record.get('text_char_count')}")
            print(f"    languages         = {record.get('languages')}")
            print(f"    extracted_blob    = {record.get('extracted_text_blob_path')}")
            return 0
        if status == DocumentStatus.failed.value:
            print("\n  RESULT: failed")
            print(f"    processing_error = {record.get('processing_error')}")
            return 2
        await asyncio.sleep(2)

    print("\n  RESULT: timed out — worker may not be running or message is still in flight.")
    return 3


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    file_path = Path(sys.argv[1]).expanduser().resolve()
    if not file_path.is_file():
        print(f"Error: {file_path} is not a readable file", file=sys.stderr)
        return 1

    backend_dir = Path(__file__).resolve().parent.parent
    for fname in (".env", ".env.dev"):
        _load_env_file(backend_dir / fname)
    sys.path.insert(0, str(backend_dir))

    return asyncio.run(_run(file_path))


if __name__ == "__main__":
    sys.exit(main())
