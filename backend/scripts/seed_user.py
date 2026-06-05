import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
from datetime import datetime, timezone

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    # New correct account details from your terminal output
    b2c_object_id = "jykf64iAkgA74TNoFizFZlLnNPI1Y_C8el5RxYcCKCk"
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    email = "tarun@dreamitcs.com"
    display_name = "Tarun Juneja"

    # Insert into the tenant database
    db = client[tenant_id]
    users_col = db["users"]

    now = datetime.now(timezone.utc).isoformat()

    user_doc = {
        "_id": "usr_seed_002",
        "created_at": now,
        "updated_at": now,
        "deleted_at": None,
        "tenant_id": tenant_id,
        "email": email,
        "display_name": display_name,
        "b2c_object_id": b2c_object_id,
        "role": "tenant_admin",
        "workspace_memberships": [],
        "last_login_at": None,
        "is_active": True
    }

    await users_col.replace_one({"b2c_object_id": b2c_object_id}, user_doc, upsert=True)
    print(f"Successfully seeded user {email} into database {tenant_id}")

if __name__ == "__main__":
    asyncio.run(main())
