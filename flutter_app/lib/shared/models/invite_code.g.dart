// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_code.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GeneratedInviteCodeImpl _$$GeneratedInviteCodeImplFromJson(
        Map<String, dynamic> json) =>
    _$GeneratedInviteCodeImpl(
      code: json['code'] as String,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$GeneratedInviteCodeImplToJson(
        _$GeneratedInviteCodeImpl instance) =>
    <String, dynamic>{
      'code': instance.code,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'max_uses': instance.maxUses,
    };
