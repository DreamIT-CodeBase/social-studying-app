"""Azure Blob Storage service — document upload, download, and deletion.

Blob hierarchy:
  Raw uploads:    {container}/{tenant_id}/{workspace_id}/{user_id}/{document_id}/{filename}
  Extracted text: {container}/{tenant_id}/{workspace_id}/extracted-text/{document_id}.txt

Uses the synchronous SDK wrapped in asyncio.to_thread() since the sync client is
battle-tested and the async client requires an extra aiohttp dependency.
"""

import asyncio
import logging
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from azure.core.exceptions import ResourceNotFoundError
from azure.storage.blob import (
    BlobSasPermissions,
    BlobServiceClient,
    ContentSettings,
    generate_blob_sas,
)

from app.core.config import settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class DirectUploadTarget:
    """A short-lived, write-only URL for one exact document blob."""

    blob_url: str
    upload_url: str
    expires_at: datetime


@dataclass(frozen=True, slots=True)
class DocumentBlobProperties:
    """The committed source blob facts needed before queueing extraction."""

    size_bytes: int
    content_type: str | None


def _blob_path(
    tenant_id: str,
    workspace_id: str,
    user_id: str,
    document_id: str,
    filename: str,
) -> str:
    return f"{tenant_id}/{workspace_id}/{user_id}/{document_id}/{filename}"


def document_blob_path(
    *,
    tenant_id: str,
    workspace_id: str,
    user_id: str,
    document_id: str,
    filename: str,
) -> str:
    """Return the canonical raw-upload path shared by API and workers."""
    return _blob_path(tenant_id, workspace_id, user_id, document_id, filename)


def document_blob_url(blob_path: str) -> str:
    """Return the non-SAS URL for a stored raw document."""
    return (
        _client()
        .get_blob_client(
            container=settings.storage_container,
            blob=blob_path,
        )
        .url
    )


def _extracted_text_path(tenant_id: str, workspace_id: str, document_id: str) -> str:
    return f"{tenant_id}/{workspace_id}/extracted-text/{document_id}.txt"


def _client() -> BlobServiceClient:
    if not settings.storage_connection_string:
        raise RuntimeError("STORAGE_CONNECTION_STRING is not configured.")
    return BlobServiceClient.from_connection_string(settings.storage_connection_string)


def _connection_string_value(name: str) -> str:
    """Read one connection-string component without logging its secret value."""
    for component in settings.storage_connection_string.split(";"):
        key, separator, value = component.partition("=")
        if separator and key.strip().lower() == name.lower() and value:
            return value
    raise RuntimeError(f"Storage connection string is missing {name}.")


def _blob_sas_url(
    *,
    path: str,
    permissions: BlobSasPermissions,
    expires_at: datetime,
) -> str:
    """Create an HTTPS-only service SAS scoped to one blob path."""
    client = _client()
    sas = generate_blob_sas(
        account_name=_connection_string_value("AccountName"),
        container_name=settings.storage_container,
        blob_name=path,
        account_key=_connection_string_value("AccountKey"),
        permission=permissions,
        # Allow a small clock-skew window for devices whose time is behind.
        start=datetime.now(UTC) - timedelta(minutes=5),
        expiry=expires_at,
        protocol="https",
    )
    blob = client.get_blob_client(container=settings.storage_container, blob=path)
    return f"{blob.url}?{sas}"


def create_direct_upload_target(
    *,
    tenant_id: str,
    workspace_id: str,
    user_id: str,
    document_id: str,
    filename: str,
    expires_in_minutes: int | None = None,
) -> DirectUploadTarget:
    """Authorize chunked upload of one new blob without exposing account keys.

    The client receives only ``create`` and ``write`` permissions for the
    generated path.  It cannot list, read, or delete any document blob.
    """
    path = _blob_path(tenant_id, workspace_id, user_id, document_id, filename)
    expires_at = datetime.now(UTC) + timedelta(
        minutes=expires_in_minutes or settings.direct_upload_sas_ttl_minutes
    )
    client = _client()
    blob = client.get_blob_client(container=settings.storage_container, blob=path)
    return DirectUploadTarget(
        blob_url=blob.url,
        upload_url=_blob_sas_url(
            path=path,
            permissions=BlobSasPermissions(create=True, write=True),
            expires_at=expires_at,
        ),
        expires_at=expires_at,
    )


async def get_document_properties(blob_path: str) -> DocumentBlobProperties:
    """Read committed blob facts before creating a document database record."""

    def _sync() -> DocumentBlobProperties:
        client = _client()
        blob = client.get_blob_client(container=settings.storage_container, blob=blob_path)
        properties = blob.get_blob_properties()
        content_settings = properties.content_settings
        return DocumentBlobProperties(
            size_bytes=properties.size,
            content_type=content_settings.content_type if content_settings else None,
        )

    return await asyncio.to_thread(_sync)


def create_blob_read_url(blob_path: str, *, expires_in_minutes: int = 30) -> str:
    """Issue a short-lived read URL for Document Intelligence ingestion."""
    return _blob_sas_url(
        path=blob_path,
        permissions=BlobSasPermissions(read=True),
        expires_at=datetime.now(UTC) + timedelta(minutes=expires_in_minutes),
    )


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
