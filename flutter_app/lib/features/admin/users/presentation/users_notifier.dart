import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/admin/users/data/users_repository.dart';
import 'package:social_study_app/shared/models/user.dart';

part 'users_notifier.g.dart';

/// The roster of users in one workspace. Backs the user management
/// screen (4.2). Family-keyed by `workspaceId`.
///
/// Mutations route through the repository and then [refresh] the list
/// so the screen always reflects server truth.
@riverpod
class WorkspaceUsersList extends _$WorkspaceUsersList {
  @override
  Future<List<User>> build(String workspaceId) {
    return ref
        .read(usersRepositoryProvider)
        .listWorkspaceUsers(workspaceId);
  }

  /// Re-fetch the roster. Used by pull-to-refresh and after mutations.
  void refresh() => ref.invalidateSelf();

  /// Create a user, then refresh. Rethrows [UserEmailConflictException]
  /// so the form can show an inline error on the email field.
  Future<User> createUser({
    required String email,
    required String displayName,
    required UserRole role,
  }) async {
    final created = await ref.read(usersRepositoryProvider).createUser(
          email: email,
          displayName: displayName,
          role: role,
        );
    refresh();
    return created;
  }

  /// Deactivate a user, then refresh.
  Future<void> deactivateUser(String userId) async {
    await ref.read(usersRepositoryProvider).deactivateUser(userId);
    refresh();
  }

  /// Change a user's role, then refresh.
  Future<User> changeRole({
    required String userId,
    required UserRole role,
  }) async {
    final updated = await ref
        .read(usersRepositoryProvider)
        .changeRole(userId: userId, role: role);
    refresh();
    return updated;
  }
}
