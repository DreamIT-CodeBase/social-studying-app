import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/models/question.dart';

part 'revision_session.freezed.dart';

/// Position in a bounded revision session. [position] is 1-based — what
/// the UI shows as "3 of 10".
@freezed
class RevisionProgress with _$RevisionProgress {
  const factory RevisionProgress({
    required int position,
    required int total,
  }) = _RevisionProgress;
}

/// Tallies for the summary at the end of a revision session.
@freezed
class RevisionSummary with _$RevisionSummary {
  const factory RevisionSummary({
    required int total,
    required int questionsAnswered,
    required int questionsCorrect,
    required int flashcardsReviewed,
  }) = _RevisionSummary;
}

/// State machine for a single student's revision session — a fixed
/// mix of question and flashcard items run end-to-end.
///
/// One state union carries the lifecycle:
/// idle → loading → question/flashcardFront → … → complete.
/// Failure branches (unavailable, error) live in the same union so the
/// screen can render every state with a flat switch.
///
/// Why a single union and not several separate providers
/// ------------------------------------------------------
/// Same reasoning as `QuestionSession` / `FlashcardSession`. The screen
/// is looking at one item, in one phase, at a time; stale "current
/// item" state should be impossible.
///
/// Why not reuse the existing infinite-loop session notifiers
/// ----------------------------------------------------------
/// Two reasons. Entering revision must not disturb the Study or
/// Flashcards tabs (those notifiers are family-keyed by workspaceId
/// only, so a shared instance would clobber them). And revision needs
/// bounded semantics — a plan length, progress, and a summary at the
/// end — that the infinite notifiers deliberately don't model.
@freezed
class RevisionSession with _$RevisionSession {
  /// Before [RevisionSessionNotifier.start] has been called.
  const factory RevisionSession.idle() = RevisionSessionIdle;

  /// Fetching the item at [progress.position].
  const factory RevisionSession.loading({
    required RevisionProgress progress,
  }) = RevisionSessionLoading;

  /// A question item is ready; the student is composing their answer.
  const factory RevisionSession.question({
    required Question question,
    String? draftAnswer,
    required RevisionProgress progress,
  }) = RevisionSessionQuestion;

  /// Answer submitted; waiting for the backend's feedback.
  const factory RevisionSession.questionSubmitting({
    required Question question,
    required String draftAnswer,
    required RevisionProgress progress,
  }) = RevisionSessionQuestionSubmitting;

  /// Feedback received — show correctness + explanation, then advance.
  const factory RevisionSession.questionGraded({
    required Question question,
    required String submittedAnswer,
    required AnswerFeedback feedback,
    required RevisionProgress progress,
  }) = RevisionSessionQuestionGraded;

  /// A flashcard item is shown front-side-up; the student recalls
  /// the back before flipping.
  const factory RevisionSession.flashcardFront({
    required Flashcard card,
    required RevisionProgress progress,
  }) = RevisionSessionFlashcardFront;

  /// The flashcard has been flipped; the student picks a rating.
  const factory RevisionSession.flashcardBack({
    required Flashcard card,
    required RevisionProgress progress,
  }) = RevisionSessionFlashcardBack;

  /// A self-rating was submitted; waiting for the backend to record it.
  const factory RevisionSession.flashcardRating({
    required Flashcard card,
    required FlashcardRating rating,
    required RevisionProgress progress,
  }) = RevisionSessionFlashcardRating;

  /// Rating recorded — show the recorded rating, then advance.
  const factory RevisionSession.flashcardRated({
    required Flashcard card,
    required FlashcardRating rating,
    required RevisionProgress progress,
  }) = RevisionSessionFlashcardRated;

  /// The plan is exhausted. UI shows the summary screen.
  const factory RevisionSession.complete({
    required RevisionSummary summary,
  }) = RevisionSessionComplete;

  /// The fetch for the current item failed in a way the student can't
  /// fix — no topics (409) or generator exhausted retries (503).
  /// [isNoTopics] drives the admin-targeted copy.
  const factory RevisionSession.unavailable({
    required String message,
    required bool isNoTopics,
  }) = RevisionSessionUnavailable;

  /// Any other failure (transport, auth, unexpected 5xx). The message
  /// is the Dio interceptor's friendly text.
  const factory RevisionSession.error({required String message}) =
      RevisionSessionError;
}
