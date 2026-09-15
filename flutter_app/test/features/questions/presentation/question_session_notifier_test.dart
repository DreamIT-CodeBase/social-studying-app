import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart';
import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/features/questions/domain/question_session.dart';
import 'package:social_study_app/features/questions/presentation/question_session_notifier.dart';
import 'package:social_study_app/shared/models/question.dart';

class _MockRepo extends Mock implements QuestionsRepository {}

class _FakeSubmission extends Fake implements AnswerSubmission {}

Question _q({String id = 'qst_a'}) => Question(
      id: id,
      topic: 'Photosynthesis',
      questionType: QuestionType.mcq,
      difficulty: DifficultyLevel.beginner,
      body: 'Which organelle?',
      options: const [
        McqOption(key: 'A', text: 'Mito'),
        McqOption(key: 'B', text: 'Chloroplast'),
      ],
    );

AnswerFeedback _fb({bool isCorrect = true, String qid = 'qst_a'}) =>
    AnswerFeedback(
      questionId: qid,
      isCorrect: isCorrect,
      canonicalAnswer: 'B',
      explanation: 'Chloroplasts contain chlorophyll.',
      xpEarned: isCorrect ? 15 : 10,
      newTopicMastery: 0.1,
      newOverallMastery: 0.1,
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
        questionsRepositoryProvider.overrideWith((_) => repo),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('build', () {
    test('initial state is idle', () {
      final state = container.read(
        questionSessionNotifierProvider('wsp_a'),
      );
      expect(state, isA<QuestionSessionIdle>());
    });
  });

  group('start', () {
    test('idle → loading → ready on successful fetch', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer((_) async => _q());

      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      final future = notifier.start();

      // Mid-fetch the state should be loading.
      expect(
        container.read(questionSessionNotifierProvider('wsp_a')),
        isA<QuestionSessionLoading>(),
      );

      await future;

      final terminal = container.read(
        questionSessionNotifierProvider('wsp_a'),
      );
      expect(terminal, isA<QuestionSessionReady>());
      expect((terminal as QuestionSessionReady).question.id, 'qst_a');
      expect(terminal.draftAnswer, isNull);
    });

    test('NoTopicsAvailable → unavailable with isNoTopics=true', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenThrow(
        const NoTopicsAvailableException('empty workspace'),
      );

      await container
          .read(questionSessionNotifierProvider('wsp_a').notifier)
          .start();

      final state = container.read(
        questionSessionNotifierProvider('wsp_a'),
      );
      expect(state, isA<QuestionSessionUnavailable>());
      final unavailable = state as QuestionSessionUnavailable;
      expect(unavailable.isNoTopics, isTrue);
      expect(unavailable.message, contains('empty workspace'));
      // No retry-after on 409 — "no topics" can't be solved by retrying.
      expect(unavailable.retryAfterSeconds, isNull);
    });

    test(
        'QuestionGenerationUnavailable → unavailable with isNoTopics=false + retryAfterSeconds',
        () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenThrow(
        const QuestionGenerationUnavailableException(
          message: 'all attempts failed',
          retryAfterSeconds: 45,
        ),
      );

      await container
          .read(questionSessionNotifierProvider('wsp_a').notifier)
          .start();

      final state = container.read(
        questionSessionNotifierProvider('wsp_a'),
      ) as QuestionSessionUnavailable;
      expect(state.isNoTopics, isFalse);
      expect(state.retryAfterSeconds, 45);
    });

    test('any other exception → error state', () async {
      when(() => repo.next(workspaceId: 'wsp_a'))
          .thenThrow(Exception('network down'));

      await container
          .read(questionSessionNotifierProvider('wsp_a').notifier)
          .start();

      final state = container.read(
        questionSessionNotifierProvider('wsp_a'),
      );
      expect(state, isA<QuestionSessionError>());
      expect((state as QuestionSessionError).message, contains('network down'));
    });

    test('start is a no-op when already past idle', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer((_) async => _q());

      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      await notifier.start();
      // Second start() — state is ready, not idle. Should NOT re-fetch.
      await notifier.start();
      verify(() => repo.next(workspaceId: 'wsp_a')).called(1);
    });
  });

  group('setDraftAnswer', () {
    test('updates the draftAnswer in ready state', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer((_) async => _q());
      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      await notifier.start();

      notifier.setDraftAnswer('B');

      final ready = container.read(
        questionSessionNotifierProvider('wsp_a'),
      ) as QuestionSessionReady;
      expect(ready.draftAnswer, 'B');
    });

    test('is a no-op when not in ready state', () {
      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      // State is still idle.
      notifier.setDraftAnswer('B');
      expect(
        container.read(questionSessionNotifierProvider('wsp_a')),
        isA<QuestionSessionIdle>(),
      );
    });
  });

  group('submit', () {
    test('ready → submitting → feedback on successful submission', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer((_) async => _q());
      when(
        () => repo.submitAnswer(
          workspaceId: 'wsp_a',
          questionId: 'qst_a',
          submission: any(named: 'submission'),
        ),
      ).thenAnswer((_) async => _fb(isCorrect: true));

      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      await notifier.start();
      notifier.setDraftAnswer('B');
      await notifier.submit();

      final state = container.read(
        questionSessionNotifierProvider('wsp_a'),
      );
      expect(state, isA<QuestionSessionFeedback>());
      final fb = state as QuestionSessionFeedback;
      expect(fb.feedback.isCorrect, isTrue);
      expect(fb.submittedAnswer, 'B');
      expect(fb.question.id, 'qst_a');
    });

    test('submit with no draft is a no-op', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer((_) async => _q());

      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      await notifier.start();
      // draftAnswer is null
      await notifier.submit();

      // Repository's submitAnswer must NOT have been called.
      verifyNever(
        () => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        ),
      );
      // Still in ready state.
      expect(
        container.read(questionSessionNotifierProvider('wsp_a')),
        isA<QuestionSessionReady>(),
      );
    });

    test('submit with whitespace-only draft is a no-op', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer((_) async => _q());

      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      await notifier.start();
      notifier.setDraftAnswer('   ');
      await notifier.submit();

      verifyNever(
        () => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        ),
      );
    });

    test('QuestionNotFoundException during submit → error state', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer((_) async => _q());
      when(
        () => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        ),
      ).thenThrow(const QuestionNotFoundException('gone'));

      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      await notifier.start();
      notifier.setDraftAnswer('B');
      await notifier.submit();

      final state = container.read(
        questionSessionNotifierProvider('wsp_a'),
      );
      expect(state, isA<QuestionSessionError>());
      expect((state as QuestionSessionError).message, contains('gone'));
    });

    test('submit is a no-op when not in ready state', () async {
      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      // State is still idle — submit should silently do nothing.
      await notifier.submit();
      verifyNever(
        () => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: any(named: 'questionId'),
          submission: any(named: 'submission'),
        ),
      );
    });
  });

  group('next', () {
    test('feedback → loading → ready on next() call', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer(
        (_) async => _q(id: 'qst_a'),
      );
      when(
        () => repo.submitAnswer(
          workspaceId: any(named: 'workspaceId'),
          questionId: 'qst_a',
          submission: any(named: 'submission'),
        ),
      ).thenAnswer((_) async => _fb(isCorrect: true, qid: 'qst_a'));

      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      await notifier.start();
      notifier.setDraftAnswer('B');
      await notifier.submit();

      // Now in feedback. Set up the next fetch to return a different
      // question.
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer(
        (_) async => _q(id: 'qst_b'),
      );
      await notifier.next();

      final state = container.read(
        questionSessionNotifierProvider('wsp_a'),
      );
      expect(state, isA<QuestionSessionReady>());
      expect((state as QuestionSessionReady).question.id, 'qst_b');
      // Fresh question — draft should reset.
      expect(state.draftAnswer, isNull);
    });

    test('next is a no-op when not in feedback state', () async {
      when(() => repo.next(workspaceId: 'wsp_a')).thenAnswer((_) async => _q());

      final notifier = container.read(
        questionSessionNotifierProvider('wsp_a').notifier,
      );
      await notifier.start();
      // State is ready, not feedback — next() should do nothing.
      await notifier.next();
      verify(() => repo.next(workspaceId: 'wsp_a')).called(1);
    });
  });
}
