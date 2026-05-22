import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart';
import 'package:social_study_app/shared/models/flashcard.dart';

void main() {
  group('DemoFlashcardsRepository.next', () {
    test('rotates through fixtures with unique ids per call', () async {
      final repo = DemoFlashcardsRepository();
      final ids = <String>[];
      for (var i = 0; i < 4; i++) {
        ids.add((await repo.next(workspaceId: 'wsp_a')).id);
      }
      // Four served cards → four distinct ids.
      expect(ids.toSet(), hasLength(4));
      // Ids carry the demo prefix + a 3-digit zero-padded counter.
      expect(ids.first, 'fc_demo_001');
      expect(ids.last, 'fc_demo_004');
    });

    test('rotation wraps after exhausting the fixture set', () async {
      final repo = DemoFlashcardsRepository();
      final topics = <String>[];
      // 5 calls over a 4-card fixture set — the 5th wraps to fixture 0.
      for (var i = 0; i < 5; i++) {
        topics.add((await repo.next(workspaceId: 'wsp_a')).topic);
      }
      expect(topics[0], topics[4]);
    });

    test('returns a fully-populated card (front + back + explanation)',
        () async {
      final repo = DemoFlashcardsRepository();
      final card = await repo.next(workspaceId: 'wsp_a');
      // Flashcards reveal everything — none of these may be blank.
      expect(card.front, isNotEmpty);
      expect(card.back, isNotEmpty);
      expect(card.explanation, isNotEmpty);
      expect(card.topic, isNotEmpty);
    });

    test('fixtures span distinct topics for UI variety', () async {
      final repo = DemoFlashcardsRepository();
      final topics = <String>{};
      for (var i = 0; i < 4; i++) {
        topics.add((await repo.next(workspaceId: 'wsp_a')).topic);
      }
      expect(topics, hasLength(4));
    });
  });

  group('DemoFlashcardsRepository.rate', () {
    test('records a rating for a previously-served card', () async {
      final repo = DemoFlashcardsRepository();
      final card = await repo.next(workspaceId: 'wsp_a');

      final response = await repo.rate(
        workspaceId: 'wsp_a',
        flashcardId: card.id,
        submission: const FlashcardRatingSubmission(
          rating: FlashcardRating.easy,
        ),
      );

      expect(response.flashcardId, card.id);
      expect(response.rating, FlashcardRating.easy);
      // ratedAt must be a parseable ISO 8601 UTC timestamp.
      final parsed = DateTime.parse(response.ratedAt);
      expect(parsed.isUtc, isTrue);
    });

    test('echoes back each rating bucket faithfully', () async {
      final repo = DemoFlashcardsRepository();
      for (final rating in FlashcardRating.values) {
        final card = await repo.next(workspaceId: 'wsp_a');
        final response = await repo.rate(
          workspaceId: 'wsp_a',
          flashcardId: card.id,
          submission: FlashcardRatingSubmission(rating: rating),
        );
        expect(response.rating, rating);
      }
    });

    test('throws FlashcardNotFoundException for an unknown id', () async {
      final repo = DemoFlashcardsRepository();
      expect(
        () => repo.rate(
          workspaceId: 'wsp_a',
          flashcardId: 'fc_never_served',
          submission: const FlashcardRatingSubmission(
            rating: FlashcardRating.hard,
          ),
        ),
        throwsA(isA<FlashcardNotFoundException>()),
      );
    });
  });
}
