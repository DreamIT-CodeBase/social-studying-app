import 'dart:async';

import 'package:social_study_app/features/progress/data/progress_repository.dart';
import 'package:social_study_app/shared/models/progress.dart';

/// Offline, deterministic implementation of the progress feed.
///
/// Backs the demo user so an offline dev can exercise the full progress
/// view — level/XP card, per-topic mastery bars, activity timeline —
/// without a live backend (and without Sprint 5.9 existing yet).
///
/// The snapshot is a fixed, plausible mid-journey profile: a Level 3
/// student partway through four topics. It's intentionally non-trivial
/// so the mastery bars and timeline have something real to render.
class DemoProgressRepository implements ProgressRepository {
  DemoProgressRepository();

  @override
  Future<StudentProgress> fetch({
    required String workspaceId,
    required String userId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _snapshot;
  }

  static const StudentProgress _snapshot = StudentProgress(
    level: 3,
    totalXp: 480,
    xpIntoLevel: 80,
    xpForNextLevel: 200,
    overallMastery: 0.58,
    topics: [
      TopicMastery(
        topicId: 'top_photosynthesis',
        topicName: 'Photosynthesis',
        mastery: 0.82,
        attempts: 14,
        successRate: 0.79,
      ),
      TopicMastery(
        topicId: 'top_cell_biology',
        topicName: 'Cell Biology',
        mastery: 0.64,
        attempts: 9,
        successRate: 0.67,
      ),
      TopicMastery(
        topicId: 'top_cellular_respiration',
        topicName: 'Cellular Respiration',
        mastery: 0.45,
        attempts: 6,
        successRate: 0.50,
      ),
      TopicMastery(
        topicId: 'top_genetics',
        topicName: 'Genetics',
        mastery: 0.31,
        attempts: 4,
        successRate: 0.25,
      ),
    ],
    recentActivity: [
      ActivityEntry(
        kind: ActivityKind.question,
        topic: 'Photosynthesis',
        isCorrect: true,
        xpEarned: 25,
        occurredAt: '2026-05-22T09:14:00Z',
      ),
      ActivityEntry(
        kind: ActivityKind.flashcard,
        topic: 'Cell Biology',
        xpEarned: 5,
        occurredAt: '2026-05-22T09:11:00Z',
      ),
      ActivityEntry(
        kind: ActivityKind.question,
        topic: 'Cellular Respiration',
        isCorrect: false,
        xpEarned: 10,
        occurredAt: '2026-05-21T18:42:00Z',
      ),
      ActivityEntry(
        kind: ActivityKind.question,
        topic: 'Genetics',
        isCorrect: true,
        xpEarned: 25,
        occurredAt: '2026-05-21T18:39:00Z',
      ),
      ActivityEntry(
        kind: ActivityKind.flashcard,
        topic: 'Photosynthesis',
        xpEarned: 5,
        occurredAt: '2026-05-21T18:35:00Z',
      ),
    ],
  );
}

/// Variant demo repository that always returns the zero-state snapshot.
///
/// Not wired into the provider — it exists so widget tests can drive the
/// progress screen's empty state through the real repository seam rather
/// than faking it.
class EmptyDemoProgressRepository implements ProgressRepository {
  const EmptyDemoProgressRepository();

  @override
  Future<StudentProgress> fetch({
    required String workspaceId,
    required String userId,
  }) async => StudentProgress.empty;
}
