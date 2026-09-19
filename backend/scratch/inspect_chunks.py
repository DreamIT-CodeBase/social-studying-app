import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

WORKSPACE_ID = "wsp_e83875ecf8a748bda10fd88ba4623e6a"

async def main():
    from app.core.config import settings
    from motor.motor_asyncio import AsyncIOMotorClient

    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    db = client["93e3ce50-a29e-462b-8956-85674a34d167_shared"]

    # Let's inspect workspaces
    workspace = await db["workspaces"].find_one({"_id": WORKSPACE_ID})
    print(f"Workspace Name: {workspace.get('name')}")
    
    # Check topics
    taxonomy_topics = []
    if workspace and "taxonomy" in workspace and workspace["taxonomy"] and "topics" in workspace["taxonomy"]:
        taxonomy_topics = workspace["taxonomy"]["topics"]
    print(f"Taxonomy topics count: {len(taxonomy_topics)}")
    for topic in taxonomy_topics[:10]:
        print(f"  * Topic: {topic.get('name')}  id={topic.get('id')}")

    # Inspect chunks collection in MongoDB
    chunks = await db["chunks"].find({"workspace_id": WORKSPACE_ID}).to_list(100)
    print(f"Total chunks in MongoDB for this workspace: {len(chunks)}")
    for i, c in enumerate(chunks[:10]):
        text_preview = c.get("text", "")[:150].replace("\n", " ")
        print(f"  Chunk {i+1} (id={c.get('_id')}, doc_id={c.get('document_id')}): {text_preview!r}...")

if __name__ == "__main__":
    asyncio.run(main())
