"""Azure Blob Storage service — document upload, download, and deletion.

Blob hierarchy:
  Raw uploads:    {container}/{tenant_id}/{workspace_id}/{user_id}/{document_id}/{filename}
  Extracted text: {container}/{tenant_id}/{workspace_id}/extracted-text/{document_id}.txt

Uses the synchronous SDK wrapped in asyncio.to_thread() since the sync client is
battle-tested and the async client requires an extra aiohttp dependency.
"""

import asyncio
import logging

from azure.core.exceptions import ResourceNotFoundError
from azure.storage.blob import BlobServiceClient, ContentSettings

from app.core.config import settings

logger = logging.getLogger(__name__)


def _blob_path(
    tenant_id: str,
    workspace_id: str,
    user_id: str,
    document_id: str,
    filename: str,
) -> str:
    return f"{tenant_id}/{workspace_id}/{user_id}/{document_id}/{filename}"


def _extracted_text_path(tenant_id: str, workspace_id: str, document_id: str) -> str:
    return f"{tenant_id}/{workspace_id}/extracted-text/{document_id}.txt"


def _client() -> BlobServiceClient:
    return BlobServiceClient.from_connection_string(settings.storage_connection_string)


async def upload_document(
    *,
    tenant_id: str,
    workspace_id: str,
    user_id: str,
    document_id: str,
    filename: str,
    content: bytes,
    content_type: str,
) -> str:
    """Upload bytes to blob storage and return the blob URL."""
    path = _blob_path(tenant_id, workspace_id, user_id, document_id, filename)

    def _sync() -> str:
        client = _client()
        blob = client.get_blob_client(container=settings.storage_container, blob=path)
        blob.upload_blob(
            content,
            overwrite=True,
            content_settings=ContentSettings(content_type=content_type),
        )
        return blob.url

    url = await asyncio.to_thread(_sync)
    logger.info("Uploaded blob: %s", path)
    return url


async def download_document(blob_path: str) -> bytes:
    """Download the bytes for a previously-uploaded document blob.

    Used by the ingestion worker (Sprint 2.3) to feed Document Intelligence.

    Args:
        blob_path: path within the configured container, as returned by
            ``upload_document`` minus the URL prefix. Use the path stored on
            the queue message, not the absolute URL on the document record.

    Raises:
        ResourceNotFoundError: if the blob has already been deleted/purged.
    """

    def _sync() -> bytes:
        client = _client()
        blob = client.get_blob_client(container=settings.storage_container, blob=blob_path)
        downloader = blob.download_blob()
        return downloader.readall()

    content = await asyncio.to_thread(_sync)
    logger.info("Downloaded blob: %s (%d bytes)", blob_path, len(content))
    return content


async def upload_extracted_text(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
    text: str,
) -> str:
    """Persist extracted plain text to a sibling blob and return its path.

    Path is deterministic from ``document_id`` so re-extraction overwrites the
    same blob. The Cosmos record stores this path in
    ``extracted_text_blob_path``.
    """
    path = _extracted_text_path(tenant_id, workspace_id, document_id)
    encoded = text.encode("utf-8")

    def _sync() -> str:
        client = _client()
        blob = client.get_blob_client(container=settings.storage_container, blob=path)
        blob.upload_blob(
            encoded,
            overwrite=True,
            content_settings=ContentSettings(content_type="text/plain; charset=utf-8"),
        )
        return path

    result = await asyncio.to_thread(_sync)
    logger.info("Uploaded extracted text: %s (%d chars)", result, len(text))
    return result


async def download_extracted_text(blob_path: str) -> str:
    """Download a previously persisted extracted-text blob as a UTF-8 string.

    Sprint 2.5 topic extraction calls this to read the output of Sprint 2.3's
    Document Intelligence step. Falls back to ``replace`` on decode errors so
    a single bad byte doesn't kill the whole document's pipeline.

    Raises:
        ResourceNotFoundError: text blob was deleted/purged between status
            update and worker pickup.
    """
    content = await download_document(blob_path)
    return content.decode("utf-8", errors="replace")


async def delete_document(
    *,
    tenant_id: str,
    workspace_id: str,
    user_id: str,
    document_id: str,
    filename: str,
) -> None:
    """Permanently delete the raw upload. Ignores 404 (blob already gone)."""
    path = _blob_path(tenant_id, workspace_id, user_id, document_id, filename)

    await _delete_blob(path)


async def delete_extracted_text(
    *,
    tenant_id: str,
    workspace_id: str,
    document_id: str,
) -> None:
    """Permanently delete a document's extracted-text blob, if it exists."""
    path = _extracted_text_path(tenant_id, workspace_id, document_id)

    await _delete_blob(path)


async def _delete_blob(path: str) -> None:
    """Delete one blob path, treating an already-absent blob as success."""

    def _sync() -> None:
        try:
            client = _client()
            blob = client.get_blob_client(container=settings.storage_container, blob=path)
            blob.delete_blob(delete_snapshots="include")
        except ResourceNotFoundError:
            logger.warning("Blob already deleted: %s", path)

    await asyncio.to_thread(_sync)
    logger.info("Deleted blob: %s", path)
