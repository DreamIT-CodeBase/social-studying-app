import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
from datetime import datetime, timezone

async def main():
    load_dotenv("backend/.env.dev")
    conn_str = os.getenv("COSMOS_CONNECTION_STRING")
    client = AsyncIOMotorClient(conn_str)

    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    db = client[tenant_id]

    now = datetime.now(timezone.utc).isoformat()

    # This user is JUST for triggering the API.
    # Since we bypass sign-in with a JWT, and the backend validates the JWT's 'sub' claim,
    # we should use the same 'sub' claim as your current token if we want to use that token.
    # But wait, the role check is done AGAINST THE DATABASE.
    # So if I change your usr_seed_001 back to tenant_admin, you can trigger the API.
    # But then the scheduler won't find you.

    # FIX: I will change the scheduler script locally to also include tenant_admins for this test?
    # No, I can't change the deployed backend's code.

    # BETTER FIX:
    # 1. Change your user back to tenant_admin.
    # 2. Trigger the scheduler (it will return 0 students found).
    # 3. Change your user to student.
    # 4. Trigger the scheduler (Wait, I can't trigger it if I'm a student).

    # ULTIMATE FIX:
    # I will create a second user with a FAKE b2c_object_id who is the tenant_admin.
    # Then I will manually call the scheduler function from a script using the Azure credentials.

    pass

if __name__ == "__main__":
    asyncio.run(main())
