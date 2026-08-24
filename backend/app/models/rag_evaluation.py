"""RAG Evaluation model — end-to-end evaluation & observability traces for RAG pipeline."""

from __future__ import annotations

from enum import StrEnum
from typing import Any
from pydantic import BaseModel, Field

from app.models.base import CosmosDocument


class RAGFailureStage(StrEnum):
    chunking = "CHUNKING"
    retrieval = "RETRIEVAL"
    question_generation = "QUESTION_GENERATION"
    answer_generation = "ANSWER_GENERATION"
    grounding = "GROUNDING"


class RetrievedChunkTrace(BaseModel):
    """Trace of an individual chunk hit returned by Azure AI Search."""

    chunk_id: str
    document_id: str
    topic_ids: list[str] = Field(default_factory=list)
    chunk_index: int = 0
    rank: int = 1
    search_score: float | None = None
    is_scope_valid: bool = True
    text_snippet: str | None = None


class ChunkingEvaluation(BaseModel):
    """Chunking stage quality metrics and boundary adherence."""

    boundary_integrity: float = Field(ge=0.0, le=1.0, default=1.0)
    size_compliance: float = Field(ge=0.0, le=1.0, default=1.0)
    semantic_coherence: float = Field(ge=0.0, le=1.0, default=1.0)
    overlap_preservation: float = Field(ge=0.0, le=1.0, default=1.0)
    avg_chunk_chars: float = 0.0
    chunk_count: int = 0
    passed: bool = True
    issues: list[str] = Field(default_factory=list)


class RetrievalEvaluation(BaseModel):
    """Retrieval stage evaluation metrics and verification signals."""

    scope_validity: float = Field(ge=0.0, le=1.0, default=1.0)
    evidence_coverage: float | None = Field(default=None, ge=0.0, le=1.0)
    context_density: float = Field(ge=0.0, le=1.0, default=1.0)
    chunk_relevance_llm: float = Field(ge=0.0, le=1.0, default=1.0)
    chunk_sufficiency_llm: float = Field(ge=0.0, le=1.0, default=1.0)
    source_hit_at_k: bool | None = None
    source_rank: int | None = None
    source_recall_at_k: float | None = Field(default=None, ge=0.0, le=1.0)
    invalid_scope_chunk_ids: list[str] = Field(default_factory=list)
    passed: bool = True
    details: dict[str, Any] = Field(default_factory=dict)


class QuestionEvaluation(BaseModel):
    """Question generation quality evaluation metrics."""

    groundedness: float = Field(ge=0.0, le=1.0, default=1.0)
    answerability: float = Field(ge=0.0, le=1.0, default=1.0)
    topic_relevance: float = Field(ge=0.0, le=1.0, default=1.0)
    passed: bool = True
    reason: str = ""


class AnswerEvaluation(BaseModel):
    """Reference answer evaluation and fact-level verification."""

    correctness: float = Field(ge=0.0, le=1.0, default=1.0)
    completeness: float = Field(ge=0.0, le=1.0, default=1.0)
    faithfulness: float = Field(ge=0.0, le=1.0, default=1.0)
    supported_facts: list[str] = Field(default_factory=list)
    missing_facts: list[str] = Field(default_factory=list)
    contradicted_facts: list[str] = Field(default_factory=list)
    uncertain_facts: list[str] = Field(default_factory=list)
    passed: bool = True


class RAGEvaluationRecord(CosmosDocument):
    """Stored in the tenant database, 'rag_evaluations' collection.

    Partition key: workspace_id.
    """

    evaluation_version: str = "rag_eval_v1"
    tenant_id: str
    workspace_id: str
    student_id: str | None = None
    session_id: str | None = None
    selected_topic_id: str | None = None
    selected_topic_name: str | None = None
    active_document_ids: list[str] = Field(default_factory=list)

    # Retrieval trace & chunk provenance
    retrieved_chunks: list[RetrievedChunkTrace] = Field(default_factory=list)
    generation_chunk_ids: list[str] = Field(default_factory=list)

    # Generation artifact metadata
    question_id: str | None = None
    question_type: str | None = None
    question_body: str | None = None
    reference_answer: str | None = None
    explanation: str | None = None

    # Multi-stage evaluation results
    chunking: ChunkingEvaluation = Field(default_factory=ChunkingEvaluation)
    retrieval: RetrievalEvaluation = Field(default_factory=RetrievalEvaluation)
    question: QuestionEvaluation = Field(default_factory=QuestionEvaluation)
    answer: AnswerEvaluation = Field(default_factory=AnswerEvaluation)

    # Summary metrics & diagnostics
    overall_score: float = Field(ge=0.0, le=1.0, default=1.0)
    passed: bool = True
    failed_stage: RAGFailureStage | None = None
    failure_reason: str | None = None

    llm_evaluator_used: bool = False
    evaluation_duration_ms: float | None = None
