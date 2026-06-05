import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    if not conn_str:
        print("COSMOS_CONNECTION_STRING not found in .env.dev")
        return

    client = AsyncIOMotorClient(conn_str)
    db_names = await client.list_database_names()

    found_any = False
    for db_name in db_names:
        if db_name in ['admin', 'local', 'config', 'platform']:
            continue

        db = client[db_name]
        try:
            tokens_col = db["notification_tokens"]
            # Get the most recent token
            latest_token = await tokens_col.find_one(sort=[("last_seen_at", -1)])

            if latest_token:
                found_any = True
                print(f"\n--- Found token in Database: {db_name} ---")
                print(f"  User ID:         {latest_token.get('user_id')}")
                print(f"  Email:           {latest_token.get('email', 'N/A')}")
                print(f"  Platform:        {latest_token.get('platform')}")
                print(f"  Last Seen:       {latest_token.get('last_seen_at')}")
                print(f"  Installation ID: {latest_token.get('installation_id')}")
        except Exception:
            continue

    if not found_any:
        print("No registered notification tokens found in any database.")
        print("Tip: Make sure you have signed in on the mobile app and accepted notification permissions.")

if __name__ == "__main__":
    asyncio.run(main())
