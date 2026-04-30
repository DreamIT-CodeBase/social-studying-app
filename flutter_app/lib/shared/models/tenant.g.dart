// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tenant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TenantImpl _$$TenantImplFromJson(Map<String, dynamic> json) => _$TenantImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$TenantTypeEnumMap, json['type']),
      adminUserId: json['adminUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$TenantImplToJson(_$TenantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$TenantTypeEnumMap[instance.type]!,
      'adminUserId': instance.adminUserId,
      'createdAt': instance.createdAt.toIso8601String(),
      'isDeleted': instance.isDeleted,
    };

const _$TenantTypeEnumMap = {
  TenantType.family: 'family',
  TenantType.school: 'school',
};
