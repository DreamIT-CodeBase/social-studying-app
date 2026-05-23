import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart'
    show
        FlashcardGenerationUnavailableException,
        FlashcardNotFoundException,
        FlashcardNotRatableException,
        NoFlashcardTopicsException;
import 'package:social_study_app/features/flashcards/data/flashcards_repository.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart'
    show
        NoTopicsAvailableException,
        QuestionGenerationUnavailableException,
        QuestionNotAnswerableException,
        QuestionNotFoundException;
import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/features/revision/domain/revision_session.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/models/question.dart';

part 'revision_session_notifier.g.dart';

/// Item kinds that appear in a revision plan.
enum RevisionItemKind { question, flashcard }

/// Owns the state machine for a bounded revision session.
///
/// The plan is built at [start] and alternates question / flashcard
/// items, starting with a question. After each item is answered or
/// rated, [advance] either fetches the next item or transitions to the
/// `complete` state with a summary when the plan is exhausted.
///
/// All transitions are guarded — calling [submitAnswer] from a
/// flashcard state, or [rate] from a question state, is a no-op rather
/// than an error, so a stale UI tap can't corrupt the state.
///
/// Lifecycle: this is a family provider keyed by `workspaceId`, with
/// its own `keepAlive: false` (the default) so leaving the revision
/// screen disposes the session and a fresh launch starts a new plan.
@riverpod
class RevisionSessionNotifier extends _$RevisionSessionNotifier {
  /// Default plan length used by [start] when no count is supplied.
  static const int defaultItemCount = 10;

  late String _workspaceId;
  late List<RevisionItemKind> _plan;
  int _position = 0; // 0-based index into _plan
  int _questionsAnswered = 0;
  int _questionsCorrect = 0;
  int _flashcardsReviewed = 0;

  @override
  RevisionSession build(String workspaceId) {
    _workspaceId = workspaceId;
    return const RevisionSession.idle();
  }

  /// Begin a revision session of [itemCount] items.
  ///
  /// Builds the alternating plan (question, flashcard, question, …) and
  /// fetches the first item. No-op unless the notifier is idle, so an
  /// initState-driven call followed by a button-triggered call can't
  /// double-fetch.
  Future<void> start({int itemCount = defaultItemCount}) async {
    if (state is! RevisionSessionIdle) return;
    final n = itemCount.clamp(1, 50);
    _plan = List<RevisionItemKind>.generate(
      n,
      (i) =>
          i.isEven ? RevisionItemKind.question : RevisionItemKind.flashcard,
    );
    _position = 0;
    _questionsAnswered = 0;
    _questionsCorrect = 0;
    _flashcardsReviewed = 0;
    await _fetchCurrent();
  }

  /// Store the student's in-progress answer for the current question.
  /// Only valid from [RevisionSessionQuestion].
  void setDraftAnswer(String draft) {
    final current = state;
    if (current is! RevisionSessionQuestion) return;
    state = RevisionSession.question(
      question: current.question,
      draftAnswer: draft,
      progress: current.progress,
    );
  }

  /// Submit the current question's draft answer for grading.
  /// Only valid from [RevisionSessionQuestion] with a non-empty draft.
  Future<void> submitAnswer() async {
    final current = state;
    if (current is! RevisionSessionQuestion) return;
    final draft = current.draftAnswer?.trim();
    if (draft == null || draft.isEmpty) return;

    state = RevisionSession.questionSubmitting(
      question: current.question,
      draftAnswer: draft,
      progress: current.progress,
    );

    try {
      final feedback =
          await ref.read(questionsRepositoryProvider).submitAnswer(
                workspaceId: _workspaceId,
                questionId: current.question.id,
                submission: AnswerSubmission(answer: draft),
              );
      _questionsAnswered++;
      if (feedback.isCorrect) _questionsCorrect++;
      state = RevisionSession.questionGraded(
        question: current.question,
        submittedAnswer: draft,
        feedback: feedback,
        progress: current.progress,
      );
    } on QuestionNotFoundException catch (e) {
      state = RevisionSession.error(message: e.message);
    } on QuestionNotAnswerableException catch (e) {
      state = RevisionSession.error(message: e.message);
    } on Object catch (e) {
      state = RevisionSession.error(message: e.toString());
    }
  }

