import 'dart:math' as math;
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
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/features/gamification/data/gamification_repository.dart';
import 'package:social_study_app/features/progress/services/recall_service.dart';

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
  List<String>? _selectedTopicIds;
  final List<FlashcardRating> _sessionRatings = [];
  int _currentIndex = 1;
  int _sessionTargetLength = 4;
  double? _lastMastery;
  DateTime? _cardStartTime;

  int get currentIndex => _currentIndex;
  int get sessionTargetLength => _sessionTargetLength;
  List<String>? get selectedTopicIds => _selectedTopicIds;
  List<FlashcardRating> get sessionRatings => List.unmodifiable(_sessionRatings);

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
  Future<void> start({double? mastery}) async {
    if (state is! FlashcardSessionIdle) return;
    _lastMastery = mastery;
    _sessionTargetLength = _sessionLengthForMastery(mastery);
    _currentIndex = 1;
    _sessionRatings.clear();
    await _fetchNext();
  }

  /// Returns how many flashcards to show this session based on mastery level.
  ///
  /// Tiers (from product spec):
  /// - BEGINNER  mastery < 0.40  → 3–4 cards
  /// - INTER     mastery < 0.75  → 10–13 cards
  /// - EXPERT    mastery ≥ 0.75  → 18–25 cards
  static int _sessionLengthForMastery(double? mastery) {
    final rng = math.Random();
    if (mastery == null || mastery < 0.40) {
      return 3 + rng.nextInt(2); // 3 or 4
    } else if (mastery < 0.75) {
      return 10 + rng.nextInt(4); // 10, 11, 12, or 13
    } else {
      return 18 + rng.nextInt(8); // 18–25
    }
  }

  /// Returns the human-readable mastery tier label for the current session.
  String get masteryTierLabel {
    if (_lastMastery == null || _lastMastery! < 0.40) return 'Beginner';
    if (_lastMastery! < 0.75) return 'Intermediate';
    return 'Expert';
  }

  /// Fetch the next card after the student has rated the current one.
  ///
  /// Only valid from the [FlashcardSession.rated] state. From any other
  /// state this is a no-op so a misfiring "next" button can't blow
  /// away an in-flight rating.
  Future<void> next() async {
    if (state is! FlashcardSessionRated) return;
    if (_currentIndex < _sessionTargetLength) {
      _currentIndex++;
      await _fetchNext();
    } else {
      _transitionToCompleted();
    }
  }

  void _transitionToCompleted() {
    int easy = 0;
    int medium = 0;
    int hard = 0;
    for (final r in _sessionRatings) {
      if (r == FlashcardRating.easy) easy++;
      if (r == FlashcardRating.medium) medium++;
      if (r == FlashcardRating.hard) hard++;
    }

    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user != null) {
      ref.read(gamificationRepositoryProvider).completeSession(
            workspaceId: _workspaceId,
            userId: user.id,
            sessionType: 'flashcard',
          ).then((_) {
            _invalidateProfile();
          }).catchError((_) {});
    }

    state = FlashcardSession.completed(
      easyCount: easy,
      mediumCount: medium,
      hardCount: hard,
    );
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
  Future<void> rate(
    FlashcardRating rating, {
    String? selectedOption,
    bool? isCorrect,
    int? responseTimeMs,
    int? sessionProgress,
    double? accuracyPercentage,
  }) async {
    final current = state;
    if (current is! FlashcardSessionRevealed) return;
    final card = current.card;

    state = FlashcardSession.rating(card: card, rating: rating);

    try {
      final repo = ref.read(flashcardsRepositoryProvider);
      final response = await repo.rate(
        workspaceId: _workspaceId,
        flashcardId: card.id,
        submission: FlashcardRatingSubmission(
          rating: rating,
          selectedOption: selectedOption,
          isCorrect: isCorrect,
          responseTimeMs: responseTimeMs,
          sessionProgress: sessionProgress,
          accuracyPercentage: accuracyPercentage,
        ),
      );
      _sessionRatings.add(rating);
      if (_cardStartTime != null) {
        final durationMs = DateTime.now().difference(_cardStartTime!).inMilliseconds;
        RecallService.instance.recordCardReview(
          topic: card.topic,
          rating: rating,
          durationMs: durationMs,
        ).catchError((_) {});
      }
      state = FlashcardSession.rated(card: card, response: response);
      _invalidateProfile();
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

  Future<void> updateFilters(List<String>? topicIds) async {
    _selectedTopicIds = topicIds;
    state = const FlashcardSession.idle();
    await start();
  }

  Future<void> resetSession() async {
    // Re-read the latest mastery so a long session doesn't lock the tier.
    final progressVal =
        ref.read(studentProgressNotifierProvider(_workspaceId)).valueOrNull;
    state = const FlashcardSession.idle();
    await start(mastery: progressVal?.overallMastery);
  }

  void _invalidateProfile() {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user != null) {
      final key = (workspaceId: _workspaceId, userId: user.id);
      ref.invalidate(gamificationProfileProvider(key));
      ref.invalidate(streakSummaryProvider(key));
      ref.invalidate(studentProgressNotifierProvider(_workspaceId));
      ref.invalidate(leaderboardProvider(_workspaceId));
    }
  }

  // ── Internal: fetch + state transitions ─────────────────────────────────

  Future<void> _fetchNext() async {
    state = const FlashcardSession.loading();
    try {
      final repo = ref.read(flashcardsRepositoryProvider);
      final card = await repo.next(
        workspaceId: _workspaceId,
        selectedTopicIds: _selectedTopicIds,
        mastery: _lastMastery,
      );
      state = FlashcardSession.viewingFront(card: card);
      _cardStartTime = DateTime.now();
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
