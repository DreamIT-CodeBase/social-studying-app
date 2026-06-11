import asyncio
import os
import sys

async def run_worker(name):
    print(f"Starting worker: {name}")
    process = await asyncio.create_subprocess_exec(
        sys.executable, "-m", f"app.workers.{name}",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT
    )
    
    while True:
        line = await process.stdout.readline()
        if not line:
            break
        print(f"[{name}] {line.decode('utf-8').rstrip()}")
        
    await process.wait()
    print(f"Worker {name} exited with {process.returncode}")

async def main():
    workers = [
        "document_ingestion",
        "topic_extraction",
        "chunking",
        "vectorization",
        "notification_scheduler"
    ]
    
    await asyncio.gather(*(run_worker(w) for w in workers))

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Shutting down workers...")
