import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/admin/analytics/data/analytics_repository.dart';
import 'package:social_study_app/features/admin/analytics/presentation/workspace_analytics_screen.dart';
import 'package:social_study_app/shared/models/analytics.dart';

class _MockRepo extends Mock implements AnalyticsRepository {}

const _wsId = 'wsp_test';

WorkspaceAnalytics _populated() => const WorkspaceAnalytics(
      workspaceId: _wsId,
      totalStudents: 12,
      activeStudents7d: 8,
      avgOverallMastery: 0.56,
      avgQuestionsPerStudent: 26.7,
      avgCorrectRate: 0.68,
      topicDistribution: [
        TopicStats(
          topic: 'Photosynthesis',
          attempts: 136,
          avgMastery: 0.72,
          correctRate: 0.79,
        ),
        TopicStats(
          topic: 'Genetics',
          attempts: 41,
          avgMastery: 0.38,
          correctRate: 0.51,
        ),
      ],
      engagementHeatmap: [
        HeatmapCell(date: '2026-05-10', events: 2),
        HeatmapCell(date: '2026-05-11', events: 5),
        HeatmapCell(date: '2026-05-12', events: 0),
        HeatmapCell(date: '2026-05-13', events: 10),
      ],
    );

Widget _wrap({required AnalyticsRepository repo}) => ProviderScope(
      overrides: [
        analyticsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const WorkspaceAnalyticsScreen(workspaceId: _wsId),
      ),
    );

/// Tall viewport so every section renders without lazy scrolling.
Future<void> _tallViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows loading state while the dashboard fetches',
      (tester) async {
    final completer = Completer<WorkspaceAnalytics>();
    when(() => repo.fetchWorkspace(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump();

    expect(find.text('Loading analytics…'), findsOneWidget);

    completer.complete(WorkspaceAnalytics.empty);
    await tester.pumpAndSettle();
  });

  testWidgets('error state shows ErrorView with a retry that refetches',
      (tester) async {
    var calls = 0;
    when(() => repo.fetchWorkspace(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('analytics fetch failed');
      return _populated();
    });

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Photosynthesis'), findsOneWidget);
  });

  testWidgets('empty workspace shows the no-analytics callout',
      (tester) async {
    when(() => repo.fetchWorkspace(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => WorkspaceAnalytics.empty);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No analytics yet'), findsOneWidget);
    // Section headers must not render on the empty state.
    expect(find.text('TOPIC DISTRIBUTION'), findsNothing);
    expect(find.text('ENGAGEMENT — LAST 14 DAYS'), findsNothing);
  });

  testWidgets('populated payload renders metrics, heatmap, and topic list',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.fetchWorkspace(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    // Metric tiles.
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('8 active this week'), findsOneWidget);
    expect(find.text('Avg mastery'), findsOneWidget);
    expect(find.text('56%'), findsOneWidget);
    expect(find.text('Questions / student'), findsOneWidget);
    expect(find.text('26.7'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('68%'), findsOneWidget);

    // Heatmap section.
    expect(find.text('ENGAGEMENT — LAST 14 DAYS'), findsOneWidget);
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('(peak: 10)'), findsOneWidget);

    // Topic distribution sorted by attempts descending — Photosynthesis
    // (136 attempts) must render before Genetics (41 attempts).
    final photoFinder = find.text('Photosynthesis');
    final geneticsFinder = find.text('Genetics');
    expect(photoFinder, findsOneWidget);
    expect(geneticsFinder, findsOneWidget);
    final photoY = tester.getTopLeft(photoFinder).dy;
    final geneticsY = tester.getTopLeft(geneticsFinder).dy;
    expect(photoY, lessThan(geneticsY));

    // Each topic card surfaces its accuracy + attempts subtitle.
    expect(find.text('136 attempts • 79% correct'), findsOneWidget);
    expect(find.text('41 attempts • 51% correct'), findsOneWidget);
  });

  testWidgets('repository receives the workspace id verbatim',
      (tester) async {
    when(() => repo.fetchWorkspace(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _populated());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    final captured = verify(
      () => repo.fetchWorkspace(workspaceId: captureAny(named: 'workspaceId')),
    ).captured;
    expect(captured, contains(_wsId));
  });
}
