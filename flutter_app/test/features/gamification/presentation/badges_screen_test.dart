import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/gamification/data/gamification_repository.dart';
import 'package:social_study_app/features/gamification/presentation/badges_screen.dart';
import 'package:social_study_app/shared/models/gamification.dart';

class _MockRepo extends Mock implements GamificationRepository {}

const _wsId = 'wsp_test';
const _userId = 'usr_test';

BadgesSummary _populated() => const BadgesSummary(
      studentId: _userId,
      earned: [
        EarnedBadge(
          badgeId: 'first_steps',
          name: 'First Steps',
          description: 'Answer your first question.',
          icon: 'spa_rounded',
          earnedAt: '2026-05-22T10:00:00Z',
        ),
        EarnedBadge(
          badgeId: 'streak_3',
          name: 'Warming Up',
          description: 'Study three days in a row.',
          icon: 'whatshot_rounded',
          earnedAt: '2026-05-23T10:00:00Z',
        ),
      ],
      available: [
        AvailableBadge(
          badgeId: 'streak_7',
          name: 'Dedicated',
          description: 'Maintain a seven-day study streak.',
          icon: 'local_fire_department_rounded',
        ),
      ],
      earnedCount: 2,
      totalCount: 3,
    );

Widget _wrap({required GamificationRepository repo}) => ProviderScope(
      overrides: [
        gamificationRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BadgesScreen(workspaceId: _wsId, userId: _userId),
      ),
    );

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows loading state while the badges fetch resolves',
      (tester) async {
    final completer = Completer<BadgesSummary>();
    when(() => repo.fetchBadges(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump();

    expect(find.text('Loading badges…'), findsOneWidget);

    completer.complete(BadgesSummary.empty);
    await tester.pumpAndSettle();
  });

  testWidgets('error state shows ErrorView with a retry that refetches',
      (tester) async {
    var calls = 0;
    when(() => repo.fetchBadges(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('badges fetch failed');
      return _populated();
    });

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('First Steps'), findsOneWidget);
  });

  testWidgets('populated payload renders earned + available sections',
      (tester) async {
    when(() => repo.fetchBadges(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    // Progress header counts the unlocks.
    expect(find.text('2 of 3 unlocked'), findsOneWidget);
    // Both section headers render.
    expect(find.text('EARNED'), findsOneWidget);
    expect(find.text('UP NEXT'), findsOneWidget);
    // Earned tiles.
    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text('Warming Up'), findsOneWidget);
    // Locked tile.
    expect(find.text('Dedicated'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
  });

  testWidgets('only-earned state hides the Up next section', (tester) async {
    when(() => repo.fetchBadges(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer(
      (_) async => const BadgesSummary(
        studentId: _userId,
        earned: [
          EarnedBadge(
            badgeId: 'first_steps',
            name: 'First Steps',
            description: 'Answer your first question.',
            icon: 'spa_rounded',
            earnedAt: '2026-05-22T10:00:00Z',
          ),
        ],
        earnedCount: 1,
        totalCount: 1,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('EARNED'), findsOneWidget);
    expect(find.text('UP NEXT'), findsNothing);
  });

  testWidgets('tapping an earned tile opens the detail sheet', (tester) async {
    when(() => repo.fetchBadges(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('First Steps'));
    await tester.pumpAndSettle();

    // Sheet shows the description + an "Earned ..." chip.
    expect(find.text('Answer your first question.'), findsOneWidget);
    expect(find.textContaining('Earned'), findsWidgets);
  });

  testWidgets('tapping a locked tile opens the criteria sheet',
      (tester) async {
    // Tall viewport so the "Up next" section sits inside the laid-out
    // tree at hit-test time — the default 800x600 viewport leaves the
    // locked tile below the fold.
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => repo.fetchBadges(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Dedicated'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dedicated'));
    await tester.pumpAndSettle();

    // Sheet shows the unlock criteria. The earned-elsewhere tiles on
    // the grid behind the sheet also carry an "Earned …" label, so we
    // scope the negative check to widgets inside the modal sheet.
    expect(
      find.text('Maintain a seven-day study streak.'),
      findsOneWidget,
    );
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.textContaining('Earned ')),
      findsNothing,
    );
  });
}
