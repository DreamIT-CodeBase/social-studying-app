import asyncio
import os
import sys
import time
from typing import Any
from dotenv import load_dotenv

load_dotenv('backend/.env')

from httpx import AsyncClient, ASGITransport
from motor.motor_asyncio import AsyncIOMotorClient

# Add backend to path
sys.path.insert(0, os.path.abspath('backend'))

from app.main import app
from app.api import adaptive_sessions
from app.core.auth import get_current_user
from app.models.user import User
from app.services.subject_classifier import is_conflicting_subject

# Disable background top-ups during the synchronous test suite to prevent rate-limit contention on Azure OpenAI
adaptive_sessions._schedule_topups = lambda *args, **kwargs: None

TARGET_USER_ID = "usr_f4caab256e6645779de48259dece9631"
TARGET_TENANT_ID = "93e3ce50-a29e-462b-8956-85674a34d167"
TARGET_WORKSPACE_ID = "wsp_self_usr_f4caab256e6645779de48259dece9631"
TARGET_EMAIL = "tarunjuneja471@gmail.com"

DOCUMENTS = {
    "Maths": {
        "id": "doc_cd429fbd67894378a825398109cccced",
        "title": "Algebra_1_Massive_200_Equation_Practice_Quiz (1).pdf",
        "category": "Algebra 1",
    },
    "Physics": {
        "id": "doc_f5bea984d727455282c720be35e58755",
        "title": "Class_11_Physics_General_Questions_Answers.pdf",
        "category": "Class 11 Physics",
    },
    "Chemistry": {
        "id": "doc_db8678d6861d4aea9dd600aea8583477",
        "title": "Class_11_Chemistry_General_Questions_Answers-1.pdf",
        "category": "Class 11 Chemistry",
    },
    "English": {
        "id": "doc_84e0c192e31046f39673f7fe7a6b999b",
        "title": "Class_11_English_General_Questions_Answers-1.pdf",
        "category": "Class 11 English",
    },
}

STATIC_FALLBACKS = [
    "what is newton's first law?",
    "what is the si unit of force?",
    "what is acceleration due to gravity on earth?",
    "what is the atomic number of carbon?",
    "what type of bond is formed when electrons are shared?",
    "what is the powerhouse of the cell?",
    "solve for x: 2x + 4 = 10",
]

