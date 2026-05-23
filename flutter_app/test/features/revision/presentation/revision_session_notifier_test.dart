import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/flashcards/data/demo_flashcards_repository.dart';
import 'package:social_study_app/features/flashcards/data/flashcards_repository.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart';
import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/features/revision/domain/revision_session.dart';
import 'package:social_study_app/features/revision/presentation/revision_session_notifier.dart';
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

AnswerFeedback _feedback({bool correct = true, int xp = 15}) => AnswerFeedback(
      questionId: 'q_1',
      isCorrect: correct,
      canonicalAnswer: 'B',
      explanation: 'Chloroplasts contain chlorophyll.',
      xpEarned: xp,
      newTopicMastery: 0.4,
      newOverallMastery: 0.3,
    );

Flashcard _card({String id = 'fc_1'}) => Flashcard(
      id: id,
      topic: 'Cell Biology',
      front: 'Which organelle is the powerhouse of the cell?',
      back: 'The mitochondrion.',
    );

FlashcardRatingResponse _rateResponse(FlashcardRating rating) =>
    FlashcardRatingResponse(
      flashcardId: 'fc_1',
      rating: rating,
      ratedAt: '2026-05-22T10:00:00Z',
    );

ProviderContainer _container({
  required QuestionsRepository questionsRepo,
  required FlashcardsRepository flashcardsRepo,
}) {
  final container = ProviderContainer(
    overrides: [
      questionsRepositoryProvider.overrideWithValue(questionsRepo),
      flashcardsRepositoryProvider.overrideWithValue(flashcardsRepo),
    ],
  );
  addTearDown(container.dispose);
  // The revision notifier is auto-dispose — without an active listener
  // the provider would tear down between the async `start`/`advance`
  // gaps and lose the state we just set. Pinning it via listen mirrors
  // what the screen's `ref.watch` does in production.
  container.listen(
    revisionSessionNotifierProvider(_wsId),
    (_, __) {},
  );
  return container;
}

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
  });

  test('build returns idle', () {
    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect(state, isA<RevisionSessionIdle>());
  });

  test('start builds an alternating plan and fetches the first item',
      () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    await container
        .read(revisionSessionNotifierProvider(_wsId).notifier)
        .start(itemCount: 4);

    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect(state, isA<RevisionSessionQuestion>());
    expect((state as RevisionSessionQuestion).progress.position, 1);
    expect(state.progress.total, 4);
  });

  test('alternating plan: Q → graded → advance fetches a flashcard',
      () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback());
    when(() => fRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start(itemCount: 4);

    notifier.setDraftAnswer('B');
    await notifier.submitAnswer();
    expect(
      container.read(revisionSessionNotifierProvider(_wsId)),
      isA<RevisionSessionQuestionGraded>(),
    );

    await notifier.advance();
    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect(state, isA<RevisionSessionFlashcardFront>());
    expect((state as RevisionSessionFlashcardFront).progress.position, 2);
  });

  test('flashcard phase: front → flip → back → rate → rated', () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
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

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start(itemCount: 2);

    notifier.setDraftAnswer('B');
    await notifier.submitAnswer();
    await notifier.advance(); // now on flashcardFront

    notifier.flip();
    expect(
      container.read(revisionSessionNotifierProvider(_wsId)),
      isA<RevisionSessionFlashcardBack>(),
    );

    await notifier.rate(FlashcardRating.easy);
    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect(state, isA<RevisionSessionFlashcardRated>());
    expect((state as RevisionSessionFlashcardRated).rating, FlashcardRating.easy);
  });

  test('advancing past the last item transitions to complete with tallies',
      () async {
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
        )).thenAnswer((_) async => _rateResponse(FlashcardRating.medium));

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start(itemCount: 2);

    // Item 1: question
    notifier.setDraftAnswer('B');
    await notifier.submitAnswer();
    await notifier.advance();

    // Item 2: flashcard
    notifier.flip();
    await notifier.rate(FlashcardRating.medium);
    await notifier.advance();

    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect(state, isA<RevisionSessionComplete>());
    final summary = (state as RevisionSessionComplete).summary;
    expect(summary.total, 2);
    expect(summary.questionsAnswered, 1);
    expect(summary.questionsCorrect, 1);
    expect(summary.flashcardsReviewed, 1);
  });

  test('incorrect answers do not bump the correct tally', () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback(correct: false));

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start(itemCount: 1);
    notifier.setDraftAnswer('A');
    await notifier.submitAnswer();
    await notifier.advance();

    final state = container.read(revisionSessionNotifierProvider(_wsId));
    final summary = (state as RevisionSessionComplete).summary;
    expect(summary.questionsAnswered, 1);
    expect(summary.questionsCorrect, 0);
  });

  test('a NoTopicsAvailable from the question fetch lands in unavailable',
      () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenThrow(const NoTopicsAvailableException());

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    await container
        .read(revisionSessionNotifierProvider(_wsId).notifier)
        .start();

    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect(state, isA<RevisionSessionUnavailable>());
    expect((state as RevisionSessionUnavailable).isNoTopics, isTrue);
  });

  test('a NoFlashcardTopics surfaces unavailable as well', () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback());
    when(() => fRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenThrow(const NoFlashcardTopicsException());

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start(itemCount: 2);
    notifier.setDraftAnswer('B');
    await notifier.submitAnswer();
    await notifier.advance();

    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect(state, isA<RevisionSessionUnavailable>());
    expect((state as RevisionSessionUnavailable).isNoTopics, isTrue);
  });

  test('a generator-busy exception lands in unavailable without no-topics',
      () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenThrow(const QuestionGenerationUnavailableException());

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    await container
        .read(revisionSessionNotifierProvider(_wsId).notifier)
        .start();

    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect(state, isA<RevisionSessionUnavailable>());
    expect((state as RevisionSessionUnavailable).isNoTopics, isFalse);
  });

  test('a generic transport error lands in error', () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenThrow(Exception('network down'));

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    await container
        .read(revisionSessionNotifierProvider(_wsId).notifier)
        .start();

    expect(
      container.read(revisionSessionNotifierProvider(_wsId)),
      isA<RevisionSessionError>(),
    );
  });

  test('submitAnswer is a no-op from a flashcard state', () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());
    when(() => qRepo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        )).thenAnswer((_) async => _feedback());
    when(() => fRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _card());

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start(itemCount: 2);
    notifier.setDraftAnswer('B');
    await notifier.submitAnswer();
    await notifier.advance(); // flashcardFront

    await notifier.submitAnswer(); // no-op
    expect(
      container.read(revisionSessionNotifierProvider(_wsId)),
      isA<RevisionSessionFlashcardFront>(),
    );
  });

  test('rate is a no-op from a question state', () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start();

    await notifier.rate(FlashcardRating.easy); // no-op
    expect(
      container.read(revisionSessionNotifierProvider(_wsId)),
      isA<RevisionSessionQuestion>(),
    );
  });

  test('start is a no-op when not idle', () async {
    when(() => qRepo.next(workspaceId: any(named: 'workspaceId')))
        .thenAnswer((_) async => _mcq());

    final container =
        _container(questionsRepo: qRepo, flashcardsRepo: fRepo);
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start(itemCount: 5);

    await notifier.start(itemCount: 8); // ignored
    final state = container.read(revisionSessionNotifierProvider(_wsId));
    expect((state as RevisionSessionQuestion).progress.total, 5);

    verify(() => qRepo.next(workspaceId: _wsId)).called(1);
  });

  test('the demo repositories drive a real revision session', () async {
    final container = _container(
      questionsRepo: DemoQuestionsRepository(),
      flashcardsRepo: DemoFlashcardsRepository(),
    );
    final notifier =
        container.read(revisionSessionNotifierProvider(_wsId).notifier);
    await notifier.start(itemCount: 2);

    final firstState = container.read(revisionSessionNotifierProvider(_wsId));
    expect(firstState, isA<RevisionSessionQuestion>());

    final q = (firstState as RevisionSessionQuestion).question;
    notifier.setDraftAnswer('B');
    await notifier.submitAnswer();
    expect(q.id, isNotEmpty);

    await notifier.advance();
    expect(
      container.read(revisionSessionNotifierProvider(_wsId)),
      isA<RevisionSessionFlashcardFront>(),
    );

    notifier.flip();
    await notifier.rate(FlashcardRating.medium);
    await notifier.advance();

    expect(
      container.read(revisionSessionNotifierProvider(_wsId)),
      isA<RevisionSessionComplete>(),
    );
  });
}
