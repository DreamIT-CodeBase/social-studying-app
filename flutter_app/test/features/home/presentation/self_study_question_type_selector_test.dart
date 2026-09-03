import 'package:flutter/material.dart';
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

    container.read(selfStudyQuestionTypeProvider.notifier).state = 'short_answer';
    expect(container.read(selfStudyQuestionTypeProvider), equals('short_answer'));

    container.read(selfStudyQuestionTypeProvider.notifier).state = null;
    expect(container.read(selfStudyQuestionTypeProvider), isNull);
  });

  test('isSelfLearningWorkspaceId identifies self-study workspace prefix', () {
    expect(isSelfLearningWorkspaceId('wsp_self_stu_123'), isTrue);
    expect(isSelfLearningWorkspaceId('wsp_classroom_456'), isFalse);
    expect(isSelfLearningWorkspaceId(''), isFalse);
  });
}
