"""RAG evaluation metrics calculation module.

Pure Python deterministic metrics calculation — no LLMs, no network I/O.
Handles all numerical scoring, scope verification, evidence coverage,
source provenance metrics, and failure stage attribution.
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Iterable, Sequence
from typing import Any

from app.models.rag_evaluation import (
    AnswerEvaluation,
    ChunkingEvaluation,
    QuestionEvaluation,
    RAGFailureStage,
    RetrievalEvaluation,
)

# ── Text & Entity Normalization Helpers ────────────────────────────────────────

_STOPWORDS = frozenset(
    {
        "the",
        "a",
        "an",
        "is",
        "are",
        "was",
        "were",
        "be",
        "of",
        "to",
        "in",
        "on",
        "for",
        "and",
        "or",
        "that",
        "this",
        "by",
        "with",
        "as",
        "it",
        "its",
        "at",
        "from",
        "what",
        "which",
        "where",
        "when",
        "why",
        "how",
        "who",
        "whom",
        "whose",
        "does",
        "do",
        "did",
        "can",
        "could",
        "would",
        "should",
        "following",
        "about",
    }
)


def normalize_text(text: str) -> str:
    """Normalize text: Unicode NFKD, lowercase, collapse whitespace, strip punctuation."""
    if not text:
        return ""
    decomposed = unicodedata.normalize("NFKD", text)
    no_diacritics = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    lowered = no_diacritics.lower().strip()
    lowered = re.sub(r"[^\w\s\d]", " ", lowered)
    return re.sub(r"\s+", " ", lowered).strip()


def extract_factual_tokens(text: str) -> list[str]:
    """Extract salient factual tokens, numbers, and entities from text."""
    if not text:
        return []
    normalized = normalize_text(text)
    tokens = [t for t in normalized.split() if t and t not in _STOPWORDS and len(t) > 1]
    return tokens


def extract_numbers_and_measures(text: str) -> list[str]:
    """Extract numeric values, dates, percentages, and scientific figures."""
    if not text:
        return []
    # Numbers with decimals, commas, units or symbols (e.g. 10%, $5.50, 2026, 3.14)
    pattern = re.compile(r"\b\d+(?:[\.,]\d+)?%?")
    return [m.lower().replace(",", "") for m in pattern.findall(text)]


# ── Chunking & Context Quality Metrics ───────────────────────────────────────

_CLEAN_ENDINGS = (".", "!", "?", "\n", ";", ":", '"', "'", "”", "’")


def evaluate_chunking_quality(
    chunks: Sequence[Any],
    *,
    min_chars: int = 20,
    target_chars: int = 2000,
    max_chars: int = 3000,
) -> ChunkingEvaluation:
    """Evaluate chunking quality: boundary cleanliness, size compliance, and coherence."""
    if not chunks:
        return ChunkingEvaluation(
            boundary_integrity=1.0,
            size_compliance=1.0,
            semantic_coherence=1.0,
            overlap_preservation=1.0,
            avg_chunk_chars=0.0,
            chunk_count=0,
            passed=True,
            issues=[],
        )

    clean_boundaries = 0
    size_compliant = 0
    total_chars = 0
    issues: list[str] = []

    for idx, c in enumerate(chunks, start=1):
        text = (getattr(c, "text", "") or str(c)).strip()
        length = len(text)
        total_chars += length

        # 1. Boundary integrity check (ends cleanly at sentence/paragraph punctuation)
        if text.endswith(_CLEAN_ENDINGS) or length < min_chars:
            clean_boundaries += 1
        else:
            issues.append(f"Chunk {idx} does not end on a clean sentence/paragraph boundary")

        # 2. Size compliance check
        if min_chars <= length <= max_chars or len(chunks) == 1:
            size_compliant += 1
        else:
            if length < min_chars:
                issues.append(f"Chunk {idx} is smaller than minimum ({length} < {min_chars})")
            else:
                issues.append(f"Chunk {idx} exceeds target size budget ({length} > {max_chars})")

    n = len(chunks)
    boundary_score = clean_boundaries / n
    size_score = size_compliant / n
    avg_chars = total_chars / n

    # Semantic coherence based on clean boundaries and size
    coherence_score = 0.6 * boundary_score + 0.4 * size_score
    passed = boundary_score >= 0.70 and size_score >= 0.70

    return ChunkingEvaluation(
        boundary_integrity=float(round(boundary_score, 4)),
        size_compliance=float(round(size_score, 4)),
        semantic_coherence=float(round(coherence_score, 4)),
        overlap_preservation=1.0,
        avg_chunk_chars=float(round(avg_chars, 1)),
        chunk_count=n,
        passed=passed,
        issues=issues,
    )


def evaluate_context_density(
    context_text: str,
    *,
    topic_name: str = "",
    question_body: str = "",
) -> float:
    """Measure signal-to-noise ratio: fraction of factual tokens relevant to topic & question."""
    if not context_text or not context_text.strip():
        return 0.0

    ctx_tokens = extract_factual_tokens(context_text)
    if not ctx_tokens:
        return 1.0

    salient_tokens = set(extract_factual_tokens(topic_name) + extract_factual_tokens(question_body))
    if not salient_tokens:
        return 1.0

    matched = sum(1 for t in ctx_tokens if t in salient_tokens)
    # Density score scaled appropriately (usually 5-30% of total tokens in good retrieval)
    raw_density = matched / len(ctx_tokens)
    scaled_density = min(1.0, raw_density * 4.0)
    return float(round(scaled_density, 4))


# ── Retrieval Metrics ─────────────────────────────────────────────────────────


def evaluate_retrieval_scope(
    retrieved_chunks: Sequence[Any],
    *,
    expected_workspace_id: str,
    active_document_ids: Iterable[str] | None = None,
    allowed_topic_ids: Iterable[str] | None = None,
) -> tuple[float, list[str], list[bool]]:
    """Validate whether retrieved chunks belong to expected workspace, documents, and topics.

    Returns:
        (scope_validity, invalid_chunk_ids, list_of_is_valid_bools)
    """
    if not retrieved_chunks:
        return 1.0, [], []

    active_docs_set = set(active_document_ids) if active_document_ids is not None else None
    allowed_topics_set = set(allowed_topic_ids) if allowed_topic_ids is not None else None

    valid_count = 0
    invalid_ids: list[str] = []
    valid_flags: list[bool] = []

    for chunk in retrieved_chunks:
        chunk_id = getattr(chunk, "chunk_id", None) or getattr(chunk, "id", str(chunk))
        doc_id = getattr(chunk, "document_id", None)
        chunk_topics = getattr(chunk, "topic_ids", []) or []
        chunk_ws = getattr(chunk, "workspace_id", None)

        is_valid = True

        # Check workspace isolation if present
        if chunk_ws is not None and chunk_ws != expected_workspace_id:
            is_valid = False

        # Check active document scope if active documents are specified
        if active_docs_set is not None and doc_id and doc_id not in active_docs_set:
            is_valid = False

        # Check topic scope if allowed topics are specified
        if allowed_topics_set is not None and chunk_topics:
            if not (set(chunk_topics) & allowed_topics_set):
                is_valid = False

        if is_valid:
            valid_count += 1
        else:
            invalid_ids.append(str(chunk_id))

        valid_flags.append(is_valid)

    scope_validity = valid_count / len(retrieved_chunks)
    return float(round(scope_validity, 4)), invalid_ids, valid_flags


def evaluate_evidence_coverage(
    required_evidence: Sequence[str],
    context_text: str,
) -> float | None:
    """Calculate deterministic evidence coverage of required facts/terms against context.

    Returns:
        Float in [0.0, 1.0], or None if no required evidence was provided.
    """
    if not required_evidence:
        return None

    if not context_text or not context_text.strip():
        return 0.0

    normalized_context = normalize_text(context_text)
    matched_count = 0

    for item in required_evidence:
        item_norm = normalize_text(item)
        if not item_norm:
            continue
        if item_norm in normalized_context:
            matched_count += 1
        else:
            # Check token overlap for composite phrases
            tokens = [t for t in item_norm.split() if t not in _STOPWORDS]
            if tokens and sum(1 for t in tokens if t in normalized_context) >= max(
                1, len(tokens) * 0.7
            ):
                matched_count += 1

    if not required_evidence:
        return None

    return float(round(matched_count / len(required_evidence), 4))


def calculate_source_provenance_metrics(
    retrieved_chunk_ids: Sequence[str],
    known_source_chunk_ids: Sequence[str] | None,
    k: int = 5,
) -> tuple[bool | None, int | None, float | None]:
    """Calculate source chunk hit@k, first source rank, and recall@k.

    Returns:
        (source_hit_at_k, source_rank, source_recall_at_k)
    """
    if not known_source_chunk_ids:
        return None, None, None

    known_set = set(known_source_chunk_ids)
    if not known_set:
        return None, None, None

    top_k_ids = list(retrieved_chunk_ids[:k])
    retrieved_set = set(top_k_ids)

    # Hit@K
    hit = bool(retrieved_set & known_set)

    # Rank of first known source chunk
    rank: int | None = None
    for i, cid in enumerate(top_k_ids, start=1):
        if cid in known_set:
            rank = i
            break

    # Recall@K
    matched_sources = len(retrieved_set & known_set)
    recall = matched_sources / len(known_set)

    return hit, rank, float(round(recall, 4))


# ── Question & Answer Metrics ────────────────────────────────────────────────


def calculate_question_groundedness_deterministic(
    question_body: str,
    context_text: str,
    reference_answer: str | None = None,
) -> float:
    """Heuristic / lexical overlap check for question groundedness."""
    if not question_body or not context_text:
        return 0.0

    q_tokens = extract_factual_tokens(question_body)
    if reference_answer:
        q_tokens.extend(extract_factual_tokens(reference_answer))

    if not q_tokens:
        return 1.0

    context_norm = normalize_text(context_text)
    matched = sum(1 for t in q_tokens if t in context_norm)
    return float(round(matched / len(q_tokens), 4))


def calculate_answer_fact_metrics(
    supported_facts: Sequence[str],
    missing_facts: Sequence[str],
    contradicted_facts: Sequence[str],
    uncertain_facts: Sequence[str] | None = None,
) -> tuple[float, float, float]:
    """Compute correctness, completeness, and faithfulness from fact classifications.

    Returns:
        (correctness, completeness, faithfulness)
    """
    n_supp = len(supported_facts)
    n_miss = len(missing_facts)
    n_contra = len(contradicted_facts)
    n_unc = len(uncertain_facts or [])

    total_facts = n_supp + n_miss + n_contra + n_unc
    if total_facts == 0:
        return 1.0, 1.0, 1.0

    # Correctness: penalty for contradictions
    correctness = max(0.0, (n_supp - n_contra) / total_facts)

    # Completeness: fraction of required/reference facts that are supported
    completeness = n_supp / total_facts

    # Faithfulness: supported statements over total generated assertions
    total_claims = n_supp + n_contra
    faithfulness = (n_supp / total_claims) if total_claims > 0 else 1.0

    return (
        float(round(correctness, 4)),
        float(round(completeness, 4)),
        float(round(faithfulness, 4)),
    )


# ── Overall Composite Scoring & Stage Attribution ────────────────────────────


def calculate_overall_rag_score(
    retrieval: RetrievalEvaluation,
    question: QuestionEvaluation,
    answer: AnswerEvaluation,
    chunking: ChunkingEvaluation | None = None,
) -> tuple[float, bool]:
    """Compute weighted composite RAG score and overall pass/fail boolean."""
    r_score = retrieval.scope_validity
    if retrieval.evidence_coverage is not None:
        r_score = (
            0.4 * retrieval.scope_validity
            + 0.3 * retrieval.evidence_coverage
            + 0.3 * retrieval.context_density
        )
    else:
        r_score = 0.6 * retrieval.scope_validity + 0.4 * retrieval.context_density

    q_score = (
        0.4 * question.groundedness + 0.3 * question.answerability + 0.3 * question.topic_relevance
    )

    a_score = 0.4 * answer.correctness + 0.3 * answer.completeness + 0.3 * answer.faithfulness

    if chunking is not None:
        c_score = 0.5 * chunking.boundary_integrity + 0.5 * chunking.size_compliance
        overall = 0.15 * c_score + 0.25 * r_score + 0.30 * q_score + 0.30 * a_score
        chunking_passed = chunking.passed
    else:
        overall = 0.30 * r_score + 0.35 * q_score + 0.35 * a_score
        chunking_passed = True

    overall = float(round(max(0.0, min(1.0, overall)), 4))

    passed = (
        overall >= 0.70
        and chunking_passed
        and retrieval.passed
        and question.passed
        and answer.passed
    )
    return overall, passed


def attribute_failure_stage(
    retrieval: RetrievalEvaluation,
    question: QuestionEvaluation,
    answer: AnswerEvaluation,
    chunking: ChunkingEvaluation | None = None,
) -> tuple[RAGFailureStage | None, str | None]:
    """Determine the primary failure stage in the RAG execution chain."""
    if chunking is not None and (not chunking.passed or chunking.boundary_integrity < 0.60):
        issue_str = ", ".join(chunking.issues[:2]) or "unclean boundaries"
        return (
            RAGFailureStage.chunking,
            f"Chunking boundary or sizing violation: {issue_str} (boundary integrity: {chunking.boundary_integrity:.2f})",
        )

    if not retrieval.passed or retrieval.scope_validity < 0.70:
        invalid_str = ", ".join(retrieval.invalid_scope_chunk_ids) or "out-of-scope chunks"
        return (
            RAGFailureStage.retrieval,
            f"Retrieval scope violation: {invalid_str} (validity: {retrieval.scope_validity:.2f})",
        )

    if not question.passed or question.groundedness < 0.50:
        return (
            RAGFailureStage.grounding,
            f"Question not grounded in retrieved context (groundedness: {question.groundedness:.2f})",
        )

    if not question.passed or question.topic_relevance < 0.50 or question.answerability < 0.50:
        return (
            RAGFailureStage.question_generation,
            f"Question generation quality issue: {question.reason or 'low answerability/relevance'}",
        )

    if len(answer.contradicted_facts) > 0 or answer.faithfulness < 0.60:
        return (
            RAGFailureStage.answer_generation,
            f"Answer contains contradictions ({len(answer.contradicted_facts)} contradicted facts)",
        )

    if not answer.passed or answer.correctness < 0.60 or answer.completeness < 0.60:
        return (
            RAGFailureStage.answer_generation,
            "Answer failed correctness or completeness threshold",
        )

    return None, None
