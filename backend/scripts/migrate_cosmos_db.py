"""Cosmos DB data migration script with shared throughput provisioning and rate limit handling.

Migrates all collections and documents from the source (old subscription)
Cosmos DB account to the destination (new subscription) Cosmos DB account.
Explicitly provisions databases with 400 RU/s shared throughput.
"""

from __future__ import annotations

import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import BulkWriteError

SRC_CS = "mongodb://cosmos-ssa-dev-ddjopeut37ed2:oTEiQwQfW6XCVoDwtTH8m1vaFLNwxcZRmLur11UbbZ1NIhGyc7wPEaEmf3jA0nyMv4JrTEUhNlHMACDboapaQg==@cosmos-ssa-dev-ddjopeut37ed2.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@cosmos-ssa-dev-ddjopeut37ed2@"
DST_CS = "mongodb://cosmos-ssa-dev-xumnzboir5vz2:NRBsvN7hhiEuZ8SVfrk9zAf9pvpulq8PfUyBu19rZyLs8bvrW6aznrGOYyNNLjMp8sfRpvryCnzqACDbl0XuoA==@cosmos-ssa-dev-xumnzboir5vz2.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@cosmos-ssa-dev-xumnzboir5vz2@"


from pymongo import IndexModel

async def safe_delete_many(dst_col) -> None:
    """Deletes documents in destination collection, handling Cosmos DB 429 rate limit retries."""
    retries = 8
    delay = 0.5
    while retries > 0:
        try:
            await dst_col.delete_many({})
            break
        except Exception as ex:
            if "16500" in str(ex) or "429" in str(ex):
                retry_after = delay
                if "RetryAfterMs=" in str(ex):
                    try:
                        ms_str = str(ex).split("RetryAfterMs=")[1].split(",")[0].split("'")[0].split("\\")[0].split("}")[0].strip()
                        retry_after = max(float(ms_str) / 1000.0, 0.1)
                    except Exception:
                        pass
                print(f"    [Rate Limit] Delete throttled. Sleeping for {retry_after:.3f}s before retry...")
                await asyncio.sleep(retry_after)
                retries -= 1
            else:
                raise ex
    if retries == 0:
        raise RuntimeError("Failed to delete documents after 8 retries due to rate limiting.")


async def safe_insert_many(dst_col, docs: list) -> None:
    """Inserts documents in batches of 15, handling Cosmos DB 429 rate limit retries."""
    batch_size = 15
    for i in range(0, len(docs), batch_size):
        batch = docs[i:i + batch_size]
        retries = 8
        delay = 0.5
        while retries > 0:
            try:
                await dst_col.insert_many(batch)
                await asyncio.sleep(0.05)  # slight throttle between batches
                break
            except BulkWriteError as e:
                is_rate_limit = False
                retry_after = 0.5
                
                # Check for Cosmos DB 429 throttling (code 16500)
                for err in e.details.get("writeErrors", []):
                    if err.get("code") == 16500:
                        is_rate_limit = True
                        errmsg = err.get("errmsg", "")
                        if "RetryAfterMs=" in errmsg:
                            try:
                                ms_str = errmsg.split("RetryAfterMs=")[1].split(",")[0].split("'")[0].split("\\")[0].split("}")[0].strip()
                                retry_after = max(float(ms_str) / 1000.0, 0.1)
                            except Exception:
                                pass
                        break
                
                if is_rate_limit:
                    print(f"    [Rate Limit] Insert throttled. Sleeping for {retry_after:.3f}s before retry...")
                    await asyncio.sleep(retry_after)
                    retries -= 1
                else:
                    raise e
            except Exception as ex:
                if "16500" in str(ex) or "429" in str(ex):
                    print(f"    [Rate Limit] Throttled (general exception). Sleeping for {delay}s...")
                    await asyncio.sleep(delay)
                    retries -= 1
                    delay *= 2
                else:
                    raise ex
        if retries == 0:
            raise RuntimeError(f"Failed to insert batch at index {i} after 8 retries due to rate limiting.")


async def copy_indexes(src_col, dst_col) -> None:
    """Copies indexes from source collection to destination collection, ignoring the default _id index."""
    try:
        indexes = []
        async for index in src_col.list_indexes():
            if index["name"] == "_id_":
                continue
            
            # Extract key and options (like unique, sparse, etc.)
            keys = list(index["key"].items())
            options = {k: v for k, v in index.items() if k not in ("key", "name", "ns", "v")}
            
            indexes.append(IndexModel(keys, name=index["name"], **options))
        
        if indexes:
            print(f"    - Copying {len(indexes)} indexes...")
            await dst_col.create_indexes(indexes)
            print("    - Indexes copied successfully.")
    except Exception as e:
        print(f"    - Error copying indexes: {e}")