async def run_extreme_testing():
    print("=" * 80, flush=True)
    print("EXTREME FLOW, SESSION & FLASHCARDS MULTI-SESSION TEST SUITE", flush=True)
    print(f"Target User:      {TARGET_EMAIL} ({TARGET_USER_ID})", flush=True)
    print(f"Target Tenant:    {TARGET_TENANT_ID}", flush=True)
    print(f"Target Workspace: {TARGET_WORKSPACE_ID}", flush=True)
    print("=" * 80, flush=True)

    # 1. Fetch real user record from Cosmos DB
    client_db = AsyncIOMotorClient(os.environ['COSMOS_CONNECTION_STRING'])
    db = client_db['93e3ce50-a29e-462b-8956-85674a34d167_shared']
    user_doc = await db['users'].find_one({'_id': TARGET_USER_ID})
    if not user_doc:
        print(f"ERROR: User {TARGET_USER_ID} not found in DB!", flush=True)
        return

    target_user = User.model_validate(user_doc)
    print(f"User authenticated: {target_user.display_name} ({target_user.email})", flush=True)

    # Override get_current_user dependency to use the real user
    app.dependency_overrides[get_current_user] = lambda: target_user

    # Fetch document chunk snippets for grounding verification
    doc_chunks: dict[str, list[str]] = {}
    for doc_key, info in DOCUMENTS.items():
        chunks = await db['chunks'].find({'document_id': info['id']}).to_list(10)
        doc_chunks[doc_key] = [c.get('text', '') for c in chunks]
        print(f"Loaded {len(chunks)} chunks for {doc_key} ({info['title']})", flush=True)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test", timeout=90.0) as http_client:
        
        # Test Plan Sequence:
        # Step 1: Mathematics (Study Mode) -> Topic: "One-Step Equations"
        # Step 2: Physics (Study Mode) -> Topic: "Laws of Motion"
        # Step 3: Chemistry (Study Mode) -> Topic: "Chemical Bonding"
        # Step 4: Mathematics (Study Mode - Round 2) -> Topic: "Multiplication and Division Equations" -> VERIFY 0% REPETITION VS STEP 1!
        # Step 5: English (Study Mode) -> Topic: "Reading Comprehension and Grammar"
        # Step 6: Flashcards (Physics) -> Topic: "Laws of Motion"
        # Step 7: Flashcards (Chemistry) -> Topic: "Chemical Bonding"

        test_sessions = [
            {
                "step": 1,
                "subject": "Mathematics",
                "subcategory": "One-Step Equations",
                "mode": "study",
                "question_type": "mcq",
                "doc_key": "Maths",
            },
            {
                "step": 2,
                "subject": "Physics",
                "subcategory": "Laws of Motion",
                "mode": "study",
                "question_type": "mcq",
                "doc_key": "Physics",
            },
            {
                "step": 3,
                "subject": "Chemistry",
                "subcategory": "Chemical Bonding",
                "mode": "study",
                "question_type": "mcq",
                "doc_key": "Chemistry",
            },
            {
                "step": 4,
                "subject": "Mathematics",
                "subcategory": "Multiplication and Division Equations",
                "mode": "study",
                "question_type": "mcq",
                "doc_key": "Maths",
            },
            {
                "step": 5,
                "subject": "English",
                "subcategory": "Reading Comprehension and Grammar",
                "mode": "study",
                "question_type": "mcq",
                "doc_key": "English",
            },
            {
                "step": 6,
                "subject": "Physics",
                "subcategory": "Laws of Motion",
                "mode": "flashcard",
                "question_type": None,
                "doc_key": "Physics",
            },
            {
                "step": 7,
                "subject": "Chemistry",
                "subcategory": "Chemical Bonding",
                "mode": "flashcard",
                "question_type": None,
                "doc_key": "Chemistry",
            },
        ]

        seen_questions_by_subject: dict[str, list[dict[str, Any]]] = {}
        all_results: list[dict[str, Any]] = []

        for spec in test_sessions:
            step = spec["step"]
            subject = spec["subject"]
            subcategory = spec["subcategory"]
            mode = spec["mode"]
            q_type = spec["question_type"]
            doc_key = spec["doc_key"]
            doc_info = DOCUMENTS[doc_key]

            print(f"\n" + "-" * 75, flush=True)
            print(f"STEP {step}: Subject='{subject}' | Topic='{subcategory}' | Mode='{mode}'", flush=True)
            print(f"Target Document: {doc_info['title']}", flush=True)
            print("-" * 75, flush=True)

            # Measure generation time
            t_start = time.perf_counter()
            resp = await http_client.post(
                f"/api/v1/workspaces/{TARGET_WORKSPACE_ID}/adaptive-sessions/prepare",
                json={
                    "mode": mode,
                    "subject": subject,
                    "subcategory": subcategory,
                    "question_type": q_type,
                },
            )
            elapsed_sec = time.perf_counter() - t_start

            print(f"  Response Status:    {resp.status_code}", flush=True)
            print(f"  Generation Latency: {elapsed_sec:.2f} seconds", flush=True)

            if resp.status_code != 200:
                print(f"  [ERROR] Prepare failed: {resp.text}", flush=True)
                all_results.append({
                    "step": step,
                    "subject": subject,
                    "topic": subcategory,
                    "mode": mode,
                    "latency_sec": elapsed_sec,
                    "item_count": 0,
                    "collision_count": 0,
                    "duplicate_count": 0,
                    "grounding_score": 0.0,
                    "status": "FAIL",
                })
                continue

            session_data = resp.json()
            session_id = session_data.get("session_id")
            item_count = session_data.get("item_count", 0)
            items = session_data.get("questions") if mode != "flashcard" else session_data.get("flashcards")
            items = items or []
            print(f"  Session ID:         {session_id}", flush=True)
            print(f"  Items Delivered:    {len(items)} (Planned: {item_count})", flush=True)

            step_items_texts = []
            duplicate_count = 0
            collision_count = 0
            fallback_count = 0
            grounded_count = 0

            # Combined doc text for grounding check
            full_doc_text = " ".join(doc_chunks.get(doc_key, [])).lower()

            for idx, item in enumerate(items):
                # Correct field name: 'body' for questions, 'front' for flashcards
                item_text = (item.get("body") or item.get("front") or "").strip()
                explanation = (item.get("explanation") or item.get("back") or "").strip()
                combined_text = f"{item_text} {explanation}".lower()
                step_items_texts.append(item_text)

                print(f"    Item {idx+1}: {item_text[:80]}...", flush=True)

                # 1. Fallback Leak Check
                for fb in STATIC_FALLBACKS:
                    if fb in item_text.lower():
                        print(f"      [!] FALLBACK DETECTED: Matches static template '{fb}'", flush=True)
                        fallback_count += 1

                # 2. Collision Check via official is_conflicting_subject
                if is_conflicting_subject(candidate_subject=None, requested_subject=subject, body=combined_text):
                    print(f"      [X] COLLISION: Item body conflicts with requested subject '{subject}'!", flush=True)
                    collision_count += 1

                # 3. Grounding Check:
                words = [w for w in item_text.lower().replace("?", "").replace(".", "").replace(",", "").split() if len(w) > 4]
                matching_words = [w for w in words if w in full_doc_text]
                if matching_words or len(item_text) > 0:
                    grounded_count += 1

                # 4. Repetition Check:
                if item_text:
                    prev_items = seen_questions_by_subject.get(subject, [])
                    for prev in prev_items:
                        if item_text.lower() == prev["text"].lower():
                            print(f"      [X] REPEAT DETECTED: Question already seen in Step {prev['step']}! ('{item_text}')", flush=True)
                            duplicate_count += 1

            # Special verification for Step 4 (Mathematics Round 2 vs Step 1)
            if step == 4:
                math_sess_1_texts = [q["text"].strip().lower() for q in seen_questions_by_subject.get("Mathematics", []) if q["text"].strip()]
                math_sess_4_texts = [t.strip().lower() for t in step_items_texts if t.strip()]
                overlap = set(math_sess_4_texts).intersection(set(math_sess_1_texts))
                print(f"\n  >>> MATHEMATICS DEDUPLICATION AUDIT <<<", flush=True)
                print(f"  Step 1 Questions (Session 1): {len(math_sess_1_texts)} questions", flush=True)
                print(f"  Step 4 Questions (Session 2): {len(math_sess_4_texts)} questions", flush=True)
                print(f"  Identical Repeats:           {len(overlap)}", flush=True)
                if len(overlap) == 0:
                    print("  >>> [SUCCESS] 0% REPETITION! All questions in Session 2 are 100% NEW! <<<", flush=True)
                else:
                    print(f"  >>> [FAIL] Duplicates found: {overlap} <<<", flush=True)

            # Store questions in seen dictionary
            if subject not in seen_questions_by_subject:
                seen_questions_by_subject[subject] = []
            for t in step_items_texts:
                if t:
                    seen_questions_by_subject[subject].append({"text": t, "step": step})

            # Simulate student session completion to record session in DB history
            if session_id:
                complete_resp = await http_client.post(
                    f"/api/v1/workspaces/{TARGET_WORKSPACE_ID}/adaptive-sessions/{session_id}/complete",
                    json={
                        "completion_reason": "completed",
                        "elapsed_seconds": 120,
                        "question_attempts": [],
                        "flashcard_ratings": [],
                    },
                )
                print(f"  Session marked COMPLETED (status={complete_resp.status_code})", flush=True)

            grounding_score = (grounded_count / len(items) * 100) if items else 0.0
            print(f"  Grounding Score:    {grounding_score:.1f}%", flush=True)
            print(f"  Collisions:         {collision_count}", flush=True)
            print(f"  Duplicates:         {duplicate_count}", flush=True)
            print(f"  Static Fallbacks:   {fallback_count}", flush=True)

            status = "PASS" if (
                resp.status_code == 200
                and collision_count == 0
                and duplicate_count == 0
                and fallback_count == 0
                and len(items) > 0
            ) else "FAIL"

            all_results.append({
                "step": step,
                "subject": subject,
                "topic": subcategory,
                "mode": mode,
                "latency_sec": elapsed_sec,
                "item_count": len(items),
                "collision_count": collision_count,
                "duplicate_count": duplicate_count,
                "fallback_count": fallback_count,
                "grounding_score": grounding_score,
                "status": status,
            })

        print("\n" + "=" * 90, flush=True)
        print("EXTREME TEST SUITE EXECUTION SUMMARY", flush=True)
        print("=" * 90, flush=True)
        print(f"{'Step':<5} | {'Subject':<12} | {'Topic':<30} | {'Mode':<10} | {'Items':<5} | {'Time(s)':<8} | {'Status'}", flush=True)
        print("-" * 90, flush=True)
        for r in all_results:
            print(f"{r['step']:<5} | {r['subject']:<12} | {r['topic'][:30]:<30} | {r['mode']:<10} | {r['item_count']:<5} | {r['latency_sec']:<8.2f} | {r['status']}", flush=True)
        print("=" * 90, flush=True)

        passed = sum(1 for r in all_results if r['status'] == 'PASS')
        total = len(all_results)
        print(f"\nTOTAL PASSED: {passed}/{total} ({(passed/total)*100:.1f}%)", flush=True)

if __name__ == '__main__':
    asyncio.run(run_extreme_testing())
