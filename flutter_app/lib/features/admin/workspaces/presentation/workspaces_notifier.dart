import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/shared/models/invite_code.dart';
import 'package:social_study_app/shared/models/workspace.dart';

part 'workspaces_notifier.g.dart';

/// The admin's list of workspaces. Backs the workspace management
/// screen (4.1).
///
/// Mutations ([createWorkspace], [updateWorkspace], [deleteWorkspace])
/// go through the repository and then [refresh] the list so the screen
/// always reflects server truth — no optimistic local patching, which
/// keeps the count fields (`studentCount`, `documentCount`) honest.
@riverpod
class WorkspacesList extends _$WorkspacesList {
  @override
  Future<List<Workspace>> build() {
    return ref.read(workspacesRepositoryProvider).list();
  }

  /// Re-fetch the list. Used by pull-to-refresh and after every mutation.
  void refresh() => ref.invalidateSelf();

  /// Create a workspace, then refresh. Rethrows
  /// [WorkspaceNameConflictException] so the form can show an inline
  /// error on the name field.
  Future<Workspace> createWorkspace({
    required String name,
    String? description,
  }) async {
    final created = await ref
        .read(workspacesRepositoryProvider)
        .create(name: name, description: description);
    refresh();
    return created;
  }

  /// Patch a workspace's name/description, then refresh.
  Future<Workspace> updateWorkspace({
    required String workspaceId,
    String? name,
    String? description,
  }) async {
    final updated = await ref.read(workspacesRepositoryProvider).update(
          workspaceId: workspaceId,
          name: name,
          description: description,
        );
    refresh();
    return updated;
  }

  /// Soft-delete a workspace, then refresh.
  Future<void> deleteWorkspace(String workspaceId) async {
    await ref.read(workspacesRepositoryProvider).delete(workspaceId);
    refresh();
  }

  /// Generate a fresh invite code for a workspace. Does not touch list
  /// state — the caller (the user-management screen) shows the code.
  Future<GeneratedInviteCode> generateInviteCode(String workspaceId) {
    return ref
        .read(workspacesRepositoryProvider)
        .generateInviteCode(workspaceId);
  }
}
