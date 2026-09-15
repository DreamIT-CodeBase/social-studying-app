"""End-to-end integration tests for the Sprint 2 ingestion pipeline.

Sprint 2.14. These tests drive the FULL upload-to-vectorized pipeline with
in-memory fakes standing in for every external service. They differ from
the per-stage worker unit tests in two important ways:

1. **One scenario crosses all four workers.** A unit test patches three or
   four functions; here we wire the workers together via fake queues so a
   failure in any handoff (status field, blob path, topic-id resolution,
   queue payload shape) shows up as a test failure.
2. **The state machine is asserted as it advances.** We record every
   document-status write and assert the full sequence
   ``pending → extracting → text_extracted → extracting_topics → … → ready``
   instead of only the final state. A regression that skips a stage or
   advances out of order is caught here even if the final state is
   coincidentally correct.

What's real
-----------
- FastAPI routing + ``POST /api/v1/workspaces/{ws}/documents``
- All four worker ``_handle`` coroutines (sans the ``run_forever`` loop)
- All four message dataclasses, round-tripped through JSON
  (``to_json`` / ``from_json``) at every fake-queue boundary so a
  serializer bug surfaces here, not in prod
- :mod:`app.services.taxonomy` merge + dep inference (seed path, CAS loop,
  edge sanitization)
- :mod:`app.services.text_chunker` (pure, no fakes)
- :mod:`app.services.vectorization` (topic-id resolution, AI Search doc
  construction)

What's fake
-----------
- Cosmos collections (in-memory dicts keyed by ``_id``)
- Blob storage (in-memory dict; raw uploads + extracted text)
- Service Bus queues (in-memory ``list[bytes]`` per stage)
- Azure AI Search (in-memory ``dict[index_name, list[doc]]``)
- Document Intelligence (canned :class:`ExtractedDocument`)
- Content Safety (canned :class:`SafetyVerdict`)
- Azure OpenAI ``chat_json`` (canned dicts per prompt) and ``embed_texts``
  (deterministic vectors of the configured dim)

Scenarios
---------
- ``test_pipeline_happy_path`` — clean upload, status reaches ``ready``,
  chunks land in fake AI Search, taxonomy gets seeded with the AI topics.
- ``test_pipeline_content_safety_flagged`` — content safety flips the
  document to ``flagged`` at the extraction stage; no downstream queue is
  touched.
- ``test_pipeline_document_intelligence_unsupported`` — DI rejects with
  ``UnsupportedContent``; the document goes to ``failed`` and the upload
  blob's raw bytes stay put for forensic review.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from dataclasses import dataclass, field
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest
from azure.core.exceptions import HttpResponseError
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.core.database import (
    CHUNKS,
    DOCUMENTS,
    MODERATION_LOG,
    WORKSPACES,
)
from app.main import app
from app.models.document import DocumentStatus
from app.models.user import UserRole
from app.services.chunk_queue import ChunkingMessage, ReceivedChunkingMessage
from app.services.content_safety import SafetyVerdict
from app.services.document_intelligence import ExtractedDocument
from app.services.document_queue import (
    ExtractionMessage,
    ReceivedExtractionMessage,
)
from app.services.topic_queue import (
    ReceivedTopicMessage,
    TopicExtractionMessage,
)
from app.services.vectorization_queue import (
    ReceivedVectorizationMessage,
    VectorizationMessage,
)
from app.workers import (
    chunking as chunking_worker,
)
from app.workers import (
    document_ingestion as extraction_worker,
)
from app.workers import (
    topic_extraction as topic_worker,
)
from app.workers import (
    vectorization as vectorization_worker,
)
from tests.unit.conftest import make_user, make_workspace

# ── Fake Cosmos ──────────────────────────────────────────────────────────────


def _matches(doc: dict, filter_: dict) -> bool:
    """Minimal Mongo-style filter matcher.

    Supports the flat ``key == value`` shape every caller in the pipeline
    actually uses. ``_id`` is matched against the document's ``_id`` field
    (Cosmos's preferred shape). Anything more exotic (``$exists`` etc.) is
    not needed by the pipeline tests and would silently match — fail loud
    instead.
    """
    for key, expected in filter_.items():
        if isinstance(expected, dict):
            raise NotImplementedError(
                f"Fake collection matcher does not support operator filters: {key!r} → {expected!r}"
            )
        if doc.get(key) != expected:
            return False
    return True


class _FakeCursor:
    """Stand-in for AsyncIOMotorCursor that supports the API the pipeline uses.

    ``find().sort()`` and ``find()`` directly are both consumed via
    ``async for``; :class:`taxonomy._docs_with_topics` also calls
    ``.to_list(length=None)``. All three paths land here.
    """

    def __init__(self, docs: list[dict]) -> None:
        self._docs = list(docs)
        self._idx = 0

    def sort(self, key: str, direction: int = 1) -> _FakeCursor:
        self._docs.sort(key=lambda d: d.get(key) or 0, reverse=direction < 0)
        return self

    async def to_list(self, length: int | None = None) -> list[dict]:
        if length is None:
            return list(self._docs)
        return list(self._docs[:length])

    def __aiter__(self) -> _FakeCursor:
        return self

    async def __anext__(self) -> dict:
        if self._idx >= len(self._docs):
            raise StopAsyncIteration
        doc = self._docs[self._idx]
        self._idx += 1
        return doc


@dataclass
class _FakeCollection:
    """In-memory collection that exercises the subset of the motor API the
    pipeline actually touches.

    Tracks every status write into ``status_history`` so tests can assert
    state-machine ordering without instrumenting each worker individually.
    """

    name: str
    docs: dict[str, dict] = field(default_factory=dict)
    status_history: list[tuple[str, str]] = field(default_factory=list)

    async def find_one(self, filter_: dict) -> dict | None:
        for doc in self.docs.values():
            if _matches(doc, filter_):
                # Return a copy so callers can mutate freely.
                return json.loads(json.dumps(doc))
        return None

    def find(self, filter_: dict) -> _FakeCursor:
        matches = [json.loads(json.dumps(d)) for d in self.docs.values() if _matches(d, filter_)]
        return _FakeCursor(matches)

    async def insert_one(self, doc: dict) -> Any:
        doc_id = doc.get("_id") or doc.get("id")
        if doc_id is None:
            raise AssertionError(f"insert_one missing _id: {doc!r}")
        self.docs[doc_id] = json.loads(json.dumps(doc))
        return MagicMock(inserted_id=doc_id)

    async def insert_many(self, docs: list[dict]) -> Any:
        inserted_ids: list[str] = []
        for doc in docs:
            doc_id = doc.get("_id") or doc.get("id")
            if doc_id is None:
                raise AssertionError(f"insert_many missing _id: {doc!r}")
            self.docs[doc_id] = json.loads(json.dumps(doc))
            inserted_ids.append(doc_id)
        return MagicMock(inserted_ids=inserted_ids)

    async def update_one(self, filter_: dict, update: dict) -> Any:
        matched = [d for d in self.docs.values() if _matches(d, filter_)]
        if not matched:
            return MagicMock(matched_count=0, modified_count=0)
        target = matched[0]
        set_payload = update.get("$set") or {}
        # Record status transitions for assertion convenience.
        if self.name == DOCUMENTS and "status" in set_payload:
            doc_id = target["_id"]
            self.status_history.append((doc_id, set_payload["status"]))
        target.update(set_payload)
        return MagicMock(matched_count=1, modified_count=1)

    async def replace_one(self, filter_: dict, doc: dict) -> Any:
        matched = [d for d in self.docs.values() if _matches(d, filter_)]
        if not matched:
            return MagicMock(matched_count=0)
        target = matched[0]
        target.clear()
        target.update(doc)
        return MagicMock(matched_count=1)

    async def delete_many(self, filter_: dict) -> Any:
        to_drop = [doc_id for doc_id, d in self.docs.items() if _matches(d, filter_)]
        for doc_id in to_drop:
            del self.docs[doc_id]
        return MagicMock(deleted_count=len(to_drop))

    async def count_documents(self, filter_: dict) -> int:
        return sum(1 for d in self.docs.values() if _matches(d, filter_))


# ── Pipeline harness ─────────────────────────────────────────────────────────


@dataclass
class _PipelineState:
    """Aggregates every fake the pipeline test fixture installs.

    Tests interact with this state to:
    - inspect Cosmos contents after the pipeline drains,
    - read upserted Search documents,
    - tweak DI / content-safety / OpenAI responses for failure scenarios.
    """

    collections: dict[tuple[str, str], _FakeCollection]
    raw_blobs: dict[str, bytes]
    text_blobs: dict[str, str]
    queues: dict[str, list[bytes]]
    search_index: dict[str, list[dict]]
    extracted: ExtractedDocument
    safety_verdict: SafetyVerdict
    di_error: HttpResponseError | None = None
    openai_topics: list[dict] = field(default_factory=list)
    embedding_dim: int = 8

    # Filled at end of the run for convenience in assertions.
    status_history: list[str] = field(default_factory=list)

    def collection(self, tenant_id: str, name: str) -> _FakeCollection:
        key = (tenant_id, name)
        if key not in self.collections:
            self.collections[key] = _FakeCollection(name=name)
        return self.collections[key]


def _clean_verdict() -> SafetyVerdict:
    return SafetyVerdict(
        severities={"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0},
        flagged_categories=[],
    )


def _flagged_verdict(category: str = "Hate", severity: int = 4) -> SafetyVerdict:
    sevs = {"Hate": 0, "SelfHarm": 0, "Sexual": 0, "Violence": 0}
    sevs[category] = severity
    return SafetyVerdict(severities=sevs, flagged_categories=[category])


def _extracted_sample() -> ExtractedDocument:
    # Long enough that the chunker emits 2+ chunks at default 2K target so
    # the vectorization stage actually has multiple chunks to embed.
    paragraph = (
        "Photosynthesis is the process by which green plants convert sunlight "
        "into chemical energy stored in glucose. The reaction takes place in "
        "the chloroplasts of plant cells, primarily in the leaves. Chlorophyll "
        "molecules capture photons and drive the splitting of water into "
        "oxygen, protons, and electrons. "
    )
    text = (paragraph * 8).strip()
    return ExtractedDocument(text=text, page_count=4, languages=["en"])


@pytest.fixture
def pipeline(monkeypatch) -> Iterator[_PipelineState]:
    """Wire up every fake the ingestion pipeline depends on.

    Yields a :class:`_PipelineState` the test can introspect. Cleanup is
    handled by ``monkeypatch`` (restores patched names) and by clearing
    FastAPI's dependency overrides.
    """
    collections: dict[tuple[str, str], _FakeCollection] = {}

    def get_collection(tenant_id: str, name: str) -> _FakeCollection:
        key = (tenant_id, name)
        if key not in collections:
            collections[key] = _FakeCollection(name=name)
        return collections[key]

    # Every module that did `from app.core.database import get_collection`
    # needs the local rebound name patched. The list mirrors actual import
    # sites — a new caller will require a new entry here, which is loud on
    # purpose: silent un-patched callers would talk to real Cosmos.
    _get_collection_callsites = [
        "app.api.documents.get_collection",
        "app.workers.document_ingestion.get_collection",
        "app.workers.topic_extraction.get_collection",
        "app.workers.chunking.get_collection",
        "app.workers.vectorization.get_collection",
        "app.services.taxonomy.get_collection",
        "app.services.vectorization.get_collection",
        "app.services.chunk_storage.get_collection",
    ]
    for path in _get_collection_callsites:
        monkeypatch.setattr(path, get_collection)

    # ── Blob storage fakes ──────────────────────────────────────────────────
    raw_blobs: dict[str, bytes] = {}
    text_blobs: dict[str, str] = {}

    async def fake_upload_document(
        *,
        tenant_id: str,
        workspace_id: str,
        user_id: str,
        document_id: str,
        filename: str,
        content: bytes,
        content_type: str,
    ) -> str:
        path = f"{tenant_id}/{workspace_id}/{user_id}/{document_id}/{filename}"
        raw_blobs[path] = content
        return f"https://fake.blob/{path}"

    async def fake_download_document(blob_path: str) -> bytes:
        if blob_path in raw_blobs:
            return raw_blobs[blob_path]
        if blob_path in text_blobs:
            return text_blobs[blob_path].encode("utf-8")
        raise AssertionError(f"fake download_document: unknown blob_path={blob_path!r}")

    async def fake_upload_extracted_text(
        *, tenant_id: str, workspace_id: str, document_id: str, text: str
    ) -> str:
        path = f"{tenant_id}/{workspace_id}/extracted-text/{document_id}.txt"
        text_blobs[path] = text
        return path

    async def fake_download_extracted_text(blob_path: str) -> str:
        if blob_path not in text_blobs:
            raise AssertionError(f"fake download_extracted_text: unknown blob_path={blob_path!r}")
        return text_blobs[blob_path]

    monkeypatch.setattr("app.services.blob_storage.upload_document", fake_upload_document)
    monkeypatch.setattr("app.services.blob_storage.download_document", fake_download_document)
    monkeypatch.setattr(
        "app.services.blob_storage.upload_extracted_text", fake_upload_extracted_text
    )
    monkeypatch.setattr(
        "app.services.blob_storage.download_extracted_text",
        fake_download_extracted_text,
    )
    # Workers import the module by name (`from app.services import blob_storage`),
    # which is a single shared module — patching the attributes above propagates
    # everywhere. No per-worker rebinding needed.

    # ── Queue fakes ─────────────────────────────────────────────────────────
    queues: dict[str, list[bytes]] = {
        "extraction": [],
        "topics": [],
        "chunking": [],
        "vectorization": [],
    }

    async def fake_publish_extraction(msg: ExtractionMessage) -> None:
        queues["extraction"].append(msg.to_json().encode("utf-8"))

    async def fake_publish_topic(msg: TopicExtractionMessage) -> None:
        queues["topics"].append(msg.to_json().encode("utf-8"))

    async def fake_publish_chunking(msg: ChunkingMessage) -> None:
        queues["chunking"].append(msg.to_json().encode("utf-8"))

    async def fake_publish_vectorization(msg: VectorizationMessage) -> None:
        queues["vectorization"].append(msg.to_json().encode("utf-8"))

    # API publishes through the imported `document_queue` module reference.
    monkeypatch.setattr(
        "app.api.documents.document_queue.publish_extraction_message",
        fake_publish_extraction,
    )
    # Each worker imports the next stage's publisher by name — patch the local
    # rebound name at each call site.
    monkeypatch.setattr("app.workers.document_ingestion.publish_topic_message", fake_publish_topic)
    monkeypatch.setattr(
        "app.workers.topic_extraction.publish_chunking_message",
        fake_publish_chunking,
    )
    monkeypatch.setattr(
        "app.workers.chunking.publish_vectorization_message",
        fake_publish_vectorization,
    )

    # ── Document Intelligence fake ──────────────────────────────────────────
    extracted_default = _extracted_sample()
    state_holder: dict[str, Any] = {
        "extracted": extracted_default,
        "verdict": _clean_verdict(),
        "di_error": None,
    }

    async def fake_extract_text(
        content: bytes, *, content_type: str = "application/octet-stream"
    ) -> ExtractedDocument:
        if state_holder["di_error"] is not None:
            raise state_holder["di_error"]
        return state_holder["extracted"]

    monkeypatch.setattr("app.services.document_intelligence.extract_text", fake_extract_text)

    # ── Content Safety fake ─────────────────────────────────────────────────
    async def fake_analyze(text: str) -> SafetyVerdict:
        return state_holder["verdict"]

    monkeypatch.setattr("app.services.content_safety.analyze_extracted_text", fake_analyze)

    # ── Azure OpenAI fakes ──────────────────────────────────────────────────
    topics_payload: list[dict] = [
        {
            "name": "Photosynthesis",
            "description": "Process plants use to convert sunlight to energy.",
            "complexity_level": 2,
            "page_refs": [1, 2],
        },
        {
            "name": "Chloroplasts",
            "description": "Plant cell organelles where photosynthesis occurs.",
            "complexity_level": 2,
            "page_refs": [2, 3],
        },
    ]

    async def fake_chat_json(
        *,
        system_prompt: str,
        user_prompt: str,
        max_output_tokens: int,
        temperature: float = 0.2,
        deployment: str | None = None,
    ) -> dict[str, Any]:
        # Three prompts share this seam. Discriminate on the JSON output
        # key each prompt instructs the model to emit — these keys appear
        # verbatim in the system prompt's schema example and are unique to
        # each pipeline:
        #   - taxonomy_merge_v1     → "merged_topics"
        #   - dependency_inference  → "edges"
        #   - topic_extraction_v1   → "topics"
        # Order matters: merge mentions "topics" inside its schema, and
        # both extraction and dep prompts mention "prerequisite". Match on
        # the canonical output key.
        if '"merged_topics"' in system_prompt:
            return {"merged_topics": []}
        if '"edges"' in system_prompt:
            # Dependency inference — return no edges. The sanitizer leaves
            # all parents as None which is the correct first-doc shape.
            return {"edges": []}
        # Topic extraction — the only remaining caller.
        return {"topics": list(topics_payload)}

    monkeypatch.setattr("app.services.azure_openai.chat_json", fake_chat_json)

    embedding_dim = 8
    monkeypatch.setattr("app.core.config.settings.azure_openai_embedding_dim", embedding_dim)
    monkeypatch.setattr(
        "app.core.config.settings.azure_openai_embedding_deployment",
        "text-embedding-3-small",
    )

    async def fake_embed_texts(
        *,
        texts: list[str],
        deployment: str | None = None,
        batch_size: int | None = None,
    ) -> list[list[float]]:
        # Deterministic per-text vectors. Length is the configured dim so
        # the vectorization service's length-mismatch guard stays green.
        return [[float((i + 1) * 0.01) for i in range(embedding_dim)] for _ in texts]

    monkeypatch.setattr("app.services.azure_openai.embed_texts", fake_embed_texts)

    # ── Azure AI Search fake ────────────────────────────────────────────────
    search_index: dict[str, list[dict]] = {}

    async def fake_ensure_index(tenant_id: str) -> str:
        from app.services.azure_ai_search import index_name_for

        name = index_name_for(tenant_id)
        search_index.setdefault(name, [])
        return name

    async def fake_upsert_chunks(*, tenant_id: str, documents: list[dict]) -> int:
        from app.services.azure_ai_search import index_name_for

        name = index_name_for(tenant_id)
        bucket = search_index.setdefault(name, [])
        by_id = {d["id"]: d for d in bucket}
        for doc in documents:
            by_id[doc["id"]] = doc
        search_index[name] = list(by_id.values())
        return len(documents)

    async def fake_delete_for_document(*, tenant_id: str, document_id: str) -> int:
        from app.services.azure_ai_search import index_name_for

        name = index_name_for(tenant_id)
        if name not in search_index:
            return 0
        before = len(search_index[name])
        search_index[name] = [d for d in search_index[name] if d.get("document_id") != document_id]
        return before - len(search_index[name])

    monkeypatch.setattr("app.services.azure_ai_search.ensure_index", fake_ensure_index)
    monkeypatch.setattr("app.services.azure_ai_search.upsert_chunks", fake_upsert_chunks)
    monkeypatch.setattr(
        "app.services.azure_ai_search.delete_for_document", fake_delete_for_document
    )

    state = _PipelineState(
        collections=collections,
        raw_blobs=raw_blobs,
        text_blobs=text_blobs,
        queues=queues,
        search_index=search_index,
        extracted=extracted_default,
        safety_verdict=state_holder["verdict"],
        openai_topics=topics_payload,
        embedding_dim=embedding_dim,
    )
    # Allow tests to mutate the live state-holder.
    state._holder = state_holder  # type: ignore[attr-defined]

    try:
        yield state
    finally:
        app.dependency_overrides.clear()


# ── Test driver ──────────────────────────────────────────────────────────────


async def _drain_pipeline(state: _PipelineState) -> None:
    """Process every fake-queue message until all four queues are empty.

    Round-trips each message through ``to_json``/``from_json`` so any drift
    between the publisher and consumer serializers is caught here, not in
    production. The receivers are real ``ReceivedXxxMessage`` dataclasses
    backed by a no-op MagicMock receiver so the workers can call
    ``complete()`` / ``dead_letter()`` without exploding.
    """
    handlers = {
        "extraction": (
            ExtractionMessage,
            ReceivedExtractionMessage,
            extraction_worker._handle,
        ),
        "topics": (
            TopicExtractionMessage,
            ReceivedTopicMessage,
            topic_worker._handle,
        ),
        "chunking": (
            ChunkingMessage,
            ReceivedChunkingMessage,
            chunking_worker._handle,
        ),
        "vectorization": (
            VectorizationMessage,
            ReceivedVectorizationMessage,
            vectorization_worker._handle,
        ),
    }
    # Process stages in pipeline order — finishing extraction can enqueue
    # topics, finishing topics can enqueue chunking, etc.
    stage_order = ["extraction", "topics", "chunking", "vectorization"]

    # Allow up to one full sweep per active message so a misbehaving handoff
    # can't spin forever. In practice happy paths drain in one sweep.
    safety_passes = 0
    while any(state.queues[s] for s in stage_order):
        safety_passes += 1
        if safety_passes > 16:
            raise AssertionError(
                f"Pipeline did not drain after {safety_passes} sweeps; "
                f"remaining={ {s: len(state.queues[s]) for s in stage_order} }"
            )
        for stage in stage_order:
            queue = state.queues[stage]
            payload_cls, received_cls, handler = handlers[stage]
            # Snapshot to avoid mid-sweep re-entrancy with newly enqueued
            # downstream messages.
            batch = list(queue)
            queue.clear()
            for raw in batch:
                payload = payload_cls.from_json(raw)
                receiver = MagicMock()
                receiver.dead_letter_message = AsyncMock()
                receiver.abandon_message = AsyncMock()
                receiver.complete_message = AsyncMock()
                received = received_cls(
                    payload=payload,
                    delivery_count=1,
                    _receiver=receiver,
                    _raw=MagicMock(),
                )
                await handler(received)


# ── Test setup helpers ──────────────────────────────────────────────────────


def _seed_workspace(state: _PipelineState, tenant_id: str, workspace_id: str) -> None:
    """Create a workspace doc in the fake Cosmos so taxonomy reads find it."""
    ws = make_workspace(workspace_id=workspace_id, tenant_id=tenant_id)
    # make_workspace returns a Workspace; insert the model dump under the
    # canonical _id key.
    doc = ws.model_dump(by_alias=True)
    state.collection(tenant_id, WORKSPACES).docs[workspace_id] = doc


def _upload(client: TestClient) -> dict:
    response = client.post(
        "/api/v1/workspaces/wsp_test001/documents",
        files={"file": ("photo.pdf", b"%PDF-1.4 fake bytes", "application/pdf")},
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.fixture
def client() -> Iterator[TestClient]:
    admin = make_user(user_id="usr_admin01", role=UserRole.tenant_admin)
    app.dependency_overrides[get_current_user] = lambda: admin
    with TestClient(app, raise_server_exceptions=True) as test_client:
        yield test_client


# ── Happy path ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_pipeline_happy_path(client: TestClient, pipeline: _PipelineState):
    """Upload → extraction → topics → chunking → vectorization → ready.

    Drives the full pipeline and asserts every observable side effect:

    - HTTP 201 with status=pending and a doc_ id.
    - Status history walks every state in pipeline order.
    - Extracted text is on disk in the fake blob store.
    - The workspace's canonical taxonomy was seeded from the doc's topics
      (first-doc path; no AI merge call needed).
    - Chunks landed in the chunks Cosmos collection and in fake AI Search,
      each tagged with the resolved canonical topic ids.
    - The document record carries chunk_count, vector_count, page_count,
      languages, and embedding_model.
    """
    tenant_id = "ten_test001"
    workspace_id = "wsp_test001"
    _seed_workspace(pipeline, tenant_id, workspace_id)

    response_body = _upload(client)
    document_id = response_body["id"]
    assert response_body["status"] == DocumentStatus.pending.value
    assert response_body["doc_type"] == "pdf"

    # Exactly one extraction message published; the rest of the queues
    # populate as workers run.
    assert len(pipeline.queues["extraction"]) == 1
    assert pipeline.queues["topics"] == []

    await _drain_pipeline(pipeline)

    documents = pipeline.collection(tenant_id, DOCUMENTS)
    final_doc = documents.docs[document_id]

    # State machine walked every stage in order.
    statuses = [s for (doc_id, s) in documents.status_history if doc_id == document_id]
    assert statuses == [
        DocumentStatus.extracting.value,
        DocumentStatus.text_extracted.value,
        DocumentStatus.extracting_topics.value,
        DocumentStatus.topics_extracted.value,
        DocumentStatus.chunking.value,
        DocumentStatus.chunked.value,
        DocumentStatus.vectorizing.value,
        DocumentStatus.ready.value,
    ]
    assert final_doc["status"] == DocumentStatus.ready.value
    assert final_doc["processing_error"] is None

    # Sprint 2.3 fields.
    assert final_doc["page_count"] == 4
    assert final_doc["languages"] == ["en"]
    assert final_doc["text_char_count"] == len(pipeline.extracted.text)
    assert final_doc["extracted_text_blob_path"].endswith(f"{document_id}.txt")

    # Sprint 2.4 — moderation log got an auto-approved audit entry.
    mod_log = pipeline.collection(tenant_id, MODERATION_LOG)
    assert len(mod_log.docs) == 1
    log_entry = next(iter(mod_log.docs.values()))
    assert log_entry["action"] == "auto_approved"
    assert log_entry["target_id"] == document_id

    # Sprint 2.5/2.6 — topics + canonical taxonomy.
    assert len(final_doc["topic_tags"]) == 2
    assert {t["name"] for t in final_doc["topic_tags"]} == {
        "Photosynthesis",
        "Chloroplasts",
    }
    workspace_doc = pipeline.collection(tenant_id, WORKSPACES).docs[workspace_id]
    canonical_topics = workspace_doc["taxonomy"]["topics"]
    assert {t["name"] for t in canonical_topics} == {"Photosynthesis", "Chloroplasts"}
    # First-doc seed bumps version once; dep inference (2.7) returns []
    # edges, which sanitize keeps as None parents and the CAS writes
    # again — version reflects both writes.
    assert workspace_doc["taxonomy_version"] >= 1

    # Sprint 2.8 — chunks persisted to the chunks collection. Per the 2.8
    # decisions memo, chunk records intentionally ship with topic_ids=[];
    # canonical-id resolution is deferred to Sprint 2.9's vectorizer seam
    # (asserted below against the Search index doc).
    chunks_col = pipeline.collection(tenant_id, CHUNKS)
    chunks = [d for d in chunks_col.docs.values() if d["document_id"] == document_id]
    assert len(chunks) >= 2, f"expected the chunker to emit multiple chunks, got {chunks}"
    assert final_doc["chunk_count"] == len(chunks)
    for chunk in chunks:
        assert chunk["topic_ids"] == []
        assert chunk["chunker_version"] == "v1"
    canonical_ids = {t["id"] for t in canonical_topics}

    # Sprint 2.9 — vector index has one Search doc per chunk, each with the
    # configured embedding dimensions and topic_ids preserved.
    from app.services.azure_ai_search import index_name_for

    index_docs = pipeline.search_index[index_name_for(tenant_id)]
    assert {d["document_id"] for d in index_docs} == {document_id}
    assert len(index_docs) == len(chunks)
    for index_doc in index_docs:
        assert len(index_doc["embedding"]) == pipeline.embedding_dim
        assert set(index_doc["topic_ids"]) == canonical_ids
        assert index_doc["embedding_model"] == "text-embedding-3-small"

    assert final_doc["vector_count"] == len(chunks)
    assert final_doc["embedding_model"] == "text-embedding-3-small"


# ── Content safety flagged ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_pipeline_content_safety_flagged(client: TestClient, pipeline: _PipelineState):
    """A flagged content-safety verdict halts the pipeline at the extraction
    stage. Downstream queues stay empty, no taxonomy gets written, no
    chunks are persisted, no vectors get indexed.

    Auditability is still preserved: the extracted text DOES land in blob
    storage so an admin can review what tripped the scanner, and a
    moderation_log entry with action=flagged is written.
    """
    tenant_id = "ten_test001"
    workspace_id = "wsp_test001"
    _seed_workspace(pipeline, tenant_id, workspace_id)

    pipeline._holder["verdict"] = _flagged_verdict(category="Hate", severity=4)

    response_body = _upload(client)
    document_id = response_body["id"]

    await _drain_pipeline(pipeline)

    documents = pipeline.collection(tenant_id, DOCUMENTS)
    final_doc = documents.docs[document_id]
    assert final_doc["status"] == DocumentStatus.flagged.value
    assert final_doc["moderation_flagged"] is True

    statuses = [s for (doc_id, s) in documents.status_history if doc_id == document_id]
    assert statuses == [
        DocumentStatus.extracting.value,
        DocumentStatus.flagged.value,
    ]

    # Audit log got a flagged entry.
    mod_log = pipeline.collection(tenant_id, MODERATION_LOG)
    assert len(mod_log.docs) == 1
    entry = next(iter(mod_log.docs.values()))
    assert entry["action"] == "flagged"
    assert entry["flagged_categories"] == ["Hate"]

    # Downstream stages never ran.
    assert pipeline.queues["topics"] == []
    assert pipeline.queues["chunking"] == []
    assert pipeline.queues["vectorization"] == []

    # No taxonomy seeded, no chunks, no Search docs.
    workspace_doc = pipeline.collection(tenant_id, WORKSPACES).docs[workspace_id]
    assert workspace_doc["taxonomy"]["topics"] == []
    assert (tenant_id, CHUNKS) not in pipeline.collections or not any(
        d["document_id"] == document_id
        for d in pipeline.collection(tenant_id, CHUNKS).docs.values()
    )
    assert pipeline.search_index == {}

    # Extracted text IS retained so admins can review it during moderation.
    assert final_doc["extracted_text_blob_path"] is not None
    assert final_doc["text_char_count"] == len(pipeline.extracted.text)


# ── Document Intelligence permanent failure ─────────────────────────────────


@pytest.mark.asyncio
async def test_pipeline_document_intelligence_unsupported(
    client: TestClient, pipeline: _PipelineState
):
    """Document Intelligence rejecting a file with ``UnsupportedContent``
    is a permanent failure: the document goes to ``failed`` with the
    processing_error filled in, no downstream queues are touched, and the
    raw upload blob stays in storage for forensic review.
    """
    tenant_id = "ten_test001"
    workspace_id = "wsp_test001"
    _seed_workspace(pipeline, tenant_id, workspace_id)

    error = HttpResponseError(message="DI hated this file")
    error.error = MagicMock(code="InvalidRequest")
    error.error.details = [MagicMock(code="UnsupportedContent")]
    pipeline._holder["di_error"] = error

    response_body = _upload(client)
    document_id = response_body["id"]

    await _drain_pipeline(pipeline)

    documents = pipeline.collection(tenant_id, DOCUMENTS)
    final_doc = documents.docs[document_id]
    assert final_doc["status"] == DocumentStatus.failed.value
    assert "Document Intelligence rejected" in final_doc["processing_error"]

    statuses = [s for (doc_id, s) in documents.status_history if doc_id == document_id]
    assert statuses == [
        DocumentStatus.extracting.value,
        DocumentStatus.failed.value,
    ]

    # Downstream stages never ran.
    assert pipeline.queues["topics"] == []
    assert pipeline.queues["chunking"] == []
    assert pipeline.queues["vectorization"] == []

    # Raw upload blob is still there for forensic review.
    assert any(document_id in path for path in pipeline.raw_blobs), (
        f"raw upload blob should be retained on DI failure; have {list(pipeline.raw_blobs)}"
    )
    # No extracted-text blob was written (DI never produced text).
    assert pipeline.text_blobs == {}

    # No moderation log entry (content safety never ran).
    mod_log = pipeline.collection(tenant_id, MODERATION_LOG)
    assert mod_log.docs == {}

    # No taxonomy mutation either.
    workspace_doc = pipeline.collection(tenant_id, WORKSPACES).docs[workspace_id]
    assert workspace_doc["taxonomy"]["topics"] == []
    assert workspace_doc["taxonomy_version"] == 0
