import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

WORKSPACE_ID = "wsp_e83875ecf8a748bda10fd88ba4623e6a"
STUDENT_ID = "usr_f4caab256e6645779de48259dece9631"

async def main():
    from app.core.config import settings
    from motor.motor_asyncio import AsyncIOMotorClient
    from app.services.flashcard_generation import generate_flashcard
    from app.mcp_tools.retrieve_content import RetrievedChunk
    from app.models.question import Question

    client = AsyncIOMotorClient(settings.cosmos_connection_string)
    db = client["93e3ce50-a29e-462b-8956-85674a34d167_shared"]

    # Get correct interactions
    interactions = await db["interactions"].find({
        "workspace_id": WORKSPACE_ID,
        "student_id": STUDENT_ID,
        "is_correct": True
    }).to_list(100)
    print(f"Total correct interactions found: {len(interactions)}")

    # Try simulating for a few interactions
    for idx, itx in enumerate(interactions[:5]):
        topic_name = itx.get("topic")
        question_id = itx.get("question_id")
        print(f"\n--- Interaction {idx+1}: Topic={topic_name!r} QuestionID={question_id!r} ---")
        
        q_doc = await db["question_queue"].find_one({"_id": question_id})
        if not q_doc:
            print("  Question document not found in db!")
            continue
            
        question_doc = Question.model_validate(q_doc)
        
        # Build the retrieved chunk text exactly like _try_candidate does
        question_text = f"Question: {question_doc.body}\n"
        if question_doc.options:
            question_text += "Options:\n"
            for opt in question_doc.options:
                question_text += f"- {opt.key}: {opt.text}\n"
        question_text += f"Correct Answer: {question_doc.answer}\n"
        if question_doc.explanation:
            question_text += f"Explanation: {question_doc.explanation}\n"
            
        chunk = RetrievedChunk(
            chunk_id="chk_q_" + question_doc.id,
            chunk_index=0,
            document_id=question_doc.document_id,
            text=question_text,
            topic_ids=[],
            score=1.0,
        )
        
        try:
            print("Calling generate_flashcard...")
            generated = await generate_flashcard(
                topic=topic_name,
                grounding_chunks=[chunk],
                seen_card_fronts=[]
            )
            print(f"SUCCESS: Front={generated.front!r} Back={generated.back!r}")
        except Exception as e:
            print(f"FAILED: {e}")

if __name__ == "__main__":
    asyncio.run(main())
