"""Document model — study material uploaded by a workspace admin."""

from enum import StrEnum

from pydantic import Field

from app.models.base import CosmosDocument


class DocumentStatus(StrEnum):
    pending = "pending"          # queued for ingestion
    processing = "processing"    # being chunked / embedded
    ready = "ready"              # embeddings stored; questions can be generated
    failed = "failed"


class DocumentType(StrEnum):
    pdf = "pdf"
    docx = "docx"
    image = "image"
    text = "text"


class TopicTag(CosmosDocument.__base__):
    name: str
    confidence: float = Field(ge=0.0, le=1.0)
    source: str = "ai"  # "ai" or "admin"


class Document(CosmosDocument):
    """Partition key: workspace_id.

    Stored in the tenant's database, 'documents' collection.
    """

    tenant_id: str
    workspace_id: str
    uploaded_by: str         # user_id
    filename: str
    blob_url: str
    file_size_bytes: int
    doc_type: DocumentType
    status: DocumentStatus = DocumentStatus.pending
    chunk_count: int = 0
    topic_tags: list[TopicTag] = Field(default_factory=list)
    processing_error: str | None = None
    moderation_flagged: bool = False


class DocumentResponse(CosmosDocument.__base__):
    id: str
    workspace_id: str
    filename: str
    doc_type: DocumentType
    status: DocumentStatus
    chunk_count: int
    topic_tags: list[TopicTag]
    moderation_flagged: bool
    created_at: str

    @classmethod
    def from_doc(cls, doc: Document) -> "DocumentResponse":
        return cls(
            id=doc.id,
            workspace_id=doc.workspace_id,
            filename=doc.filename,
            doc_type=doc.doc_type,
            status=doc.status,
            chunk_count=doc.chunk_count,
            topic_tags=doc.topic_tags,
            moderation_flagged=doc.moderation_flagged,
            created_at=doc.created_at,
        )
