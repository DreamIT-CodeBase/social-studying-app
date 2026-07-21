import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/admin/users/data/demo_users_repository.dart';
import 'package:social_study_app/features/admin/users/data/users_repository.dart';
import 'package:social_study_app/features/admin/users/presentation/users_screen.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/shared/models/invite_code.dart';
import 'package:social_study_app/shared/models/user.dart';

class _MockUsersRepo extends Mock implements UsersRepository {}

class _MockWorkspacesRepo extends Mock implements WorkspacesRepository {}

const _wsId = 'wsp_test';

User _user({
  String id = 'usr_1',
  String name = 'Maya Chen',
  String email = 'maya@example.com',
  UserRole role = UserRole.student,
}) =>
    User(
      id: id,
      email: email,
      displayName: name,
      tenantId: 'ten_demo',
      role: role,
      workspaceMemberships: [
        WorkspaceMembership(workspaceId: _wsId, role: role),
      ],
      createdAt: DateTime(2026, 4, 10),
    );

Widget _wrap(_MockUsersRepo usersRepo, {_MockWorkspacesRepo? wsRepo}) =>
    ProviderScope(
      overrides: [
        usersRepositoryProvider.overrideWithValue(usersRepo),
        workspacesRepositoryProvider
            .overrideWithValue(wsRepo ?? _MockWorkspacesRepo()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: WorkspaceUsersScreen(workspaceId: _wsId),
        ),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(UserRole.student);
  });

  late _MockUsersRepo usersRepo;

  setUp(() {
    usersRepo = _MockUsersRepo();
  });

  testWidgets('shows a loading indicator while the roster fetch resolves',
      (tester) async {
    final completer = Completer<List<User>>();
    when(() => usersRepo.listWorkspaceUsers(any()))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pump();

    expect(find.text('Loading roster…'), findsOneWidget);

    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('error state shows ErrorView with a retry action',
      (tester) async {
    when(() => usersRepo.listWorkspaceUsers(any()))
        .thenThrow(Exception('roster fetch failed'));

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('empty roster shows the invite card and an empty message',
      (tester) async {
    when(() => usersRepo.listWorkspaceUsers(any()))
        .thenAnswer((_) async => <User>[]);

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    expect(find.text('Invite students'), findsOneWidget);
    expect(find.text('No members yet'), findsOneWidget);
  });

  testWidgets('populated roster renders names, emails, and role chips',
      (tester) async {
    when(() => usersRepo.listWorkspaceUsers(any())).thenAnswer(
      (_) async => [
        _user(),
        _user(
          id: 'usr_2',
          name: 'Sofia Ramirez',
          email: 'sofia@example.com',
          role: UserRole.workspaceAdmin,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    expect(find.text('Maya Chen'), findsOneWidget);
    expect(find.text('sofia@example.com'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
  });

  testWidgets('admins sort above students in the roster', (tester) async {
    when(() => usersRepo.listWorkspaceUsers(any())).thenAnswer(
      (_) async => [
        _user(name: 'Zoe Student'),
        _user(
          id: 'usr_2',
          name: 'Aaron Admin',
          email: 'aaron@example.com',
          role: UserRole.workspaceAdmin,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    final adminY = tester.getTopLeft(find.text('Aaron Admin')).dy;
    final studentY = tester.getTopLeft(find.text('Zoe Student')).dy;
    expect(adminY, lessThan(studentY));
  });

  testWidgets('adding a user calls the repository and refreshes',
      (tester) async {
    var calls = 0;
    when(() => usersRepo.listWorkspaceUsers(any())).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? [_user()]
          : [_user(), _user(id: 'usr_2', name: 'Noah Kim')];
    });
    when(() => usersRepo.createUser(
          workspaceId: any(named: 'workspaceId'),
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          role: any(named: 'role'),
        )).thenAnswer((_) async => _user(id: 'usr_2', name: 'Noah Kim'));

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Add User'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Noah Kim');
    await tester.enterText(find.byType(TextField).last, 'noah@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Add User'));
    await tester.pumpAndSettle();

    verify(() => usersRepo.createUser(
          workspaceId: _wsId,
          email: 'noah@example.com',
          displayName: 'Noah Kim',
          role: UserRole.student,
        )).called(1);
    expect(find.text('User added'), findsOneWidget);
  });

  testWidgets('a duplicate email is shown inline on the email field',
      (tester) async {
    when(() => usersRepo.listWorkspaceUsers(any()))
        .thenAnswer((_) async => [_user()]);
    when(() => usersRepo.createUser(
          workspaceId: any(named: 'workspaceId'),
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          role: any(named: 'role'),
        )).thenThrow(
      const UserEmailConflictException("'taken@example.com' already exists"),
    );

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Dup User');
    await tester.enterText(find.byType(TextField).last, 'taken@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Add User'));
    await tester.pumpAndSettle();

    expect(find.text("'taken@example.com' already exists"), findsOneWidget);
  });

  testWidgets('a malformed email is rejected before any repository call',
      (tester) async {
    when(() => usersRepo.listWorkspaceUsers(any()))
        .thenAnswer((_) async => [_user()]);

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'No Email');
    await tester.enterText(find.byType(TextField).last, 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Add User'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    verifyNever(() => usersRepo.createUser(
          workspaceId: any(named: 'workspaceId'),
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          role: any(named: 'role'),
        ));
  });

  testWidgets('generating an invite code shows the code in a dialog',
      (tester) async {
    when(() => usersRepo.listWorkspaceUsers(any()))
        .thenAnswer((_) async => [_user()]);
    final wsRepo = _MockWorkspacesRepo();
    when(() => wsRepo.generateInviteCode(any())).thenAnswer(
      (_) async => GeneratedInviteCode(
        code: 'ABCD1234',
        maxUses: 30,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      ),
    );

    await tester.pumpWidget(_wrap(usersRepo, wsRepo: wsRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite students'));
    await tester.pumpAndSettle();

    verify(() => wsRepo.generateInviteCode(_wsId)).called(1);
    expect(find.text('ABCD1234'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Copy'), findsOneWidget);
  });

  testWidgets('removing a user confirms then calls the repository',
      (tester) async {
    var calls = 0;
    when(() => usersRepo.listWorkspaceUsers(any())).thenAnswer((_) async {
      calls++;
      return calls == 1 ? [_user()] : <User>[];
    });
    when(() => usersRepo.removeMember(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Remove user?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    verify(() => usersRepo.removeMember(
          workspaceId: _wsId,
          userId: 'usr_1',
        )).called(1);
    expect(find.text('Maya Chen removed'), findsOneWidget);
  });

  testWidgets('promoting a student to admin calls changeRole',
      (tester) async {
    var calls = 0;
    when(() => usersRepo.listWorkspaceUsers(any())).thenAnswer((_) async {
      calls++;
      return [
        _user(role: calls == 1 ? UserRole.student : UserRole.workspaceAdmin),
      ];
    });
    when(() => usersRepo.changeRole(
          workspaceId: any(named: 'workspaceId'),
          userId: any(named: 'userId'),
          role: any(named: 'role'),
        )).thenAnswer((_) async => _user(role: UserRole.workspaceAdmin));

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make admin'));
    await tester.pumpAndSettle();

    verify(() => usersRepo.changeRole(
          workspaceId: _wsId,
          userId: 'usr_1',
          role: UserRole.workspaceAdmin,
        )).called(1);
  });

  testWidgets('the tenant owner has no overflow menu', (tester) async {
    when(() => usersRepo.listWorkspaceUsers(any())).thenAnswer(
      (_) async => [_user(name: 'Owner', role: UserRole.tenantAdmin)],
    );

    await tester.pumpWidget(_wrap(usersRepo));
    await tester.pumpAndSettle();

    expect(find.text('Owner'), findsWidgets); // name + role chip
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });

  testWidgets('the demo repository drives the screen end to end',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usersRepositoryProvider.overrideWithValue(DemoUsersRepository()),
          workspacesRepositoryProvider
              .overrideWithValue(_MockWorkspacesRepo()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WorkspaceUsersScreen(workspaceId: 'wsp_demo_001'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 members'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);
  });
}
