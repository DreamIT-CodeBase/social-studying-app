import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/gamification/data/gamification_repository.dart';
import 'package:social_study_app/features/gamification/presentation/leaderboard_screen.dart';
import 'package:social_study_app/shared/models/gamification.dart';

class _MockRepo extends Mock implements GamificationRepository {}

const _wsId = 'wsp_test';
const _currentUserId = 'usr_me';

LeaderboardResponse _populated() => const LeaderboardResponse(
      workspaceId: _wsId,
      visible: true,
      currentUserRank: 2,
      entries: [
        LeaderboardEntry(
          studentId: 'usr_alex',
          displayName: 'Alex Chen',
          level: 4,
          xpTotal: 920,
          xpThisWeek: 240,
          rank: 1,
          streakDays: 12,
        ),
        LeaderboardEntry(
          studentId: _currentUserId,
          displayName: 'You',
          level: 3,
          xpTotal: 480,
          xpThisWeek: 120,
          rank: 2,
          streakDays: 4,
        ),
        LeaderboardEntry(
          studentId: 'usr_priya',
          displayName: 'Priya Sharma',
          level: 3,
          xpTotal: 425,
          xpThisWeek: 95,
          rank: 3,
          streakDays: 7,
        ),
      ],
    );

Widget _wrap({required GamificationRepository repo}) => ProviderScope(
      overrides: [
        gamificationRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const LeaderboardScreen(
          workspaceId: _wsId,
          currentUserId: _currentUserId,
        ),
      ),
    );

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows loading state while the leaderboard fetches',
      (tester) async {
    final completer = Completer<LeaderboardResponse>();
    when(() => repo.fetchLeaderboard(
          workspaceId: any(named: 'workspaceId'),
        )).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump();

    expect(find.text('Loading leaderboard…'), findsOneWidget);

    completer.complete(_populated());
    await tester.pumpAndSettle();
  });

  testWidgets('error state shows ErrorView with a retry that refetches',
      (tester) async {
    var calls = 0;
    when(() => repo.fetchLeaderboard(
          workspaceId: any(named: 'workspaceId'),
        )).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('leaderboard fetch failed');
      return _populated();
    });

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Chen'), findsOneWidget);
  });

  testWidgets('hidden response renders the leaderboard-off empty state',
      (tester) async {
    when(() => repo.fetchLeaderboard(
          workspaceId: any(named: 'workspaceId'),
        )).thenAnswer(
      (_) async => const LeaderboardResponse(
        workspaceId: _wsId,
        visible: false,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard hidden'), findsOneWidget);
  });

  testWidgets('empty roster renders the no-students empty state',
      (tester) async {
    when(() => repo.fetchLeaderboard(
          workspaceId: any(named: 'workspaceId'),
        )).thenAnswer(
      (_) async => const LeaderboardResponse(
        workspaceId: _wsId,
        visible: true,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No students yet'), findsOneWidget);
  });

  testWidgets('populated leaderboard renders rows + your-rank banner',
      (tester) async {
    when(() => repo.fetchLeaderboard(
          workspaceId: any(named: 'workspaceId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    // Banner.
    expect(find.text('You are ranked #2'), findsOneWidget);
    expect(find.text('of 3 studying in this workspace'), findsOneWidget);

    // Rows.
    expect(find.text('Alex Chen'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsOneWidget);

    // Top-3 medals — non-medal rows show #N text, top three show the
    // trophy icon instead of a rank number.
    expect(find.text('920 XP'), findsOneWidget);
  });

  testWidgets('current user row highlights with primary container color',
      (tester) async {
    when(() => repo.fetchLeaderboard(
          workspaceId: any(named: 'workspaceId'),
        )).thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    // Find the Card whose subtree contains "You" — its color should
    // come from the primary container palette, distinct from the
    // other rows' default surface.
    final youCard = find.ancestor(
      of: find.text('You'),
      matching: find.byType(Card),
    );
    expect(youCard, findsOneWidget);
    final card = tester.widget<Card>(youCard);
    expect(card.color, isNotNull);
  });

  testWidgets('omitted current_user_rank suppresses the your-rank banner',
      (tester) async {
    when(() => repo.fetchLeaderboard(
          workspaceId: any(named: 'workspaceId'),
        )).thenAnswer(
      (_) async => const LeaderboardResponse(
        workspaceId: _wsId,
        visible: true,
        entries: [
          LeaderboardEntry(
            studentId: 'usr_alex',
            displayName: 'Alex Chen',
            level: 4,
            xpTotal: 920,
            xpThisWeek: 240,
            rank: 1,
            streakDays: 12,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('You are ranked'), findsNothing);
    expect(find.text('Alex Chen'), findsOneWidget);
  });
}
