from app.models.document import Document, DocumentStatus, DocumentType, TopicTag
from app.services.subject_classifier import (
    classify_document_subject,
    classify_subject_from_text,
)


def test_classify_english_subjects():
    assert classify_subject_from_text("Newtonian Mechanics and Gravitation") == "Physics"
    assert classify_subject_from_text("Integral Calculus and Derivatives") == "Mathematics"
    assert classify_subject_from_text("Organic Chemistry and Covalent Bonds") == "Chemistry"
    assert classify_subject_from_text("Cellular Mitosis and DNA Replication") == "Biology"
    assert classify_subject_from_text("Python Algorithms and Data Structures") == "Computer Science"
    assert classify_subject_from_text("Random Uncategorized Title") == "Study"


def test_classify_us_curriculum_subjects():
    assert classify_subject_from_text("AP US History Reconstruction") == "History"
    assert classify_subject_from_text("US Government and Constitution") == "Government & Politics"
    assert classify_subject_from_text("Principles of Microeconomics: Supply and Demand") == "Economics"
    assert classify_subject_from_text("AP Psychology: Cognitive Neuroscience and Conditioning") == "Psychology"
    assert classify_subject_from_text("English Literature and Rhetorical Analysis") == "English & Literature"
    assert classify_subject_from_text("AP Environmental Science and Plate Tectonics") == "Earth & Space Science"
    assert classify_subject_from_text("Introduction to Sociology and Social Structures") == "Sociology & Anthropology"
    assert classify_subject_from_text("Introduction to Philosophy and Ethics") == "Philosophy"
    assert classify_subject_from_text("Business Administration and Marketing Strategy") == "Business"
    assert classify_subject_from_text("AP Art History and Music Theory") == "Art & Music"
    assert classify_subject_from_text("Nursing Pharmacology and Clinical Medicine") == "Health & Medicine"
    assert classify_subject_from_text("Electrical Engineering and Circuit Schematics") == "Engineering"


def test_classify_multilingual_subjects():
    # Hindi
    assert classify_subject_from_text("भौतिक विज्ञान गति के नियम") == "Physics"
    assert classify_subject_from_text("कक्षा 10 गणित ज्यामिति") == "Mathematics"
    assert classify_subject_from_text("रासायनिक अभिक्रियाएं एवं समीकरण") == "Chemistry"
    assert classify_subject_from_text("जीवविज्ञान कोशिका संरचना") == "Biology"

    # Spanish
    assert classify_subject_from_text("Física clásica y leyes de Newton") == "Physics"
    assert classify_subject_from_text("Matemáticas avanzadas y álgebra") == "Mathematics"
    assert classify_subject_from_text("Química inorgánica y enlaces") == "Chemistry"
    assert classify_subject_from_text("Biología celular y genética") == "Biology"

    # French
    assert classify_subject_from_text("Physique quantique et thermodynamique") == "Physics"
    assert classify_subject_from_text("Mathématiques équations différentielles") == "Mathematics"
    assert classify_subject_from_text("Chimie organique et molécules") == "Chemistry"


def test_classify_document_subject():
    doc_physics = Document(
        id="doc_1",
        tenant_id="t1",
        workspace_id="w1",
        uploaded_by="u1",
        filename="Physics_Chapter_4.pdf",
        blob_url="https://blob/doc.pdf",
        file_size_bytes=1000,
        doc_type=DocumentType.pdf,
        status=DocumentStatus.ready,
    )
    assert classify_document_subject(doc_physics) == "Physics"

    doc_math_topics = Document(
        id="doc_2",
        tenant_id="t1",
        workspace_id="w1",
        uploaded_by="u1",
        filename="lecture_notes_october.pdf",
        blob_url="https://blob/doc.pdf",
        file_size_bytes=1000,
        doc_type=DocumentType.pdf,
        status=DocumentStatus.ready,
        topic_tags=[TopicTag(name="Quadratic Equations")],
    )
    assert classify_document_subject(doc_math_topics) == "Mathematics"
