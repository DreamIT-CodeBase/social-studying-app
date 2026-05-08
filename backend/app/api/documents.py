"""Document upload and management endpoints.

Routes are nested under workspaces so the workspace_id is always present
in the path, making access checks straightforward.
"""

import mimetypes
from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, File, UploadFile, status

from app.core.auth import get_current_user, require_role
from app.core.database import DOCUMENTS, get_collection
from app.core.exceptions import ForbiddenError, NotFoundError, ValidationError
from app.models.base import utc_now
from app.models.document import Document, DocumentResponse, DocumentType
from app.models.user import User, UserRole
from app.services import blob_storage

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


@router.post("", response_model=DocumentResponse, status_code=status.HTTP_201_CREATED)
async def upload_document(
    workspace_id: str,
    file: Annotated[UploadFile, File(description="PDF, DOCX, image, or plain text — max 50 MB")],
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> DocumentResponse:
    """Upload a study material file to blob storage and create a document record."""
    _assert_workspace_access(current_user, workspace_id)

    content_type = (
        file.content_type
        or mimetypes.guess_type(file.filename or "")[0]
        or ""
    )
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


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    workspace_id: str,
    document_id: str,
    current_user: User = Depends(require_role(UserRole.tenant_admin, UserRole.workspace_admin)),
) -> None:
    """Soft-delete a document record (blob is retained for audit; purge via worker)."""
    _assert_workspace_access(current_user, workspace_id)
    col = get_collection(current_user.tenant_id, DOCUMENTS)
    result = await col.update_one(
        {"_id": document_id, "workspace_id": workspace_id, "deleted_at": None},
        {"$set": {"deleted_at": utc_now(), "updated_at": utc_now()}},
    )
    if result.matched_count == 0:
        raise NotFoundError("Document", document_id)


# ── Helpers ───────────────────────────────────────────────────────────────────


def _assert_workspace_access(user: User, workspace_id: str) -> None:
    if user.role == UserRole.tenant_admin:
        return
    ids = {m.workspace_id for m in user.workspace_memberships}
    if workspace_id not in ids:
        raise ForbiddenError("You are not a member of this workspace")
