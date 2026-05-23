import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/data/flashcards_repository.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart';
import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/features/revision/presentation/revision_screen.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/models/question.dart';

class _MockQuestionsRepo extends Mock implements QuestionsRepository {}

class _MockFlashcardsRepo extends Mock implements FlashcardsRepository {}

const _wsId = 'wsp_test';

Question _mcq({String id = 'q_1'}) => Question(
      id: id,
      topic: 'Photosynthesis',
      questionType: QuestionType.mcq,
      difficulty: DifficultyLevel.beginner,
      body: 'Which organelle is the site of photosynthesis?',
      options: const [
        McqOption(key: 'A', text: 'Mitochondria'),
        McqOption(key: 'B', text: 'Chloroplast'),
      ],
    );

AnswerFeedback _feedback({bool correct = true}) => AnswerFeedback(
      questionId: 'q_1',
      isCorrect: correct,
      canonicalAnswer: 'B',
      explanation: 'Chloroplasts contain chlorophyll.',
      xpEarned: 15,
      newTopicMastery: 0.4,
      newOverallMastery: 0.3,
    );

Flashcard _card({String id = 'fc_1'}) => Flashcard(
      id: id,
      topic: 'Cell Biology',
      front: 'Powerhouse of the cell?',
      back: 'The mitochondrion.',
    );

FlashcardRatingResponse _rateResponse(FlashcardRating rating) =>
    FlashcardRatingResponse(
      flashcardId: 'fc_1',
      rating: rating,
      ratedAt: '2026-05-22T10:00:00Z',
    );

Widget _wrap({
  required QuestionsRepository qRepo,
  required FlashcardsRepository fRepo,
}) =>
    ProviderScope(
      overrides: [
        questionsRepositoryProvider.overrideWithValue(qRepo),
        flashcardsRepositoryProvider.overrideWithValue(fRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const RevisionScreen(workspaceId: _wsId),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const AnswerSubmission(answer: ''));
    registerFallbackValue(
      const FlashcardRatingSubmission(rating: FlashcardRating.easy),
    );
  });

  late _MockQuestionsRepo qRepo;
  late _MockFlashcardsRepo fRepo;

  setUp(() {
    qRepo = _MockQuestionsRepo();
    fRepo = _MockFlashcardsRepo();
    RevisionScreen.debugItemCount = 2;
  });

  tearDown(() {
    RevisionScreen.debugItemCount = null;
  });

  testWidgets('shows the AppBar progress bar and first question',
      (tester) async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();

    expect(find.text('Revision'), findsOneWidget);
    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('Which organelle is the site of photosynthesis?'),
        findsOneWidget);
    expect(find.text('Chloroplast'), findsOneWidget);
  });

  testWidgets('the loading state shows the item count', (tester) async {
    final completer = Completer<Question>();
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pump();
    await tester.pump();

    expect(find.text('Loading item 1 of 2…'), findsOneWidget);

    completer.complete(_mcq());
    await tester.pumpAndSettle();
  });

  testWidgets('submitting a question shows the graded view with explanation',
      (tester) async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback());

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pumpAndSettle();

    expect(find.text('Correct!'), findsOneWidget);
    expect(find.textContaining('chlorophyll'), findsOneWidget);
    expect(find.text('+15 XP'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
  });

  testWidgets('Continue advances to the next item and flips into the flashcard',
      (tester) async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback());
    when(() => fRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Powerhouse of the cell?'), findsOneWidget);
    expect(find.text('Item 2 of 2'), findsOneWidget);
  });

  testWidgets('tapping the flashcard reveals the back and rating buttons',
      (tester) async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback());
    when(() => fRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Powerhouse of the cell?'));
    await tester.pumpAndSettle();

    expect(find.text('The mitochondrion.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Easy'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Medium'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hard'), findsOneWidget);
  });

  testWidgets(
      'rating the last flashcard and continuing transitions to the summary',
      (tester) async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback(correct: true));
    when(() => fRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());
    when(() => fRepo.rate(
          workspaceId: any(named: 'workspaceId'),
          flashcardId: any(named: 'flashcardId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _rateResponse(FlashcardRating.easy));

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();

    // Item 1: question
    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Item 2: flashcard
    await tester.tap(find.text('Powerhouse of the cell?'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Easy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Session complete!'), findsOneWidget);
    expect(find.textContaining('2 items'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget); // accuracy
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Restart'), findsOneWidget);
  });

  testWidgets('Restart from the summary kicks off a fresh session',
      (tester) async {
    var qCalls = 0;
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      qCalls++;
      return _mcq();
    });
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback());
    when(() => fRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());
    when(() => fRepo.rate(
          workspaceId: any(named: 'workspaceId'),
          flashcardId: any(named: 'flashcardId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _rateResponse(FlashcardRating.easy));

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Powerhouse of the cell?'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Easy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Session complete!'), findsOneWidget);
    final beforeRestart = qCalls;

    await tester.tap(find.widgetWithText(OutlinedButton, 'Restart'));
    await tester.pumpAndSettle();

    expect(qCalls, greaterThan(beforeRestart));
    expect(find.text('Item 1 of 2'), findsOneWidget);
  });

  testWidgets('no-topics state shows admin-targeted copy without retry',
      (tester) async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenThrow(const NoTopicsAvailableException());

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();

    expect(find.text('No content yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try Again'), findsNothing);
  });

  testWidgets('generator-busy state offers a retry that re-fetches',
      (tester) async {
    var calls = 0;
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw const QuestionGenerationUnavailableException();
      }
      return _mcq();
    });

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();

    expect(find.text('Generator is busy'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Chloroplast'), findsOneWidget);
  });

  testWidgets('generic error shows ErrorView with retry', (tester) async {
    var calls = 0;
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('network down');
      return _mcq();
    });

    await tester.pumpWidget(_wrap(qRepo: qRepo, fRepo: fRepo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Chloroplast'), findsOneWidget);
  });

  testWidgets('the demo repositories drive the revision loop end to end',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionsRepositoryProvider
              .overrideWithValue(DemoQuestionsRepository()),
          flashcardsRepositoryProvider
              .overrideWithValue(DemoFlashcardsRepository()),
        ],
        child: const MaterialApp(
          home: RevisionScreen(workspaceId: 'wsp_demo_001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Which organelle is the primary site of photosynthesis?'),
      findsOneWidget,
    );
    expect(find.text('Item 1 of 2'), findsOneWidget);
  });
}
