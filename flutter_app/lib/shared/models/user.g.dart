// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkspaceMembershipImpl _$$WorkspaceMembershipImplFromJson(
        Map<String, dynamic> json) =>
    _$WorkspaceMembershipImpl(
      workspaceId: json['workspace_id'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      workspaceName: json['workspace_name'] as String?,
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.parse(json['joined_at'] as String),
    );

Map<String, dynamic> _$$WorkspaceMembershipImplToJson(
        _$WorkspaceMembershipImpl instance) =>
    <String, dynamic>{
      'workspace_id': instance.workspaceId,
      'role': _$UserRoleEnumMap[instance.role]!,
      'workspace_name': instance.workspaceName,
      'joined_at': instance.joinedAt?.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.tenantAdmin: 'tenant_admin',
  UserRole.workspaceAdmin: 'workspace_admin',
  UserRole.student: 'student',
};

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      tenantId: json['tenant_id'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      workspaceMemberships: (json['workspace_memberships'] as List<dynamic>?)
              ?.map((e) =>
                  WorkspaceMembership.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <WorkspaceMembership>[],
      avatarUrl: json['avatar_url'] as String?,
      gradeLevel: (json['grade_level'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin: json['last_login_at'] == null
          ? null
          : DateTime.parse(json['last_login_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'display_name': instance.displayName,
      'tenant_id': instance.tenantId,
      'role': _$UserRoleEnumMap[instance.role]!,
      'workspace_memberships': instance.workspaceMemberships,
      'avatar_url': instance.avatarUrl,
      'grade_level': instance.gradeLevel,
      'created_at': instance.createdAt.toIso8601String(),
      'last_login_at': instance.lastLogin?.toIso8601String(),
      'is_active': instance.isActive,
    };
