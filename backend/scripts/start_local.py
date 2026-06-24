"""
start_local.py — Single command to run the FastAPI server + all workers locally.

Usage:
    .venv\\Scripts\\python scripts\\start_local.py

This starts:
  - The FastAPI API server (uvicorn, --reload)
  - All background workers (document_ingestion, topic_extraction, chunking,
    vectorization, notification_scheduler)

Each worker restarts automatically if it exits (e.g. after draining the queue
with max_wait_seconds). This mirrors the Container Apps behaviour where the
worker process is always alive and ready to consume new messages.

Press Ctrl-C to stop everything.
"""

import asyncio
import sys
import signal
import os
from pathlib import Path

# ── Configuration ─────────────────────────────────────────────────────────────

API_HOST = "0.0.0.0"
API_PORT = 8000

WORKERS = [
    "document_ingestion",
    "topic_extraction",
    "chunking",
    "vectorization",
    "notification_scheduler",
]

# How long to wait before restarting a worker that exited cleanly (seconds).
# Workers exit after their max_wait_seconds (30 s) of idle time; we restart
# them immediately so they're ready for the next upload.
WORKER_RESTART_DELAY = 1

# ── Helpers ───────────────────────────────────────────────────────────────────

_shutdown = asyncio.Event()


async def _stream_output(name: str, stream: asyncio.StreamReader) -> None:
    """Print prefixed worker output lines to stdout."""
    while True:
        line = await stream.readline()
        if not line:
            break
        try:
            print(f"[{name}] {line.decode('utf-8', errors='replace').rstrip()}", flush=True)
        except Exception:
            pass


async def run_worker_forever(name: str) -> None:
    """Launch a worker subprocess and restart it whenever it exits (until shutdown)."""
    while not _shutdown.is_set():
        print(f"[{name}] Starting...", flush=True)
        try:
            proc = await asyncio.create_subprocess_exec(
                sys.executable, "-m", f"app.workers.{name}",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                cwd=Path(__file__).resolve().parent.parent,  # backend dir
            )
            await _stream_output(name, proc.stdout)
            await proc.wait()
            if not _shutdown.is_set():
                print(f"[{name}] Exited (code {proc.returncode}), restarting in {WORKER_RESTART_DELAY}s...", flush=True)
                await asyncio.sleep(WORKER_RESTART_DELAY)
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"[{name}] ERROR: {e} — retrying in {WORKER_RESTART_DELAY}s", flush=True)
            await asyncio.sleep(WORKER_RESTART_DELAY)

    print(f"[{name}] Shutdown.", flush=True)


async def run_api_server() -> None:
    """Launch uvicorn as a subprocess."""
    backend_dir = Path(__file__).resolve().parent.parent
    print(f"[api] Starting FastAPI on http://{API_HOST}:{API_PORT}", flush=True)
    try:
        proc = await asyncio.create_subprocess_exec(
            sys.executable, "-m", "uvicorn",
            "app.main:app",
            "--host", API_HOST,
            "--port", str(API_PORT),
            "--reload",
            "--log-level", "info",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            cwd=backend_dir,
        )
        await _stream_output("api", proc.stdout)
        await proc.wait()
        print(f"[api] Server exited (code {proc.returncode})", flush=True)
    except asyncio.CancelledError:
        pass


# ── Shutdown ──────────────────────────────────────────────────────────────────

def _request_shutdown(tasks: list[asyncio.Task]) -> None:
    """Signal all tasks to stop."""
    _shutdown.set()
    for t in tasks:
        t.cancel()


# ── Entry point ───────────────────────────────────────────────────────────────

async def main() -> None:
    tasks: list[asyncio.Task] = []

    # Start API server
    tasks.append(asyncio.create_task(run_api_server(), name="api"))

    # Start all workers (each in its own restart loop)
    for w in WORKERS:
        tasks.append(asyncio.create_task(run_worker_forever(w), name=w))

    # Install Ctrl-C handler
    loop = asyncio.get_running_loop()
    try:
        loop.add_signal_handler(signal.SIGINT,  lambda: _request_shutdown(tasks))
        loop.add_signal_handler(signal.SIGTERM, lambda: _request_shutdown(tasks))
    except NotImplementedError:
        # Windows — KeyboardInterrupt will handle it
        pass

    print("=" * 60, flush=True)
    print("  Local dev server running", flush=True)
    print(f"  API  : http://localhost:{API_PORT}", flush=True)
    print(f"  Workers: {', '.join(WORKERS)}", flush=True)
    print("  Press Ctrl-C to stop", flush=True)
    print("=" * 60, flush=True)

    try:
        await asyncio.gather(*tasks)
    except (KeyboardInterrupt, asyncio.CancelledError):
        _shutdown.set()
        # Cancel any still-running tasks
        for t in tasks:
            if not t.done():
                t.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        print("\n[main] All processes stopped. Goodbye.", flush=True)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
