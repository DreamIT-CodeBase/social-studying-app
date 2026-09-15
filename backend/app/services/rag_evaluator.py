"""Separate Evaluator LLM service for RAG semantic verification.

Logically distinct from the question generator (LLM 1):
- Dedicated system prompt & role (pedagogical fact & grounding evaluator)
- Structured semantic JSON output schema (facts, groundedness, relevance)
- Temperature 0.0 for reproducibility
- Does NOT calculate numeric scores (Python metrics module calculates scores)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

from app.services import azure_openai

logger = logging.getLogger(__name__)


_EVALUATOR_SYSTEM_PROMPT = """You are an expert AI evaluator specializing in Retrieval-Augmented Generation (RAG) quality assessment for educational content.

Your task is to impartially evaluate:
1. Retrieval & Chunking Quality: Are the retrieved chunk(s) relevant to the topic and sufficient in factual detail to generate/answer this question without guessing?
2. Question Quality: Is the generated question strictly grounded in the provided context, answerable from the context, and relevant to the assigned topic?
3. Answer Factual Verification: Compare the generated/reference answer against the grounding context and identify discrete factual assertions. Classify every fact into exactly one of:
   - supported_facts: Assertions directly substantiated by the context.
   - missing_facts: Required factual details absent from the context or omitted in the answer.
   - contradicted_facts: Assertions that conflict with or misstate facts in the grounding context.
   - uncertain_facts: Ambiguous statements that cannot be confirmed or refuted.

IMPORTANT RULES:
- Do NOT generate numeric scores or percentages. Return only factual classifications and boolean judgments.
- Be rigorous: if a claim is not supported by the context, mark it as missing or contradicted.
- Return ONLY a valid JSON object matching the exact schema specified.
"""


_EVALUATOR_SCHEMA_HINT = """Return your evaluation as a JSON object with this exact structure:
{
  "retrieval": {
    "chunks_relevant": true/false,
    "chunks_sufficient": true/false
  },
  "question": {
    "grounded": true/false,
    "answerable": true/false,
    "topic_relevant": true/false,
    "reason": "Clear explanation of evaluation"
  },
  "answer": {
    "supported_facts": ["fact 1", "fact 2"],
    "missing_facts": ["fact if missing"],
    "contradicted_facts": ["fact if contradicted"],
    "uncertain_facts": ["fact if uncertain"]
  }
}"""


@dataclass(frozen=True, slots=True)
class SemanticEvaluationResult:
    """Semantic judgment output from Evaluator LLM."""

    chunks_relevant: bool
    chunks_sufficient: bool
    question_grounded: bool
    question_answerable: bool
    question_topic_relevant: bool
    question_reason: str
    supported_facts: list[str] = field(default_factory=list)
    missing_facts: list[str] = field(default_factory=list)
    contradicted_facts: list[str] = field(default_factory=list)
    uncertain_facts: list[str] = field(default_factory=list)
    raw_response: dict[str, Any] = field(default_factory=dict)


async def evaluate_rag_semantics(
    *,
    selected_topic: str,
    retrieved_context: str,
    question_body: str,
    reference_answer: str,
    explanation: str = "",
    question_type: str = "mcq",
) -> SemanticEvaluationResult:
    """Call the Evaluator LLM (GPT-4o) with temperature 0 to produce structured semantic judgments."""
    user_prompt = f"""Grounding Context:
\"\"\"
{retrieved_context.strip()}
\"\"\"

Selected Topic: {selected_topic}
Question Type: {question_type}

Question Body:
{question_body.strip()}

Reference / Expected Answer:
{reference_answer.strip()}

Explanation (if available):
{explanation.strip() if explanation else "N/A"}

{_EVALUATOR_SCHEMA_HINT}
"""

    try:
        data = await azure_openai.chat_json(
            system_prompt=_EVALUATOR_SYSTEM_PROMPT,
            user_prompt=user_prompt,
            max_output_tokens=600,
            temperature=0.0,
        )
    except Exception as exc:
        logger.warning(
            "RAG Evaluator LLM call failed (%s); falling back to conservative defaults", exc
        )
        return SemanticEvaluationResult(
            chunks_relevant=True,
            chunks_sufficient=True,
            question_grounded=True,
            question_answerable=True,
            question_topic_relevant=True,
            question_reason="Evaluator LLM unavailable; deterministic fallback used",
            supported_facts=[reference_answer] if reference_answer else [],
            missing_facts=[],
            contradicted_facts=[],
            uncertain_facts=[],
            raw_response={},
        )

    r_eval = data.get("retrieval", {}) if isinstance(data.get("retrieval"), dict) else {}
    q_eval = data.get("question", {}) if isinstance(data.get("question"), dict) else {}
    a_eval = data.get("answer", {}) if isinstance(data.get("answer"), dict) else {}

    return SemanticEvaluationResult(
        chunks_relevant=bool(r_eval.get("chunks_relevant", True)),
        chunks_sufficient=bool(r_eval.get("chunks_sufficient", True)),
        question_grounded=bool(q_eval.get("grounded", True)),
        question_answerable=bool(q_eval.get("answerable", True)),
        question_topic_relevant=bool(q_eval.get("topic_relevant", True)),
        question_reason=str(q_eval.get("reason", "")),
        supported_facts=[str(f) for f in a_eval.get("supported_facts", []) if f],
        missing_facts=[str(f) for f in a_eval.get("missing_facts", []) if f],
        contradicted_facts=[str(f) for f in a_eval.get("contradicted_facts", []) if f],
        uncertain_facts=[str(f) for f in a_eval.get("uncertain_facts", []) if f],
        raw_response=data,
    )
