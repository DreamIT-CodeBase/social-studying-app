import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/core/utils/subject_classifier.dart';

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
  });
}
