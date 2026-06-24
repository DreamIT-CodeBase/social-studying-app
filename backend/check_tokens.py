import asyncio
from app.core.database import NOTIFICATION_TOKENS, get_collection

async def main():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    collection = get_collection(tenant_id, NOTIFICATION_TOKENS)
    
    docs = await collection.find({}).to_list(length=10)
    for doc in docs:
        print(f"User: {doc.get('user_id')}, Token: {doc.get('token')[:30]}..., Platform: {doc.get('platform')}")

if __name__ == "__main__":
    asyncio.run(main())
