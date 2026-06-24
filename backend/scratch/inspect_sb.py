import asyncio
import os
from azure.servicebus.management import ServiceBusAdministrationClient
from app.core.config import settings

async def main():
    conn_str = settings.service_bus_connection
    queue_name = settings.service_bus_documents_queue
    print(f"Connecting to Service Bus queue: {queue_name}...")
    
    with ServiceBusAdministrationClient.from_connection_string(conn_str) as admin_client:
        queue_runtime_properties = admin_client.get_queue_runtime_properties(queue_name)
        print("\n=== QUEUE RUNTIME PROPERTIES ===")
        print(f"Queue Name: {queue_runtime_properties.name}")
        print(f"Active Message Count: {queue_runtime_properties.active_message_count}")
        print(f"Dead Letter Message Count: {queue_runtime_properties.dead_letter_message_count}")
        print(f"Scheduled Message Count: {queue_runtime_properties.scheduled_message_count}")
        print(f"Total Message Count: {queue_runtime_properties.total_message_count}")
        print("================================")

if __name__ == "__main__":
    # Load env first
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
