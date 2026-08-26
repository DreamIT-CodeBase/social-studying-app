import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/core/theme/theme_manager.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart';
import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/features/questions/presentation/question_screen.dart';
import 'package:social_study_app/shared/models/question.dart';

class _MockRepo extends Mock implements QuestionsRepository {}

const _wsId = 'wsp_test';

Question _mcq() => const Question(
      id: 'q_mcq',
      topic: 'Photosynthesis',
      questionType: QuestionType.mcq,
      difficulty: DifficultyLevel.beginner,
      body: 'Which organelle is the primary site of photosynthesis?',
      options: [
        McqOption(key: 'A', text: 'Mitochondria'),
        McqOption(key: 'B', text: 'Chloroplast'),
        McqOption(key: 'C', text: 'Ribosome'),
        McqOption(key: 'D', text: 'Nucleus'),
      ],
    );

Question _trueFalse() => const Question(
      id: 'q_tf',
      topic: 'Cell Biology',
      questionType: QuestionType.trueFalse,
      difficulty: DifficultyLevel.intermediate,
      body: 'Plants release oxygen during photosynthesis.',
    );

Question _short() => const Question(
      id: 'q_short',
      topic: 'Cell Biology',
      questionType: QuestionType.shortAnswer,
      difficulty: DifficultyLevel.beginner,
      body: 'What gas do plants release during photosynthesis?',
    );

Question _long() => const Question(
      id: 'q_long',
      topic: 'Photosynthesis',
      questionType: QuestionType.longAnswer,
      difficulty: DifficultyLevel.advanced,
      body: 'Explain how plants convert sunlight into chemical energy.',
    );

Question _math() => const Question(
      id: 'q_math',
      topic: 'Algebra',
      questionType: QuestionType.mathematical,
      difficulty: DifficultyLevel.intermediate,
      body: 'Solve for x: 2x + 6 = 14.',
    );

AnswerFeedback _feedback({bool correct = true}) => AnswerFeedback(
      questionId: 'q_mcq',
      isCorrect: correct,
      canonicalAnswer: 'B',
      explanation: 'Chloroplasts contain chlorophyll, which captures light.',
      xpEarned: 15,
      newTopicMastery: 0.42,
      newOverallMastery: 0.30,
    );

Widget _wrap(_MockRepo repo) => ProviderScope(
      overrides: [
        questionsRepositoryProvider.overrideWithValue(repo),
        appThemeModeProvider.overrideWith((ref) => AppThemeModeNotifier()..state = AppThemeMode.kids),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: QuestionScreen(workspaceId: _wsId)),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const AnswerSubmission(answer: ''));
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows a loading state while the first question generates',
      (tester) async {
    final completer = Completer<Question>();
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump(); // run the post-frame `start`
    await tester.pump(); // rebuild into the loading state

    expect(find.text('Generating your question…'), findsOneWidget);

    completer.complete(_mcq());
    await tester.pumpAndSettle();
  });

  testWidgets('renders an MCQ question with all options', (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(
      find.text('Which organelle is the primary site of photosynthesis?'),
      findsOneWidget,
    );
    expect(find.text('Chloroplast'), findsOneWidget);
    expect(find.text('Nucleus'), findsOneWidget);
    expect(find.text('Photosynthesis'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(
      tester.getCenter(find.text('15:00')).dx,
      greaterThan(tester.getCenter(find.text('0 XP')).dx),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('14:59'), findsOneWidget);
  });

  testWidgets('submit is disabled until an option is selected', (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    final before = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit Answer'),
    );
    expect(before.onPressed, isNull);

    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();

    final after = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit Answer'),
    );
    expect(after.onPressed, isNotNull);
  });

  testWidgets('submitting a correct MCQ answer shows the feedback view',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
          revision: any(named: 'revision'),
        )).thenAnswer((_) async => _feedback());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.submitAnswer(
          workspaceId: _wsId,
          questionId: 'q_mcq',
          submission: captureAny(named: 'submission'),
          revision: any(named: 'revision'),
        )).captured;
    expect((captured.single as AnswerSubmission).answer, 'B');

    expect(find.text('Correct!', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('chlorophyll', skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('an incorrect answer shows the canonical answer', (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
          revision: any(named: 'revision'),
        )).thenAnswer((_) async => _feedback(correct: false));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mitochondria'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Not quite', skipOffstage: false), findsOneWidget);
    expect(find.text('CORRECT ANSWER', skipOffstage: false), findsOneWidget);
    expect(find.text('B.  Chloroplast', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the Next Question button fetches a new question',
      (tester) async {
    var calls = 0;
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      return calls == 1 ? _mcq() : _trueFalse();
    });
    when(() => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
          revision: any(named: 'revision'),
        )).thenAnswer((_) async => _feedback());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next Question'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(
      find.text('Plants release oxygen during photosynthesis.'),
      findsOneWidget,
    );
  });

  testWidgets('renders a true/false question with True and False options',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _trueFalse());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('True'), findsOneWidget);
    expect(find.text('False'), findsOneWidget);
  });

  testWidgets('renders a short-answer question with a text field',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _short());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Type your answer'), findsOneWidget);
  });

  testWidgets('renders a long-answer question with a text field',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _long());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Write your full answer'), findsOneWidget);
  });

  testWidgets('renders a mathematical question with a notation hint',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _math());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter your answer'),
      findsOneWidget,
    );
  });

  testWidgets('typing then submitting a short answer reaches feedback',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _short());
    when(() => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
          revision: any(named: 'revision'),
        )).thenAnswer((_) async => _feedback());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'oxygen');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final captured = verify(() => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: captureAny(named: 'submission'),
          revision: any(named: 'revision'),
        )).captured;
    expect((captured.single as AnswerSubmission).answer, 'oxygen');
    expect(find.text('Correct!', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the no-topics state shows admin-targeted copy and no retry',
      (tester) async {
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenThrow(const NoTopicsAvailableException());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('No questions yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try Again'), findsNothing);
  });

  testWidgets('the generator-busy state offers a retry that re-fetches',
      (tester) async {
    var calls = 0;
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw const QuestionGenerationUnavailableException();
      }
      return _mcq();
    });

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Generator is busy'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Chloroplast'), findsOneWidget);
  });

  testWidgets('a generic error shows an ErrorView with retry', (tester) async {
    var calls = 0;
    when(() => repo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('network down');
      return _mcq();
    });

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('Chloroplast'), findsOneWidget);
  });

  testWidgets('the demo repository drives the question loop end to end',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionsRepositoryProvider
              .overrideWithValue(DemoQuestionsRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: QuestionScreen(workspaceId: 'wsp_demo_001')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First demo fixture is the photosynthesis MCQ.
    expect(
      find.text('Which organelle is the primary site of photosynthesis?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Chloroplast'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit Answer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Correct!', skipOffstage: false), findsOneWidget);
  });
}
