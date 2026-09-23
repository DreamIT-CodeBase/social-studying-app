import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/flashcards/data/flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_session_notifier.dart';
import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/features/questions/presentation/question_session_notifier.dart';
import 'package:social_study_app/features/revision/presentation/revision_session_notifier.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/models/question.dart';

class _MockQuestionsRepo extends Mock implements QuestionsRepository {}

class _MockFlashcardsRepo extends Mock implements FlashcardsRepository {}

Question _testQuestion() => const Question(
      id: 'q_test',
      topic: 'Math',
      questionType: QuestionType.mcq,
      difficulty: DifficultyLevel.beginner,
      body: 'What is 2 + 2?',
      options: [
        McqOption(key: 'A', text: '3'),
        McqOption(key: 'B', text: '4'),
      ],
    );

Flashcard _testFlashcard() => const Flashcard(
      id: 'fc_test',
      topic: 'Math',
      front: '2 + 2',
      back: '4',
    );

void main() {
  late _MockQuestionsRepo mockQuestionsRepo;
  late _MockFlashcardsRepo mockFlashcardsRepo;
  late ProviderContainer container;

  setUp(() {
    mockQuestionsRepo = _MockQuestionsRepo();
    mockFlashcardsRepo = _MockFlashcardsRepo();
    when(() => mockQuestionsRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _testQuestion());
    when(() => mockFlashcardsRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _testFlashcard());

    container = ProviderContainer(
      overrides: [
        questionsRepositoryProvider.overrideWith((_) => mockQuestionsRepo),
        flashcardsRepositoryProvider.overrideWith((_) => mockFlashcardsRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('Study Question Session Target Length strictly follows mastery level',
      () {
    test('Beginner tier (mastery < 0.40) has 5 to 7 questions', () async {
      for (final mastery in [0.0, 0.2, 0.39]) {
        final notifier = container.read(
          questionSessionNotifierProvider('wsp_test_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.sessionTargetLength,
          inInclusiveRange(5, 7),
          reason: 'Mastery $mastery should yield 5-7 questions',
        );
      }
    });

    test('Intermediate tier (0.40 <= mastery < 0.75) has 12 to 15 questions',
        () async {
      for (final mastery in [0.40, 0.55, 0.74]) {
        final notifier = container.read(
          questionSessionNotifierProvider('wsp_test_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.sessionTargetLength,
          inInclusiveRange(12, 15),
          reason: 'Mastery $mastery should yield 12-15 questions',
        );
      }
    });

    test('Expert tier (mastery >= 0.75) has 20 to 25 questions', () async {
      for (final mastery in [0.75, 0.90, 1.0]) {
        final notifier = container.read(
          questionSessionNotifierProvider('wsp_test_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.sessionTargetLength,
          inInclusiveRange(20, 25),
          reason: 'Mastery $mastery should yield 20-25 questions',
        );
      }
    });
  });

  group('Flashcard Session Target Length strictly follows mastery level', () {
    test('Beginner tier (mastery < 0.40) has 3 to 4 cards', () async {
      for (final mastery in [0.0, 0.2, 0.39]) {
        final notifier = container.read(
          flashcardSessionNotifierProvider('wsp_fc_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.sessionTargetLength,
          inInclusiveRange(3, 4),
          reason: 'Mastery $mastery should yield 3-4 cards',
        );
      }
    });

    test('Intermediate tier (0.40 <= mastery < 0.75) has 10 to 13 cards',
        () async {
      for (final mastery in [0.40, 0.55, 0.74]) {
        final notifier = container.read(
          flashcardSessionNotifierProvider('wsp_fc_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.sessionTargetLength,
          inInclusiveRange(10, 13),
          reason: 'Mastery $mastery should yield 10-13 cards',
        );
      }
    });

    test('Expert tier (mastery >= 0.75) has 18 to 25 cards', () async {
      for (final mastery in [0.75, 0.90, 1.0]) {
        final notifier = container.read(
          flashcardSessionNotifierProvider('wsp_fc_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.sessionTargetLength,
          inInclusiveRange(18, 25),
          reason: 'Mastery $mastery should yield 18-25 cards',
        );
      }
    });
  });

  group('Revision Session Plan Item Count strictly follows mastery level', () {
    test('Beginner tier (mastery < 0.40) has 5 to 7 items', () async {
      for (final mastery in [0.0, 0.2, 0.39]) {
        final notifier = container.read(
          revisionSessionNotifierProvider('wsp_rev_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.itemCount,
          inInclusiveRange(5, 7),
          reason: 'Mastery $mastery should yield 5-7 revision items',
        );
      }
    });

    test('Intermediate tier (0.40 <= mastery < 0.75) has 12 to 15 items',
        () async {
      for (final mastery in [0.40, 0.55, 0.74]) {
        final notifier = container.read(
          revisionSessionNotifierProvider('wsp_rev_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.itemCount,
          inInclusiveRange(12, 15),
          reason: 'Mastery $mastery should yield 12-15 revision items',
        );
      }
    });

    test('Expert tier (mastery >= 0.75) has 20 to 25 items', () async {
      for (final mastery in [0.75, 0.90, 1.0]) {
        final notifier = container.read(
          revisionSessionNotifierProvider('wsp_rev_$mastery').notifier,
        );
        await notifier.start(mastery: mastery);
        expect(
          notifier.itemCount,
          inInclusiveRange(20, 25),
          reason: 'Mastery $mastery should yield 20-25 revision items',
        );
      }
    });
  });
}
