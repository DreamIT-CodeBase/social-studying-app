import asyncio
from app.core.database import get_collection, QUESTION_QUEUE

async def main():
    col = get_collection('93e3ce50-a29e-462b-8956-85674a34d167', QUESTION_QUEUE)
    res = await col.update_many(
        {'prefetched_for': {'$ne': None}},
        {'$set': {'prefetched_for': None}}
    )
    print(f'Cleared {res.modified_count} prefetches')

if __name__ == '__main__':
    asyncio.run(main())
