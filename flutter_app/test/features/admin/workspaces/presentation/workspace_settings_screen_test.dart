import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspace_settings_screen.dart';
import 'package:social_study_app/shared/models/workspace.dart';

class _MockRepo extends Mock implements WorkspacesRepository {}

const _wsId = 'wsp_1';

Workspace _ws({WorkspaceSettings? settings}) => Workspace(
      id: _wsId,
      tenantId: 'ten_demo',
      name: 'Grade 5 Science',
      settings: settings ??
          const WorkspaceSettings(
            questionsPerDay: 8,
            questionTypes: ['mcq', 'short_answer'],
          ),
      createdAt: DateTime(2026, 4, 1),
    );

Widget _wrap(_MockRepo repo) => ProviderScope(
      overrides: [
        workspacesRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: WorkspaceSettingsScreen(workspaceId: _wsId),
      ),
    );

/// The settings form is a scrolling list — give it a tall viewport so
/// every section (including the switches and the validation row) is laid
/// out without needing to scroll the lazy list into view.
Future<void> _tallViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows a loading indicator while the workspace fetch resolves',
      (tester) async {
    final completer = Completer<List<Workspace>>();
    when(repo.list).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();

    expect(find.text('Loading settings…'), findsOneWidget);

    completer.complete([_ws()]);
    await tester.pumpAndSettle();
  });

  testWidgets('error state shows ErrorView with a retry action',
      (tester) async {
    when(repo.list).thenThrow(Exception('list failed'));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('a missing workspace shows the not-found state', (tester) async {
    when(repo.list).thenAnswer(
      (_) async => [
        Workspace(
          id: 'wsp_other',
          tenantId: 'ten_demo',
          name: 'Other',
          settings: const WorkspaceSettings(),
          createdAt: DateTime(2026, 4, 1),
        ),
      ],
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Workspace not found'), findsOneWidget);
  });

  testWidgets('renders the current settings', (tester) async {
    await _tallViewport(tester);
    when(repo.list).thenAnswer((_) async => [_ws()]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('8'), findsOneWidget); // questions per day
    expect(find.byType(SwitchListTile), findsNWidgets(3));
    expect(find.byType(FilterChip), findsNWidgets(5));
    expect(find.text('Multiple choice'), findsOneWidget);
  });

  testWidgets('save is disabled until a setting changes', (tester) async {
    await _tallViewport(tester);
    when(repo.list).thenAnswer((_) async => [_ws()]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save Changes'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('toggling a switch enables save and persists the change',
      (tester) async {
    await _tallViewport(tester);
    var calls = 0;
    when(repo.list).thenAnswer((_) async {
      calls++;
      return [
        calls == 1
            ? _ws()
            : _ws(
                settings: const WorkspaceSettings(
                  questionsPerDay: 8,
                  questionTypes: ['mcq', 'short_answer'],
                  adaptiveDifficulty: false,
                ),
              ),
      ];
    });
    when(() => repo.update(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          settings: any(named: 'settings'),
        )).thenAnswer((_) async => _ws());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // The third switch is "Adaptive difficulty" — seeded on, toggle off.
    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();

    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save Changes'),
    );
    expect(enabled.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.update(
          workspaceId: _wsId,
          name: any(named: 'name'),
          description: any(named: 'description'),
          settings: captureAny(named: 'settings'),
        )).captured;
    expect((captured.single as WorkspaceSettings).adaptiveDifficulty, isFalse);
    expect(find.text('Settings saved'), findsOneWidget);
  });

  testWidgets('clearing every question format blocks saving', (tester) async {
    await _tallViewport(tester);
    when(repo.list).thenAnswer((_) async => [_ws()]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Multiple choice'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Short answer'));
    await tester.pumpAndSettle();

    expect(find.text('Select at least one question format.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save Changes'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the demo repository drives the screen end to end',
      (tester) async {
    await _tallViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspacesRepositoryProvider
              .overrideWithValue(DemoWorkspacesRepository()),
        ],
        child: const MaterialApp(
          home: WorkspaceSettingsScreen(workspaceId: 'wsp_demo_001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Question formats'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(3));
  });
}
