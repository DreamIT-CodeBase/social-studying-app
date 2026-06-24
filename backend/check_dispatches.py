import asyncio
from app.core.database import NOTIFICATION_DISPATCHES, get_collection

async def main():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    print(f"Checking notification dispatches for tenant {tenant_id}...")
    collection = get_collection(tenant_id, NOTIFICATION_DISPATCHES)
    
    cursor = collection.find({})
    docs = await cursor.to_list(length=None)
    
    if not docs:
        print("No dispatches found.")
        return
        
    # Sort in Python by dispatched_at descending
    docs.sort(key=lambda x: x.get('dispatched_at', ''), reverse=True)
    
    for doc in docs[:20]:
        print(f"[{doc.get('dispatched_at')}] User: {doc.get('user_id')} - Event: {doc.get('notification_type')} - Outcome: {doc.get('outcome')}")
        if doc.get('failure_reason'):
            print(f"  Failure reason: {doc.get('failure_reason')}")

if __name__ == "__main__":
    asyncio.run(main())
