import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/progress/data/demo_progress_repository.dart';
import 'package:social_study_app/shared/models/progress.dart';

void main() {
  group('DemoProgressRepository', () {
    test('returns a non-trivial mid-journey snapshot', () async {
      final repo = DemoProgressRepository();
      final progress = await repo.fetch(
        workspaceId: 'wsp_a',
        userId: 'usr_demo_001',
      );

      expect(progress.level, 3);
      expect(progress.totalXp, greaterThan(0));
      // xpForNextLevel must be > 0 so the UI can divide for the bar.
      expect(progress.xpForNextLevel, greaterThan(0));
      expect(progress.xpIntoLevel, lessThanOrEqualTo(progress.xpForNextLevel));
      expect(progress.hasActivity, isTrue);
    });

    test('every topic mastery is a normalized 0..1 fraction', () async {
      final repo = DemoProgressRepository();
      final progress = await repo.fetch(
        workspaceId: 'wsp_a',
        userId: 'usr_demo_001',
      );

      expect(progress.topics, isNotEmpty);
      for (final topic in progress.topics) {
        expect(topic.mastery, inInclusiveRange(0.0, 1.0));
        expect(topic.successRate, inInclusiveRange(0.0, 1.0));
        expect(topic.attempts, greaterThanOrEqualTo(0));
      }
      expect(progress.overallMastery, inInclusiveRange(0.0, 1.0));
    });

    test('activity timeline covers both questions and flashcards', () async {
      final repo = DemoProgressRepository();
      final progress = await repo.fetch(
        workspaceId: 'wsp_a',
        userId: 'usr_demo_001',
      );

      final kinds = progress.recentActivity.map((a) => a.kind).toSet();
      expect(kinds, contains(ActivityKind.question));
      expect(kinds, contains(ActivityKind.flashcard));
      // Flashcard entries are self-rated — no correctness verdict.
      for (final entry in progress.recentActivity) {
        if (entry.kind == ActivityKind.flashcard) {
          expect(entry.isCorrect, isNull);
        }
      }
    });
  });

  group('EmptyDemoProgressRepository', () {
    test('returns the zero state with hasActivity false', () async {
      const repo = EmptyDemoProgressRepository();
      final progress = await repo.fetch(
        workspaceId: 'wsp_a',
        userId: 'usr_x',
      );

      expect(progress, StudentProgress.empty);
      expect(progress.hasActivity, isFalse);
      expect(progress.level, 1);
      expect(progress.topics, isEmpty);
      expect(progress.recentActivity, isEmpty);
    });
  });
}
