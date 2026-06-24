import asyncio
from app.core.config import settings
from app.services.notifications import send_study_reminder, NotificationPayload
from app.models.notification import NotificationType
from app.core.database import NOTIFICATION_TOKENS, get_collection

async def main():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    collection = get_collection(tenant_id, NOTIFICATION_TOKENS)
    
    # Get all unique users
    users = await collection.distinct("user_id")
    print(f"Found {len(users)} users with registered tokens.")
    
    for user_id in users:
        print(f"Sending test push to {user_id}...")
        results = await send_study_reminder(
            tenant_id=tenant_id,
            user_id=user_id,
            workspace_id="wsp_f2672fc1d8ed4623a26095cc1214c3e0",
            questions_per_day=5,
        )
        for r in results:
            print(f"  Result: {r.outcome} (Reason: {r.failure_reason})")

if __name__ == "__main__":
    asyncio.run(main())
