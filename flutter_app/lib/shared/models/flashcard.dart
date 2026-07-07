// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime —
// JsonSerializable picks up the keys correctly.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'flashcard.freezed.dart';
part 'flashcard.g.dart';

/// Mirrors `app.models.flashcard.FlashcardRating` on the backend.
///
/// The student's self-assessment of how well they recalled the back of
/// the card. Three buckets — the same cognitive load Anki / Quizlet /
/// SuperMemo settled on. Sprint 5/6's spaced-repetition scheduler reads
/// these rating events to compute the next review interval.
///
/// Wire-format strings are explicit `@JsonValue`s so a backend rename
/// can't silently break Flutter parsing.
enum FlashcardRating {
  /// Recalled instantly — push the next review out.
  @JsonValue('easy')
  easy,

  /// Recalled with some effort.
  @JsonValue('medium')
  medium,

  /// Didn't recall — surface this card again soon.
  @JsonValue('hard')
  hard,
}

/// The student-facing view of a generated flashcard.
///
/// Mirrors `app.models.flashcard.FlashcardForStudent` exactly.
///
/// **Unlike [Question], a flashcard reveals everything up front.** The
/// `back` and `explanation` are part of this shape — the student is
/// self-rating their recall, not being tested against a hidden answer.
/// The UI controls *when* `back` becomes visible (the flip gesture);
/// the model never withholds it.
@freezed
class Flashcard with _$Flashcard {
  const factory Flashcard({
    required String id,
    required String topic,

    /// The cue side — shown first, what the student tries to recall from.
    required String front,

    /// The recall target — revealed after the flip gesture.
    required String back,

    /// Optional extra context shown alongside the back after the flip.
    @Default('') String explanation,
  }) = _Flashcard;

  factory Flashcard.fromJson(Map<String, dynamic> json) =>
      _$FlashcardFromJson(json);
}

/// Request body for `POST /flashcards/{flashcard_id}/rate`.
///
/// Mirrors `app.models.flashcard.FlashcardRatingSubmission`.
@freezed
class FlashcardRatingSubmission with _$FlashcardRatingSubmission {
  const factory FlashcardRatingSubmission({
    required FlashcardRating rating,
    @JsonKey(name: 'selected_option') String? selectedOption,
    @JsonKey(name: 'is_correct') bool? isCorrect,
    @JsonKey(name: 'response_time_ms') int? responseTimeMs,
    @JsonKey(name: 'session_progress') int? sessionProgress,
    @JsonKey(name: 'accuracy_percentage') double? accuracyPercentage,
  }) = _FlashcardRatingSubmission;

  factory FlashcardRatingSubmission.fromJson(Map<String, dynamic> json) =>
      _$FlashcardRatingSubmissionFromJson(json);
}

/// Response body for `POST /flashcards/{flashcard_id}/rate`.
///
/// Mirrors `app.models.flashcard.FlashcardRatingResponse`. Echoes the
/// stored rating + timestamp so the UI can update local state without
/// a refetch.
@freezed
class FlashcardRatingResponse with _$FlashcardRatingResponse {
  const factory FlashcardRatingResponse({
    @JsonKey(name: 'flashcard_id') required String flashcardId,
    required FlashcardRating rating,
    @JsonKey(name: 'rated_at') required String ratedAt,

    // ── Sprint 5 gamification ──────────────────────────────────────────
    @JsonKey(name: 'xp_earned') @Default(0) int xpEarned,
    @JsonKey(name: 'new_level') @Default(1) int newLevel,
    @JsonKey(name: 'leveled_up') @Default(false) bool leveledUp,
    @JsonKey(name: 'streak_days') @Default(0) int streakDays,
    @JsonKey(name: 'streak_extended') @Default(false) bool streakExtended,
    @JsonKey(name: 'badges_unlocked')
    @Default(<FlashcardBadgeUnlock>[])
    List<FlashcardBadgeUnlock> badgesUnlocked,
  }) = _FlashcardRatingResponse;

  factory FlashcardRatingResponse.fromJson(Map<String, dynamic> json) =>
      _$FlashcardRatingResponseFromJson(json);
}

/// A badge unlocked on a flashcard rating response. Mirrors the
/// backend's ``FlashcardRatingBadgeUnlock`` wire model.
@freezed
class FlashcardBadgeUnlock with _$FlashcardBadgeUnlock {
  const factory FlashcardBadgeUnlock({
    @JsonKey(name: 'badge_id') required String badgeId,
    required String name,
    required String description,
    required String icon,
  }) = _FlashcardBadgeUnlock;

  factory FlashcardBadgeUnlock.fromJson(Map<String, dynamic> json) =>
      _$FlashcardBadgeUnlockFromJson(json);
}
