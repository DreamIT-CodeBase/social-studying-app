import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/taxonomy/data/demo_taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_editor_screen.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';

class _MockRepo extends Mock implements TaxonomyRepository {}

const _wsId = 'wsp_test';

Taxonomy _tax({int version = 1, List<CanonicalTopic>? topics}) => Taxonomy(
      taxonomyVersion: version,
      lastMergedAt: '2026-05-22T10:00:00Z',
      topics: topics ??
          const [
            CanonicalTopic(
              id: 'tpc_root',
              name: 'Cells',
              description: 'Basic units of life.',
              complexityLevel: 2,
            ),
            CanonicalTopic(
              id: 'tpc_child',
              name: 'Photosynthesis',
              parentId: 'tpc_root',
              aliases: ['Plant Energy'],
              complexityLevel: 3,
            ),
          ],
    );

Widget _wrap(_MockRepo repo, {ThemeData? theme}) => ProviderScope(
      overrides: [
        taxonomyRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        home: const TaxonomyEditorScreen(workspaceId: _wsId),
      ),
    );

/// The edit sheet stacks name + description + aliases + parent dropdown
/// + complexity slider + buttons into a scrollable column. In the
/// default 800x600 widget-test viewport the Apply button lands just
/// below the visible area (y=610) and taps miss silently. Every test
/// that opens the sheet — and the e2e load test, which pumps a tree
/// taller than 600px — runs against a tall viewport so hit-testing
/// works.
Future<void> _tallViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUpAll(() {
    registerFallbackValue(<CanonicalTopic>[]);
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows a loading state while the initial fetch resolves',
      (tester) async {
    await _tallViewport(tester);
    final completer = Completer<Taxonomy>();
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('Loading taxonomy…'), findsOneWidget);

    completer.complete(_tax());
    await tester.pumpAndSettle();
  });

  testWidgets('load error shows ErrorView with a retry that re-fetches',
      (tester) async {
    await _tallViewport(tester);
    var calls = 0;
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('network down');
      return _tax();
    });

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Cells'), findsOneWidget);
  });

  testWidgets('empty taxonomy shows the empty state', (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax(topics: const []));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('No topics to edit'), findsOneWidget);
  });

  testWidgets('loaded taxonomy renders topic rows and the make-root target',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Cells'), findsOneWidget);
    expect(find.text('Photosynthesis'), findsOneWidget);
    expect(find.text('Shape the learning path'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);
    expect(find.text('All changes saved'), findsOneWidget);
    expect(
      find.text('Drag a topic here to clear its parent'),
      findsOneWidget,
    );
  });

  testWidgets('dark theme gives the editor overview and rows distinct surfaces',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo, theme: AppTheme.dark));
    await tester.pumpAndSettle();

    final overview = tester.widget<Container>(
      find.byKey(const ValueKey('taxonomy_editor_overview')),
    );
    final overviewDecoration = overview.decoration! as BoxDecoration;
    expect(
      overviewDecoration.color,
      AppTheme.dark.colorScheme.primaryContainer,
    );

    final topicRow = tester.widget<Container>(
      find.byKey(const ValueKey('taxonomy_editor_row_tpc_root')),
    );
    final rowDecoration = topicRow.decoration! as BoxDecoration;
    expect(
      rowDecoration.color,
      AppTheme.dark.colorScheme.surfaceContainerHighest,
    );
  });

  testWidgets('complexity editor stays within the backend 1 to 5 range',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cells'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 1);
    expect(slider.max, 5);
  });

  testWidgets('Save is disabled until an edit lands', (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('editing a topic name flips Save on and propagates the rename',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cells'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Topic'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Cell Biology');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Cell Biology'), findsOneWidget);
    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('empty name in the edit sheet shows an inline validation error',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cells'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a topic name'), findsOneWidget);
    // The sheet stays open so the admin can correct the name.
    expect(find.text('Edit Topic'), findsOneWidget);
  });

  testWidgets('Save calls repo.update with the loaded version', (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax(version: 7));
    when(() => repo.update(
          workspaceId: any(named: 'workspaceId'),
          expectedVersion: any(named: 'expectedVersion'),
          topics: any(named: 'topics'),
        )).thenAnswer((_) async => _tax(version: 8));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cells'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Cell Biology');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    verify(() => repo.update(
          workspaceId: _wsId,
          expectedVersion: 7,
          topics: any(named: 'topics'),
        )).called(1);
    expect(find.text('Taxonomy saved'), findsOneWidget);
  });

  testWidgets('a 409 version conflict triggers a reload and warning dialog',
      (tester) async {
    await _tallViewport(tester);
    var getCalls = 0;
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      getCalls++;
      return _tax(version: getCalls == 1 ? 7 : 9);
    });
    when(() => repo.update(
          workspaceId: any(named: 'workspaceId'),
          expectedVersion: any(named: 'expectedVersion'),
          topics: any(named: 'topics'),
        )).thenThrow(const TaxonomyVersionConflictException());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cells'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Cell Biology');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Edits out of date'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Got it'));
    await tester.pumpAndSettle();

    // After reload, the original "Cells" name is restored — the local
    // rename was discarded.
    expect(find.text('Cells'), findsOneWidget);
    expect(find.text('Cell Biology'), findsNothing);
    // The reload re-fetched.
    expect(getCalls, 2);
  });

  testWidgets('a 422 validation error surfaces in the banner', (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());
    when(() => repo.update(
          workspaceId: any(named: 'workspaceId'),
          expectedVersion: any(named: 'expectedVersion'),
          topics: any(named: 'topics'),
        )).thenThrow(
      const TaxonomyValidationException('Cycle detected at tpc_root'),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cells'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Cell Biology');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Cycle detected at tpc_root'), findsOneWidget);
  });

  testWidgets('deleting a leaf topic removes it from the list', (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // The Photosynthesis row has the leaf-with-no-children shape, so it's
    // deletable. Find the row's delete icon — there are two delete
    // buttons on screen (one per row); use the second, which sits beside
    // Photosynthesis after the alphabetical tree sort.
    final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButtons, findsNWidgets(2));
    await tester.tap(deleteButtons.last);
    await tester.pumpAndSettle();

    expect(find.text('Delete topic?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Photosynthesis'), findsNothing);
    expect(find.text('Cells'), findsOneWidget);
  });

  testWidgets('deleting a topic with children is refused with a message',
      (tester) async {
    await _tallViewport(tester);
    when(() => repo.get(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _tax());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // The first delete icon belongs to the root topic, which has a child.
    final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Re-parent the subtopics'),
      findsOneWidget,
    );
    // The confirmation dialog must not appear.
    expect(find.text('Delete topic?'), findsNothing);
  });

  testWidgets('the demo repository drives the editor end to end',
      (tester) async {
    await _tallViewport(tester);
    // No priming `get` — that would await `Future.delayed(Duration.zero)`
    // outside any `tester.pump`, and inside FakeAsync the timer never
    // fires, so the test would hang. The editor's own `_load` seeds the
    // workspace via `putIfAbsent` on its first fetch.
    final demoRepo = DemoTaxonomyRepository(networkDelay: Duration.zero);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taxonomyRepositoryProvider.overrideWithValue(demoRepo),
        ],
        child: const MaterialApp(
          home: TaxonomyEditorScreen(workspaceId: 'wsp_demo'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cells'), findsOneWidget);
    expect(find.text('Photosynthesis'), findsOneWidget);
    expect(find.text('Cellular Respiration'), findsOneWidget);
  });
}
