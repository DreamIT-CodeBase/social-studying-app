import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:social_study_app/shared/models/question.dart';

part 'question_session.freezed.dart';

/// State machine for a single student's question-answering session.
///
/// One state union carries the entire lifecycle: idle → loading →
/// ready → submitting → feedback → loading (next) → … Failure
/// branches (unavailable, error) also land in this same union so
/// `AsyncValue<QuestionSession>` isn't needed — the union covers
/// loading/error states directly.
///
/// Why a single union and not three or four separate providers
/// -----------------------------------------------------------
/// The screen needs ONE bound state — the user can only be looking
/// at one question, in one state, at a time. Splitting "loading"
/// from "current question" from "feedback" into separate providers
/// would force the UI to coordinate three watch calls, and a stale
/// "current question" provider would survive past the feedback
/// transition. One union keeps the screen branch logic flat and
/// keeps stale state impossible.
@freezed
class QuestionSession with _$QuestionSession {
  /// Initial state — before any [QuestionSessionNotifier.start] call.
  const factory QuestionSession.idle() = QuestionSessionIdle;

  /// Fetching a question from the backend.
  ///
  /// Distinguished from [submitting] because the UI affordances are
  /// different: a centered spinner vs. a disabled-submit button.
  const factory QuestionSession.loading() = QuestionSessionLoading;

  /// A question is ready; the student is composing their answer.
  ///
  /// [draftAnswer] is the student's in-progress response. For MCQ
  /// it's the option key ("A"/"B"/...); for short_answer / long_answer /
  /// mathematical it's the in-progress text; for true_false it's
  /// "true" / "false". `null` = nothing entered yet.
  const factory QuestionSession.ready({
    required Question question,
    String? draftAnswer,
  }) = QuestionSessionReady;

  /// Answer submitted; waiting for the backend's feedback response.
  const factory QuestionSession.submitting({
    required Question question,
    required String draftAnswer,
  }) = QuestionSessionSubmitting;

  /// Feedback received — show correctness, explanation, XP, mastery
  /// delta. UI displays this until the student taps "next question".
  const factory QuestionSession.feedback({
    required Question question,
    required String submittedAnswer,
    required AnswerFeedback feedback,
  }) = QuestionSessionFeedback;

  /// Question fetch failed in a way the student can't fix:
  /// - 409 NoTopicsAvailable: workspace has no taxonomy yet.
  /// - 503 QuestionGenerationUnavailable: pipeline exhausted retries.
  ///
  /// [retryAfterSeconds] is the backend's hint (default 30 for 503,
  /// null for 409 since "no topics" can't be solved by retrying).
  /// [isNoTopics] lets the UI surface admin-targeted copy ("ask
  /// your teacher to upload material") instead of "try again".
  const factory QuestionSession.unavailable({
    required String message,
    required bool isNoTopics,
    int? retryAfterSeconds,
  }) = QuestionSessionUnavailable;

  /// Any other failure (transport, auth, 5xx-not-503, etc.). The
  /// message is the Dio interceptor's friendly text.
  const factory QuestionSession.error({required String message}) =
      QuestionSessionError;

  /// Study session completed.
  const factory QuestionSession.completed({
    required int correctCount,
    required int totalCount,
  }) = QuestionSessionCompleted;
}
