import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_notifier.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_viewer_screen.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';

class _MockRepo extends Mock implements TaxonomyRepository {}

Taxonomy _tax({int version = 1, List<CanonicalTopic>? topics}) => Taxonomy(
      taxonomyVersion: version,
      topics: topics ??
          const [
            CanonicalTopic(
              id: 'tpc_root',
              name: 'Cells',
              description: 'The basic units of life.',
              complexityLevel: 2,
              sourceDocumentIds: ['doc_1'],
            ),
            CanonicalTopic(
              id: 'tpc_child',
              name: 'Photosynthesis',
              parentId: 'tpc_root',
              description: 'Plants making food from light.',
              complexityLevel: 3,
              aliases: ['Plant Energy'],
              sourceDocumentIds: ['doc_1', 'doc_2'],
            ),
          ],
    );

Widget _wrap({required _MockRepo repo}) => ProviderScope(
      overrides: [
        taxonomyRepositoryProvider.overrideWith((_) => repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const TaxonomyViewerScreen(workspaceId: 'wsp_test'),
      ),
    );

void main() {
  late _MockRepo repo;

  setUpAll(() {
    TaxonomyViewer.debugPollInterval = const Duration(milliseconds: 5);
    TaxonomyViewer.debugMaxPollAttempts = 5;
  });

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows loading indicator while initial fetch resolves',
      (tester) async {
    final completer = Completer<Taxonomy>();
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(_tax());
    await tester.pumpAndSettle();
  });

  testWidgets('renders topic names + version header on happy path',
      (tester) async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenAnswer((_) async => _tax(version: 7));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('2 topics'), findsOneWidget);
    expect(find.text('v7'), findsOneWidget);
    expect(find.text('Cells'), findsOneWidget);
    expect(find.text('Photosynthesis'), findsOneWidget);
  });

  testWidgets('renders description, alias chips, and complexity', (tester) async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Plants making food from light.'), findsOneWidget);
    expect(find.text('Plant Energy'), findsOneWidget);
    // Complexity chips render as L<int>.
    expect(find.text('L2'), findsOneWidget);
    expect(find.text('L3'), findsOneWidget);
  });

  testWidgets('empty taxonomy shows the empty state', (tester) async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenAnswer((_) async => _tax(version: 0, topics: const []));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No topics yet'), findsOneWidget);
    // The taxonomy header is suppressed on empty state.
    expect(find.text('0 topics'), findsNothing);
  });

  testWidgets('error state shows ErrorView with a retry action',
      (tester) async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenThrow(Exception('backend exploded'));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('TaxonomyWorkspaceNotFoundException shows the friendly message',
      (tester) async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenThrow(const TaxonomyWorkspaceNotFoundException());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.text('This workspace is no longer available.'),
      findsOneWidget,
    );
  });

  testWidgets('Regenerate AppBar button is visible when data is ready',
      (tester) async {
    when(() => repo.get(workspaceId: 'wsp_test'))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Regenerate'), findsOneWidget);
  });

  testWidgets(
    'pressing Regenerate shows confirmation dialog and fires POST on confirm',
    (tester) async {
      // First get = initial build (version 1). After regenerate fires
      // and the poll loop kicks in, subsequent gets must surface a
      // version bump so the notifier exits its loop — otherwise the
      // pending poll Timer fails the test at teardown.
      var pollCount = 0;
      when(() => repo.get(workspaceId: 'wsp_test')).thenAnswer((_) async {
        pollCount++;
        return _tax(version: pollCount == 1 ? 1 : 2);
      });
      when(() => repo.regenerate(workspaceId: 'wsp_test'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(_wrap(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Regenerate'));
      await tester.pumpAndSettle();
      expect(find.text('Regenerate taxonomy?'), findsOneWidget);

      // Two widgets carry the "Regenerate" text once the dialog opens
      // — the AppBar TextButton and the dialog FilledButton. We want
      // the dialog's confirm button.
      await tester.tap(find.widgetWithText(FilledButton, 'Regenerate'));
      await tester.pumpAndSettle();

      verify(() => repo.regenerate(workspaceId: 'wsp_test')).called(1);
      // Version header now reflects the bumped version.
      expect(find.text('v2'), findsOneWidget);
    },
  );
}
