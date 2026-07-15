"""Document upload and management endpoints.

Routes are nested under workspaces so the workspace_id is always present
in the path, making access checks straightforward.
"""

import asyncio
import html
import ipaddress
import logging
import mimetypes
import re
import socket
from typing import Annotated
from urllib.parse import urljoin, urlsplit
from uuid import uuid4

import httpx
from fastapi import APIRouter, Depends, File, UploadFile, status
from pydantic import BaseModel, HttpUrl

from app.core.auth import get_current_user
from app.core.database import DOCUMENTS, WORKSPACES, get_collection
from app.core.exceptions import ForbiddenError, NotFoundError, ValidationError
from app.models.base import utc_now
from app.models.document import Document, DocumentResponse, DocumentStatus, DocumentType
from app.models.user import User, UserRole
from app.services import blob_storage, document_queue
from app.services.document_queue import ExtractionMessage

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/workspaces/{workspace_id}/documents", tags=["documents"])

_ALLOWED_MIME_TO_TYPE: dict[str, DocumentType] = {
    "application/pdf": DocumentType.pdf,
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": DocumentType.docx,
    "image/jpeg": DocumentType.image,
    "image/png": DocumentType.image,
    "image/webp": DocumentType.image,
    "text/plain": DocumentType.text,
}

_MAX_FILE_BYTES = 50 * 1024 * 1024  # 50 MB
_MAX_SCRAPE_BYTES = 5 * 1024 * 1024  # 5 MB
_MAX_SCRAPE_REDIRECTS = 5
_SCRAPE_TIMEOUT_SECONDS = 20
_ALLOWED_SCRAPE_CONTENT_TYPES = {
    "application/xhtml+xml",
    "text/html",
    "text/plain",
}


class ScrapeRequest(BaseModel):
    url: HttpUrl


