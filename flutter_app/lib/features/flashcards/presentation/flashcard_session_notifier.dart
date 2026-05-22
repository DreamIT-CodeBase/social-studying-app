import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart'
    show
        FlashcardGenerationUnavailableException,
        FlashcardNotFoundException,
        FlashcardNotRatableException,
        NoFlashcardTopicsException;
import 'package:social_study_app/features/flashcards/data/flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/domain/flashcard_session.dart';
import 'package:social_study_app/shared/models/flashcard.dart';

part 'flashcard_session_notifier.g.dart';

/// Owns the state machine for one flashcard-review session.
///
/// Methods correspond to user actions in the UI:
///
/// - [start] / [next]  — fetch the next card (→ loading → viewingFront)
/// - [flip]            — reveal the back (viewingFront → revealed)
/// - [rate]            — submit a self-rating (revealed → rating → rated)
///
/// All transitions are guarded — calling [rate] before [flip], or
/// [flip] before a card has loaded, is a no-op rather than an error,
/// so a stale UI tap can't corrupt the state. In particular [rate] is
/// only valid from `revealed`: a student cannot rate recall on a card
/// whose back they never saw.
///
/// Lifecycle: this is a family provider keyed by `workspaceId` so
/// switching workspaces yields a fresh session rather than carrying
/// state across boundaries.
@riverpod
class FlashcardSessionNotifier extends _$FlashcardSessionNotifier {
  late String _workspaceId;

  @override
  FlashcardSession build(String workspaceId) {
    _workspaceId = workspaceId;
    return const FlashcardSession.idle();
  }

  /// Initial fetch — only valid from the [FlashcardSession.idle] state.
  ///
  /// No-op from any other state so a screen that calls [start] in
  /// initState() and later calls [next] from a "next card" button
  /// doesn't accidentally double-fetch.
  Future<void> start() async {
    if (state is! FlashcardSessionIdle) return;
    await _fetchNext();
  }

  /// Fetch the next card after the student has rated the current one.
  ///
  /// Only valid from the [FlashcardSession.rated] state. From any other
  /// state this is a no-op so a misfiring "next" button can't blow
  /// away an in-flight rating.
  Future<void> next() async {
    if (state is! FlashcardSessionRated) return;
    await _fetchNext();
  }

  /// Reveal the back of the card.
  ///
  /// Only valid from [FlashcardSession.viewingFront]. From any other
  /// state — including [FlashcardSession.revealed] (already flipped) —
  /// this is a no-op, so a double-tap can't toggle the card back to
  /// front while the rating buckets are active.
  void flip() {
    final current = state;
    if (current is! FlashcardSessionViewingFront) return;
    state = FlashcardSession.revealed(card: current.card);
  }

  /// Submit the student's self-rating for the current card.
  ///
  /// Only valid from [FlashcardSession.revealed] — the student must
  /// have flipped the card before rating their recall. From any other
  /// state this is a no-op.
  Future<void> rate(FlashcardRating rating) async {
    final current = state;
    if (current is! FlashcardSessionRevealed) return;
    final card = current.card;

    state = FlashcardSession.rating(card: card, rating: rating);

    try {
      final repo = ref.read(flashcardsRepositoryProvider);
      final response = await repo.rate(
        workspaceId: _workspaceId,
        flashcardId: card.id,
        submission: FlashcardRatingSubmission(rating: rating),
      );
      state = FlashcardSession.rated(card: card, response: response);
    } on FlashcardNotFoundException catch (e) {
      // The card was deleted between fetch and rating — rare (admin
      // moderation), but the student should see a clear error rather
      // than a 500.
      state = FlashcardSession.error(message: e.message);
    } on FlashcardNotRatableException catch (e) {
      // The card moved to a non-approved state after the student
      // fetched it (admin flagged it mid-review). Same UX — surface
      // the message, let the student retry with `next()`.
      state = FlashcardSession.error(message: e.message);
    } on Object catch (e) {
      state = FlashcardSession.error(message: e.toString());
    }
  }

  // ── Internal: fetch + state transitions ─────────────────────────────────

  Future<void> _fetchNext() async {
    state = const FlashcardSession.loading();
    try {
      final repo = ref.read(flashcardsRepositoryProvider);
      final card = await repo.next(workspaceId: _workspaceId);
      state = FlashcardSession.viewingFront(card: card);
    } on NoFlashcardTopicsException catch (e) {
      state = FlashcardSession.unavailable(
        message: e.message,
        isNoTopics: true,
      );
    } on FlashcardGenerationUnavailableException catch (e) {
      state = FlashcardSession.unavailable(
        message: e.message,
        isNoTopics: false,
        retryAfterSeconds: e.retryAfterSeconds,
      );
    } on Object catch (e) {
      state = FlashcardSession.error(message: e.toString());
    }
  }
}
