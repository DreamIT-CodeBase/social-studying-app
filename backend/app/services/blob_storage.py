"""Azure Blob Storage service — document upload and deletion.

Blob hierarchy: {container}/{tenant_id}/{workspace_id}/{user_id}/{document_id}/{filename}

Uses the synchronous SDK wrapped in asyncio.to_thread() since the sync client is
battle-tested and the async client requires an extra aiohttp dependency.
"""

import asyncio
import logging

from azure.core.exceptions import ResourceNotFoundError
from azure.storage.blob import BlobServiceClient, ContentSettings

from app.core.config import settings

logger = logging.getLogger(__name__)


def _blob_path(tenant_id: str, workspace_id: str, user_id: str, document_id: str, filename: str) -> str:
    return f"{tenant_id}/{workspace_id}/{user_id}/{document_id}/{filename}"


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


async def delete_document(
    *,
    tenant_id: str,
    workspace_id: str,
    user_id: str,
    document_id: str,
    filename: str,
) -> None:
    """Soft-delete the blob. Ignores 404 (blob already gone)."""
    path = _blob_path(tenant_id, workspace_id, user_id, document_id, filename)

    def _sync() -> None:
        try:
            client = _client()
            blob = client.get_blob_client(container=settings.storage_container, blob=path)
            blob.delete_blob(delete_snapshots="include")
        except ResourceNotFoundError:
            logger.warning("Blob already deleted: %s", path)

    await asyncio.to_thread(_sync)
    logger.info("Deleted blob: %s", path)
