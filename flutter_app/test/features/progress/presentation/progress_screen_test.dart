import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/progress/data/demo_progress_repository.dart';
import 'package:social_study_app/features/progress/data/progress_repository.dart';
import 'package:social_study_app/features/progress/presentation/progress_screen.dart';
import 'package:social_study_app/shared/models/progress.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/features/screen_time/providers/screen_time_providers.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';

class _FakeScreenTimeNotifier extends ScreenTimeNotifier {
  @override
  Future<ScreenTimeWallet> build() async {
    return ScreenTimeWallet.initial();
  }

  @override
  Future<void> refreshWallet() async {}
}


class _MockProgressRepo extends Mock implements ProgressRepository {}

class _MockAuthRepo extends Mock implements AuthRepository {}

const _wsId = 'wsp_test';

User _student() => User(
      id: 'usr_demo_001',
      email: 'demo@socialstudyapp.com',
      displayName: 'Demo Student',
      tenantId: 'ten_demo',
      role: UserRole.student,
      createdAt: DateTime(2026, 1, 1),
    );

StudentProgress _populated() => StudentProgress(
      level: 3,
      totalXp: 480,
      xpIntoLevel: 80,
      xpForNextLevel: 200,
      overallMastery: 0.58,
      topics: const [
        TopicMastery(
          topicId: 'top_photo',
          topicName: 'Photosynthesis',
          mastery: 0.82,
          attempts: 14,
          successRate: 0.79,
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
          occurredAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        ),
        ActivityEntry(
          kind: ActivityKind.flashcard,
          topic: 'Genetics',
          xpEarned: 5,
          occurredAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 6))
              .toIso8601String(),
        ),
        ActivityEntry(
          kind: ActivityKind.question,
          topic: 'Genetics',
          isCorrect: false,
          xpEarned: 10,
          occurredAt: DateTime.now()
              .toUtc()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        ),
      ],
    );

Widget _wrap({
  required ProgressRepository repo,
  required AuthRepository authRepo,
}) =>
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(authRepo),
        screenTimeNotifierProvider.overrideWith(() => _FakeScreenTimeNotifier()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ProgressScreen(workspaceId: _wsId)),
      ),
    );


/// The progress view is a scrolling list — give it a tall viewport so
/// every section (overall mastery, every topic card, every activity row)
/// is laid out without needing to scroll the lazy ListView into view.
Future<void> _tallViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Most tests use the student-authenticated path so `StudentProgressNotifier`
/// resolves a non-null userId and reaches the repo.
_MockAuthRepo _authedRepo() {
  final repo = _MockAuthRepo();
  when(() => repo.getStoredUser()).thenAnswer((_) async => _student());
  return repo;
}

void main() {
  late _MockProgressRepo repo;
  late _MockAuthRepo authRepo;

  setUp(() {
    repo = _MockProgressRepo();
    authRepo = _authedRepo();
  });

  testWidgets('shows a loading state while the snapshot fetches',
      (tester) async {
    final completer = Completer<StudentProgress>();
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo: repo, authRepo: authRepo));
    // Let auth resolve, then the notifier kicks off the fetch.
    await tester.pump();
    await tester.pump();

    expect(find.text('Loading your progress…'), findsOneWidget);

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

    await tester.pumpWidget(_wrap(repo: repo, authRepo: authRepo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Level 3'), findsOneWidget);
  });

  testWidgets('zero state shows the Level 1 card and a no-progress message',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => StudentProgress.empty);

    await tester.pumpWidget(_wrap(repo: repo, authRepo: authRepo));

    await tester.pumpAndSettle();

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0 / 100 XP to level 2'), findsOneWidget);
    expect(find.text('No progress yet'), findsOneWidget);
    // The topic + activity section headers must NOT render on empty.
    expect(find.text('TOPIC MASTERY'), findsNothing);
    expect(find.text('RECENT ACTIVITY'), findsNothing);
  });

  testWidgets('populated snapshot renders level, mastery, topics, activity',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo, authRepo: authRepo));
    await tester.pumpAndSettle();

    // Level card
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('480 XP total'), findsOneWidget);
    expect(find.text('80 / 200 XP to level 4'), findsOneWidget);

    // Overall mastery
    expect(find.text('Overall mastery'), findsOneWidget);
    expect(find.text('58%'), findsOneWidget);

    // Topic cards
    expect(find.text('TOPIC MASTERY'), findsOneWidget);
    expect(find.text('Photosynthesis'), findsWidgets); // topic + activity row
    expect(find.text('82%'), findsOneWidget);
    expect(find.text('Genetics'), findsWidgets);
    expect(find.text('31%'), findsOneWidget);

    // Activity timeline
    expect(find.text('RECENT ACTIVITY'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text('Reviewed'), findsOneWidget);
    expect(find.text('+25'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
  });

  testWidgets('mastery bars use the success-rate detail line', (tester) async {
    await _tallViewport(tester);
    when(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo, authRepo: authRepo));
    await tester.pumpAndSettle();

    expect(find.text('14 attempts • 79% correct'), findsOneWidget);
    expect(find.text('4 attempts • 25% correct'), findsOneWidget);
  });

  testWidgets('an unauthenticated session falls back to the empty state',
      (tester) async {
    await _tallViewport(tester);
    final unauthRepo = _MockAuthRepo();
    when(() => unauthRepo.getStoredUser()).thenAnswer((_) async => null);

    await tester.pumpWidget(_wrap(repo: repo, authRepo: unauthRepo));

    await tester.pumpAndSettle();

    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('No progress yet'), findsOneWidget);
    // The notifier short-circuits to empty when there's no user, so the
    // repo is never called.
    verifyNever(() => repo.fetch(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        ));
  });

  testWidgets('the demo repository drives the screen end to end',
      (tester) async {
    await _tallViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider
              .overrideWithValue(DemoProgressRepository()),
          authRepositoryProvider.overrideWithValue(_authedRepo()),
          screenTimeNotifierProvider.overrideWith(() => _FakeScreenTimeNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProgressScreen(workspaceId: 'wsp_demo_001')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('Photosynthesis'), findsWidgets);
    expect(find.text('Cell Biology'), findsWidgets);
  });

  testWidgets('the empty demo variant renders the zero state', (tester) async {
    await _tallViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider
              .overrideWithValue(const EmptyDemoProgressRepository()),
          authRepositoryProvider.overrideWithValue(_authedRepo()),
          screenTimeNotifierProvider.overrideWith(() => _FakeScreenTimeNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProgressScreen(workspaceId: 'wsp_demo_001')),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No progress yet'), findsOneWidget);
  });
}
