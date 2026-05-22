// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime —
// JsonSerializable picks up the keys correctly.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'progress.freezed.dart';
part 'progress.g.dart';

/// Student progress models — backs the student progress view (4.11) and
/// the admin per-student detail view (Sprint 5.10).
///
/// **Contract note.** The backend `GET /workspaces/{ws}/users/{uid}/progress`
/// endpoint is Sprint 5.9 — not yet implemented. These models define the
/// wire contract that endpoint must satisfy; the demo repository serves
/// them fully offline today, and `RealProgressRepository` is coded
/// against this shape ready for 5.9 to land. Field names below are the
/// source of truth for the Pydantic response model on the backend.

/// One topic's mastery summary, derived from the `knowledge_states`
/// collection (per-topic mastery score, attempts, success rate).
@freezed
class TopicMastery with _$TopicMastery {
  const factory TopicMastery({
    @JsonKey(name: 'topic_id') required String topicId,
    @JsonKey(name: 'topic_name') required String topicName,

    /// Mastery as a 0.0–1.0 fraction (the backend stores 0–100; the
    /// repository normalizes so the UI never has to remember the scale).
    required double mastery,
    @Default(0) int attempts,

    /// Fraction of attempts answered correctly, 0.0–1.0.
    @JsonKey(name: 'success_rate') @Default(0.0) double successRate,
  }) = _TopicMastery;

  factory TopicMastery.fromJson(Map<String, dynamic> json) =>
      _$TopicMasteryFromJson(json);
}

/// Whether a timeline entry came from a graded question or a flashcard
/// self-rating.
enum ActivityKind {
  @JsonValue('question')
  question,
  @JsonValue('flashcard')
  flashcard,
}

/// One row in the recent-activity timeline.
@freezed
class ActivityEntry with _$ActivityEntry {
  const factory ActivityEntry({
    required ActivityKind kind,
    required String topic,

    /// True/false for a graded question; `null` for a flashcard, which
    /// is self-rated and has no correctness verdict.
    @JsonKey(name: 'is_correct') bool? isCorrect,
    @JsonKey(name: 'xp_earned') @Default(0) int xpEarned,

    /// ISO 8601 UTC timestamp of the interaction.
    @JsonKey(name: 'occurred_at') required String occurredAt,
  }) = _ActivityEntry;

  factory ActivityEntry.fromJson(Map<String, dynamic> json) =>
      _$ActivityEntryFromJson(json);
}

/// The complete progress snapshot for one student in one workspace.
@freezed
class StudentProgress with _$StudentProgress {
  const StudentProgress._();

  const factory StudentProgress({
    required int level,
    @JsonKey(name: 'total_xp') required int totalXp,

    /// XP accumulated within the current level (resets to 0 on level-up).
    @JsonKey(name: 'xp_into_level') required int xpIntoLevel,

    /// XP span of the current level — `xpIntoLevel / xpForNextLevel` is
    /// the progress-bar fraction. Always > 0 so the UI can divide safely.
    @JsonKey(name: 'xp_for_next_level') required int xpForNextLevel,

    /// Overall mastery across all topics, 0.0–1.0.
    @JsonKey(name: 'overall_mastery') required double overallMastery,
    @Default(<TopicMastery>[]) List<TopicMastery> topics,
    @JsonKey(name: 'recent_activity')
    @Default(<ActivityEntry>[])
    List<ActivityEntry> recentActivity,
  }) = _StudentProgress;

  factory StudentProgress.fromJson(Map<String, dynamic> json) =>
      _$StudentProgressFromJson(json);

  /// A zero-state snapshot — a brand-new student who hasn't answered
  /// anything yet. The progress screen renders this as its empty state
  /// (see [hasActivity]).
  static const StudentProgress empty = StudentProgress(
    level: 1,
    totalXp: 0,
    xpIntoLevel: 0,
    xpForNextLevel: 100,
    overallMastery: 0,
  );

  /// True once the student has any mastery data or timeline history —
  /// the screen branches on this to choose its empty vs. data state.
  bool get hasActivity => topics.isNotEmpty || recentActivity.isNotEmpty;
}
