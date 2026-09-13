"""Document upload and management endpoints.

Routes are nested under workspaces so the workspace_id is always present
in the path, making access checks straightforward.
"""

import asyncio
import base64
import hashlib
import hmac
import html
import ipaddress
import json
import logging
import mimetypes
import re
import socket
import time
from typing import Annotated
from urllib.parse import urljoin, urlsplit
from uuid import uuid4

import httpx
from azure.core.exceptions import ResourceNotFoundError
from fastapi import APIRouter, Depends, File, UploadFile, status
from pydantic import BaseModel, Field, HttpUrl
from pydantic import ValidationError as PydanticValidationError

from app.core.auth import get_current_user
from app.core.config import settings
from app.core.database import DOCUMENTS, WORKSPACES, get_collection
from app.core.exceptions import (
    ForbiddenError,
    NotFoundError,
    ServiceUnavailableError,
    ValidationError,
)
from app.models.base import utc_now
from app.models.document import (
    Document,
    DocumentResponse,
    DocumentStatus,
    DocumentType,
    DocumentUpdateRequest,
)
from app.models.user import User, UserRole
from app.services import blob_storage, document_purge, document_queue
from app.services.cosmos_retry import run_with_throttle_retry
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

# Compatibility ceiling for already-released mobile builds, which still send
# the entire multipart body through Container Apps.  New clients use the
# direct Blob flow below and can use the full Document Intelligence S0 limit.
_MAX_FILE_BYTES = 100 * 1024 * 1024  # 100 MB
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


class DirectUploadRequest(BaseModel):
    """Metadata that is safe to send before the file body reaches Blob Storage."""

    filename: str = Field(min_length=1, max_length=255)
    content_type: str = Field(min_length=1, max_length=255)
    file_size_bytes: int = Field(gt=0)


class DirectUploadResponse(BaseModel):
    document_id: str
    upload_url: str
    upload_token: str
    block_size_bytes: int
    expires_at: str
    max_file_size_bytes: int


class DirectUploadCompleteRequest(BaseModel):
    upload_token: str = Field(min_length=1)


class _DirectUploadSession(BaseModel):
    document_id: str
    tenant_id: str
    workspace_id: str
    uploaded_by: str
    filename: str
    content_type: str
    file_size_bytes: int
    expires_at: int


