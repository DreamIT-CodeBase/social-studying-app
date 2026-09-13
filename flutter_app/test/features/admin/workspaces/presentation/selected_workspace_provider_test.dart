import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/selected_workspace_provider.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockWorkspacesRepository extends Mock implements WorkspacesRepository {}

void main() {
  test('admin selection skips and rejects self-learning workspaces', () async {
    final authRepository = _MockAuthRepository();
    final workspacesRepository = _MockWorkspacesRepository();
    final createdAt = DateTime(2026, 1, 1);
    final user = User(
      id: 'usr_admin',
      email: 'admin@example.com',
      displayName: 'Admin',
      tenantId: 'ten_test',
      role: UserRole.workspaceAdmin,
      workspaceMemberships: [
        WorkspaceMembership(
          workspaceId: 'wsp_self_usr_admin',
          role: UserRole.workspaceAdmin,
          joinedAt: createdAt,
        ),
        WorkspaceMembership(
          workspaceId: 'wsp_classroom',
          role: UserRole.workspaceAdmin,
          joinedAt: createdAt,
        ),
      ],
      createdAt: createdAt,
    );
    final classroom = Workspace(
      id: 'wsp_classroom',
      tenantId: 'ten_test',
      name: 'Science Classroom',
      settings: const WorkspaceSettings(),
      createdAt: createdAt,
    );

    when(authRepository.getStoredUser).thenAnswer((_) async => user);
    when(workspacesRepository.list).thenAnswer((_) async => [classroom]);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        workspacesRepositoryProvider.overrideWithValue(workspacesRepository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);
    await container.read(workspacesListProvider.future);

    expect(container.read(selectedWorkspaceProvider), 'wsp_classroom');

    container
        .read(selectedWorkspaceProvider.notifier)
        .selectWorkspace('wsp_self_usr_admin');
    expect(container.read(selectedWorkspaceProvider), 'wsp_classroom');
  });
}
