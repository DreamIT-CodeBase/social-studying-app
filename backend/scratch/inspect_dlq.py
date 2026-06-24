import asyncio
import os
from azure.servicebus.aio import ServiceBusClient
from app.core.config import settings

async def main():
    conn_str = settings.service_bus_connection
    queue_name = settings.service_bus_documents_queue
    print(f"Connecting to Service Bus DLQ for queue: {queue_name}...")
    
    sb = ServiceBusClient.from_connection_string(conn_str)
    async with sb:
        dlq_receiver = sb.get_queue_receiver(
            queue_name=queue_name,
            sub_queue="deadletter",
            max_wait_time=5
        )
        async with dlq_receiver:
            messages = await dlq_receiver.receive_messages(max_message_count=10, max_wait_time=5)
            print(f"\nFound {len(messages)} messages in DLQ.")
            for i, msg in enumerate(messages):
                print(f"\n--- DLQ Message #{i+1} ---")
                print(f"Message ID: {msg.message_id}")
                print(f"Body: {str(msg)}")
                
                # Check application properties for DLQ details
                props = msg.application_properties or {}
                print(f"Dead Letter Reason: {props.get(b'DeadLetterReason') or props.get('DeadLetterReason')}")
                print(f"Dead Letter Description: {props.get(b'DeadLetterErrorDescription') or props.get('DeadLetterErrorDescription')}")
                print("-------------------------")

if __name__ == "__main__":
    from pathlib import Path
    backend_dir = Path(__file__).resolve().parent.parent
    for fname in (".env", ".env.dev"):
        path = backend_dir / fname
        if not path.exists():
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

    asyncio.run(main())
