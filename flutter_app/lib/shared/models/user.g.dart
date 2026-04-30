// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkspaceMembershipImpl _$$WorkspaceMembershipImplFromJson(
        Map<String, dynamic> json) =>
    _$WorkspaceMembershipImpl(
      workspaceId: json['workspaceId'] as String,
      workspaceName: json['workspaceName'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
    );

Map<String, dynamic> _$$WorkspaceMembershipImplToJson(
        _$WorkspaceMembershipImpl instance) =>
    <String, dynamic>{
      'workspaceId': instance.workspaceId,
      'workspaceName': instance.workspaceName,
      'role': _$UserRoleEnumMap[instance.role]!,
    };

const _$UserRoleEnumMap = {
  UserRole.tenantAdmin: 'tenantAdmin',
  UserRole.workspaceAdmin: 'workspaceAdmin',
  UserRole.student: 'student',
};

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      tenantId: json['tenantId'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      workspaceMemberships: (json['workspaceMemberships'] as List<dynamic>?)
              ?.map((e) =>
                  WorkspaceMembership.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      avatarUrl: json['avatarUrl'] as String?,
      gradeLevel: (json['gradeLevel'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLogin: DateTime.parse(json['lastLogin'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'tenantId': instance.tenantId,
      'role': _$UserRoleEnumMap[instance.role]!,
      'workspaceMemberships': instance.workspaceMemberships,
      'avatarUrl': instance.avatarUrl,
      'gradeLevel': instance.gradeLevel,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastLogin': instance.lastLogin.toIso8601String(),
      'isDeleted': instance.isDeleted,
    };