async def ensure_shared_db(dst_client, db_name) -> None:
    """Creates a shared throughput database on destination, retrying on 429 rate limit."""
    retries = 10
    delay = 1.0
    while retries > 0:
        try:
            print(f"  - Ensuring '{db_name}' exists with 400 RU/s shared database-level throughput...")
            await dst_client[db_name].command({
                "customAction": "CreateDatabase",
                "offerThroughput": 400
            })
            print("    - Shared throughput database created/verified.")
            return
        except Exception as e:
            if "16500" in str(e) or "429" in str(e):
                retry_after = delay
                if "RetryAfterMs=" in str(e):
                    try:
                        ms_str = str(e).split("RetryAfterMs=")[1].split(",")[0].split("'")[0].split("\\")[0].split("}")[0].strip()
                        retry_after = max(float(ms_str) / 1000.0, 0.1)
                    except Exception:
                        pass
                print(f"    [Rate Limit] CreateDatabase throttled. Sleeping for {retry_after:.3f}s before retry...")
                await asyncio.sleep(retry_after)
                retries -= 1
            else:
                # If it's another error (like database already exists or similar), print warning and exit
                print(f"    - Note/Warning creating shared DB: {e}")
                return
    raise RuntimeError(f"Failed to create shared throughput database '{db_name}' after 10 retries due to rate limiting.")


async def migrate() -> None:
    print("Connecting to source and destination databases...")
    src_client: AsyncIOMotorClient = AsyncIOMotorClient(SRC_CS)
    dst_client: AsyncIOMotorClient = AsyncIOMotorClient(DST_CS)

    try:
        # Test connections
        await src_client.admin.command("ping")
        print("  - Connection to source Cosmos DB: OK")
        await dst_client.admin.command("ping")
        print("  - Connection to destination Cosmos DB: OK")

        # Drop all destination databases EXCEPT "platform" and system databases
        dst_db_names = await dst_client.list_database_names()
        print(f"\nFound existing databases on destination: {dst_db_names}")
        for db_name in dst_db_names:
            if db_name not in ("admin", "config", "local", "platform"):
                print(f"Dropping database '{db_name}' on destination...")
                await dst_client.drop_database(db_name)
                print(f"Dropped '{db_name}' successfully.")

        # Get list of databases from source
        db_names = await src_client.list_database_names()
        print(f"\nFound databases on source: {db_names}")

        # Filter out system databases
        dbs_to_migrate = [db for db in db_names if db not in ("admin", "config", "local")]
        print(f"Databases selected for migration: {dbs_to_migrate}")

        for db_name in dbs_to_migrate:
            print(f"\n>>> Preparing database: '{db_name}'")
            src_db = src_client[db_name]
            dst_db = dst_client[db_name]

            # If the database is platform, we do not drop/recreate it to preserve existing data.
            if db_name == "platform":
                print("  - Skipping 'platform' database drop/recreation to preserve its collections.")
            else:
                await ensure_shared_db(dst_client, db_name)

            collections = await src_db.list_collection_names()
            print(f"  Collections in '{db_name}': {collections}")

            for col_name in collections:
                if col_name.startswith("system."):
                    continue

                # If the database is platform, we skip copying/overwriting platform collection per user's request.
                if db_name == "platform":
                    print(f"  - Skipping migration for platform collection '{col_name}' to preserve existing data.")
                    continue

                print(f"  * Collection: {col_name}")
                src_col = src_db[col_name]
                dst_col = dst_db[col_name]

                # Fetch all documents
                docs = []
                async for doc in src_col.find({}):
                    docs.append(doc)

                if docs:
                    print(f"    - Found {len(docs)} documents. Writing to destination...")
                    # Delete existing to prevent collisions on retry
                    await safe_delete_many(dst_col)
                    await safe_insert_many(dst_col, docs)
                    print("    - Migration of documents successful.")
                else:
                    print("    - Collection is empty. Creating collection in destination...")
                    try:
                        await dst_db.create_collection(col_name)
                        print("    - Created empty collection.")
                    except Exception:
                        # Already exists
                        pass

                # Copy indexes from source to destination
                await copy_indexes(src_col, dst_col)

        print("\n=== Migration completed successfully! ===")

    finally:
        src_client.close()
        dst_client.close()


if __name__ == "__main__":
    asyncio.run(migrate())