  /// Flip the current flashcard.
  /// Only valid from [RevisionSessionFlashcardFront].
  void flip() {
    final current = state;
    if (current is! RevisionSessionFlashcardFront) return;
    state = RevisionSession.flashcardBack(
      card: current.card,
      progress: current.progress,
    );
  }

  /// Submit a self-rating for the current flashcard.
  /// Only valid from [RevisionSessionFlashcardBack].
  Future<void> rate(FlashcardRating rating) async {
    final current = state;
    if (current is! RevisionSessionFlashcardBack) return;

    state = RevisionSession.flashcardRating(
      card: current.card,
      rating: rating,
      progress: current.progress,
    );

    try {
      await ref.read(flashcardsRepositoryProvider).rate(
            workspaceId: _workspaceId,
            flashcardId: current.card.id,
            submission: FlashcardRatingSubmission(rating: rating),
          );
      _flashcardsReviewed++;
      state = RevisionSession.flashcardRated(
        card: current.card,
        rating: rating,
        progress: current.progress,
      );
    } on FlashcardNotFoundException catch (e) {
      state = RevisionSession.error(message: e.message);
    } on FlashcardNotRatableException catch (e) {
      state = RevisionSession.error(message: e.message);
    } on Object catch (e) {
      state = RevisionSession.error(message: e.toString());
    }
  }

  /// Move to the next item in the plan, or transition to `complete` if
  /// the plan is exhausted. Only valid from a graded or rated state.
  Future<void> advance() async {
    final current = state;
    if (current is! RevisionSessionQuestionGraded &&
        current is! RevisionSessionFlashcardRated) {
      return;
    }
    _position++;
    if (_position >= _plan.length) {
      state = RevisionSession.complete(
        summary: RevisionSummary(
          total: _plan.length,
          questionsAnswered: _questionsAnswered,
          questionsCorrect: _questionsCorrect,
          flashcardsReviewed: _flashcardsReviewed,
        ),
      );
      return;
    }
    await _fetchCurrent();
  }

  // ── Internal: fetch the item at the current position ────────────────────

  Future<void> _fetchCurrent() async {
    final progress = RevisionProgress(
      position: _position + 1,
      total: _plan.length,
    );
    state = RevisionSession.loading(progress: progress);
    try {
      switch (_plan[_position]) {
        case RevisionItemKind.question:
          final question = await ref
              .read(questionsRepositoryProvider)
              .next(workspaceId: _workspaceId);
          state = RevisionSession.question(
            question: question,
            progress: progress,
          );
        case RevisionItemKind.flashcard:
          final card = await ref
              .read(flashcardsRepositoryProvider)
              .next(workspaceId: _workspaceId);
          state = RevisionSession.flashcardFront(
            card: card,
            progress: progress,
          );
      }
    } on NoTopicsAvailableException catch (e) {
      state = RevisionSession.unavailable(
        message: e.message,
        isNoTopics: true,
      );
    } on NoFlashcardTopicsException catch (e) {
      state = RevisionSession.unavailable(
        message: e.message,
        isNoTopics: true,
      );
    } on QuestionGenerationUnavailableException catch (e) {
      state = RevisionSession.unavailable(
        message: e.message,
        isNoTopics: false,
      );
    } on FlashcardGenerationUnavailableException catch (e) {
      state = RevisionSession.unavailable(
        message: e.message,
        isNoTopics: false,
      );
    } on Object catch (e) {
      state = RevisionSession.error(message: e.toString());
    }
  }
}
