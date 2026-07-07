import 'dart:math' as math;
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
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/features/gamification/data/gamification_repository.dart';
import 'package:social_study_app/features/progress/services/recall_service.dart';

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
  int _questionsAnswered = 0;
  int _questionsCorrect = 0;
  int _sessionTargetLength = 5;
  DateTime? _questionStartTime;

  int get questionsAnswered => _questionsAnswered;
  int get questionsCorrect => _questionsCorrect;
  int get sessionTargetLength => _sessionTargetLength;

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
  Future<void> start({double? mastery}) async {
    if (state is! QuestionSessionIdle) return;
    
    _sessionTargetLength = 20;

    _questionsAnswered = 0;
    _questionsCorrect = 0;
    await _fetchNext();
  }

  /// Fetch the next question after the student has seen feedback.
  ///
  /// Only valid from [feedback] state. From any other state this is
  /// a no-op so a misfiring "next" button can't blow away an
  /// in-flight submit.
  Future<void> next() async {
    if (state is! QuestionSessionFeedback) return;
    if (_questionsAnswered >= _sessionTargetLength) {
      _transitionToCompleted();
    } else {
      await _fetchNext();
    }
  }

  void _transitionToCompleted() {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user != null) {
      ref.read(gamificationRepositoryProvider).completeSession(
            workspaceId: _workspaceId,
            userId: user.id,
            sessionType: 'study',
          ).then((_) {
            _invalidateProfile();
          }).catchError((_) {});
    }
    state = QuestionSession.completed(
      correctCount: _questionsCorrect,
      totalCount: _sessionTargetLength,
    );
  }

  /// End the current study session, returning to the idle state.
  ///
  /// Valid from [ready] or [feedback]. Not valid from [loading] or
  /// [submitting] — those are transient states with in-flight work
  /// that should complete before the user can exit.
  void endSession() {
    if (state is QuestionSessionReady ||
        state is QuestionSessionFeedback ||
        state is QuestionSessionError ||
        state is QuestionSessionUnavailable ||
        state is QuestionSessionCompleted) {
      if (_questionsAnswered > 0 && state is! QuestionSessionCompleted) {
        final authState = ref.read(authNotifierProvider).valueOrNull;
        final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
        if (user != null) {
          ref.read(gamificationRepositoryProvider).completeSession(
                workspaceId: _workspaceId,
                userId: user.id,
                sessionType: 'study',
              ).then((_) {
                _invalidateProfile();
              }).catchError((_) {});
        }
      }
      state = const QuestionSession.idle();
    }
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
      _questionsAnswered++;
      if (_questionStartTime != null) {
        final durationMs = DateTime.now().difference(_questionStartTime!).inMilliseconds;
        RecallService.instance.recordQuestionAnswered(
          topic: current.question.topic,
          durationMs: durationMs,
        ).catchError((_) {});
      }
      if (feedback.isCorrect) {
        _questionsCorrect++;
      }
      state = QuestionSession.feedback(
        question: current.question,
        submittedAnswer: draft,
        feedback: feedback,
      );
      _invalidateProfile();
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

  void _invalidateProfile() {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user != null) {
      final key = (workspaceId: _workspaceId, userId: user.id);
      ref.invalidate(gamificationProfileProvider(key));
      ref.invalidate(streakSummaryProvider(key));
      ref.invalidate(studentProgressNotifierProvider(_workspaceId));
    }
  }

  // ── Internal: fetch + state transitions ─────────────────────────────────

  Future<void> _fetchNext() async {
    state = const QuestionSession.loading();
    try {
      final repo = ref.read(questionsRepositoryProvider);
      final question = await repo.next(workspaceId: _workspaceId);
      state = QuestionSession.ready(question: question);
      _questionStartTime = DateTime.now();
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
