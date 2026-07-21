import asyncio
from app.core.database import NOTIFICATION_TOKENS, get_collection
from app.services.notifications import get_sender, NotificationPayload, NotificationType
from app.models.notification import NotificationToken

async def main():
    tenant_id = "93e3ce50-a29e-462b-8956-85674a34d167"
    user_id = "usr_f4caab256e6645779de48259dece9631"
    
    print(f"Fetching latest active token for user {user_id}...")
    collection = get_collection(tenant_id, NOTIFICATION_TOKENS)
    
    # Get all tokens and sort in memory to avoid Cosmos DB indexing constraints
    cursor = collection.find({"user_id": user_id, "deleted_at": None})
    docs = await cursor.to_list(length=100)
    
    if not docs:
        print("No active notification tokens found for this user!")
        return

    # Sort in memory by last_seen_at descending
    docs.sort(key=lambda x: x.get("last_seen_at", ""), reverse=True)
    doc = docs[0]
    token = NotificationToken(**doc)
    print(f"Found active token: {token.token[:30]}... (Last Seen: {token.last_seen_at})")
    
    sender = get_sender()
    print(f"Using sender: {type(sender).__name__}")
    
    payload = NotificationPayload(
        notification_type=NotificationType.study_reminder,
        title="🔔 Professional Expandable Test",
        body="Congratulations! Your push notifications are now configured with a professional design. Tap the down arrow on the right side or drag down on the notification to see this full, expanded description text!",
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
    print(f"Result: {result.outcome} (Reason: {result.failure_reason})")

if __name__ == "__main__":
    asyncio.run(main())
