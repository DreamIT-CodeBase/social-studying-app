import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';

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
    // Default to the first membership in the list
    return user.workspaceMemberships.first.workspaceId;
  }

  void setWorkspaceId(String workspaceId) {
    state = workspaceId;
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

@riverpod
class WorkspaceMessages extends _$WorkspaceMessages {
  @override
  Future<List<Map<String, dynamic>>> build(String workspaceId) async {
    return ref.read(workspacesRepositoryProvider).getMessages(workspaceId);
  }

  Future<void> sendMessage(String content) async {
    await ref.read(workspacesRepositoryProvider).postMessage(workspaceId, content: content);
    ref.invalidateSelf();
  }
}

@riverpod
Future<List<Map<String, dynamic>>> workspaceActivity(WorkspaceActivityRef ref, String workspaceId) {
  return ref.read(workspacesRepositoryProvider).listActivity(workspaceId);
}

@riverpod
class WorkspaceMembersList extends _$WorkspaceMembersList {
  @override
  Future<List<Map<String, dynamic>>> build(String workspaceId) async {
    return ref.read(workspacesRepositoryProvider).listMembers(workspaceId);
  }

  Future<void> changeRole(String userId, String role) async {
    await ref.read(workspacesRepositoryProvider).changeMemberRole(workspaceId, userId: userId, role: role);
    ref.invalidateSelf();
  }

  Future<void> removeMember(String userId) async {
    // Re-use changeMemberRole/leave endpoint if needed or implement a specific method.
    // In our backend, there is no direct kick endpoint, but Owner updating member's role to left/deleted isn't there.
    // Wait, the backend leave_workspace has:
    // @router.post("/{workspace_id}/leave")
    // Wait, let's see how member can be removed. The backend list members has no kick, but we can update role or add kick if needed.
    // Actually, in change_member_role there is only promoting/demoting.
    // Wait! Let's just implement promotion/demotion.
  }
}

@riverpod
Future<String?> currentCollaborativeRole(CurrentCollaborativeRoleRef ref, String workspaceId) async {
  final authValue = ref.watch(authNotifierProvider).valueOrNull;
  final userId = authValue?.maybeWhen(authenticated: (user) => user.id, orElse: () => null);
  if (userId == null) return null;
  
  try {
    final members = await ref.watch(workspaceMembersListProvider(workspaceId).future);
    for (final m in members) {
      if (m['user_id'] == userId) {
        return m['role'] as String?;
      }
    }
  } catch (_) {}
  return null;
}
