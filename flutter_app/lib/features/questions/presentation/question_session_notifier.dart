import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart'
    show
        NoTopicsAvailableException,
        QuestionGenerationUnavailableException,
        QuestionNotAnswerableException,
        QuestionNotFoundException;
import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/features/questions/domain/question_session.dart';
import 'package:social_study_app/shared/models/question.dart';

part 'question_session_notifier.g.dart';

/// Owns the state machine for one question-answering session.
///
/// Methods correspond to user actions in the UI:
///
/// - [start] / [next]   — fetch the next question (idle → loading → ready)
/// - [setDraftAnswer]   — store the student's in-progress response
/// - [submit]           — send the answer (ready → submitting → feedback)
///
/// All transitions are guarded — calling [submit] when not in the
/// ``ready`` state is a no-op, not an error, so a stale UI tap can't
/// corrupt the state.
///
/// Lifecycle: this is a family provider keyed by `workspaceId` so
/// switching workspaces yields a fresh session rather than carrying
/// state across boundaries.
@riverpod
class QuestionSessionNotifier extends _$QuestionSessionNotifier {
  late String _workspaceId;

  @override
  QuestionSession build(String workspaceId) {
    _workspaceId = workspaceId;
    return const QuestionSession.idle();
  }

  /// Initial fetch — only valid from the [idle] state.
  ///
  /// No-op from any other state so a screen that calls [start] in
  /// initState() and later calls [next] from a "next question" button
  /// doesn't accidentally double-fetch.
  Future<void> start() async {
    if (state is! QuestionSessionIdle) return;
    await _fetchNext();
  }

  /// Fetch the next question after the student has seen feedback.
  ///
  /// Only valid from [feedback] state. From any other state this is
  /// a no-op so a misfiring "next" button can't blow away an
  /// in-flight submit.
  Future<void> next() async {
    if (state is! QuestionSessionFeedback) return;
    await _fetchNext();
  }

  /// Store the student's in-progress response.
  ///
  /// Only valid from [ready] state (the question is shown and the
  /// student is composing). From any other state — including
  /// [submitting] (the answer is already locked in) and [feedback]
  /// (the question is graded) — this is a no-op.
  void setDraftAnswer(String draft) {
    final current = state;
    if (current is! QuestionSessionReady) return;
    state = QuestionSession.ready(
      question: current.question,
      draftAnswer: draft,
    );
  }

  /// Submit the draft answer for grading.
  ///
  /// Only valid from [ready] with a non-empty [draftAnswer]. The
  /// emptiness check prevents the backend from rejecting with 422 on
  /// a UI bug; the UI's submit button should be disabled when the
  /// draft is empty, but defence-in-depth here is free.
  Future<void> submit() async {
    final current = state;
    if (current is! QuestionSessionReady) return;
    final draft = current.draftAnswer?.trim();
    if (draft == null || draft.isEmpty) return;

    state = QuestionSession.submitting(
      question: current.question,
      draftAnswer: draft,
    );

    try {
      final repo = ref.read(questionsRepositoryProvider);
      final feedback = await repo.submitAnswer(
        workspaceId: _workspaceId,
        questionId: current.question.id,
        submission: AnswerSubmission(answer: draft),
      );
      state = QuestionSession.feedback(
        question: current.question,
        submittedAnswer: draft,
        feedback: feedback,
      );
    } on QuestionNotFoundException catch (e) {
      // The question was deleted between fetch and submit — rare
      // (admin moderation), but the student should see a clear
      // error rather than a 500.
      state = QuestionSession.error(message: e.message);
    } on QuestionNotAnswerableException catch (e) {
      // The question moved to pending_review / rejected after the
      // student fetched it (admin flagged mid-attempt). Same UX —
      // surface the message, let the student retry with `next()`.
      state = QuestionSession.error(message: e.message);
    } on Object catch (e) {
      state = QuestionSession.error(message: e.toString());
    }
  }

  // ── Internal: fetch + state transitions ─────────────────────────────────

  Future<void> _fetchNext() async {
    state = const QuestionSession.loading();
    try {
      final repo = ref.read(questionsRepositoryProvider);
      final question = await repo.next(workspaceId: _workspaceId);
      state = QuestionSession.ready(question: question);
    } on NoTopicsAvailableException catch (e) {
      state = QuestionSession.unavailable(
        message: e.message,
        isNoTopics: true,
      );
    } on QuestionGenerationUnavailableException catch (e) {
      state = QuestionSession.unavailable(
        message: e.message,
        isNoTopics: false,
        retryAfterSeconds: e.retryAfterSeconds,
      );
    } on Object catch (e) {
      state = QuestionSession.error(message: e.toString());
    }
  }
}
