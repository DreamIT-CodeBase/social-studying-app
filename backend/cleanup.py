import asyncio
from app.core.database import get_collection

async def sync_workspaces():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    wsp_col = get_collection(tenant_id, "workspaces")
    user_col = get_collection(tenant_id, "users")
    doc_col = get_collection(tenant_id, "documents")
    
    # Get all active user IDs
    valid_users = await user_col.find({"deleted_at": None}).to_list(length=None)
    valid_user_ids = {u["_id"] for u in valid_users}
    print(f"Found {len(valid_user_ids)} active users in DB.")
    
    cursor = wsp_col.find({"deleted_at": None})
    async for w in cursor:
        wid = w["_id"]
        # Count documents for this workspace
        doc_count = await doc_col.count_documents({"workspace_id": wid, "deleted_at": None})
        
        # Filter student_ids
        student_ids = w.get("student_ids", [])
        new_student_ids = [sid for sid in student_ids if sid in valid_user_ids]
        
        # Filter admin_ids
        admin_ids = w.get("admin_ids", [])
        new_admin_ids = [aid for aid in admin_ids if aid in valid_user_ids]
        
        changed = False
        updates = {}
        
        if w.get("document_count", 0) != doc_count:
            updates["document_count"] = doc_count
            changed = True
            
        if len(new_student_ids) != len(student_ids):
            updates["student_ids"] = new_student_ids
            changed = True
            
        if len(new_admin_ids) != len(admin_ids):
            updates["admin_ids"] = new_admin_ids
            changed = True
            
        if changed:
            await wsp_col.update_one({"_id": wid}, {"$set": updates})
            print(f"Synced '{w['name']}': {updates}")

if __name__ == "__main__":
    asyncio.run(sync_workspaces())
