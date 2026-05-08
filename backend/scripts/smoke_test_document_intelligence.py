"""Smoke test for Azure AI Document Intelligence — Sprint 2.1.

Reads a local file (PDF, image, DOCX, etc.), runs the prebuilt-read model via
the service wrapper, and prints extracted text + page count.

Run from the backend/ directory::

    python scripts/smoke_test_document_intelligence.py path/to/sample.pdf

Required env vars (loaded from backend/.env):

    DOCUMENT_INTELLIGENCE_ENDPOINT   e.g. https://di-ssa-dev-xxx.cognitiveservices.azure.com/
    DOCUMENT_INTELLIGENCE_KEY        from Key Vault secret 'document-intelligence-key'
"""

from __future__ import annotations

import asyncio
import mimetypes
import sys
from pathlib import Path

# Python's mimetypes registry doesn't know modern Office formats by default.
mimetypes.add_type(
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document", ".docx"
)
mimetypes.add_type(
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".xlsx"
)
mimetypes.add_type(
    "application/vnd.openxmlformats-officedocument.presentationml.presentation", ".pptx"
)


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return
    import os

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


async def _run(file_path: Path) -> int:
    from app.services.document_intelligence import extract_text

    content = file_path.read_bytes()
    content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    print(
        f"Analyzing {file_path.name} ({len(content):,} bytes, "
        f"content-type={content_type}) with prebuilt-read…"
    )

    extracted = await extract_text(content, content_type=content_type)

    print(f"\n  pages:     {extracted.page_count}")
    print(f"  languages: {extracted.languages or ['unknown']}")
    print(f"  chars:     {len(extracted.text):,}")
    print("\n--- first 500 chars ---")
    print(extracted.text[:500])
    print("--- end ---")
    return 0


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    file_path = Path(sys.argv[1]).expanduser().resolve()
    if not file_path.is_file():
        print(f"Error: {file_path} is not a readable file", file=sys.stderr)
        return 1

    backend_dir = Path(__file__).resolve().parent.parent
    for fname in (".env", ".env.dev"):
        _load_env_file(backend_dir / fname)
    sys.path.insert(0, str(backend_dir))

    return asyncio.run(_run(file_path))


if __name__ == "__main__":
    sys.exit(main())
