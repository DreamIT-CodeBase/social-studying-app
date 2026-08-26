"""Azure AI Document Intelligence — text extraction for uploaded study materials.

Sprint 2.1 sets up the SDK wrapper. The Sprint 2.3 ingestion worker calls
``extract_text`` to pull plain text out of PDFs, images, and Word documents
before topic extraction and chunking run.

We standardize on the ``prebuilt-read`` model (text + OCR only, no layout).
See ``memory/document_intelligence_decisions.md`` for the rationale.

The Azure SDK ships only a synchronous client for analyze operations, so calls
are wrapped in ``asyncio.to_thread`` to keep the event loop free.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass

from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.ai.documentintelligence.models import AnalyzeDocumentRequest, AnalyzeResult
from azure.core.credentials import AzureKeyCredential

from app.core.config import settings
from app.core.exceptions import ServiceUnavailableError

logger = logging.getLogger(__name__)

_PREBUILT_READ = "prebuilt-read"


@dataclass(frozen=True, slots=True)
class ExtractedDocument:
    """Result of running Document Intelligence on a single file."""

    text: str
    page_count: int
    languages: list[str]


def _client() -> DocumentIntelligenceClient:
    if not settings.document_intelligence_endpoint or not settings.document_intelligence_key:
        raise ServiceUnavailableError(
            "Document Intelligence is not configured "
            "(set DOCUMENT_INTELLIGENCE_ENDPOINT and DOCUMENT_INTELLIGENCE_KEY)."
        )
    return DocumentIntelligenceClient(
        endpoint=settings.document_intelligence_endpoint,
        credential=AzureKeyCredential(settings.document_intelligence_key),
    )


def _to_extracted(result: AnalyzeResult) -> ExtractedDocument:
    text = (result.content or "").strip()
    pages = result.pages or []
    languages = sorted({lang.locale for lang in (result.languages or []) if lang.locale})
    return ExtractedDocument(text=text, page_count=len(pages), languages=languages)


async def extract_text(
    content: bytes,
    *,
    content_type: str = "application/octet-stream",
) -> ExtractedDocument:
    """Extract plain text and metadata from a document's raw bytes.

    Accepts any format Document Intelligence supports (PDF, DOCX, PPTX, XLSX,
    HTML, JPEG, PNG, BMP, TIFF, HEIF). Returns the concatenated text in reading
    order plus page count and detected language locales.

    Args:
        content: raw file bytes.
        content_type: MIME type. ``application/octet-stream`` works for PDFs and
            images (the service sniffs magic bytes), but Office formats (DOCX,
            XLSX, PPTX) are ZIP-based and require their explicit MIME type or
            the service rejects them with ``UnsupportedContent``. Pass the value
            from the upload's ``Content-Type`` header.

    Raises:
        ServiceUnavailableError: if the Document Intelligence credentials are
            missing or the service rejects the request.
    """
    if not content:
        raise ValueError("extract_text() requires non-empty content")

    def _sync() -> AnalyzeResult:
        with _client() as client:
            poller = client.begin_analyze_document(
                model_id=_PREBUILT_READ,
                body=content,
                content_type=content_type,
            )
            return poller.result()

    try:
        result = await asyncio.to_thread(_sync)
    except Exception as exc:
        logger.exception("Document Intelligence analyze failed")
        raise ServiceUnavailableError(f"Document Intelligence extraction failed: {exc}") from exc

    extracted = _to_extracted(result)
    logger.info(
        "Document Intelligence extracted %d chars across %d pages (langs=%s)",
        len(extracted.text),
        extracted.page_count,
        extracted.languages or ["unknown"],
    )
    return extracted


async def extract_text_from_url(document_url: str) -> ExtractedDocument:
    """Extract text from a private, time-limited Blob URL.

    The worker no longer has to download a large PDF into its Container Apps
    memory before it can call Document Intelligence.  Azure reads the source
    directly from Blob Storage, which is both faster and avoids OOM failures
    for documents near the supported 500 MB processing limit.
    """
    if not document_url:
        raise ValueError("extract_text_from_url() requires a document URL")

    def _sync() -> AnalyzeResult:
        with _client() as client:
            poller = client.begin_analyze_document(
                model_id=_PREBUILT_READ,
                body=AnalyzeDocumentRequest(url_source=document_url),
            )
            return poller.result()

    try:
        result = await asyncio.to_thread(_sync)
    except Exception as exc:
        logger.exception("Document Intelligence URL analysis failed")
        raise ServiceUnavailableError(f"Document Intelligence extraction failed: {exc}") from exc

    extracted = _to_extracted(result)
    logger.info(
        "Document Intelligence URL extraction produced %d chars across %d pages (langs=%s)",
        len(extracted.text),
        extracted.page_count,
        extracted.languages or ["unknown"],
    )
    return extracted
