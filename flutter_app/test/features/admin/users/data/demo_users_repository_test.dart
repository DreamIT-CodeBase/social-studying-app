import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/admin/users/data/demo_users_repository.dart';
import 'package:social_study_app/shared/models/user.dart';

void main() {
  group('DemoUsersRepository.listWorkspaceUsers', () {
    test('returns the three seeded members of the demo workspace', () async {
      final repo = DemoUsersRepository();
      final users = await repo.listWorkspaceUsers('wsp_demo_001');
      expect(users, hasLength(3));
      expect(users.map((u) => u.displayName), contains('Maya Chen'));
    });

    test('returns an empty list for a workspace with no members', () async {
      final repo = DemoUsersRepository();
      expect(await repo.listWorkspaceUsers('wsp_other'), isEmpty);
    });

    test('returns an unmodifiable view', () async {
      final repo = DemoUsersRepository();
      final users = await repo.listWorkspaceUsers('wsp_demo_001');
      expect(() => users.clear(), throwsUnsupportedError);
    });
  });

  group('DemoUsersRepository.createUser', () {
    test('adds a user the roster reflects', () async {
      final repo = DemoUsersRepository();
      final created = await repo.createUser(
        workspaceId: 'wsp_demo_001',
        email: 'noah@socialstudyapp.com',
        displayName: 'Noah Kim',
        role: UserRole.student,
      );
      expect(created.email, 'noah@socialstudyapp.com');
      expect(created.role, UserRole.student);

      final users = await repo.listWorkspaceUsers('wsp_demo_001');
      expect(users, hasLength(4));
    });

    test('lower-cases the email and rejects a duplicate', () async {
      final repo = DemoUsersRepository();
      expect(
        () => repo.createUser(
          workspaceId: 'wsp_demo_001',
          email: 'MAYA@socialstudyapp.com',
          displayName: 'Maya Two',
          role: UserRole.student,
        ),
        throwsA(isA<UserEmailConflictException>()),
      );
    });
  });

  group('DemoUsersRepository.deactivateUser', () {
    test('removes the user from the roster', () async {
      final repo = DemoUsersRepository();
      await repo.deactivateUser('usr_demo_101');
      final users = await repo.listWorkspaceUsers('wsp_demo_001');
      expect(users.map((u) => u.id), isNot(contains('usr_demo_101')));
    });

    test('throws UserNotFoundException for an unknown id', () async {
      final repo = DemoUsersRepository();
      expect(
        () => repo.deactivateUser('usr_ghost'),
        throwsA(isA<UserNotFoundException>()),
      );
    });
  });

  group('DemoUsersRepository.changeRole', () {
    test('updates the role and the roster reflects it', () async {
      final repo = DemoUsersRepository();
      final updated = await repo.changeRole(
        workspaceId: 'wsp_demo_001',
        userId: 'usr_demo_101',
        role: UserRole.workspaceAdmin,
      );
      expect(updated.role, UserRole.workspaceAdmin);

      final users = await repo.listWorkspaceUsers('wsp_demo_001');
      expect(
        users.firstWhere((u) => u.id == 'usr_demo_101').role,
        UserRole.workspaceAdmin,
      );
    });

    test('throws UserNotFoundException for an unknown id', () async {
      final repo = DemoUsersRepository();
      expect(
        () => repo.changeRole(
          workspaceId: 'wsp_demo_001',
          userId: 'usr_ghost',
          role: UserRole.student,
        ),
        throwsA(isA<UserNotFoundException>()),
      );
    });
  });
}
