import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/admin/students/presentation/student_progress_detail_screen.dart';
import 'package:social_study_app/features/progress/data/progress_repository.dart';
import 'package:social_study_app/shared/models/progress.dart';

class _MockProgressRepo extends Mock implements ProgressRepository {}

const _wsId = 'wsp_test';
const _studentId = 'stu_target';
const _studentName = 'Maya Chen';

StudentProgress _populated() => const StudentProgress(
      level: 3,
      totalXp: 480,
      xpIntoLevel: 80,
      xpForNextLevel: 200,
      overallMastery: 0.58,
      topics: [
        TopicMastery(
          topicId: 'top_photo',
          topicName: 'Photosynthesis',
          mastery: 0.82,
          attempts: 14,
          successRate: 0.79,
        ),
        TopicMastery(
          topicId: 'top_resp',
          topicName: 'Cellular Respiration',
          mastery: 0.35,
          attempts: 6,
          successRate: 0.50,
        ),
        TopicMastery(
          topicId: 'top_gen',
          topicName: 'Genetics',
          mastery: 0.20,
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
      ],
    );

Widget _wrap({required ProgressRepository repo}) => ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const StudentProgressDetailScreen(
          workspaceId: _wsId,
          studentId: _studentId,
          studentName: _studentName,
        ),
      ),
    );

/// Tall viewport so every section lays out without lazy-scroll churn.
Future<void> _tallViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  late _MockProgressRepo repo;

  setUp(() {
    repo = _MockProgressRepo();
  });

  testWidgets('shows loading state while the snapshot fetches',
      (tester) async {
    final completer = Completer<StudentProgress>();
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump();

    expect(find.text('Loading student progress…'), findsOneWidget);

    completer.complete(StudentProgress.empty);
    await tester.pumpAndSettle();
  });

  testWidgets('error state shows ErrorView with a retry that refetches',
      (tester) async {
    var calls = 0;
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('progress fetch failed');
      return _populated();
    });

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Level 3'), findsOneWidget);
  });

  testWidgets('zero state shows the no-activity callout', (tester) async {
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => StudentProgress.empty);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No activity yet'), findsOneWidget);
    // Topic / activity section headers must not render when there's
    // no activity.
    expect(find.text('TOPIC MASTERY'), findsNothing);
    expect(find.text('WEAK AREAS'), findsNothing);
  });

  testWidgets('populated snapshot renders the admin layout', (tester) async {
    await _tallViewport(tester);
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    // AppBar shows the student's name + subtitle.
    expect(find.text(_studentName), findsOneWidget);
    expect(find.text('Student progress'), findsOneWidget);

    // Level card.
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('480 XP total'), findsOneWidget);

    // Stat tiles.
    expect(find.text('Overall'), findsOneWidget);
    expect(find.text('58%'), findsOneWidget);
    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('Attempts'), findsOneWidget);

    // Weak areas: Cellular Respiration (35%) and Genetics (20%) are
    // both < 50% and have attempts > 0.
    expect(find.text('WEAK AREAS'), findsOneWidget);
    expect(find.text('Below 50% mastery'), findsOneWidget);
    expect(find.text('TOPIC MASTERY'), findsOneWidget);
    expect(find.text('RECENT ACTIVITY'), findsOneWidget);
  });

  testWidgets('endpoint args carry the target student id, not the caller',
      (tester) async {
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.fetch(
          workspaceId: captureAny(named: 'workspaceId'),
          userId: captureAny(named: 'userId'),
        )).captured;
    expect(captured, contains(_wsId));
    expect(captured, contains(_studentId));
  });
}
