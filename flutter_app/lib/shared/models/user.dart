// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Tenant/workspace role. Mirrors `app.models.user.UserRole` — the
/// wire values are snake_case, so each variant carries an explicit
/// `@JsonValue` (without it, json_serializable would emit `tenantAdmin`
/// and fail to round-trip against the backend's `tenant_admin`).
enum UserRole {
  @JsonValue('tenant_admin')
  tenantAdmin,
  @JsonValue('workspace_admin')
  workspaceAdmin,
  @JsonValue('student')
  student,
}

/// One workspace a user belongs to. Mirrors
/// `app.models.user.WorkspaceMembership` (`workspace_id`, `role`,
/// `joined_at`).
///
/// `workspaceName` is *not* part of the backend document — it's an
/// optional display convenience populated by the demo path and by UI
/// joins against the workspace list. Keeping it nullable means parsing
/// a real backend payload (which omits it) still succeeds.
@freezed
class WorkspaceMembership with _$WorkspaceMembership {
  const factory WorkspaceMembership({
    @JsonKey(name: 'workspace_id') required String workspaceId,
    required UserRole role,
    @JsonKey(name: 'workspace_name') String? workspaceName,
    @JsonKey(name: 'joined_at') DateTime? joinedAt,
  }) = _WorkspaceMembership;

  factory WorkspaceMembership.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceMembershipFromJson(json);
}

/// An app user. Tolerant superset of the backend's `UserResponse`
/// projection: every field the projection omits (`workspace_memberships`,
/// `last_login_at`, `avatar_url`, `grade_level`) is optional with a
/// default, so `User.fromJson` succeeds against `GET /users/me` *and*
/// against the richer demo/auth payloads that do carry memberships.
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'tenant_id') required String tenantId,
    required UserRole role,
    @JsonKey(name: 'workspace_memberships')
    @Default(<WorkspaceMembership>[])
    List<WorkspaceMembership> workspaceMemberships,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'grade_level') int? gradeLevel,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'last_login_at') DateTime? lastLogin,

    /// False once the account has been soft-deleted (`is_active` on the
    /// backend).
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
