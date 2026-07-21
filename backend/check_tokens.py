import asyncio
from app.core.database import NOTIFICATION_TOKENS, get_collection

async def main():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    collection = get_collection(tenant_id, NOTIFICATION_TOKENS)
    
    docs = await collection.find({}).to_list(length=10)
    for doc in docs:
        print(
            f"User: {doc.get('user_id')}, "
            f"Token: {doc.get('token')[:20]}..., "
            f"Platform: {doc.get('platform')}, "
            f"Last Seen: {doc.get('last_seen_at')}, "
            f"Registered: {doc.get('registered_at')}"
        )

if __name__ == "__main__":
    asyncio.run(main())
