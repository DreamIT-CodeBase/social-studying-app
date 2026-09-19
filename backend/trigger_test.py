import asyncio
from app.core.database import NOTIFICATION_TOKENS, get_collection
from app.services.notifications import get_sender, NotificationPayload, NotificationType
from app.models.notification import NotificationToken

async def main():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    print(f"Fetching registered notification tokens for tenant: {tenant_id}...")
    collection = get_collection(tenant_id, NOTIFICATION_TOKENS)
    
    # Get all tokens
    cursor = collection.find({})
    docs = await cursor.to_list(length=100)
    
    if not docs:
        print("No notification tokens found in the database. Make sure you opened the Flutter app so it could register its token!")
        return

    sender = get_sender()
    print(f"Using sender: {type(sender).__name__}")
    
    for doc in docs:
        token = NotificationToken(**doc)
        print(f"Triggering push to user {token.user_id} (Platform: {token.platform})")
        
        payload = NotificationPayload(
            notification_type=NotificationType.study_reminder,
            title="🔔 Azure Push Test",
            body="If you are reading this, Azure Notification Hubs is successfully connected to Firebase and Flutter!",
            data={
                "type": NotificationType.study_reminder.value,
                "workspace_id": "test",
            },
        )
        
        result = await sender.send_to_installation(
            installation_id=token.installation_id,
            device_token=token.token,
            platform=token.platform,
            payload=payload,
        )
        print(f"Result for {token.installation_id}: {result.outcome} (Reason: {result.failure_reason})")

if __name__ == "__main__":
    asyncio.run(main())
