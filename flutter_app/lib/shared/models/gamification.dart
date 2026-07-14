// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime —
// JsonSerializable picks up the keys correctly.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'gamification.freezed.dart';
part 'gamification.g.dart';

/// Gamification models — back the Sprint 5.4 student gamification UI
/// (XP/level/streak/badges/leaderboard) and the 5.5 celebration overlay.
///
/// **Contract note.** Field names below mirror the Sprint 5.2 backend
/// (`backend/app/api/gamification.py`). When the backend renames a
/// field, this file is the source of truth on the Flutter side and
/// must be kept in sync.

/// One badge already on the student's profile.
@freezed
class EarnedBadge with _$EarnedBadge {
  const factory EarnedBadge({
    @JsonKey(name: 'badge_id') required String badgeId,
    required String name,
    required String description,

    /// Material Icons name string (e.g. `"local_fire_department_rounded"`)
    /// — the UI maps it through [iconForName] in `presentation/widgets/
    /// badge_icon.dart` so we don't ship a giant codepoint table.
    required String icon,

    /// ISO 8601 UTC timestamp the badge was awarded.
    @JsonKey(name: 'earned_at') required String earnedAt,
  }) = _EarnedBadge;

  factory EarnedBadge.fromJson(Map<String, dynamic> json) =>
      _$EarnedBadgeFromJson(json);
}

/// A catalog badge the student hasn't unlocked yet.
@freezed
class AvailableBadge with _$AvailableBadge {
  const factory AvailableBadge({
    @JsonKey(name: 'badge_id') required String badgeId,
    required String name,
    required String description,
    required String icon,
  }) = _AvailableBadge;

  factory AvailableBadge.fromJson(Map<String, dynamic> json) =>
      _$AvailableBadgeFromJson(json);
}

/// Wire shape of a badge unlocked on the just-completed answer or
/// flashcard rating. Drives the 5.5 unlock-modal celebration.
@freezed
class BadgeUnlock with _$BadgeUnlock {
  const factory BadgeUnlock({
    @JsonKey(name: 'badge_id') required String badgeId,
    required String name,
    required String description,
    required String icon,
  }) = _BadgeUnlock;

  factory BadgeUnlock.fromJson(Map<String, dynamic> json) =>
      _$BadgeUnlockFromJson(json);
}

/// Earned + available badge lists in a single payload.
@freezed
class BadgesSummary with _$BadgesSummary {
  const BadgesSummary._();

  const factory BadgesSummary({
    @JsonKey(name: 'student_id') required String studentId,
    @Default(<EarnedBadge>[]) List<EarnedBadge> earned,
    @Default(<AvailableBadge>[]) List<AvailableBadge> available,
    @JsonKey(name: 'earned_count') @Default(0) int earnedCount,
    @JsonKey(name: 'total_count') @Default(0) int totalCount,
  }) = _BadgesSummary;

  factory BadgesSummary.fromJson(Map<String, dynamic> json) =>
      _$BadgesSummaryFromJson(json);

  /// Zero-state for a student who hasn't earned anything yet.
  static const BadgesSummary empty = BadgesSummary(studentId: '');

  bool get hasEarned => earned.isNotEmpty;
}

/// Streak summary — drives the home page streak card.
@freezed
class StreakSummary with _$StreakSummary {
  const StreakSummary._();

  const factory StreakSummary({
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'streak_days') @Default(0) int streakDays,
    @JsonKey(name: 'longest_streak_days') @Default(0) int longestStreakDays,

    /// ISO date (YYYY-MM-DD) of the last day the student studied, or
    /// `null` if they've never studied.
    @JsonKey(name: 'last_active_date') String? lastActiveDate,

    /// Convenience boolean — true iff the student already has activity
    /// today. Powers the "you've studied today!" flame styling.
    @JsonKey(name: 'active_today') @Default(false) bool activeToday,
  }) = _StreakSummary;

  factory StreakSummary.fromJson(Map<String, dynamic> json) =>
      _$StreakSummaryFromJson(json);

  static const StreakSummary empty = StreakSummary(studentId: '');
}

/// Full gamification profile — XP totals, level + progress, streak,
/// per-topic XP, activity history. Backs the dedicated profile view
/// and seeds the home page cards.
@freezed
class GamificationProfile with _$GamificationProfile {
  const GamificationProfile._();

