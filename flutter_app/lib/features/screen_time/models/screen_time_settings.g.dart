// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_time_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScreenTimeSettingsImpl _$$ScreenTimeSettingsImplFromJson(
        Map<String, dynamic> json) =>
    _$ScreenTimeSettingsImpl(
      workspaceId: json['workspace_id'] as String,
      enableBlocking: json['enable_blocking'] as bool? ?? true,
      blockedPackages: (json['blocked_packages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      xpToMinuteRatio: (json['xp_to_minute_ratio'] as num?)?.toInt() ?? 10,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$$ScreenTimeSettingsImplToJson(
        _$ScreenTimeSettingsImpl instance) =>
    <String, dynamic>{
      'workspace_id': instance.workspaceId,
      'enable_blocking': instance.enableBlocking,
      'blocked_packages': instance.blockedPackages,
      'xp_to_minute_ratio': instance.xpToMinuteRatio,
      'updated_at': instance.updatedAt,
    };
