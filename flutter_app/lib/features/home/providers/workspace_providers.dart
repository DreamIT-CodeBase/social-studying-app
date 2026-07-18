import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

part 'workspace_providers.g.dart';

@Riverpod(keepAlive: true)
class ActiveWorkspaceId extends _$ActiveWorkspaceId {
  @override
  String? build() {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );
    if (user == null || user.workspaceMemberships.isEmpty) {
      return null;
    }

    // Try to get the synchronously loaded workspace from persistence
    // Prefer a joined class/family workspace over the automatic self-study
    // workspace so enrolled students land in their active learning space.
    final selfWorkspaceId = 'wsp_self_${user.id}';
    final savedId = SessionPersistenceService.instance.getWorkspaceSync();
    if (savedId != null &&
        savedId != selfWorkspaceId &&
        user.workspaceMemberships.any((m) => m.workspaceId == savedId)) {
      return savedId;
    }
    for (final membership in user.workspaceMemberships) {
      if (membership.workspaceId != selfWorkspaceId) {
        return membership.workspaceId;
      }
    }
    // Only self-study exists; preserve a valid saved self-study selection.
    if (savedId == selfWorkspaceId &&
        user.workspaceMemberships.any((m) => m.workspaceId == savedId)) {
      return savedId;
    }
    return user.workspaceMemberships.first.workspaceId;
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
  
  for (final membership in user.workspaceMemberships) {
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

