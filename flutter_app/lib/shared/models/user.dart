import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

enum UserRole { tenantAdmin, workspaceAdmin, student }

@freezed
class WorkspaceMembership with _$WorkspaceMembership {
  const factory WorkspaceMembership({
    required String workspaceId,
    required String workspaceName,
    required UserRole role,
  }) = _WorkspaceMembership;

  factory WorkspaceMembership.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceMembershipFromJson(json);
}

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String displayName,
    required String tenantId,
    required UserRole role,
    @Default([]) List<WorkspaceMembership> workspaceMemberships,
    String? avatarUrl,
    int? gradeLevel,
    required DateTime createdAt,
    required DateTime lastLogin,
    @Default(false) bool isDeleted,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
