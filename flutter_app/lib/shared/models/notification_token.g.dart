// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationTokenRegistrationImpl
    _$$NotificationTokenRegistrationImplFromJson(Map<String, dynamic> json) =>
        _$NotificationTokenRegistrationImpl(
          installationId: json['installation_id'] as String,
          token: json['token'] as String,
          platform: $enumDecode(_$DevicePlatformEnumMap, json['platform']),
        );

Map<String, dynamic> _$$NotificationTokenRegistrationImplToJson(
        _$NotificationTokenRegistrationImpl instance) =>
    <String, dynamic>{
      'installation_id': instance.installationId,
      'token': instance.token,
      'platform': _$DevicePlatformEnumMap[instance.platform]!,
    };

const _$DevicePlatformEnumMap = {
  DevicePlatform.android: 'android',
  DevicePlatform.ios: 'ios',
};

_$NotificationTokenResponseImpl _$$NotificationTokenResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$NotificationTokenResponseImpl(
      installationId: json['installation_id'] as String,
      token: json['token'] as String,
      platform: $enumDecode(_$DevicePlatformEnumMap, json['platform']),
      registeredAt: json['registered_at'] as String,
      lastSeenAt: json['last_seen_at'] as String,
    );

Map<String, dynamic> _$$NotificationTokenResponseImplToJson(
        _$NotificationTokenResponseImpl instance) =>
    <String, dynamic>{
      'installation_id': instance.installationId,
      'token': instance.token,
      'platform': _$DevicePlatformEnumMap[instance.platform]!,
      'registered_at': instance.registeredAt,
      'last_seen_at': instance.lastSeenAt,
    };
