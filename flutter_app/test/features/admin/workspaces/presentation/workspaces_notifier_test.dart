import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
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
      lastLogin: DateTime(2026, 1, 1),
    );

Future<ProviderContainer> _container(WorkspacesRepository repo) async {
  final authRepo = _MockAuthRepo();
  when(() => authRepo.getStoredUser()).thenAnswer((_) async => _adminUser());
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      workspacesRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authNotifierProvider.future);
  return container;
}

void main() {
  group('WorkspacesList', () {
    test('build loads the seeded workspace list', () async {
      final container = await _container(DemoWorkspacesRepository());
      final list = await container.read(workspacesListProvider.future);
      expect(list, hasLength(1));
      expect(list.single.name, 'Demo Classroom');
    });

    test('createWorkspace adds a row the refreshed list reflects',
        () async {
      final container = await _container(DemoWorkspacesRepository());
      await container.read(workspacesListProvider.future);

      final created = await container
          .read(workspacesListProvider.notifier)
          .createWorkspace(name: 'Algebra');
      expect(created.name, 'Algebra');

      final list = await container.read(workspacesListProvider.future);
      expect(list, hasLength(2));
      expect(list.map((w) => w.name), contains('Algebra'));
    });

    test('createWorkspace rethrows a name conflict for inline form errors',
        () async {
      final container = await _container(DemoWorkspacesRepository());
      await container.read(workspacesListProvider.future);

      expect(
        () => container
            .read(workspacesListProvider.notifier)
            .createWorkspace(name: 'Demo Classroom'),
        throwsA(isA<WorkspaceNameConflictException>()),
      );
    });

    test('deleteWorkspace removes the row from the refreshed list',
        () async {
      final container = await _container(DemoWorkspacesRepository());
      await container.read(workspacesListProvider.future);

      await container
          .read(workspacesListProvider.notifier)
          .deleteWorkspace('wsp_demo_001');

      final list = await container.read(workspacesListProvider.future);
      expect(list, isEmpty);
    });

    test('updateWorkspace patches the name', () async {
      final container = await _container(DemoWorkspacesRepository());
      await container.read(workspacesListProvider.future);

      final updated = await container
          .read(workspacesListProvider.notifier)
          .updateWorkspace(workspaceId: 'wsp_demo_001', name: 'Renamed');
      expect(updated.name, 'Renamed');

      final list = await container.read(workspacesListProvider.future);
      expect(list.single.name, 'Renamed');
    });

    test('generateInviteCode returns a code without touching list state',
        () async {
      final container = await _container(DemoWorkspacesRepository());
      await container.read(workspacesListProvider.future);

      final invite = await container
          .read(workspacesListProvider.notifier)
          .generateInviteCode('wsp_demo_001');
      expect(invite.code, hasLength(8));
    });
  });
}
