import asyncio
from app.core.database import NOTIFICATION_TOKENS, get_collection

async def main():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    col = get_collection(tenant_id, NOTIFICATION_TOKENS)
    doc = await col.find_one({"user_id": "usr_seed_001"})
    if doc:
        print("\n=== YOUR FCM TOKEN ===")
        print(doc.get("token"))
        print("======================\n")
    else:
        print("Token not found.")

if __name__ == "__main__":
    asyncio.run(main())
