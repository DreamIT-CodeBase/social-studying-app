import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/core/utils/subject_classifier.dart';
import 'package:social_study_app/shared/models/document.dart';

void main() {
  test('classifies uploaded computing-document topics consistently', () {
    expect(subjectForTopic('Agents in Copilot Studio'), 'Computer Science');
    expect(subjectForTopic('Billing Methods in Microsoft Foundry'),
        'Computer Science');
    expect(subjectForTopic('Building Agents With GitHub Copilot'),
        'Computer Science');
  });

  test('does not invent a chemistry label for an unknown topic', () {
    expect(subjectForTopic('An Uncategorised Topic'), 'Study');
  });

  test('continues to classify core subjects', () {
    expect(subjectForTopic('Chemical bonds and molecules'), 'Chemistry');
    expect(subjectForTopic('Cell mitosis and DNA'), 'Biology');
    expect(subjectForTopic('Force and motion'), 'Physics');
    expect(subjectForTopic('Calculus and derivatives'), 'Mathematics');
  });

  test('classifies diverse US school and college curriculum subjects', () {
    expect(subjectForTopic('AP US History Reconstruction'), 'History');
    expect(subjectForTopic('US Government and Constitution'),
        'Government & Politics');
    expect(subjectForTopic('Principles of Microeconomics: Supply and Demand'),
        'Economics');
    expect(
        subjectForTopic(
            'AP Psychology: Cognitive Neuroscience and Conditioning'),
        'Psychology');
    expect(subjectForTopic('English Literature and Rhetorical Analysis'),
        'English & Literature');
    expect(subjectForTopic('AP Environmental Science and Plate Tectonics'),
        'Earth & Space Science');
    expect(subjectForTopic('Introduction to Sociology and Social Structures'),
        'Sociology & Anthropology');
    expect(
        subjectForTopic('Introduction to Philosophy and Ethics'), 'Philosophy');
    expect(subjectForTopic('Business Administration and Marketing Strategy'),
        'Business');
    expect(subjectForTopic('AP Art History and Music Theory'), 'Art & Music');
    expect(subjectForTopic('Nursing Pharmacology and Clinical Medicine'),
        'Health & Medicine');
    expect(subjectForTopic('Electrical Engineering and Circuit Schematics'),
        'Engineering');
  });

  test('classifies multilingual topics correctly', () {
    // Hindi
    expect(subjectForTopic('भौतिक विज्ञान गति के नियम'), 'Physics');
    expect(subjectForTopic('कक्षा 10 गणित ज्यामिति'), 'Mathematics');
    expect(subjectForTopic('रासायनिक अभिक्रियाएं एवं समीकरण'), 'Chemistry');
    expect(subjectForTopic('जीवविज्ञान कोशिका संरचना'), 'Biology');

    // Spanish
    expect(subjectForTopic('Física clásica y leyes de Newton'), 'Physics');
    expect(subjectForTopic('Matemáticas avanzadas y álgebra'), 'Mathematics');
    expect(subjectForTopic('Química inorgánica y enlaces'), 'Chemistry');
    expect(subjectForTopic('Biología celular y genética'), 'Biology');

    // French
    expect(subjectForTopic('Physique quantique et thermodynamique'), 'Physics');
    expect(subjectForTopic('Mathématiques équations différentielles'),
        'Mathematics');
    expect(subjectForTopic('Chimie organique et molécules'), 'Chemistry');
  });

  test('classifies document by filename and tags', () {
    const docPhysics = Document(
      id: 'doc_1',
      workspaceId: 'w1',
      filename: 'Physics_Electromagnetism.pdf',
      docType: DocumentType.pdf,
      status: DocumentStatus.ready,
      createdAt: '2026-05-14T00:00:00Z',
    );
    expect(subjectForDocument(docPhysics), 'Physics');

    const docMath = Document(
      id: 'doc_2',
      workspaceId: 'w1',
      filename: 'notes_may.pdf',
      docType: DocumentType.pdf,
      status: DocumentStatus.ready,
      createdAt: '2026-05-14T00:00:00Z',
      topicTags: [TopicTag(name: 'Quadratic Equations')],
    );
    expect(subjectForDocument(docMath), 'Mathematics');

    const docNovel = Document(
      id: 'doc_3',
      workspaceId: 'w1',
      filename: 'gatsby_ch1.pdf',
      docType: DocumentType.pdf,
      status: DocumentStatus.ready,
      createdAt: '2026-05-14T00:00:00Z',
      category: 'The Great Gatsby',
    );
    expect(subjectForDocument(docNovel), 'The Great Gatsby');

    const docBible = Document(
      id: 'doc_4',
      workspaceId: 'w1',
      filename: 'scriptures.pdf',
      docType: DocumentType.pdf,
      status: DocumentStatus.ready,
      createdAt: '2026-05-14T00:00:00Z',
      category: 'The Holy Bible',
    );
    expect(subjectForDocument(docBible), 'The Holy Bible');
  });

  test('provides appropriate emojis and colors including novels and Bible', () {
    expect(subjectEmoji('Physics'), '⚛️');
    expect(subjectEmoji('Mathematics'), '📐');
    expect(subjectEmoji('Chemistry'), '🧪');
    expect(subjectEmoji('Biology'), '🧬');
    expect(subjectEmoji('Computer Science'), '💻');
    expect(subjectEmoji('The Great Gatsby'), '📖');
    expect(subjectEmoji('The Holy Bible'), '📜');
    expect(subjectEmoji('Study'), '📖');
    expect(subjectEmoji(null), '📚');

    expect(subjectColor('The Holy Bible'), isNotNull);
    expect(subjectColor('The Great Gatsby'), isNotNull);
  });
}
