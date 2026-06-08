import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/admin/users/data/demo_users_repository.dart';
import 'package:social_study_app/features/admin/users/data/real_users_repository.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'users_repository.g.dart';

/// Source-of-truth for workspace user management (4.2) — the student
/// roster, direct user creation, deactivation, and role changes.
///
/// Maps the implemented backend routes (flat under `/users`, note these
/// differ from the plan's §5.3 quick-reference):
/// - `GET    /users/?workspace_id={id}` → [listWorkspaceUsers]
/// - `POST   /users/`                   → [createUser]
/// - `DELETE /users/{id}`               → [deactivateUser]
///
/// [changeRole] maps `PATCH /users/{id}` — **a documented (§5.3) but
/// not-yet-implemented route.** It works in the demo path today; the
/// real call lights up when the backend adds the endpoint.
abstract class UsersRepository {
  /// Users belonging to `workspaceId`.
  Future<List<User>> listWorkspaceUsers(String workspaceId);

  /// Directly create a user in the caller's tenant.
  ///
  /// Throws [UserEmailConflictException] (409) when the email is taken.
  Future<User> createUser({
    required String email,
    required String displayName,
    required UserRole role,
  });

  /// Soft-delete (deactivate) a user.
  ///
  /// Throws [UserNotFoundException] (404).
  Future<void> deactivateUser(String userId);

  /// Change a user's role.
  ///
  /// Throws [UserNotFoundException] (404).
  Future<User> changeRole({required String userId, required UserRole role});
}

/// Selects demo vs. real implementation by authenticated user.
@Riverpod(keepAlive: true)
UsersRepository usersRepository(UsersRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoUsersRepository();
  }
  return RealUsersRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