@router.post("/scrape", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def scrape_document(
    workspace_id: str,
    body: ScrapeRequest,
    current_user: User = Depends(get_current_user),
) -> DocumentResponse:
    """Fetch a public study page, store its text, and enqueue ingestion."""
    await _assert_admin(current_user, workspace_id)

    raw_bytes, content_type_header, final_url = await _fetch_public_document(str(body.url))
    if (
        content_type_header in {"text/html", "application/xhtml+xml"}
        or "<html" in raw_bytes[:256].decode("utf-8", errors="ignore").lower()
    ):
        text = _html_to_plain(raw_bytes.decode("utf-8", errors="replace"))
    else:
        text = raw_bytes.decode("utf-8", errors="replace").strip()

    if not text:
        raise ValidationError("Scraped page contained no readable text.")

    content = text.encode("utf-8")
    host = final_url.host or "website"
    path_slug = re.sub(r"[^a-zA-Z0-9_-]", "_", final_url.path.strip("/"))[:40]
    filename = f"scraped_{host}{'_' + path_slug if path_slug else ''}.txt"
    document_id = f"doc_{uuid4().hex}"
    blob_path = (
        f"{current_user.tenant_id}/{workspace_id}/{current_user.id}/{document_id}/{filename}"
    )

    blob_url = await blob_storage.upload_document(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        user_id=current_user.id,
        document_id=document_id,
        filename=filename,
        content=content,
        content_type="text/plain",
    )

    doc = Document(
        **{"_id": document_id},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        uploaded_by=current_user.id,
        filename=filename,
        blob_url=blob_url,
        file_size_bytes=len(content),
        doc_type=DocumentType.text,
    )
    col = get_collection(current_user.tenant_id, DOCUMENTS)
    await col.insert_one(doc.model_dump(by_alias=True))

    wsp_col = get_collection(current_user.tenant_id, WORKSPACES)
    await wsp_col.update_one(
        {"_id": workspace_id},
        {"$inc": {"document_count": 1}},
    )

    try:
        await document_queue.publish_extraction_message(
            ExtractionMessage(
                document_id=document_id,
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                blob_path=blob_path,
                content_type="text/plain",
                uploaded_by=current_user.id,
                uploaded_at=doc.created_at,
            )
        )
    except Exception as exc:
        logger.exception("Failed to publish extraction message for scraped doc %s", document_id)
        await col.update_one(
            {"_id": document_id, "workspace_id": workspace_id},
            {
                "$set": {
                    "status": DocumentStatus.failed.value,
                    "processing_error": f"Failed to enqueue for processing: {exc}",
                    "updated_at": utc_now(),
                }
            },
        )
        raise ValidationError(
            "Page was scraped but could not be queued for processing. Please try again."
        ) from exc

    return DocumentResponse.from_doc(doc)


async def _fetch_public_document(url: str) -> tuple[bytes, str, httpx.URL]:
    """Fetch a bounded text response while validating every redirect target."""
    current_url = httpx.URL(url)
    timeout = httpx.Timeout(_SCRAPE_TIMEOUT_SECONDS)

    async with httpx.AsyncClient(
        follow_redirects=False,
        timeout=timeout,
        trust_env=False,
    ) as client:
        for redirect_count in range(_MAX_SCRAPE_REDIRECTS + 1):
            await _assert_public_http_url(str(current_url))
            try:
                async with client.stream(
                    "GET",
                    current_url,
                    headers={"Accept": "text/html, application/xhtml+xml, text/plain"},
                ) as response:
                    if response.is_redirect:
                        if redirect_count >= _MAX_SCRAPE_REDIRECTS:
                            raise ValidationError("URL redirected too many times.")
                        location = response.headers.get("location")
                        if not location:
                            raise ValidationError("URL returned an invalid redirect.")
                        current_url = httpx.URL(urljoin(str(current_url), location))
                        continue

                    response.raise_for_status()
                    content_type = response.headers.get("content-type", "").split(";", 1)[0].lower()
                    if content_type not in _ALLOWED_SCRAPE_CONTENT_TYPES:
                        raise ValidationError(
                            "URL must return an HTML, XHTML, or plain-text study page."
                        )

                    content_length = response.headers.get("content-length")
                    if content_length:
                        try:
                            if int(content_length) > _MAX_SCRAPE_BYTES:
                                raise ValidationError(
                                    f"Scraped page exceeds the "
                                    f"{_MAX_SCRAPE_BYTES // (1024 * 1024)} MB limit."
                                )
                        except ValueError:
                            pass

                    content = bytearray()
                    async for chunk in response.aiter_bytes():
                        content.extend(chunk)
                        if len(content) > _MAX_SCRAPE_BYTES:
                            raise ValidationError(
                                f"Scraped page exceeds the "
                                f"{_MAX_SCRAPE_BYTES // (1024 * 1024)} MB limit."
                            )
                    if not content:
                        raise ValidationError("Scraped page returned no content.")
                    return bytes(content), content_type, current_url
            except ValidationError:
                raise
            except httpx.HTTPStatusError as exc:
                raise ValidationError(
                    f"Failed to fetch URL (HTTP {exc.response.status_code})."
                ) from exc
            except httpx.RequestError as exc:
                raise ValidationError("Could not reach the requested URL.") from exc

    raise ValidationError("URL redirected too many times.")


async def _assert_public_http_url(url: str) -> None:
    """Reject credentials, unusual ports, and non-public destination addresses."""
    parsed = urlsplit(url)
    if parsed.scheme not in {"http", "https"}:
        raise ValidationError("Only HTTP and HTTPS study URLs are supported.")
    if parsed.username is not None or parsed.password is not None:
        raise ValidationError("Study URLs cannot include credentials.")

    host = parsed.hostname
    if not host:
        raise ValidationError("Study URL must include a valid hostname.")
    try:
        port = parsed.port or (443 if parsed.scheme == "https" else 80)
    except ValueError as exc:
        raise ValidationError("Study URL contains an invalid port.") from exc
    if port not in {80, 443}:
        raise ValidationError("Study URLs may use only standard HTTP or HTTPS ports.")

    normalized_host = host.rstrip(".").lower()
    if normalized_host == "localhost" or normalized_host.endswith(
        (".localhost", ".local", ".internal")
    ):
        raise ValidationError("Private or local network URLs are not allowed.")

    try:
        addresses = {ipaddress.ip_address(normalized_host)}
    except ValueError:
        try:
            resolved = await asyncio.to_thread(
                socket.getaddrinfo,
                normalized_host,
                port,
                type=socket.SOCK_STREAM,
            )
        except socket.gaierror as exc:
            raise ValidationError("Study URL hostname could not be resolved.") from exc
        addresses = {ipaddress.ip_address(item[4][0].split("%", 1)[0]) for item in resolved}

    if not addresses or any(not address.is_global for address in addresses):
        raise ValidationError("Private or local network URLs are not allowed.")


def _html_to_plain(html_text: str) -> str:
    """Remove scripts, styles, markup, and excess whitespace from an HTML page."""
    text = re.sub(
        r"<(script|style)[^>]*>.*?</\1>",
        " ",
        html_text,
        flags=re.DOTALL | re.IGNORECASE,
    )
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return html.unescape(text).strip()


@router.post("", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def upload_document(
    workspace_id: str,
    file: Annotated[UploadFile, File(description="PDF, DOCX, image, or plain text — max 50 MB")],
    current_user: User = Depends(get_current_user),
) -> DocumentResponse:
    """Upload a study material file to blob storage and create a document record."""
    await _assert_admin(current_user, workspace_id)

    content_type = file.content_type or mimetypes.guess_type(file.filename or "")[0] or ""
    doc_type = _ALLOWED_MIME_TO_TYPE.get(content_type)
    if doc_type is None:
        raise ValidationError(
            f"Unsupported file type '{content_type}'. "
            "Accepted: PDF, DOCX, JPEG, PNG, WEBP, plain text."
        )

    content = await file.read()
    if len(content) == 0:
        raise ValidationError("Uploaded file is empty.")
    if len(content) > _MAX_FILE_BYTES:
        raise ValidationError("File exceeds the 50 MB size limit.")

    document_id = f"doc_{uuid4().hex}"
    filename = file.filename or f"{document_id}.bin"

    # Blob path matches the layout in app/services/blob_storage._blob_path.
    # Recomputed here (not extracted from the URL) so the queue payload stays
    # decoupled from the public URL format.
    blob_path = (
        f"{current_user.tenant_id}/{workspace_id}/{current_user.id}/{document_id}/{filename}"
    )

    blob_url = await blob_storage.upload_document(
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        user_id=current_user.id,
        document_id=document_id,
        filename=filename,
        content=content,
        content_type=content_type,
    )

    doc = Document(
        **{"_id": document_id},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        uploaded_by=current_user.id,
        filename=filename,
        blob_url=blob_url,
        file_size_bytes=len(content),
        doc_type=doc_type,
    )
    col = get_collection(current_user.tenant_id, DOCUMENTS)
    await col.insert_one(doc.model_dump(by_alias=True))

    # Update workspace document count
    wsp_col = get_collection(current_user.tenant_id, "workspaces")
    await wsp_col.update_one({"_id": workspace_id}, {"$inc": {"document_count": 1}})

    # Hand off to the ingestion worker. If publish fails, mark the document
    # failed in Cosmos so the admin sees a clear error instead of a phantom
    # 'pending' that never progresses. The 503 surfaces back to the client
    # so the upload retries land on a fresh document_id.
    try:
        await document_queue.publish_extraction_message(
            ExtractionMessage(
                document_id=document_id,
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                blob_path=blob_path,
                content_type=content_type,
                uploaded_by=current_user.id,
                uploaded_at=doc.created_at,
            )
        )
    except Exception as exc:
        logger.exception("Failed to publish extraction message for %s", document_id)
        await col.update_one(
            {"_id": document_id, "workspace_id": workspace_id},
            {
                "$set": {
                    "status": DocumentStatus.failed.value,
                    "processing_error": f"Failed to enqueue for processing: {exc}",
                    "updated_at": utc_now(),
                }
            },
        )
        raise ValidationError(
            "Document was uploaded but could not be queued for processing. Please try again."
        ) from exc

    return DocumentResponse.from_doc(doc)


@router.get("", response_model=list[DocumentResponse])
async def list_documents(
    workspace_id: str,
    current_user: User = Depends(get_current_user),
) -> list[DocumentResponse]:
    """List all non-deleted documents in a workspace."""
    _assert_workspace_access(current_user, workspace_id)
    col = get_collection(current_user.tenant_id, DOCUMENTS)
    cursor = col.find(
        {
            "workspace_id": workspace_id,
            "tenant_id": current_user.tenant_id,
            "deleted_at": None,
        }
    )
    return [DocumentResponse.from_doc(Document.model_validate(d)) async for d in cursor]


@router.get("/{document_id}", response_model=DocumentResponse)
async def get_document(
    workspace_id: str,
    document_id: str,
    current_user: User = Depends(get_current_user),
) -> DocumentResponse:
    """Fetch a single document's current state.

    Sprint 2.10's Flutter polling screen calls this every couple of seconds
    while the doc walks the ingestion state machine
    (``pending → … → ready | failed | flagged``). Filter includes
    ``deleted_at: None`` so a soft-deleted doc returns 404 — the polling
    UI should stop polling, not show stale state.
    """
    _assert_workspace_access(current_user, workspace_id)
    col = get_collection(current_user.tenant_id, DOCUMENTS)
    raw = await col.find_one(
        {
            "_id": document_id,
            "workspace_id": workspace_id,
            "tenant_id": current_user.tenant_id,
            "deleted_at": None,
        }
    )
    if raw is None:
        raise NotFoundError("Document", document_id)
    return DocumentResponse.from_doc(Document.model_validate(raw))


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    workspace_id: str,
    document_id: str,
    current_user: User = Depends(get_current_user),
) -> None:
    """Soft-delete a document record (blob is retained for audit; purge via worker)."""
    await _assert_admin(current_user, workspace_id)
    col = get_collection(current_user.tenant_id, DOCUMENTS)
    result = await col.update_one(
        {"_id": document_id, "workspace_id": workspace_id, "deleted_at": None},
        {"$set": {"deleted_at": utc_now(), "updated_at": utc_now()}},
    )
    if result.matched_count == 0:
        raise NotFoundError("Document", document_id)

    # Update workspace document count
    wsp_col = get_collection(current_user.tenant_id, "workspaces")
    await wsp_col.update_one({"_id": workspace_id}, {"$inc": {"document_count": -1}})


# ── Helpers ───────────────────────────────────────────────────────────────────


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")


async def _assert_admin(user: User, workspace_id: str) -> None:
    """Raise ForbiddenError if the user is not an admin of this workspace."""
    if user.role == UserRole.tenant_admin:
        return

    admin_memberships = {
        m.workspace_id
        for m in user.workspace_memberships
        if m.role in (UserRole.workspace_admin, UserRole.tenant_admin)
    }
    if workspace_id not in admin_memberships:
        raise ForbiddenError("You do not have admin access to this workspace")
