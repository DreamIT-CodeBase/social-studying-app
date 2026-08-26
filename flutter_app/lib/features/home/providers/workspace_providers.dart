import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

part 'workspace_providers.g.dart';

/// Memberships used by the student UI. The personal workspace ID is
/// deterministic and the backend provisions it in `get_current_user`, so the
/// client can expose it immediately even when secure storage still contains a
/// profile written before that membership was added.
List<WorkspaceMembership> effectiveStudentMemberships(User? user) {
  if (user == null) return const [];
  final memberships = List<WorkspaceMembership>.of(user.workspaceMemberships);

  // This provider is consumed only by the student application. Do not key the
  // personal workspace off the account's legacy/global role: Google accounts
  // created before workspace roles were separated can legitimately carry a
  // workspace-admin role and still need their personal study space here.
  final selfWorkspaceId = 'wsp_self_${user.id}';
  if (!memberships.any((item) => item.workspaceId == selfWorkspaceId)) {
    memberships.insert(
      0,
      WorkspaceMembership(
        workspaceId: selfWorkspaceId,
        role: UserRole.workspaceAdmin,
        workspaceName: 'Self Learning Workspace',
      ),
    );
  }
  return memberships;
}

@Riverpod(keepAlive: true)
class ActiveWorkspaceId extends _$ActiveWorkspaceId {
  @override
  String? build() {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );
    final memberships = effectiveStudentMemberships(user);
    if (user == null || memberships.isEmpty) {
      return null;
    }

    // Always honor the user's saved workspace preference first.
    // This prevents an auth refresh from overriding the user's explicit choice
    // (e.g., switching to Self Study workspace and reloading stays on Self Study).
    final savedId = SessionPersistenceService.instance.getWorkspaceSync();
    if (savedId != null &&
        memberships.any((m) => m.workspaceId == savedId)) {
      return savedId;
    }

    // Cold-start (no valid saved preference): prefer a joined class/family
    // workspace over the automatic self-study workspace so enrolled students
    // land in their active learning space on first launch.
    final selfWorkspaceId = 'wsp_self_${user.id}';
    for (final membership in memberships) {
      if (membership.workspaceId != selfWorkspaceId) {
        return membership.workspaceId;
      }
    }
    return memberships.first.workspaceId;
  }

  void setWorkspaceId(String workspaceId) {
    state = workspaceId;
    SessionPersistenceService.instance.saveWorkspace(workspaceId).catchError((_) {});
  }
}

@riverpod
WorkspaceMembership? activeWorkspaceMembership(ActiveWorkspaceMembershipRef ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  final user = authState?.maybeWhen(
    authenticated: (u) => u,
    orElse: () => null,
  );
  if (user == null) return null;
  
  final activeId = ref.watch(activeWorkspaceIdProvider);
  if (activeId == null) return null;
  
  for (final membership in effectiveStudentMemberships(user)) {
    if (membership.workspaceId == activeId) {
      return membership;
    }
  }
  return null;
}

@riverpod
bool isActiveWorkspaceAdmin(IsActiveWorkspaceAdminRef ref) {
  final membership = ref.watch(activeWorkspaceMembershipProvider);
  if (membership == null) return false;
  return membership.role == UserRole.workspaceAdmin || membership.role == UserRole.tenantAdmin;
}

@riverpod
Future<List<Workspace>> studentWorkspaces(StudentWorkspacesRef ref) {
  // Watch auth state so we refetch workspaces if memberships change (like being invited)
  ref.watch(authNotifierProvider);
  return ref.watch(workspacesRepositoryProvider).list();
}

@riverpod
Workspace? activeStudentWorkspace(ActiveStudentWorkspaceRef ref) {
  final workspacesAsync = ref.watch(studentWorkspacesProvider);
  final activeId = ref.watch(activeWorkspaceIdProvider);
  if (activeId == null) return null;
  
  final list = workspacesAsync.valueOrNull ?? [];
  for (final w in list) {
    if (w.id == activeId) {
      return w;
    }
  }
  return null;
}
