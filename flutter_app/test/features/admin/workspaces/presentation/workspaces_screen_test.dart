import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_screen.dart';
import 'package:social_study_app/shared/models/workspace.dart';

class _MockRepo extends Mock implements WorkspacesRepository {}

Workspace _ws({
  String id = 'wsp_1',
  String name = 'Grade 5 Science',
  String description = 'Earth and life science',
  int studentCount = 12,
  int documentCount = 4,
  int adminCount = 1,
}) =>
    Workspace(
      id: id,
      tenantId: 'ten_demo',
      name: name,
      description: description,
      studentCount: studentCount,
      documentCount: documentCount,
      adminCount: adminCount,
      settings: const WorkspaceSettings(),
      createdAt: DateTime(2026, 4, 1),
    );

Widget _wrap(_MockRepo repo) => ProviderScope(
      overrides: [
        workspacesRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const WorkspacesScreen(),
      ),
    );

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows a loading indicator while the first fetch resolves',
      (tester) async {
    final completer = Completer<List<Workspace>>();
    when(repo.list).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();

    expect(find.text('Loading workspaces…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('error state shows ErrorView with a retry action',
      (tester) async {
    when(repo.list).thenThrow(Exception('backend down'));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('empty state shows the create CTA', (tester) async {
    when(repo.list).thenAnswer((_) async => <Workspace>[]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('No workspaces yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create Workspace'),
        findsOneWidget);
  });

  testWidgets('populated list renders the workspace name and counts',
      (tester) async {
    when(repo.list).thenAnswer((_) async => [_ws()]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Grade 5 Science'), findsOneWidget);
    expect(find.text('Earth and life science'), findsOneWidget);
    expect(find.text('12 students'), findsOneWidget);
    expect(find.text('4 documents'), findsOneWidget);
    expect(find.text('1 admins'), findsOneWidget);
  });

  testWidgets('creating a workspace calls the repository and refreshes',
      (tester) async {
    var listCalls = 0;
    when(repo.list).thenAnswer((_) async {
      listCalls++;
      return listCalls == 1 ? [_ws()] : [_ws(), _ws(id: 'wsp_2', name: 'Algebra')];
    });
    when(() => repo.create(
          name: any(named: 'name'),
          description: any(named: 'description'),
        )).thenAnswer((_) async => _ws(id: 'wsp_2', name: 'Algebra'));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('New Workspace'), findsWidgets); // sheet title + FAB

    await tester.enterText(find.byType(TextField).first, 'Algebra');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Workspace'));
    await tester.pumpAndSettle();

    verify(() => repo.create(name: 'Algebra', description: null)).called(1);
    expect(find.text('Workspace created'), findsOneWidget);
    expect(find.text('Algebra'), findsOneWidget);
  });

  testWidgets('a name conflict is shown inline on the name field',
      (tester) async {
    when(repo.list).thenAnswer((_) async => [_ws()]);
    when(() => repo.create(
          name: any(named: 'name'),
          description: any(named: 'description'),
        )).thenThrow(
      const WorkspaceNameConflictException("Name 'Grade 5 Science' is taken"),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New Workspace'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Grade 5 Science');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Workspace'));
    await tester.pumpAndSettle();

    expect(find.text("Name 'Grade 5 Science' is taken"), findsOneWidget);
    // The sheet stays open so the admin can correct the name.
    expect(find.widgetWithText(FilledButton, 'Create Workspace'),
        findsOneWidget);
  });

  testWidgets('empty name submission shows an inline validation error',
      (tester) async {
    when(repo.list).thenAnswer((_) async => [_ws()]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New Workspace'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a workspace name'), findsOneWidget);
    verifyNever(() => repo.create(
          name: any(named: 'name'),
          description: any(named: 'description'),
        ));
  });

  testWidgets('deleting a workspace confirms then calls the repository',
      (tester) async {
    var listCalls = 0;
    when(repo.list).thenAnswer((_) async {
      listCalls++;
      return listCalls == 1 ? [_ws()] : <Workspace>[];
    });
    when(() => repo.delete(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete workspace?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => repo.delete('wsp_1')).called(1);
    expect(find.text("'Grade 5 Science' deleted"), findsOneWidget);
  });

  testWidgets('editing a workspace pre-fills the form and saves the patch',
      (tester) async {
    var listCalls = 0;
    when(repo.list).thenAnswer((_) async {
      listCalls++;
      return [_ws(name: listCalls == 1 ? 'Grade 5 Science' : 'Grade 6 Science')];
    });
    when(() => repo.update(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
        )).thenAnswer((_) async => _ws(name: 'Grade 6 Science'));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Workspace'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Grade 6 Science');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();

    verify(() => repo.update(
          workspaceId: 'wsp_1',
          name: 'Grade 6 Science',
          description: any(named: 'description'),
        )).called(1);
    expect(find.text('Workspace updated'), findsOneWidget);
  });

  testWidgets('the demo repository drives the screen end to end',
      (tester) async {
    // Smoke test against the real in-process demo data — proves the
    // screen wiring works without any mock stubbing.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspacesRepositoryProvider
              .overrideWithValue(DemoWorkspacesRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WorkspacesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo Classroom'), findsOneWidget);
  });
}