@router.post("/scrape", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def scrape_document(
    workspace_id: str,
    body: ScrapeRequest,
    current_user: User = Depends(get_current_user),
) -> DocumentResponse:
    """Fetch a public study page, store its text, and enqueue ingestion."""
    # Self-study material belongs to the learner. Workspace membership is
    # sufficient for scraping public pages; SSRF and size limits still apply.
    _assert_workspace_access(current_user, workspace_id)

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
                    headers={
                        "Accept": "text/html, application/xhtml+xml, text/plain",
                        "User-Agent": "Mozilla/5.0 (compatible; SocialStudyingBot/1.0)",
                    },
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
    """Extract readable page text, including useful metadata for JS-heavy pages."""
    metadata = re.findall(
        r'<meta[^>]+(?:name|property)=["\'](?:description|og:description)["\'][^>]+content=["\']([^"\']+)',
        html_text,
        flags=re.IGNORECASE,
    )
    title = re.findall(r"<title[^>]*>(.*?)</title>", html_text, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(
        r"<(script|style)[^>]*>.*?</\1>",
        " ",
        html_text,
        flags=re.DOTALL | re.IGNORECASE,
    )
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    readable = html.unescape(text).strip()
    supplements = [html.unescape(value).strip() for value in [*title, *metadata] if value.strip()]
    if supplements:
        readable = "\n\n".join(dict.fromkeys([*supplements, readable]))
    return readable.strip()


@router.post(
    "/uploads",
    response_model=DirectUploadResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_direct_upload(
    workspace_id: str,
    body: DirectUploadRequest,
    current_user: User = Depends(get_current_user),
) -> DirectUploadResponse:
    """Authorize a resumable, direct-to-Blob document upload.

    File bytes deliberately never pass through FastAPI or Container Apps.  The
    returned SAS can create/write exactly one blob and expires quickly; the
    follow-up ``/complete`` call verifies the committed blob before it is
    queued for ingestion.
    """
    await _assert_admin(current_user, workspace_id)
    filename = _safe_filename(body.filename)
    content_type, _ = _validate_upload_metadata(
        filename=filename,
        content_type=body.content_type,
        file_size_bytes=body.file_size_bytes,
        maximum_size_bytes=settings.max_document_upload_bytes,
    )
    document_id = f"doc_{uuid4().hex}"

    try:
        target = blob_storage.create_direct_upload_target(
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            user_id=current_user.id,
            document_id=document_id,
            filename=filename,
        )
    except Exception as exc:
        logger.exception("Could not create direct upload target for %s", document_id)
        raise ServiceUnavailableError("Document storage is temporarily unavailable.") from exc

    upload_token = _sign_direct_upload_session(
        _DirectUploadSession(
            document_id=document_id,
            tenant_id=current_user.tenant_id,
            workspace_id=workspace_id,
            uploaded_by=current_user.id,
            filename=filename,
            content_type=content_type,
            file_size_bytes=body.file_size_bytes,
            expires_at=int(target.expires_at.timestamp()),
        )
    )
    return DirectUploadResponse(
        document_id=document_id,
        upload_url=target.upload_url,
        upload_token=upload_token,
        block_size_bytes=settings.direct_upload_block_size_bytes,
        expires_at=target.expires_at.isoformat(),
        max_file_size_bytes=settings.max_document_upload_bytes,
    )


@router.post(
    "/uploads/{document_id}/complete",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def complete_direct_upload(
    workspace_id: str,
    document_id: str,
    body: DirectUploadCompleteRequest,
    current_user: User = Depends(get_current_user),
) -> DocumentResponse:
    """Verify a direct Blob upload, create its record, and queue processing."""
    await _assert_admin(current_user, workspace_id)
    session = _verify_direct_upload_session(body.upload_token)
    if (
        session.document_id != document_id
        or session.tenant_id != current_user.tenant_id
        or session.workspace_id != workspace_id
        or session.uploaded_by != current_user.id
    ):
        raise ForbiddenError("This upload authorization does not belong to your account.")

    blob_path = blob_storage.document_blob_path(
        tenant_id=session.tenant_id,
        workspace_id=session.workspace_id,
        user_id=session.uploaded_by,
        document_id=session.document_id,
        filename=session.filename,
    )
    col = get_collection(current_user.tenant_id, DOCUMENTS)

    # A lost response after a successful finalization is a normal mobile
    # network failure.  Returning the existing record makes the completion
    # call idempotent and prevents duplicate queue messages/count increments.
    existing = await col.find_one({"_id": document_id, "workspace_id": workspace_id})
    if existing is not None:
        return DocumentResponse.from_doc(Document.model_validate(existing))

    try:
        properties = await blob_storage.get_document_properties(blob_path)
    except ResourceNotFoundError as exc:
        raise ValidationError("Upload was not completed. Please upload the file again.") from exc
    except Exception as exc:
        logger.exception("Could not verify direct upload %s", document_id)
        raise ServiceUnavailableError(
            "Could not verify the uploaded file. Please try again."
        ) from exc

    if properties.size_bytes != session.file_size_bytes:
        raise ValidationError("Uploaded file size did not match the selected file. Please retry.")
    actual_content_type = _normalized_content_type(properties.content_type or "")
    if actual_content_type != session.content_type:
        raise ValidationError("Uploaded file type did not match the selected file. Please retry.")

    _, doc_type = _validate_upload_metadata(
        filename=session.filename,
        content_type=session.content_type,
        file_size_bytes=properties.size_bytes,
        maximum_size_bytes=settings.max_document_upload_bytes,
    )
    doc = Document(
        **{"_id": document_id},
        tenant_id=current_user.tenant_id,
        workspace_id=workspace_id,
        uploaded_by=current_user.id,
        filename=session.filename,
        blob_url=blob_storage.document_blob_url(blob_path),
        file_size_bytes=properties.size_bytes,
        doc_type=doc_type,
    )
    await col.insert_one(doc.model_dump(by_alias=True))

    wsp_col = get_collection(current_user.tenant_id, WORKSPACES)
    await wsp_col.update_one({"_id": workspace_id}, {"$inc": {"document_count": 1}})

    try:
        await document_queue.publish_extraction_message(
            ExtractionMessage(
                document_id=document_id,
                tenant_id=current_user.tenant_id,
                workspace_id=workspace_id,
                blob_path=blob_path,
                content_type=session.content_type,
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
        raise ServiceUnavailableError(
            "Document was uploaded but could not be queued for processing. Please try again."
        ) from exc

    return DocumentResponse.from_doc(doc)


@router.post("", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def upload_document(
    workspace_id: str,
    file: Annotated[UploadFile, File(description="PDF, DOCX, image, or plain text — max 50 MB")],
    current_user: User = Depends(get_current_user),
) -> DocumentResponse:
    """Upload a study material file to blob storage and create a document record."""
    await _assert_admin(current_user, workspace_id)

    content = await file.read()
    document_id = f"doc_{uuid4().hex}"
    filename = _safe_filename(file.filename or f"{document_id}.bin")
    content_type, doc_type = _validate_upload_metadata(
        filename=filename,
        content_type=file.content_type or mimetypes.guess_type(filename)[0] or "",
        file_size_bytes=len(content),
        maximum_size_bytes=_MAX_FILE_BYTES,
    )

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


@router.patch("/{document_id}", response_model=DocumentResponse)
async def update_document(
    workspace_id: str,
    document_id: str,
    body: DocumentUpdateRequest,
    current_user: User = Depends(get_current_user),
) -> DocumentResponse:
    """Update document category, subcategory, or moderation status."""
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

    updates: dict = {"updated_at": utc_now()}
    if body.category is not None:
        updates["category"] = body.category.strip()
    if body.subcategory is not None:
        updates["subcategory"] = body.subcategory.strip()
    if body.moderation_flagged is not None:
        updates["moderation_flagged"] = body.moderation_flagged

    await col.update_one(
        {"_id": document_id, "workspace_id": workspace_id},
        {"$set": updates},
    )
    updated_raw = await col.find_one({"_id": document_id, "workspace_id": workspace_id})
    return DocumentResponse.from_doc(Document.model_validate(updated_raw))


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    workspace_id: str,
    document_id: str,
    current_user: User = Depends(get_current_user),
) -> None:
    """Permanently erase a study material and every stored derivative."""
    await _assert_admin(current_user, workspace_id)
    col = get_collection(current_user.tenant_id, DOCUMENTS)
    raw = await run_with_throttle_retry(
        lambda: col.find_one(
            {
                "_id": document_id,
                "workspace_id": workspace_id,
                "tenant_id": current_user.tenant_id,
            }
        ),
        operation_name=f"read document {document_id} for purge",
    )
    if raw is None:
        raise NotFoundError("Document", document_id)

    document = Document.model_validate(raw)
    purge_started_at = document.deleted_at or utc_now()
    if document.deleted_at is None:
        marker = await run_with_throttle_retry(
            lambda: col.update_one(
                {
                    "_id": document_id,
                    "workspace_id": workspace_id,
                    "tenant_id": current_user.tenant_id,
                    "deleted_at": None,
                },
                {"$set": {"deleted_at": purge_started_at, "updated_at": purge_started_at}},
            ),
            operation_name=f"mark document {document_id} for purge",
        )
        if marker.matched_count == 0:
            raise NotFoundError("Document", document_id)

    try:
        await document_purge.purge_document(document=document)
    except Exception as exc:
        logger.exception("Permanent purge failed for document=%s", document_id)
        # Make the row visible again so the admin can retry the idempotent
        # purge instead of being left with an inaccessible partial deletion.
        try:
            await run_with_throttle_retry(
                lambda: col.update_one(
                    {"_id": document_id, "deleted_at": purge_started_at},
                    {"$set": {"deleted_at": None, "updated_at": utc_now()}},
                ),
                operation_name=f"restore document {document_id} after failed purge",
            )
        except Exception:
            # Never let a failed recovery write replace the intentional 503
            # with an unhandled 500. A later DELETE can resume a marked row.
            logger.exception("Could not restore document=%s after failed purge", document_id)
        raise ServiceUnavailableError(
            "The study material could not be completely deleted. Please try again."
        ) from exc


# ── Helpers ───────────────────────────────────────────────────────────────────


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")


def _safe_filename(filename: str) -> str:
    """Keep user filenames in one blob path segment and reject controls."""
    basename = filename.replace("\\", "/").rsplit("/", 1)[-1].strip()
    if not basename or basename in {".", ".."}:
        raise ValidationError("Uploaded file must have a valid filename.")
    if any(ord(char) < 32 for char in basename):
        raise ValidationError("Uploaded filename contains unsupported characters.")
    if len(basename) > 255:
        raise ValidationError("Uploaded filename is too long.")
    return basename


def _normalized_content_type(content_type: str) -> str:
    return content_type.split(";", 1)[0].strip().lower()


def _validate_upload_metadata(
    *,
    filename: str,
    content_type: str,
    file_size_bytes: int,
    maximum_size_bytes: int,
) -> tuple[str, DocumentType]:
    """Validate the same contract for legacy and direct upload paths."""
    normalized_content_type = _normalized_content_type(content_type)
    doc_type = _ALLOWED_MIME_TO_TYPE.get(normalized_content_type)
    if doc_type is None:
        guessed_type = _normalized_content_type(mimetypes.guess_type(filename)[0] or "")
        doc_type = _ALLOWED_MIME_TO_TYPE.get(guessed_type)
        if doc_type is not None:
            normalized_content_type = guessed_type
    if doc_type is None:
        raise ValidationError(
            f"Unsupported file type '{content_type}'. "
            "Accepted: PDF, DOCX, JPEG, PNG, WEBP, plain text."
        )
    if file_size_bytes <= 0:
        raise ValidationError("Uploaded file is empty.")
    if file_size_bytes > maximum_size_bytes:
        maximum_mb = maximum_size_bytes // (1024 * 1024)
        file_size_mb = round(file_size_bytes / (1024 * 1024), 1)
        raise ValidationError(
            f"File size ({file_size_mb} MB) exceeds the {maximum_mb} MB document size limit. "
            "Please split large documents into individual chapters or compress the PDF before uploading."
        )
    return normalized_content_type, doc_type


def _upload_session_key() -> bytes:
    """Use the server-only storage connection string as the token signing key."""
    if not settings.storage_connection_string:
        raise ServiceUnavailableError("Document storage is temporarily unavailable.")
    return settings.storage_connection_string.encode("utf-8")


def _url_safe_b64_decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def _sign_direct_upload_session(session: _DirectUploadSession) -> str:
    payload = json.dumps(
        session.model_dump(),
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    payload_b64 = base64.urlsafe_b64encode(payload).rstrip(b"=")
    signature = hmac.new(_upload_session_key(), payload_b64, hashlib.sha256).digest()
    signature_b64 = base64.urlsafe_b64encode(signature).rstrip(b"=")
    return f"{payload_b64.decode('ascii')}.{signature_b64.decode('ascii')}"


def _verify_direct_upload_session(token: str) -> _DirectUploadSession:
    try:
        payload_b64, signature_b64 = token.split(".", 1)
        payload = payload_b64.encode("ascii")
        expected_signature = hmac.new(_upload_session_key(), payload, hashlib.sha256).digest()
        provided_signature = _url_safe_b64_decode(signature_b64)
        if not hmac.compare_digest(expected_signature, provided_signature):
            raise ValueError("signature mismatch")
        session = _DirectUploadSession.model_validate_json(_url_safe_b64_decode(payload_b64))
    except (UnicodeEncodeError, ValueError, PydanticValidationError) as exc:
        raise ValidationError(
            "Upload authorization is invalid. Please start the upload again."
        ) from exc

    if session.expires_at < int(time.time()):
        raise ValidationError("Upload authorization expired. Please start the upload again.")
    return session


async def _assert_admin(user: User, workspace_id: str) -> None:
    """Raise ForbiddenError if the user is not an admin of this workspace."""
    if user.role == UserRole.tenant_admin:
        return

    if (
        workspace_id.startswith("wsp_self_")
        or workspace_id.startswith("wsp_personal_")
        or user.id in workspace_id
    ):
        ids = {m.workspace_id for m in user.workspace_memberships}
        if workspace_id in ids or user.id in workspace_id:
            return

    admin_memberships = {
        m.workspace_id
        for m in user.workspace_memberships
        if m.role in (UserRole.workspace_admin, UserRole.tenant_admin)
    }
    if workspace_id not in admin_memberships:
        raise ForbiddenError("You do not have admin access to this workspace")


@router.post("/{document_id}/approve", response_model=DocumentResponse)
async def approve_document(
    workspace_id: str,
    document_id: str,
    current_user: User = Depends(get_current_user),
) -> DocumentResponse:
    """Approve a flagged document, clear the safety flag, and resume ingestion."""
    await _assert_admin(current_user, workspace_id)
    tenant_id = current_user.tenant_id
    doc_col = get_collection(tenant_id, DOCUMENTS)
    doc_raw = await doc_col.find_one(
        {"_id": document_id, "workspace_id": workspace_id, "deleted_at": None}
    )
    if doc_raw is None:
        raise NotFoundError("Document", document_id)

    doc = Document.model_validate(doc_raw)
    if doc.status != DocumentStatus.flagged:
        return DocumentResponse.from_doc(doc)

    # Clear flag and resume at text_extracted (or pending if text not yet extracted)
    resume_status = (
        DocumentStatus.text_extracted
        if doc.extracted_text
        else DocumentStatus.pending
    )
    now = utc_now()
    await doc_col.update_one(
        {"_id": document_id},
        {
            "$set": {
                "status": resume_status.value,
                "processing_error": None,
                "updated_at": now,
            }
        },
    )

    from app.core.database import MODERATION_LOG
    from app.models.moderation import ModerationAction
    mod_col = get_collection(tenant_id, MODERATION_LOG)
    await mod_col.update_many(
        {"target_id": document_id, "workspace_id": workspace_id, "action": ModerationAction.flagged.value},
        {"$set": {"action": ModerationAction.approved.value, "performed_by": current_user.id, "updated_at": now}},
    )

    if resume_status == DocumentStatus.text_extracted:
        await document_queue.enqueue_topic_extraction(
            tenant_id=tenant_id,
            workspace_id=workspace_id,
            document_id=document_id,
        )
    else:
        await document_queue.enqueue_extraction(
            ExtractionMessage(
                tenant_id=tenant_id,
                workspace_id=workspace_id,
                document_id=document_id,
                blob_path=doc.blob_path,
                document_type=doc.document_type.value,
            )
        )

    updated_raw = await doc_col.find_one({"_id": document_id})
    return DocumentResponse.from_doc(Document.model_validate(updated_raw))

