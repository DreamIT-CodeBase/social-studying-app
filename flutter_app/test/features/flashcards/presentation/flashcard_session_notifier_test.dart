import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/data/flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/domain/flashcard_session.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_session_notifier.dart';
import 'package:social_study_app/shared/models/flashcard.dart';

class _MockRepo extends Mock implements FlashcardsRepository {}

class _FakeSubmission extends Fake implements FlashcardRatingSubmission {}

Flashcard _card({String id = 'fc_a'}) => Flashcard(
      id: id,
      topic: 'Photosynthesis',
      front: 'What pigment captures light?',
      back: 'Chlorophyll.',
      explanation: 'It absorbs red and blue light.',
    );

FlashcardRatingResponse _response({
  String id = 'fc_a',
  FlashcardRating rating = FlashcardRating.easy,
}) =>
    FlashcardRatingResponse(
      flashcardId: id,
      rating: rating,
      ratedAt: '2026-05-22T10:00:00+00:00',
    );

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_FakeSubmission());
  });

  setUp(() {
    repo = _MockRepo();
    container = ProviderContainer(
      overrides: [
        flashcardsRepositoryProvider.overrideWith((_) => repo),
      ],
    );
  });

  tearDown(() => container.dispose());

  FlashcardSession read() =>
      container.read(flashcardSessionNotifierProvider('wsp_a'));
  FlashcardSessionNotifier notifier() =>
      container.read(flashcardSessionNotifierProvider('wsp_a').notifier);

  group('build', () {
    test('initial state is idle', () {
      expect(read(), isA<FlashcardSessionIdle>());
    });
  });

  group('start', () {
    test('idle → loading → viewingFront on successful fetch', () async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card());

      final future = notifier().start();
      // Mid-fetch the state should be loading.
      expect(read(), isA<FlashcardSessionLoading>());
      await future;

      final terminal = read();
      expect(terminal, isA<FlashcardSessionViewingFront>());
      expect((terminal as FlashcardSessionViewingFront).card.id, 'fc_a');
    });

    test('NoFlashcardTopics → unavailable with isNoTopics=true', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenThrow(
        const NoFlashcardTopicsException('empty workspace'),
      );

      await notifier().start();

      final state = read();
      expect(state, isA<FlashcardSessionUnavailable>());
      final unavailable = state as FlashcardSessionUnavailable;
      expect(unavailable.isNoTopics, isTrue);
      expect(unavailable.message, contains('empty workspace'));
      // No retry-after on 409 — "no topics" can't be solved by retrying.
      expect(unavailable.retryAfterSeconds, isNull);
    });

    test(
        'FlashcardGenerationUnavailable → unavailable, isNoTopics=false + retry',
        () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenThrow(
        const FlashcardGenerationUnavailableException(
          message: 'all attempts failed',
          retryAfterSeconds: 45,
        ),
      );

      await notifier().start();

      final state = read() as FlashcardSessionUnavailable;
      expect(state.isNoTopics, isFalse);
      expect(state.retryAfterSeconds, 45);
    });

    test('any other exception → error state', () async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenThrow(Exception('network down'));

      await notifier().start();

      final state = read();
      expect(state, isA<FlashcardSessionError>());
      expect((state as FlashcardSessionError).message, contains('network down'));
    });

    test('start is a no-op when already past idle', () async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card());

      final n = notifier();
      await n.start();
      // Second start() — state is viewingFront, not idle. No re-fetch.
      await n.start();
      verify(() => repo.next(workspaceId: 'wsp_a')).called(1);
    });
  });

  group('flip', () {
    test('viewingFront → revealed', () async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card());
      final n = notifier();
      await n.start();

      n.flip();

      final state = read();
      expect(state, isA<FlashcardSessionRevealed>());
      expect((state as FlashcardSessionRevealed).card.id, 'fc_a');
    });

    test('is a no-op when not in viewingFront state', () {
      // State is still idle.
      notifier().flip();
      expect(read(), isA<FlashcardSessionIdle>());
    });

    test('double flip is a no-op — stays revealed', () async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card());
      final n = notifier();
      await n.start();

      n.flip();
      n.flip();

      expect(read(), isA<FlashcardSessionRevealed>());
    });
  });

  group('rate', () {
    Future<FlashcardSessionNotifier> reachRevealed() async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card());
      final n = notifier();
      await n.start();
      n.flip();
      return n;
    }

    test('revealed → rating → rated on successful submission', () async {
      final n = await reachRevealed();
      when(
        () => repo.rate(
          workspaceId: 'wsp_a',
          flashcardId: 'fc_a',
          submission: any(named: 'submission'),
        ),
      ).thenAnswer((_) async => _response(rating: FlashcardRating.easy));

      await n.rate(FlashcardRating.easy);

      final state = read();
      expect(state, isA<FlashcardSessionRated>());
      final rated = state as FlashcardSessionRated;
      expect(rated.card.id, 'fc_a');
      expect(rated.response.rating, FlashcardRating.easy);
    });

    test('mid-submission the state is rating', () async {
      final n = await reachRevealed();
      when(
        () => repo.rate(
          workspaceId: 'wsp_a',
          flashcardId: 'fc_a',
          submission: any(named: 'submission'),
        ),
      ).thenAnswer((_) async => _response(rating: FlashcardRating.hard));

      final future = n.rate(FlashcardRating.hard);
      final mid = read();
      expect(mid, isA<FlashcardSessionRating>());
      expect((mid as FlashcardSessionRating).rating, FlashcardRating.hard);
      await future;
    });

    test('is a no-op when not in revealed state (card not flipped)',
        () async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card());
      final n = notifier();
      await n.start();
      // State is viewingFront — the student never flipped.
      await n.rate(FlashcardRating.easy);

      verifyNever(
        () => repo.rate(
          workspaceId: any(named: 'workspaceId'),
          flashcardId: any(named: 'flashcardId'),
          submission: any(named: 'submission'),
        ),
      );
      expect(read(), isA<FlashcardSessionViewingFront>());
    });

    test('FlashcardNotFoundException during rate → error state', () async {
      final n = await reachRevealed();
      when(
        () => repo.rate(
          workspaceId: any(named: 'workspaceId'),
          flashcardId: any(named: 'flashcardId'),
          submission: any(named: 'submission'),
        ),
      ).thenThrow(const FlashcardNotFoundException('gone'));

      await n.rate(FlashcardRating.medium);

      final state = read();
      expect(state, isA<FlashcardSessionError>());
      expect((state as FlashcardSessionError).message, contains('gone'));
    });

    test('FlashcardNotRatableException during rate → error state', () async {
      final n = await reachRevealed();
      when(
        () => repo.rate(
          workspaceId: any(named: 'workspaceId'),
          flashcardId: any(named: 'flashcardId'),
          submission: any(named: 'submission'),
        ),
      ).thenThrow(const FlashcardNotRatableException('pending_review'));

      await n.rate(FlashcardRating.medium);

      expect(read(), isA<FlashcardSessionError>());
    });
  });

  group('next', () {
    Future<FlashcardSessionNotifier> reachRated() async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card(id: 'fc_a'));
      when(
        () => repo.rate(
          workspaceId: 'wsp_a',
          flashcardId: 'fc_a',
          submission: any(named: 'submission'),
        ),
      ).thenAnswer((_) async => _response(id: 'fc_a'));

      final n = notifier();
      await n.start();
      n.flip();
      await n.rate(FlashcardRating.easy);
      return n;
    }

    test('rated → loading → viewingFront with a fresh card', () async {
      final n = await reachRated();
      // The next fetch returns a different card.
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card(id: 'fc_b'));

      await n.next();

      final state = read();
      expect(state, isA<FlashcardSessionViewingFront>());
      expect((state as FlashcardSessionViewingFront).card.id, 'fc_b');
    });

    test('next is a no-op when not in rated state', () async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenAnswer((_) async => _card());
      final n = notifier();
      await n.start();
      // State is viewingFront, not rated — next() should do nothing.
      await n.next();
      verify(() => repo.next(workspaceId: 'wsp_a')).called(1);
    });
  });
}
