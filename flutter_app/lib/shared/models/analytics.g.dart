// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TopicStatsImpl _$$TopicStatsImplFromJson(Map<String, dynamic> json) =>
    _$TopicStatsImpl(
      topic: json['topic'] as String,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      avgMastery: (json['avg_mastery'] as num?)?.toDouble() ?? 0.0,
      correctRate: (json['correct_rate'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$TopicStatsImplToJson(_$TopicStatsImpl instance) =>
    <String, dynamic>{
      'topic': instance.topic,
      'attempts': instance.attempts,
      'avg_mastery': instance.avgMastery,
      'correct_rate': instance.correctRate,
    };

_$DifficultyStatsImpl _$$DifficultyStatsImplFromJson(
        Map<String, dynamic> json) =>
    _$DifficultyStatsImpl(
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$DifficultyStatsImplToJson(
        _$DifficultyStatsImpl instance) =>
    <String, dynamic>{
      'attempts': instance.attempts,
      'correct': instance.correct,
    };

_$HeatmapCellImpl _$$HeatmapCellImplFromJson(Map<String, dynamic> json) =>
    _$HeatmapCellImpl(
      date: json['date'] as String,
      events: (json['events'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$HeatmapCellImplToJson(_$HeatmapCellImpl instance) =>
    <String, dynamic>{
      'date': instance.date,
      'events': instance.events,
    };

_$WorkspaceAnalyticsImpl _$$WorkspaceAnalyticsImplFromJson(
        Map<String, dynamic> json) =>
    _$WorkspaceAnalyticsImpl(
      workspaceId: json['workspace_id'] as String,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      activeStudents7d: (json['active_students_7d'] as num?)?.toInt() ?? 0,
      avgOverallMastery:
          (json['avg_overall_mastery'] as num?)?.toDouble() ?? 0.0,
      avgQuestionsPerStudent:
          (json['avg_questions_per_student'] as num?)?.toDouble() ?? 0.0,
      avgCorrectRate: (json['avg_correct_rate'] as num?)?.toDouble() ?? 0.0,
      topicDistribution: (json['topic_distribution'] as List<dynamic>?)
              ?.map((e) => TopicStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TopicStats>[],
      difficultyDistribution:
          (json['difficulty_distribution'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(
                    k, DifficultyStats.fromJson(e as Map<String, dynamic>)),
              ) ??
              const <String, DifficultyStats>{},
      engagementHeatmap: (json['engagement_heatmap'] as List<dynamic>?)
              ?.map((e) => HeatmapCell.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <HeatmapCell>[],
    );

Map<String, dynamic> _$$WorkspaceAnalyticsImplToJson(
        _$WorkspaceAnalyticsImpl instance) =>
    <String, dynamic>{
      'workspace_id': instance.workspaceId,
      'total_students': instance.totalStudents,
      'active_students_7d': instance.activeStudents7d,
      'avg_overall_mastery': instance.avgOverallMastery,
      'avg_questions_per_student': instance.avgQuestionsPerStudent,
      'avg_correct_rate': instance.avgCorrectRate,
      'topic_distribution': instance.topicDistribution,
      'difficulty_distribution': instance.difficultyDistribution,
      'engagement_heatmap': instance.engagementHeatmap,
    };

_$TenantWorkspaceSummaryImpl _$$TenantWorkspaceSummaryImplFromJson(
        Map<String, dynamic> json) =>
    _$TenantWorkspaceSummaryImpl(
      workspaceId: json['workspace_id'] as String,
      name: json['name'] as String,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      activeStudents7d: (json['active_students_7d'] as num?)?.toInt() ?? 0,
      avgMastery: (json['avg_mastery'] as num?)?.toDouble() ?? 0.0,
      totalQuestionsAnswered:
          (json['total_questions_answered'] as num?)?.toInt() ?? 0,
      totalFlashcardsReviewed:
          (json['total_flashcards_reviewed'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$TenantWorkspaceSummaryImplToJson(
        _$TenantWorkspaceSummaryImpl instance) =>
    <String, dynamic>{
      'workspace_id': instance.workspaceId,
      'name': instance.name,
      'total_students': instance.totalStudents,
      'active_students_7d': instance.activeStudents7d,
      'avg_mastery': instance.avgMastery,
      'total_questions_answered': instance.totalQuestionsAnswered,
      'total_flashcards_reviewed': instance.totalFlashcardsReviewed,
    };

_$TenantAnalyticsImpl _$$TenantAnalyticsImplFromJson(
        Map<String, dynamic> json) =>
    _$TenantAnalyticsImpl(
      tenantId: json['tenant_id'] as String,
      totalWorkspaces: (json['total_workspaces'] as num?)?.toInt() ?? 0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      activeStudents7d: (json['active_students_7d'] as num?)?.toInt() ?? 0,
      workspaces: (json['workspaces'] as List<dynamic>?)
              ?.map((e) =>
                  TenantWorkspaceSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TenantWorkspaceSummary>[],
    );

Map<String, dynamic> _$$TenantAnalyticsImplToJson(
        _$TenantAnalyticsImpl instance) =>
    <String, dynamic>{
      'tenant_id': instance.tenantId,
      'total_workspaces': instance.totalWorkspaces,
      'total_students': instance.totalStudents,
      'active_students_7d': instance.activeStudents7d,
      'workspaces': instance.workspaces,
    };
