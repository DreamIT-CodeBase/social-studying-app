"""List all databases, tenants, workspaces, and documents in Cosmos DB."""

from __future__ import annotations

import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


async def inspect_all_cosmos():
    from motor.motor_asyncio import AsyncIOMotorClient
    from app.core.config import settings
    from app.core.database import USERS, WORKSPACES, DOCUMENTS, CHUNKS

    conn_str = settings.cosmos_connection_string
    if not conn_str:
        print("Error: COSMOS_CONNECTION_STRING is empty in settings / .env")
        return

    client = AsyncIOMotorClient(conn_str)

    print("=" * 80)
    print("           COSMOS DB: ALL DATABASES, WORKSPACES & DOCUMENTS")
    print("=" * 80)

    try:
        db_names = await client.list_database_names()
    except Exception as e:
        print(f"Error listing database names: {e}")
        db_names = ["tenant_data_shared", "ten_smoke001_shared", "ten_demo_001_shared", "93e3ce50-a29e-462b-8956-85674a34d167_shared"]

    print(f"Found Databases: {db_names}\n")

    for db_name in db_names:
        if db_name in ("admin", "local", "config"):
            continue
        db = client[db_name]
        try:
            col_names = await db.list_collection_names()
        except Exception:
            col_names = []

        print("-" * 80)
        print(f"DATABASE: {db_name} (Collections: {col_names})")
        print("-" * 80)

        # 1. Inspect Users
        if USERS in col_names:
            print("  [USERS]")
            async for u in db[USERS].find({}):
                uid = u.get("_id")
                email = u.get("email", "N/A")
                role = u.get("role", "N/A")
                tenant_id = u.get("tenant_id", "N/A")
                print(f"    • User ID: {uid} | Email: {email} | Role: {role} | Tenant ID: {tenant_id}")

        # 2. Inspect Workspaces
        if WORKSPACES in col_names:
            print("\n  [WORKSPACES]")
            async for ws in db[WORKSPACES].find({}):
                ws_id = ws.get("_id")
                ws_name = ws.get("name", ws.get("title", "Untitled"))
                tenant_id = ws.get("tenant_id", "N/A")
                owner_id = ws.get("owner_id", ws.get("user_id", "N/A"))
                print(f"    • Workspace ID:   {ws_id}")
                print(f"      - Name:         {ws_name}")
                print(f"      - Tenant ID:    {tenant_id}")
                print(f"      - Owner User:   {owner_id}")

        # 3. Inspect Documents
        if DOCUMENTS in col_names:
            print("\n  [DOCUMENTS]")
            doc_count = 0
            async for doc in db[DOCUMENTS].find({}):
                doc_count += 1
                doc_id = doc.get("_id")
                ws_id = doc.get("workspace_id", "N/A")
                tenant_id = doc.get("tenant_id", "N/A")
                title = doc.get("filename", doc.get("title", "Untitled Document"))
                status = doc.get("status", "unknown")
                deleted = doc.get("deleted_at")
                print(f"    • Document ID:   {doc_id}")
                print(f"      - Title:        {title}")
                print(f"      - Workspace ID: {ws_id}")
                print(f"      - Tenant ID:    {tenant_id}")
                print(f"      - Status:       {status} (Deleted: {deleted is not None})")

            if doc_count == 0:
                print("    (No documents found)")

        print()


if __name__ == "__main__":
    asyncio.run(inspect_all_cosmos())
