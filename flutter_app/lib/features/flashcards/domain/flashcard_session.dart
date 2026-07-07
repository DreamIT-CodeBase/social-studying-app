import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:social_study_app/shared/models/flashcard.dart';

part 'flashcard_session.freezed.dart';

/// State machine for a single student's flashcard-review session.
///
/// One state union carries the entire lifecycle:
/// idle → loading → viewingFront → revealed → rating → rated →
/// loading (next) → … Failure branches (unavailable, error) also land
/// in this same union so `AsyncValue<FlashcardSession>` isn't needed —
/// the union covers loading/error states directly.
///
/// Why a single union and not several separate providers
/// ------------------------------------------------------
/// Same reasoning as `QuestionSession`: the screen needs ONE bound
/// state. The student looks at one card, in one phase, at a time.
/// Splitting "is the back revealed" from "the current card" from "the
/// submitted rating" into separate providers would force the UI to
/// coordinate multiple watch calls, and a stale "current card"
/// provider could survive past a transition. One union keeps the
/// screen branch logic flat and stale state impossible.
///
/// The flip is a *state transition*, not ephemeral widget state: the
/// rating buckets are only valid once the back has been revealed, and
/// the notifier enforces that ordering. A student can't rate a card
/// they haven't flipped.
@freezed
class FlashcardSession with _$FlashcardSession {
  /// Initial state — before any [FlashcardSessionNotifier.start] call.
  const factory FlashcardSession.idle() = FlashcardSessionIdle;

  /// Fetching a flashcard from the backend.
  const factory FlashcardSession.loading() = FlashcardSessionLoading;

  /// A card is shown front-side-up; the student is recalling the back
  /// in their head. The back exists on [card] but the UI keeps it
  /// hidden until the flip — see the class doc on why the back isn't
  /// withheld at the model layer.
  const factory FlashcardSession.viewingFront({
    required Flashcard card,
  }) = FlashcardSessionViewingFront;

  /// The student flipped the card; the back + explanation are visible
  /// and the three rating buckets (easy/medium/hard) are now active.
  const factory FlashcardSession.revealed({
    required Flashcard card,
  }) = FlashcardSessionRevealed;

  /// A self-rating was submitted; waiting for the backend to record it.
  const factory FlashcardSession.rating({
    required Flashcard card,
    required FlashcardRating rating,
  }) = FlashcardSessionRating;

  /// The rating was recorded. UI shows the stored rating and a
  /// "next card" CTA. [response] carries the server-confirmed
  /// timestamp.
  const factory FlashcardSession.rated({
    required Flashcard card,
    required FlashcardRatingResponse response,
  }) = FlashcardSessionRated;

  /// Card fetch failed in a way the student can't fix:
  /// - 409 NoFlashcardTopics: workspace has no taxonomy yet.
  /// - 503 FlashcardGenerationUnavailable: pipeline exhausted retries.
  ///
  /// [retryAfterSeconds] is the backend's hint (default 30 for 503,
  /// null for 409 since "no topics" can't be solved by retrying).
  /// [isNoTopics] lets the UI surface admin-targeted copy ("ask your
  /// teacher to upload material") instead of "try again".
  const factory FlashcardSession.unavailable({
    required String message,
    required bool isNoTopics,
    int? retryAfterSeconds,
  }) = FlashcardSessionUnavailable;

  /// Any other failure (transport, auth, 5xx-not-503, etc.). The
  /// message is the Dio interceptor's friendly text.
  const factory FlashcardSession.error({required String message}) =
      FlashcardSessionError;

  /// Review session of 25 cards successfully completed.
  /// Carries the counts of rated cards for summary UI.
  const factory FlashcardSession.completed({
    required int easyCount,
    required int mediumCount,
    required int hardCount,
  }) = FlashcardSessionCompleted;
}
