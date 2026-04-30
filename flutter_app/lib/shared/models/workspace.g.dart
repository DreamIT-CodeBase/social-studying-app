// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkspaceSettingsImpl _$$WorkspaceSettingsImplFromJson(
        Map<String, dynamic> json) =>
    _$WorkspaceSettingsImpl(
      dailyQuestionGoal: (json['dailyQuestionGoal'] as num?)?.toInt() ?? 5,
      gamificationEnabled: json['gamificationEnabled'] as bool? ?? true,
      leaderboardVisible: json['leaderboardVisible'] as bool? ?? true,
      moderationThreshold:
          (json['moderationThreshold'] as num?)?.toDouble() ?? 0.7,
    );

Map<String, dynamic> _$$WorkspaceSettingsImplToJson(
        _$WorkspaceSettingsImpl instance) =>
    <String, dynamic>{
      'dailyQuestionGoal': instance.dailyQuestionGoal,
      'gamificationEnabled': instance.gamificationEnabled,
      'leaderboardVisible': instance.leaderboardVisible,
      'moderationThreshold': instance.moderationThreshold,
    };

_$WorkspaceImpl _$$WorkspaceImplFromJson(Map<String, dynamic> json) =>
    _$WorkspaceImpl(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      settings:
          WorkspaceSettings.fromJson(json['settings'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );

Map<String, dynamic> _$$WorkspaceImplToJson(_$WorkspaceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'name': instance.name,
      'description': instance.description,
      'settings': instance.settings,
      'createdAt': instance.createdAt.toIso8601String(),
      'isDeleted': instance.isDeleted,
    };
