"""Document model — study material uploaded by a workspace admin."""

from enum import StrEnum

from pydantic import Field

from app.models.base import CosmosDocument


class DocumentStatus(StrEnum):
    """State machine for the ingestion pipeline.

    Owned by Sprint 2.3:        pending → extracting → text_extracted | failed
    Owned by Sprint 2.4:        extracting → flagged (terminal, admin review)
    Owned by Sprint 2.5:        text_extracted → extracting_topics → topics_extracted | failed
    Owned by 2.8/2.9 (TBD):     topics_extracted → processing → ready

    `pending` is the upload-time state (queued for worker pickup). Kept the
    name `pending` (not `queued`) for backwards compatibility with Sprint 1
    tests; semantically identical.
    """

    pending = "pending"                          # 2.2: uploaded, queued for the extractor
    extracting = "extracting"                    # 2.3: worker has the message, DI call in flight
    text_extracted = "text_extracted"            # 2.3+2.4: text persisted AND screened clean
    extracting_topics = "extracting_topics"      # 2.5: topic worker has the doc, GPT-4o in flight
    topics_extracted = "topics_extracted"        # 2.5: topics persisted, awaiting chunking
    processing = "processing"                    # 2.8+: chunking / embedding (placeholder for now)
    ready = "ready"                              # final: questions can be generated
    flagged = "flagged"                          # 2.4: content safety flagged — admin review
    failed = "failed"                            # terminal failure


class DocumentType(StrEnum):
    pdf = "pdf"
    docx = "docx"
    image = "image"
    text = "text"


class TopicTag(CosmosDocument.__base__):
    """A topic identified within a single document.

    Sprint 2.5 fills the rich fields (description, complexity_level, page_refs)
    from the GPT-4o extraction call. Sprint 2.6's taxonomy merge then maps a
    document's TopicTags onto the workspace-level canonical taxonomy.
    """

    name: str
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    source: str = "ai"  # "ai" or "admin"

    # Sprint 2.5 — populated by the topic extraction worker.
    description: str | None = None
    # 1 = elementary, 5 = advanced. Reflects depth of treatment in THIS source.
    complexity_level: int | None = Field(default=None, ge=1, le=5)
    page_refs: list[int] = Field(default_factory=list)


class Document(CosmosDocument):
    """Partition key: workspace_id.

    Stored in the tenant's database, 'documents' collection.
    """

    tenant_id: str
    workspace_id: str
    uploaded_by: str         # user_id
    filename: str
    blob_url: str            # raw uploaded file
    file_size_bytes: int
    doc_type: DocumentType
    status: DocumentStatus = DocumentStatus.pending
    chunk_count: int = 0
    topic_tags: list[TopicTag] = Field(default_factory=list)
    processing_error: str | None = None
    moderation_flagged: bool = False

    # ── Sprint 2.3: text extraction outputs ───────────────────────────────────
    extracted_text_blob_path: str | None = None  # blob path within container
    text_char_count: int | None = None
    page_count: int | None = None
    languages: list[str] = Field(default_factory=list)
    processing_started_at: str | None = None     # ISO 8601 UTC
    processing_completed_at: str | None = None   # ISO 8601 UTC


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
    # Surface ingestion progress so the Flutter polling screen (2.10) can render.
    page_count: int | None = None
    text_char_count: int | None = None
    languages: list[str] = Field(default_factory=list)
    processing_error: str | None = None

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
            page_count=doc.page_count,
            text_char_count=doc.text_char_count,
            languages=doc.languages,
            processing_error=doc.processing_error,
        )
