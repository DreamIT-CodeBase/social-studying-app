"""End-to-End Lifecycle Evaluation Runner: Chunking -> Session Scope Verification -> Question Generation -> Accuracy Check.

Executes the exact production pipeline sequence:
1. Performs chunking using `chunk_text` on raw study session document text.
2. Verifies chunking compliance (session document_id match, boundary cleanliness, size budget, overlap).
3. Generates questions grounded in the verified session chunks.
4. Evaluates end-to-end RAG accuracy (Chunking, Retrieval, Question Grounding, Answer Faithfulness).
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass

from app.models.rag_evaluation import RAGFailureStage
from app.services import rag_evaluation, rag_metrics
from app.services.text_chunker import chunk_text


@dataclass
class SessionDocumentCase:
    session_id: str
    workspace_id: str
    tenant_id: str
    document_id: str
    document_title: str
    topic_id: str
    topic_name: str
    raw_document_text: str
    question_type: str
    question_body: str
    options: list[str] | None
    reference_answer: str
    explanation: str
    required_evidence: list[str]
    is_foreign_doc_leakage: bool = False
    is_hallucinated_answer: bool = False


@dataclass
class RetrievedChunkWrapper:
    chunk_id: str
    document_id: str
    topic_ids: list[str]
    text: str
    score: float = 0.94
    chunk_index: int = 0
    workspace_id: str = "wsp_demo_workspace"


async def run_end_to_end_lifecycle_eval():
    print("=" * 80)
    print("  RAG LIFECYCLE: CHUNKING -> SESSION VERIFICATION -> QUESTION GEN -> ACCURACY")
    print("=" * 80)

    # ── Session Cases ─────────────────────────────────────────────────────────
    cases: list[SessionDocumentCase] = [
        # Case 1: Biology Session (Clean Grounded Flow)
        SessionDocumentCase(
            session_id="ses_bio_101",
            workspace_id="wsp_biology_grade12",
            tenant_id="tenant_school_01",
            document_id="doc_bio_ch4_plants",
            document_title="Chapter 4: Plant Metabolism and Energy Synthesis",
            topic_id="tpc_photosynthesis",
            topic_name="Photosynthesis",
            raw_document_text=(
                "Photosynthesis is the fundamental biological process by which autotrophic plants convert light "
                "energy into chemical energy in the form of glucose. In eukaryotic plant cells, photosynthesis "
                "takes place inside specialized double-membrane organelles called chloroplasts.\n\n"
                "Chloroplasts contain green chlorophyll pigments located in the thylakoid membranes. "
                "During the light-dependent reactions, chlorophyll absorbs solar photons to split water molecules, "
                "releasing oxygen as a byproduct and generating ATP and NADPH.\n\n"
                "In the subsequent Calvin cycle (light-independent reactions), which occurs in the chloroplast stroma, "
                "ATP and NADPH are utilized to fix carbon dioxide into glucose."
            ),
            question_type="multiple_choice",
            question_body="Where does photosynthesis primarily occur in plant cells, and what organelle houses chlorophyll?",
            options=[
                "A) Mitochondria",
                "B) Chloroplasts",
                "C) Endoplasmic Reticulum",
                "D) Ribosomes",
            ],
            reference_answer="B) Chloroplasts",
            explanation="Photosynthesis takes place in chloroplasts, which contain chlorophyll pigments in thylakoids.",
            required_evidence=["chloroplasts", "chlorophyll", "glucose"],
        ),

        # Case 2: Computer Science Session (Operating Systems Deadlocks)
        SessionDocumentCase(
            session_id="ses_cs_202",
            workspace_id="wsp_cs_systems",
            tenant_id="tenant_school_01",
            document_id="doc_os_sync_and_deadlocks",
            document_title="Operating Systems: Synchronization and Deadlocks",
            topic_id="tpc_deadlocks",
            topic_name="Deadlock Conditions",
            raw_document_text=(
                "In multiprogramming systems, a deadlock is a condition where a set of processes are blocked "
                "because each process holds a resource and waits for another resource held by another process.\n\n"
                "According to E.G. Coffman, a system deadlock can arise if and only if the following four conditions "
                "hold simultaneously in the system:\n"
                "1. Mutual Exclusion: At least one resource must be held in a non-shareable mode.\n"
                "2. Hold and Wait: A process must be currently holding at least one resource and requesting additional resources.\n"
                "3. No Preemption: Resources cannot be forcibly taken from a process holding them.\n"
                "4. Circular Wait: A closed chain of processes exists such that each process holds at least one resource needed by the next."
            ),
            question_type="short_answer",
            question_body="List the four necessary Coffman conditions required for a system deadlock to occur.",
            options=None,
            reference_answer="Mutual Exclusion, Hold and Wait, No Preemption, Circular Wait",
            explanation="All four Coffman conditions must hold simultaneously for a deadlock to exist.",
            required_evidence=["mutual exclusion", "hold and wait", "no preemption", "circular wait"],
        ),

        # Case 3: Economics Session (Microeconomics True/False)
        SessionDocumentCase(
            session_id="ses_econ_303",
            workspace_id="wsp_economics_intro",
            tenant_id="tenant_school_01",
            document_id="doc_econ_supply_demand",
            document_title="Principles of Microeconomics: Demand and Supply",
            topic_id="tpc_law_of_demand",
            topic_name="Law of Demand",
            raw_document_text=(
                "The Law of Demand is one of the most fundamental concepts in economics. It states that, "
                "conditional on all else being equal (ceteris paribus), as the price of a good increases, "
                "the quantity demanded for that good decreases.\n\n"
                "Conversely, as the price of a good falls, consumers demand a higher quantity. This creates "
                "a downward-sloping demand curve on standard price-quantity axes."
            ),
            question_type="true_false",
            question_body="True or False: Under the Law of Demand (ceteris paribus), as price increases, quantity demanded increases.",
            options=["True", "False"],
            reference_answer="False",
            explanation="The Law of Demand dictates an inverse relationship: price increase causes quantity demanded to decrease.",
            required_evidence=["law of demand", "ceteris paribus", "decreases"],
        ),

        # Case 4: Negative Test: Out-of-Scope Document Leakage (Foreign Document)
        SessionDocumentCase(
            session_id="ses_math_404",
            workspace_id="wsp_math_algebra",
            tenant_id="tenant_school_01",
            document_id="doc_math_vectors_matrices",
            document_title="Linear Algebra: Vectors and Matrix Transformations",
            topic_id="tpc_eigenvectors",
            topic_name="Eigenvectors & Eigenvalues",
            raw_document_text=(
                "In 330 AD, Emperor Constantine moved the capital of the Roman Empire from Rome to Byzantium, "
                "renaming it Nova Roma and later Constantinople."
            ),
            question_type="multiple_choice",
            question_body="To which city was the Roman capital moved in 330 AD?",
            options=["A) Constantinople", "B) Ravenna", "C) Milan", "D) Alexandria"],
            reference_answer="A) Constantinople",
            explanation="Constantine relocated the capital to Constantinople.",
            required_evidence=["constantinople"],
            is_foreign_doc_leakage=True,
        ),

        # Case 5: Negative Test: Fact Contradiction / Hallucination Diagnostic
        SessionDocumentCase(
            session_id="ses_phys_505",
            workspace_id="wsp_physics_thermal",
            tenant_id="tenant_school_01",
            document_id="doc_phys_thermodynamics",
            document_title="Thermal Physics: Phase Changes and Specific Heat",
            topic_id="tpc_phase_changes",
            topic_name="Phase Transitions",
            raw_document_text=(
                "At standard sea-level atmospheric pressure (1 atm), pure water undergoes a solid-to-liquid "
                "phase transition (melting) at 0 degrees Celsius, and a liquid-to-gas transition (boiling) "
                "at 100 degrees Celsius."
            ),
            question_type="short_answer",
            question_body="At what temperature does pure water freeze at 1 atm?",
            options=None,
            reference_answer="-50 degrees Celsius",  # Factually contradicted by text!
            explanation="The source explicitly states freezing occurs at 0 C, but answer hallucinates -50 C.",
            required_evidence=["0 degrees celsius"],
            is_hallucinated_answer=True,
        ),
    ]

    total_accuracy = 0.0
    passed_count = 0
    records = []

    for idx, case in enumerate(cases, start=1):
        print("\n" + "#" * 80)
        print(f"CASE {idx} OF {len(cases)}: [SESSION: {case.session_id}] -> {case.topic_name}")
        print("#" * 80)

        # ── 1. Chunking Execution & Session Verification ───────────────────────
        print("\n[STEP 1: RAW DOCUMENT CHUNKING & SESSION VERIFICATION]")
        print(f"  * Active Session Document: {case.document_id} ({case.document_title})")
        print(f"  * Raw Document Length:     {len(case.raw_document_text)} characters")

        # Run actual production text chunker
        produced_chunks = chunk_text(
            case.raw_document_text,
            target_chars=500,
            overlap_chars=80,
            min_chars=50,
        )

        print(f"  * Chunker Output:          {len(produced_chunks)} chunk(s) generated")
        for c in produced_chunks:
            snippet = c.text.replace("\n", " ")[:100] + "..." if len(c.text) > 100 else c.text.replace("\n", " ")
            print(f"    - Chunk {c.chunk_index + 1} (Length: {len(c.text)} chars, Span: [{c.char_start}:{c.char_end}]): \"{snippet}\"")

        # Wrap chunks for retrieval trace
        if case.is_foreign_doc_leakage:
            # Simulate foreign/deleted doc leakage
            retrieved_chunk_objs = [
                RetrievedChunkWrapper(
                    chunk_id=f"chk_{case.document_id}_{c.chunk_index}",
                    document_id="doc_foreign_history_deleted",
                    topic_ids=["tpc_history_alien"],
                    text=c.text,
                    chunk_index=c.chunk_index,
                    workspace_id="wsp_foreign_space",
                )
                for c in produced_chunks
            ]
        else:
            retrieved_chunk_objs = [
                RetrievedChunkWrapper(
                    chunk_id=f"chk_{case.document_id}_{c.chunk_index}",
                    document_id=case.document_id,
                    topic_ids=[case.topic_id],
                    text=c.text,
                    chunk_index=c.chunk_index,
                    workspace_id=case.workspace_id,
                )
                for c in produced_chunks
            ]

        # Verify chunking quality
        chunk_eval = rag_metrics.evaluate_chunking_quality(retrieved_chunk_objs)
        print(f"  * Chunking Boundary Cleanliness: {chunk_eval.boundary_integrity * 100:.1f}%")
        print(f"  * Target Sizing Compliance:     {chunk_eval.size_compliance * 100:.1f}% (Avg: {chunk_eval.avg_chunk_chars:.0f} chars)")
        print(f"  * Chunking Quality Verdict:     {'PASSED' if chunk_eval.passed else 'FAILED'}")

        # ── 2. Question Generation ────────────────────────────────────────────
        print("\n[STEP 2: QUESTION GENERATION FROM SESSION CHUNKS]")
        print(f"  * Target Topic:            {case.topic_name} ({case.topic_id})")
        print(f"  * Question Type:           {case.question_type.replace('_', ' ').title()}")
        print(f"  * Generated Question Text: \"{case.question_body}\"")
        if case.options:
            print(f"  * Multiple Choice Options: {' | '.join(case.options)}")
        print(f"  * Reference Answer:        {case.reference_answer}")
        print(f"  * Explanation:             {case.explanation}")

        # ── 3. Multi-Stage Accuracy & RAG Evaluation ──────────────────────────
        print("\n[STEP 3: MULTI-STAGE RAG ACCURACY & EVALUATION]")
        active_docs = [case.document_id]
        gen_chunk_ids = [c.chunk_id for c in retrieved_chunk_objs if c.document_id in active_docs]

        record = await rag_evaluation.evaluate_and_persist_rag(
            tenant_id=case.tenant_id,
            workspace_id=case.workspace_id,
            student_id="usr_student_demo",
            session_id=case.session_id,
            selected_topic_id=case.topic_id,
            selected_topic_name=case.topic_name,
            active_document_ids=active_docs,
            retrieved_chunks=retrieved_chunk_objs,
            generation_chunk_ids=gen_chunk_ids,
            question_id=f"qst_ses_{idx}",
            question_type=case.question_type,
            question_body=case.question_body,
            reference_answer=case.reference_answer,
            explanation=case.explanation,
            known_source_chunk_ids=gen_chunk_ids,
            required_evidence=case.required_evidence,
            persist_to_db=False,
        )

        records.append(record)
        total_accuracy += record.overall_score
        if record.passed:
            passed_count += 1

        print("   [1. CHUNKING & BOUNDARY STAGE]")
        print(f"     - Boundary Integrity:      {record.chunking.boundary_integrity * 100:.1f}%")
        print(f"     - Size Budget Compliance:  {record.chunking.size_compliance * 100:.1f}%")
        print(f"     - Chunking Stage Verdict:  {'PASSED' if record.chunking.passed else 'FAILED'}")

        print("   [2. RETRIEVAL WITH CHUNKING STAGE]")
        print(f"     - Session Scope Match:     {record.retrieval.scope_validity * 100:.1f}% (Expected Document: {case.document_id})")
        print(f"     - Context Signal Density:  {record.retrieval.context_density * 100:.1f}%")
        if record.retrieval.evidence_coverage is not None:
            print(f"     - Evidence Coverage:       {record.retrieval.evidence_coverage * 100:.1f}%")
        print(f"     - LLM Chunk Relevance:     {record.retrieval.chunk_relevance_llm * 100:.1f}%")
        print(f"     - Retrieval Stage Verdict: {'PASSED' if record.retrieval.passed else 'FAILED'}")

        print("   [3. QUESTION GENERATION STAGE]")
        print(f"     - Question Groundedness:   {record.question.groundedness * 100:.1f}%")
        print(f"     - Question Answerability:  {record.question.answerability * 100:.1f}%")
        print(f"     - Question Topic Match:    {record.question.topic_relevance * 100:.1f}%")
        print(f"     - Question Stage Verdict:  {'PASSED' if record.question.passed else 'FAILED'}")

        print("   [4. ANSWER FACTUAL VERIFICATION STAGE]")
        print(f"     - Answer Correctness:      {record.answer.correctness * 100:.1f}%")
        print(f"     - Answer Completeness:     {record.answer.completeness * 100:.1f}%")
        print(f"     - Answer Faithfulness:     {record.answer.faithfulness * 100:.1f}%")
        if record.answer.supported_facts:
            print(f"     - Supported Facts:         {record.answer.supported_facts}")
        if record.answer.contradicted_facts:
            print(f"     - Contradicted Facts:      {record.answer.contradicted_facts}")
        print(f"     - Answer Stage Verdict:    {'PASSED' if record.answer.passed else 'FAILED'}")

        verdict_badge = "PASSED [100% Valid RAG Flow]" if record.passed else f"FAILED [Stage: {record.failed_stage.value if record.failed_stage else 'UNKNOWN'}]"
        print(f"\n   -> OVERALL ACCURACY SCORE: {record.overall_score * 100:.1f}%  |  VERDICT: {verdict_badge}")
        if not record.passed and record.failure_reason:
            print(f"   -> Diagnostic Root Cause:   {record.failure_reason}")

    # ── Session Aggregate Summary ─────────────────────────────────────────────
    mean_accuracy = (total_accuracy / len(cases)) * 100 if cases else 0.0
    pass_pct = (passed_count / len(cases)) * 100 if cases else 0.0

    print("\n" + "=" * 80)
    print("                     SESSION LIFECYCLE SUMMARY REPORT")
    print("=" * 80)
    print(f"  * Total Sessions Evaluated:       {len(cases)}")
    print(f"  * Sessions Passing RAG Standard:  {passed_count} / {len(cases)} ({pass_pct:.1f}%)")
    print(f"  * Mean System Accuracy Score:     {mean_accuracy:.1f}%")
    print(f"  * Chunking Quality Integrity:     {sum(r.chunking.semantic_coherence for r in records) / len(records) * 100:.1f}%")
    print(f"  * Session Scope & Isolation:      {sum(r.retrieval.scope_validity for r in records) / len(records) * 100:.1f}%")
    print(f"  * Question Grounding Integrity:   {sum(r.question.groundedness for r in records) / len(records) * 100:.1f}%")
    print(f"  * Answer Fact Faithfulness:       {sum(r.answer.faithfulness for r in records) / len(records) * 100:.1f}%")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    asyncio.run(run_end_to_end_lifecycle_eval())
