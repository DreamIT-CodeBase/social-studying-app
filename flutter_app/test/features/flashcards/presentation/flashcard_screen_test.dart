import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/data/flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_screen.dart';
import 'package:social_study_app/shared/models/flashcard.dart';

class _MockRepo extends Mock implements FlashcardsRepository {}

const _wsId = 'wsp_test';

Flashcard _card() => const Flashcard(
      id: 'fc_1',
      topic: 'Photosynthesis',
      front: 'What pigment captures light energy during photosynthesis?',
      back: 'Chlorophyll.',
      explanation: 'Chlorophyll absorbs red and blue light, reflecting green.',
    );

FlashcardRatingResponse _response(FlashcardRating rating) =>
    FlashcardRatingResponse(
      flashcardId: 'fc_1',
      rating: rating,
      ratedAt: '2026-05-22T10:00:00Z',
    );

Widget _wrap(_MockRepo repo) => ProviderScope(
      overrides: [
        flashcardsRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: FlashcardScreen(workspaceId: _wsId)),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(
      const FlashcardRatingSubmission(rating: FlashcardRating.easy),
    );
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows a loading state while the first card generates',
      (tester) async {
    final completer = Completer<Flashcard>();
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('Finding a card…'), findsOneWidget);

    completer.complete(_card());
    await tester.pumpAndSettle();
  });

  testWidgets('shows the front of the card with a flip hint', (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(
      find.text('What pigment captures light energy during photosynthesis?'),
      findsOneWidget,
    );
    expect(find.text('QUESTION'), findsOneWidget);
    // The back and the rating buckets are hidden until the flip.
    expect(find.text('Chlorophyll.'), findsNothing);
    expect(find.text('How well did you recall it?'), findsNothing);
  });

  testWidgets('tapping the card flips it and reveals the back + ratings',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text(
      'What pigment captures light energy during photosynthesis?',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chlorophyll.'), findsOneWidget);
    expect(find.text('How well did you recall it?'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
  });

  testWidgets('rating a card records the rating and offers the next card',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());
    when(() => repo.rate(
          workspaceId: any(named: 'workspaceId'),
          flashcardId: any(named: 'flashcardId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _response(FlashcardRating.easy));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text(
      'What pigment captures light energy during photosynthesis?',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Easy'));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.rate(
          workspaceId: _wsId,
          flashcardId: 'fc_1',
          submission: captureAny(named: 'submission'),
        )).captured;
    expect(
      (captured.single as FlashcardRatingSubmission).rating,
      FlashcardRating.easy,
    );
    expect(find.text('Rated Easy'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next Card'), findsOneWidget);
  });

  testWidgets('the Next Card button fetches a new card', (tester) async {
    var calls = 0;
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      return calls == 1
          ? _card()
          : const Flashcard(
              id: 'fc_2',
              topic: 'Genetics',
              front: 'What does a genotype describe?',
              back: 'The inherited genetic code.',
            );
    });
    when(() => repo.rate(
          workspaceId: any(named: 'workspaceId'),
          flashcardId: any(named: 'flashcardId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _response(FlashcardRating.medium));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(
      'What pigment captures light energy during photosynthesis?',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Medium'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next Card'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('What does a genotype describe?'), findsOneWidget);
  });

  testWidgets('the no-topics state shows admin-targeted copy and no retry',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenThrow(const NoFlashcardTopicsException());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('No flashcards yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try Again'), findsNothing);
  });

  testWidgets('the generator-busy state offers a retry that re-fetches',
      (tester) async {
    var calls = 0;
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw const FlashcardGenerationUnavailableException();
      }
      return _card();
    });

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Generator is busy'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Try Again'));
    await tester.pumpAndSettle();

    expect(
      find.text('What pigment captures light energy during photosynthesis?'),
      findsOneWidget,
    );
  });

  testWidgets('a generic error shows an ErrorView with retry', (tester) async {
    var calls = 0;
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('network down');
      return _card();
    });

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(
      find.text('What pigment captures light energy during photosynthesis?'),
      findsOneWidget,
    );
  });

  testWidgets('the demo repository drives the flashcard loop end to end',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flashcardsRepositoryProvider
              .overrideWithValue(DemoFlashcardsRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FlashcardScreen(workspaceId: 'wsp_demo_001')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First demo fixture is the photosynthesis card.
    expect(
      find.text('What pigment captures light energy during photosynthesis?'),
      findsOneWidget,
    );

    await tester.tap(find.text(
      'What pigment captures light energy during photosynthesis?',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Easy'));
    await tester.pumpAndSettle();

    expect(find.text('Rated Easy'), findsOneWidget);
  });
}
