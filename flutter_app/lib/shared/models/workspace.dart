// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

/// Per-workspace configuration. Mirrors `app.models.workspace.WorkspaceSettings`
/// exactly — the admin settings screen (4.4) reads and patches this.
///
/// Wire keys are snake_case (the backend uses no alias generator), so
/// every multi-word field carries an explicit `@JsonKey`.
@freezed
class WorkspaceSettings with _$WorkspaceSettings {
  const factory WorkspaceSettings({
    /// How many questions a student is expected to answer per day.
    @JsonKey(name: 'questions_per_day') @Default(5) int questionsPerDay,

    /// Which question formats the generator may produce. Values are the
    /// snake_case `QuestionType` wire strings (`mcq`, `short_answer`, …).
    @JsonKey(name: 'question_types')
    @Default(<String>['mcq', 'short_answer'])
    List<String> questionTypes,

    /// When true, AI-generated content that passes safety is auto-served;
    /// when false it lands in the moderation queue for admin review.
    @JsonKey(name: 'auto_approve_content') @Default(true) bool autoApproveContent,

    /// Whether the workspace leaderboard is visible to students.
    @JsonKey(name: 'leaderboard_visible') @Default(true) bool leaderboardVisible,

    /// Whether difficulty calibration adapts to each student's mastery.
    @JsonKey(name: 'adaptive_difficulty') @Default(true) bool adaptiveDifficulty,
  }) = _WorkspaceSettings;

  factory WorkspaceSettings.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceSettingsFromJson(json);
}

/// A classroom or family learning group within a tenant.
///
/// Mirrors `app.models.workspace.WorkspaceResponse` (the API projection,
/// not the full Cosmos document) — so it carries the derived `*_count`
/// fields the backend computes from `admin_ids` / `student_ids` rather
/// than those id lists themselves.
@freezed
class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    required String name,
    @Default('') String description,

    /// Number of workspace admins (teachers / parents).
    @JsonKey(name: 'admin_count') @Default(0) int adminCount,

    /// Number of enrolled students.
    @JsonKey(name: 'student_count') @Default(0) int studentCount,

    /// Number of uploaded study documents.
    @JsonKey(name: 'document_count') @Default(0) int documentCount,
    required WorkspaceSettings settings,

    /// False once the workspace has been soft-deleted.
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @Default('personal') String type,
    @JsonKey(name: 'owner_id') String? ownerId,
    @JsonKey(name: 'join_code') String? joinCode,
  }) = _Workspace;

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}
