import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

async def main():
    load_dotenv(".env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    if not conn_str:
        print("COSMOS_CONNECTION_STRING not found in .env.dev")
        return

    client = AsyncIOMotorClient(conn_str)

    # We need to find which tenant databases exist.
    # In this app, tenant databases are named like 'tenant_...'
    db_names = await client.list_database_names()
    tenant_dbs = [name for name in db_names if name.startswith("tenant_")]

    if not tenant_dbs:
        print("No tenant databases found.")
        return

    print(f"Found tenant databases: {tenant_dbs}")

    for db_name in tenant_dbs:
        db = client[db_name]
        tokens_col = db["notification_tokens"]

        # Get the most recent token
        latest_token = await tokens_col.find_one(sort=[("last_seen_at", -1)])

        if latest_token:
            print(f"Found token in {db_name}:")
            print(f"  User ID: {latest_token.get('user_id')}")
            print(f"  Platform: {latest_token.get('platform')}")
            print(f"  Last Seen: {latest_token.get('last_seen_at')}")
            print(f"  Installation ID: {latest_token.get('installation_id')}")

            # Now try to send a push using the app's services
            # But wait, we need ANH credentials in .env.dev for the service to work.
            # Let's just check if they are there first.
            anh_conn = os.getenv("NOTIFICATION_HUB_CONNECTION_STRING")
            if not anh_conn:
                print("\nWARNING: NOTIFICATION_HUB_CONNECTION_STRING missing in .env.dev.")
                print("The backend will only use LoggingSender (no real push).")
            else:
                print("\nNOTIFICATION_HUB_CONNECTION_STRING is present. Ready to send.")

if __name__ == "__main__":
    asyncio.run(main())
