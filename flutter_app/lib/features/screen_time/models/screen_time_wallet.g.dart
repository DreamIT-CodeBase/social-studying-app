// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_time_wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScreenTimeWalletImpl _$$ScreenTimeWalletImplFromJson(
        Map<String, dynamic> json) =>
    _$ScreenTimeWalletImpl(
      studentId: json['student_id'] as String? ?? '',
      workspaceId: json['workspace_id'] as String? ?? '',
      totalEarnedMinutes: (json['total_earned_minutes'] as num?)?.toInt() ?? 0,
      availableMinutes: (json['available_minutes'] as num?)?.toInt() ?? 0,
      consumedMinutes: (json['consumed_minutes'] as num?)?.toInt() ?? 0,
      lastKnownXp: (json['last_known_xp'] as num?)?.toInt() ?? 0,
      lastSyncTime: json['last_sync_time'] == null
          ? null
          : DateTime.parse(json['last_sync_time'] as String),
      consumedToday: (json['consumed_today'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ScreenTimeWalletImplToJson(
        _$ScreenTimeWalletImpl instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'workspace_id': instance.workspaceId,
      'total_earned_minutes': instance.totalEarnedMinutes,
      'available_minutes': instance.availableMinutes,
      'consumed_minutes': instance.consumedMinutes,
      'last_known_xp': instance.lastKnownXp,
      'last_sync_time': instance.lastSyncTime?.toIso8601String(),
      'consumed_today': instance.consumedToday,
    };
