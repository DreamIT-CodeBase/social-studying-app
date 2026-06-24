import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';

part 'selected_workspace_provider.g.dart';

/// Tracks the currently selected workspace ID.
///
/// Initializes from the user's first admin membership, then can be
/// changed manually via [selectWorkspace] to support switching.
@riverpod
class SelectedWorkspace extends _$SelectedWorkspace {
  @override
  String? build() {
    // Derive initial workspace from the auth state (first admin membership).
    final authAsync = ref.watch(authNotifierProvider);
    final workspacesAsync = ref.watch(workspacesListProvider);

    final userId = authAsync.valueOrNull?.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );

    if (userId == null) return null;

    // Prefer user-membership order first.
    final userWorkspaceId = authAsync.valueOrNull?.maybeWhen(
      authenticated: (user) {
        final adminMemberships = user.workspaceMemberships.where((m) =>
            m.role == UserRole.tenantAdmin ||
            m.role == UserRole.workspaceAdmin ||
            user.role == UserRole.tenantAdmin);
        return adminMemberships.isNotEmpty
            ? adminMemberships.first.workspaceId
            : null;
      },
      orElse: () => null,
    );

    // If the workspace list is loaded, verify the ID is still valid.
    final workspaces = workspacesAsync.valueOrNull ?? [];
    if (userWorkspaceId != null) {
      final exists = workspaces.any((w) => w.id == userWorkspaceId);
      if (exists || workspaces.isEmpty) return userWorkspaceId;
    }

    // Fall back to the first workspace in the list.
    return workspaces.isNotEmpty ? workspaces.first.id : null;
  }

  /// Manually switch to a different workspace.
  void selectWorkspace(String workspaceId) {
    state = workspaceId;
  }
}

/// Returns the [Workspace] object for the currently selected workspace,
/// or null if no workspace is selected or the list hasn't loaded yet.
@riverpod
Workspace? activeWorkspace(ActiveWorkspaceRef ref) {
  final selectedId = ref.watch(selectedWorkspaceProvider);
  final workspacesAsync = ref.watch(workspacesListProvider);
  final workspaces = workspacesAsync.valueOrNull ?? [];
  if (selectedId == null) return null;
  try {
    return workspaces.firstWhere((w) => w.id == selectedId);
  } catch (_) {
    return workspaces.isNotEmpty ? workspaces.first : null;
  }
}
