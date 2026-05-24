// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime —
// JsonSerializable picks up the keys correctly.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics.freezed.dart';
part 'analytics.g.dart';

/// Analytics wire models — Sprint 5.11 workspace dashboard +
/// Sprint 5.10/5.11 tenant roll-up. Mirrors
/// `backend/app/api/analytics.py`. Field names below are the source
/// of truth for the Pydantic response on the backend.

/// Per-topic row in the workspace dashboard's topic-distribution
/// list. Backend orders alphabetically by topic name.
@freezed
class TopicStats with _$TopicStats {
  const factory TopicStats({
    required String topic,
    @Default(0) int attempts,

    /// Mean mastery across students that have at least one
    /// [KnowledgeState] row for this topic. 0.0–1.0.
    @JsonKey(name: 'avg_mastery') @Default(0.0) double avgMastery,

    /// Fraction of attempts answered correctly across all students,
    /// 0.0–1.0.
    @JsonKey(name: 'correct_rate') @Default(0.0) double correctRate,
  }) = _TopicStats;

  factory TopicStats.fromJson(Map<String, dynamic> json) =>
      _$TopicStatsFromJson(json);
}

/// Per-difficulty attempts + correct counts. The v1 backend returns
/// zeros for every bucket — the Interaction row doesn't currently
/// carry difficulty, so the aggregation is stubbed. The wire shape
/// is preserved so the UI can render a placeholder.
@freezed
class DifficultyStats with _$DifficultyStats {
  const factory DifficultyStats({
    @Default(0) int attempts,
    @Default(0) int correct,
  }) = _DifficultyStats;

  factory DifficultyStats.fromJson(Map<String, dynamic> json) =>
      _$DifficultyStatsFromJson(json);
}

/// One day on the engagement heatmap. ISO date `YYYY-MM-DD` UTC.
@freezed
class HeatmapCell with _$HeatmapCell {
  const factory HeatmapCell({
    required String date,
    @Default(0) int events,
  }) = _HeatmapCell;

  factory HeatmapCell.fromJson(Map<String, dynamic> json) =>
      _$HeatmapCellFromJson(json);
}

/// Workspace-level dashboard payload.
@freezed
class WorkspaceAnalytics with _$WorkspaceAnalytics {
  const WorkspaceAnalytics._();

  const factory WorkspaceAnalytics({
    @JsonKey(name: 'workspace_id') required String workspaceId,
    @JsonKey(name: 'total_students') @Default(0) int totalStudents,
    @JsonKey(name: 'active_students_7d') @Default(0) int activeStudents7d,
    @JsonKey(name: 'avg_overall_mastery')
    @Default(0.0)
    double avgOverallMastery,
    @JsonKey(name: 'avg_questions_per_student')
    @Default(0.0)
    double avgQuestionsPerStudent,
    @JsonKey(name: 'avg_correct_rate') @Default(0.0) double avgCorrectRate,
    @JsonKey(name: 'topic_distribution')
    @Default(<TopicStats>[])
    List<TopicStats> topicDistribution,
    @JsonKey(name: 'difficulty_distribution')
    @Default(<String, DifficultyStats>{})
    Map<String, DifficultyStats> difficultyDistribution,
    @JsonKey(name: 'engagement_heatmap')
    @Default(<HeatmapCell>[])
    List<HeatmapCell> engagementHeatmap,
  }) = _WorkspaceAnalytics;

  factory WorkspaceAnalytics.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceAnalyticsFromJson(json);

  /// Zero-state for a brand-new workspace.
  static const WorkspaceAnalytics empty = WorkspaceAnalytics(workspaceId: '');

  /// True iff any student has any kind of activity logged in this
  /// workspace — the dashboard renders an empty state otherwise.
  bool get hasActivity =>
      totalStudents > 0 || engagementHeatmap.any((c) => c.events > 0);
}

/// Per-workspace summary row on the tenant dashboard.
@freezed
class TenantWorkspaceSummary with _$TenantWorkspaceSummary {
  const factory TenantWorkspaceSummary({
    @JsonKey(name: 'workspace_id') required String workspaceId,
    required String name,
    @JsonKey(name: 'total_students') @Default(0) int totalStudents,
    @JsonKey(name: 'active_students_7d') @Default(0) int activeStudents7d,
    @JsonKey(name: 'avg_mastery') @Default(0.0) double avgMastery,
    @JsonKey(name: 'total_questions_answered')
    @Default(0)
    int totalQuestionsAnswered,
    @JsonKey(name: 'total_flashcards_reviewed')
    @Default(0)
    int totalFlashcardsReviewed,
  }) = _TenantWorkspaceSummary;

  factory TenantWorkspaceSummary.fromJson(Map<String, dynamic> json) =>
      _$TenantWorkspaceSummaryFromJson(json);
}

/// Tenant-level roll-up payload.
@freezed
class TenantAnalytics with _$TenantAnalytics {
  const factory TenantAnalytics({
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'total_workspaces') @Default(0) int totalWorkspaces,
    @JsonKey(name: 'total_students') @Default(0) int totalStudents,
    @JsonKey(name: 'active_students_7d') @Default(0) int activeStudents7d,
    @Default(<TenantWorkspaceSummary>[])
    List<TenantWorkspaceSummary> workspaces,
  }) = _TenantAnalytics;

  factory TenantAnalytics.fromJson(Map<String, dynamic> json) =>
      _$TenantAnalyticsFromJson(json);
}