  const factory GamificationProfile({
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'workspace_id') required String workspaceId,
    @JsonKey(name: 'xp_total') @Default(0) int xpTotal,
    @JsonKey(name: 'xp_this_week') @Default(0) int xpThisWeek,

    /// Per-topic XP — key is topic display name.
    @JsonKey(name: 'xp_by_topic')
    @Default(<String, int>{})
    Map<String, int> xpByTopic,
    @Default(1) int level,
    @JsonKey(name: 'xp_into_level') @Default(0) int xpIntoLevel,
    @JsonKey(name: 'xp_for_next_level') @Default(100) int xpForNextLevel,
    @JsonKey(name: 'streak_days') @Default(0) int streakDays,
    @JsonKey(name: 'longest_streak_days') @Default(0) int longestStreakDays,
    @JsonKey(name: 'last_active_date') String? lastActiveDate,
    @JsonKey(name: 'questions_answered') @Default(0) int questionsAnswered,
    @JsonKey(name: 'questions_correct') @Default(0) int questionsCorrect,
    @JsonKey(name: 'flashcards_reviewed') @Default(0) int flashcardsReviewed,
    @Default(<EarnedBadge>[]) List<EarnedBadge> badges,

    /// Last 30 days of activity counts — `{"2026-05-23": 12, ...}`.
    @JsonKey(name: 'daily_activity')
    @Default(<String, int>{})
    Map<String, int> dailyActivity,

    /// Last 30 days of net XP by UTC calendar date.
    @JsonKey(name: 'daily_xp')
    @Default(<String, int>{})
    Map<String, int> dailyXp,
  }) = _GamificationProfile;

  factory GamificationProfile.fromJson(Map<String, dynamic> json) =>
      _$GamificationProfileFromJson(json);

  /// Zero-state for a brand-new student.
  static const GamificationProfile empty = GamificationProfile(
    studentId: '',
    workspaceId: '',
  );

  /// 0.0–1.0 fraction within the current level — ready to plug into a
  /// [LinearProgressIndicator]. Always finite; clamped if a malformed
  /// payload comes through.
  double get levelProgress {
    if (xpForNextLevel <= 0) return 0;
    final raw = xpIntoLevel / xpForNextLevel;
    return raw.clamp(0.0, 1.0);
  }

  /// Question accuracy as a 0–1 fraction; 0 when no questions answered
  /// (the UI surfaces this as "—" rather than 0% to avoid implying
  /// failure).
  double get accuracy =>
      questionsAnswered == 0 ? 0 : questionsCorrect / questionsAnswered;
}

/// One row on the workspace leaderboard.
@freezed
class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    @JsonKey(name: 'student_id') required String studentId,
    @JsonKey(name: 'display_name') required String displayName,
    @Default(1) int level,
    @JsonKey(name: 'xp_total') @Default(0) int xpTotal,
    @JsonKey(name: 'xp_this_week') @Default(0) int xpThisWeek,
    @Default(0) int rank,
    @JsonKey(name: 'streak_days') @Default(0) int streakDays,
  }) = _LeaderboardEntry;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);
}

/// Leaderboard response — the ranked list plus the caller's own rank
/// (carried separately so it survives when the caller falls off the
/// visible window) plus the workspace-visibility flag.
@freezed
class LeaderboardResponse with _$LeaderboardResponse {
  const LeaderboardResponse._();

  const factory LeaderboardResponse({
    @JsonKey(name: 'workspace_id') required String workspaceId,
    @Default(<LeaderboardEntry>[]) List<LeaderboardEntry> entries,
    @JsonKey(name: 'current_user_rank') int? currentUserRank,

    /// False ⇒ the workspace setting hides the leaderboard from the
    /// calling student. `entries` is empty in that case. Admins
    /// always see `visible: true`.
    @Default(true) bool visible,
  }) = _LeaderboardResponse;

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardResponseFromJson(json);

  /// Convenience zero-state for the hidden case.
  static const LeaderboardResponse hidden = LeaderboardResponse(
    workspaceId: '',
    visible: false,
  );
}

@freezed
class SessionCompletionFeedback with _$SessionCompletionFeedback {
  const factory SessionCompletionFeedback({
    @JsonKey(name: 'xp_earned') required int xpEarned,
    @JsonKey(name: 'new_level') required int newLevel,
    @JsonKey(name: 'leveled_up') required bool leveledUp,
    @JsonKey(name: 'streak_days') required int streakDays,
    @JsonKey(name: 'streak_extended') required bool streakExtended,
    @JsonKey(name: 'badges_unlocked')
    @Default(<EarnedBadge>[])
    List<EarnedBadge> badgesUnlocked,
  }) = _SessionCompletionFeedback;

  factory SessionCompletionFeedback.fromJson(Map<String, dynamic> json) =>
      _$SessionCompletionFeedbackFromJson(json);
}
