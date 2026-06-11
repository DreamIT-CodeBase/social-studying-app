import asyncio
from app.core.database import NOTIFICATION_TOKENS, get_collection

async def main():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    col = get_collection(tenant_id, NOTIFICATION_TOKENS)
    tokens = await col.find({}).to_list(None)
    for t in tokens:
        print("Token user_id:", t["user_id"], "Platform:", t["platform"])

if __name__ == "__main__":
    asyncio.run(main())
