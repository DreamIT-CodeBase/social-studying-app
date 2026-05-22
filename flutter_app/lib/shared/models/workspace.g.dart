// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WorkspaceSettingsImpl _$$WorkspaceSettingsImplFromJson(
        Map<String, dynamic> json) =>
    _$WorkspaceSettingsImpl(
      questionsPerDay: (json['questions_per_day'] as num?)?.toInt() ?? 5,
      questionTypes: (json['question_types'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>['mcq', 'short_answer'],
      autoApproveContent: json['auto_approve_content'] as bool? ?? true,
      leaderboardVisible: json['leaderboard_visible'] as bool? ?? true,
      adaptiveDifficulty: json['adaptive_difficulty'] as bool? ?? true,
    );

Map<String, dynamic> _$$WorkspaceSettingsImplToJson(
        _$WorkspaceSettingsImpl instance) =>
    <String, dynamic>{
      'questions_per_day': instance.questionsPerDay,
      'question_types': instance.questionTypes,
      'auto_approve_content': instance.autoApproveContent,
      'leaderboard_visible': instance.leaderboardVisible,
      'adaptive_difficulty': instance.adaptiveDifficulty,
    };

_$WorkspaceImpl _$$WorkspaceImplFromJson(Map<String, dynamic> json) =>
    _$WorkspaceImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      adminCount: (json['admin_count'] as num?)?.toInt() ?? 0,
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
      settings:
          WorkspaceSettings.fromJson(json['settings'] as Map<String, dynamic>),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$WorkspaceImplToJson(_$WorkspaceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'name': instance.name,
      'description': instance.description,
      'admin_count': instance.adminCount,
      'student_count': instance.studentCount,
      'document_count': instance.documentCount,
      'settings': instance.settings,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
    };
