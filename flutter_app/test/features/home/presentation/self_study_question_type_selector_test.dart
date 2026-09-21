import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/features/home/providers/self_study_subject_providers.dart';

void main() {
  test('selfStudyQuestionTypeProvider defaults to null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(selfStudyQuestionTypeProvider), isNull);

    container.read(selfStudyQuestionTypeProvider.notifier).state = 'mcq';
    expect(container.read(selfStudyQuestionTypeProvider), equals('mcq'));

    container.read(selfStudyQuestionTypeProvider.notifier).state =
        'true_false';
    expect(
        container.read(selfStudyQuestionTypeProvider), equals('true_false'));

    container.read(selfStudyQuestionTypeProvider.notifier).state =
        'long_answer';
    expect(
        container.read(selfStudyQuestionTypeProvider), equals('long_answer'));

    container.read(selfStudyQuestionTypeProvider.notifier).state = null;
    expect(container.read(selfStudyQuestionTypeProvider), isNull);
  });

  test('isSelfLearningWorkspaceId identifies self-study workspace prefix', () {
    expect(isSelfLearningWorkspaceId('wsp_self_stu_123'), isTrue);
    expect(isSelfLearningWorkspaceId('wsp_classroom_456'), isFalse);
    expect(isSelfLearningWorkspaceId(''), isFalse);
  });

  test('question_type query string is generated for both self-study and admin workspaces', () {
    for (final ws in ['wsp_self_stu_123', 'wsp_classroom_normal_789']) {
      for (final type in ['mcq', 'true_false', 'short_answer', 'long_answer']) {
        final typeQuery = '&question_type=${Uri.encodeComponent(type)}';
        final url = '/student/session/$ws?mode=study$typeQuery';
        expect(url, contains('question_type=$type'));
        expect(url, contains('/student/session/$ws'));
      }
    }
  });
}
