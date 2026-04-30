import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

@freezed
class WorkspaceSettings with _$WorkspaceSettings {
  const factory WorkspaceSettings({
    @Default(5) int dailyQuestionGoal,
    @Default(true) bool gamificationEnabled,
    @Default(true) bool leaderboardVisible,
    @Default(0.7) double moderationThreshold,
  }) = _WorkspaceSettings;

  factory WorkspaceSettings.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceSettingsFromJson(json);
}

@freezed
class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    required String tenantId,
    required String name,
    String? description,
    required WorkspaceSettings settings,
    required DateTime createdAt,
    @Default(false) bool isDeleted,
  }) = _Workspace;

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}
