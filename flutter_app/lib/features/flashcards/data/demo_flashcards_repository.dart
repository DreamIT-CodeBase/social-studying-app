import 'dart:async';

import 'package:social_study_app/features/flashcards/data/flashcards_repository.dart';
import 'package:social_study_app/shared/models/flashcard.dart';

/// Typed exceptions the UI layer branches on. Mirror the HTTP status
/// codes the real repository surfaces from the backend (Sprint 3.12).

/// 409 from `POST /flashcards/next` — the workspace has no canonical
/// topics yet. Not retryable; the UI should tell the student to ask an
/// admin to upload study material.
class NoFlashcardTopicsException implements Exception {
  const NoFlashcardTopicsException([this.message = 'No topics available']);
  final String message;
  @override
  String toString() => 'NoFlashcardTopicsException: $message';
}

/// 503 from `POST /flashcards/next` — the generation pipeline exhausted
/// its retry budget. Retryable after [retryAfterSeconds].
class FlashcardGenerationUnavailableException implements Exception {
  const FlashcardGenerationUnavailableException({
    this.message = 'Couldn\'t generate a flashcard right now',
    this.retryAfterSeconds = 30,
  });
  final String message;
  final int retryAfterSeconds;
  @override
  String toString() =>
      'FlashcardGenerationUnavailableException(retryAfter=${retryAfterSeconds}s): $message';
}

/// 404 from `POST /flashcards/{id}/rate` — the flashcard was deleted
/// between fetch and rating.
class FlashcardNotFoundException implements Exception {
  const FlashcardNotFoundException([this.message = 'Flashcard not found']);
  final String message;
  @override
  String toString() => 'FlashcardNotFoundException: $message';
}

/// 409 from `POST /flashcards/{id}/rate` — the flashcard moved to a
/// non-approved state (admin flagged it mid-review).
class FlashcardNotRatableException implements Exception {
  const FlashcardNotRatableException([
    this.message = 'Flashcard is not in a ratable state',
  ]);
  final String message;
  @override
  String toString() => 'FlashcardNotRatableException: $message';
}

/// Offline, deterministic implementation of the flashcard loop.
///
/// Backs the demo user so an offline dev can exercise the full
/// flip + self-rate interaction without a live backend.
///
/// Behaviour:
/// - Rotates through a small fixture set on every [next] call (4 cards
///   across distinct topics so the UI has variety to render).
/// - [rate] validates the flashcard id against the set of served cards
///   and returns a synthetic [FlashcardRatingResponse] with a real
///   timestamp.
/// - State is in-process; restarting the app resets the rotation
///   index. That's a feature, not a bug — the demo flow is meant to
///   be reproducible.
class DemoFlashcardsRepository implements FlashcardsRepository {
  DemoFlashcardsRepository();

  // Rotation index across calls — bumped by `next`, used to pick the
  // next fixture deterministically.
  int _index = 0;

  // Ids served so far. `rate` checks membership so an unknown id
  // surfaces a FlashcardNotFoundException, matching the real backend.
  final Set<String> _served = {};

  @override
  Future<Flashcard> next({
    required String workspaceId,
    List<String>? selectedTopicIds,
    double? mastery,
    String? subject,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final fixture = _fixtures[_index % _fixtures.length];
    _index++;
    final id = 'fc_demo_${_index.toString().padLeft(3, '0')}';
    _served.add(id);
    return fixture.copyWith(id: id);
  }

  @override
  Future<FlashcardRatingResponse> rate({
    required String workspaceId,
    required String flashcardId,
    required FlashcardRatingSubmission submission,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!_served.contains(flashcardId)) {
      throw const FlashcardNotFoundException();
    }
    return FlashcardRatingResponse(
      flashcardId: flashcardId,
      rating: submission.rating,
      ratedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  // ── Fixtures ─────────────────────────────────────────────────────────────

  static const List<Flashcard> _fixtures = [
    Flashcard(
      id: 'placeholder',
      topic: 'Photosynthesis',
      front: 'What pigment captures light energy during photosynthesis?',
      back: 'Chlorophyll.',
      explanation:
          'Chlorophyll, housed in chloroplasts, absorbs red and blue '
          'light and reflects green — which is why leaves look green.',
    ),
    Flashcard(
      id: 'placeholder',
      topic: 'Cell Biology',
      front: 'Which organelle is the "powerhouse of the cell"?',
      back: 'The mitochondrion.',
      explanation:
          'Mitochondria produce ATP through cellular respiration, '
          'supplying most of the cell\'s usable energy.',
    ),
    Flashcard(
      id: 'placeholder',
      topic: 'Cellular Respiration',
      front: 'What are the three stages of cellular respiration?',
      back: 'Glycolysis, the Krebs cycle, and the electron transport chain.',
      explanation:
          'Glycolysis splits glucose in the cytoplasm; the Krebs cycle '
          'and electron transport chain run in the mitochondria.',
    ),
    Flashcard(
      id: 'placeholder',
      topic: 'Genetics',
      front: 'What does an organism\'s genotype describe?',
      back: 'Its complete set of genes — the inherited genetic code.',
      explanation:
          'Genotype is the genetic makeup; phenotype is how those genes '
          'are expressed as observable traits.',
    ),
  ];
}
