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

    expect(find.text('Loading next card…'), findsOneWidget);

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
    expect(find.text('Chlorophyll.'), findsNothing);
  });

  testWidgets('tapping the card flips it and reveals the back', (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text(
      'What pigment captures light energy during photosynthesis?',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chlorophyll.'), findsOneWidget);
    expect(find.text('Swipe Left'), findsOneWidget);
    expect(find.text('Remembered'), findsOneWidget);
    expect(find.text('Swipe Right'), findsOneWidget);
    expect(find.text('Forgot'), findsOneWidget);
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

    // Drag the card to the left to swipe Easy
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(GestureDetector).first));
    await gesture.moveBy(const Offset(-300, 0));
    await gesture.up();
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
    await tester.pumpAndSettle(const Duration(milliseconds: 1000));
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

    expect(
      find.text('What pigment captures light energy during photosynthesis?'),
      findsOneWidget,
    );

    await tester.tap(find.text(
      'What pigment captures light energy during photosynthesis?',
    ));
    await tester.pumpAndSettle();

    // Swipe the card left to advance
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(GestureDetector).first));
    await gesture.moveBy(const Offset(-300, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(const Duration(milliseconds: 1000));
  });
}
