import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/data/real_workspaces_repository.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/models/invite_code.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'workspaces_repository.g.dart';

/// Source-of-truth for workspace CRUD + invite-code generation (4.1),
/// and for persisting [WorkspaceSettings] changes from the settings
/// screen (4.4) via [update].
///
/// Maps the implemented backend routes (note: these differ from the
/// plan's §5.2 quick-reference — the real routes are flat under
/// `/workspaces`, with PATCH for partial updates):
/// - `GET    /workspaces/`                  → [list]
/// - `POST   /workspaces/`                  → [create]
/// - `PATCH  /workspaces/{id}`              → [update]
/// - `DELETE /workspaces/{id}`              → [delete]
/// - `POST   /workspaces/{id}/invite-codes` → [generateInviteCode]
abstract class WorkspacesRepository {
  /// Workspaces the caller belongs to (tenant admins see all of theirs).
  Future<List<Workspace>> list();

  /// Create a workspace in the caller's tenant.
  ///
  /// Throws [WorkspaceNameConflictException] (409) when a live
  /// workspace with the same name already exists in the tenant.
  Future<Workspace> create({required String name, String? description});

  /// Patch a workspace. Any `null` argument is left unchanged — this
  /// maps the backend's `WorkspaceUpdate` partial-update semantics, and
  /// is how the settings screen persists a [WorkspaceSettings] change
  /// without touching name/description.
  ///
  /// Throws [WorkspaceNotFoundException] (404).
  Future<Workspace> update({
    required String workspaceId,
    String? name,
    String? description,
    WorkspaceSettings? settings,
  });

  /// Soft-delete a workspace (tenant-admin only on the backend).
  ///
  /// Throws [WorkspaceNotFoundException] (404).
  Future<void> delete(String workspaceId);

  /// Generate a fresh invite code students can redeem to join.
  ///
  /// Throws [WorkspaceNotFoundException] (404).
  Future<GeneratedInviteCode> generateInviteCode(String workspaceId);


}

/// Selects demo vs. real implementation by authenticated user — the
/// same heuristic every repository in the app uses.
@Riverpod(keepAlive: true)
WorkspacesRepository workspacesRepository(WorkspacesRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoWorkspacesRepository();
  }
  return RealWorkspacesRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
