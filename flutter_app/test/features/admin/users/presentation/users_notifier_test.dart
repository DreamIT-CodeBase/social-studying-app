import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/admin/users/data/demo_users_repository.dart';
import 'package:social_study_app/features/admin/users/data/users_repository.dart';
import 'package:social_study_app/features/admin/users/presentation/users_notifier.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

User _adminUser() => User(
      id: 'usr_demo_001',
      email: 'demo@socialstudyapp.com',
      displayName: 'Demo Admin',
      tenantId: 'ten_demo',
      role: UserRole.tenantAdmin,
      createdAt: DateTime(2026, 1, 1),
    );

Future<ProviderContainer> _container(UsersRepository repo) async {
  final authRepo = _MockAuthRepo();
  when(() => authRepo.getStoredUser()).thenAnswer((_) async => _adminUser());
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      usersRepositoryProvider.overrideWithValue(repo),
      workspacesRepositoryProvider
          .overrideWithValue(DemoWorkspacesRepository()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authNotifierProvider.future);
  return container;
}

void main() {
  group('WorkspaceUsersList', () {
    test('build loads the seeded roster', () async {
      final container = await _container(DemoUsersRepository());
      final users = await container
          .read(workspaceUsersListProvider('wsp_demo_001').future);
      expect(users, hasLength(3));
    });

    test('createUser adds a row the refreshed roster reflects', () async {
      final container = await _container(DemoUsersRepository());
      await container.read(workspaceUsersListProvider('wsp_demo_001').future);

      await container
          .read(workspaceUsersListProvider('wsp_demo_001').notifier)
          .createUser(
            email: 'noah@socialstudyapp.com',
            displayName: 'Noah Kim',
            role: UserRole.student,
          );

      final users = await container
          .read(workspaceUsersListProvider('wsp_demo_001').future);
      expect(users, hasLength(4));
    });

    test('createUser rethrows an email conflict for inline form errors',
        () async {
      final container = await _container(DemoUsersRepository());
      await container.read(workspaceUsersListProvider('wsp_demo_001').future);

      expect(
        () => container
            .read(workspaceUsersListProvider('wsp_demo_001').notifier)
            .createUser(
              email: 'maya@socialstudyapp.com',
              displayName: 'Dup',
              role: UserRole.student,
            ),
        throwsA(isA<UserEmailConflictException>()),
      );
    });

    test('deactivateUser drops the row from the refreshed roster', () async {
      final container = await _container(DemoUsersRepository());
      await container.read(workspaceUsersListProvider('wsp_demo_001').future);

      await container
          .read(workspaceUsersListProvider('wsp_demo_001').notifier)
          .deactivateUser('usr_demo_101');

      final users = await container
          .read(workspaceUsersListProvider('wsp_demo_001').future);
      expect(users, hasLength(2));
    });

    test('changeRole updates the role in the refreshed roster', () async {
      final container = await _container(DemoUsersRepository());
      await container.read(workspaceUsersListProvider('wsp_demo_001').future);

      await container
          .read(workspaceUsersListProvider('wsp_demo_001').notifier)
          .changeRole(
            userId: 'usr_demo_101',
            role: UserRole.workspaceAdmin,
          );

      final users = await container
          .read(workspaceUsersListProvider('wsp_demo_001').future);
      expect(
        users.firstWhere((u) => u.id == 'usr_demo_101').role,
        UserRole.workspaceAdmin,
      );
    });
  });
}
