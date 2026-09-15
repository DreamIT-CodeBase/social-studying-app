import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockWorkspacesRepo extends Mock implements WorkspacesRepository {}

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
    test('filters self-learning workspaces out of all admin state', () async {
      final repo = _MockWorkspacesRepo();
      final createdAt = DateTime(2026, 1, 1);
      when(repo.list).thenAnswer(
        (_) async => [
          Workspace(
            id: 'wsp_self_usr_demo_001',
            tenantId: 'ten_demo',
            name: 'Self Learning Workspace',
            settings: const WorkspaceSettings(),
            createdAt: createdAt,
          ),
          Workspace(
            id: 'wsp_classroom',
            tenantId: 'ten_demo',
            name: 'Science Class',
            settings: const WorkspaceSettings(),
            createdAt: createdAt,
          ),
        ],
      );

      final container = await _container(repo);
      final list = await container.read(workspacesListProvider.future);

      expect(list.map((workspace) => workspace.id), ['wsp_classroom']);
    });

    test('build loads the seeded workspace list', () async {
      final container = await _container(DemoWorkspacesRepository());
      final list = await container.read(workspacesListProvider.future);
      expect(list, hasLength(1));
      expect(list.single.name, 'Demo Classroom');
    });

    test('createWorkspace adds a row the refreshed list reflects', () async {
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

    test('deleteWorkspace removes the row from the refreshed list', () async {
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

    test('updateSettings persists a settings patch', () async {
      final container = await _container(DemoWorkspacesRepository());
      await container.read(workspacesListProvider.future);

      final updated =
          await container.read(workspacesListProvider.notifier).updateSettings(
                workspaceId: 'wsp_demo_001',
                settings: const WorkspaceSettings(
                  questionsPerDay: 12,
                  leaderboardVisible: false,
                ),
              );
      expect(updated.settings.questionsPerDay, 12);
      expect(updated.settings.leaderboardVisible, isFalse);

      final list = await container.read(workspacesListProvider.future);
      expect(list.single.settings.questionsPerDay, 12);
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
