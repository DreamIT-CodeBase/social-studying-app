import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/questions/data/demo_questions_repository.dart';
import 'package:social_study_app/shared/models/question.dart';

/// Pins the demo repository's deterministic behaviour:
/// - Sequential calls to [next] yield distinct questions (rotation).
/// - The rotation covers all 4 fixture types so a UI dev exercising the
///   demo path sees variety.
/// - [submitAnswer] grades against the fixture's stored canonical
///   answer (case-insensitive) and feeds plausible mastery numbers
///   back into the response.
/// - Unknown question id raises [QuestionNotFoundException] — same
///   shape the real repository surfaces from a 404.

void main() {
  group('DemoQuestionsRepository.next', () {
    test('yields a question with a unique id on each call', () async {
      final repo = DemoQuestionsRepository();
      final q1 = await repo.next(workspaceId: 'wsp_demo');
      final q2 = await repo.next(workspaceId: 'wsp_demo');
      expect(q1.id, isNot(q2.id));
      expect(q1.id, startsWith('qst_demo_'));
      expect(q2.id, startsWith('qst_demo_'));
    });

    test('rotates through all four fixture types within four calls',
        () async {
      final repo = DemoQuestionsRepository();
      final types = <QuestionType>{};
      for (var i = 0; i < 4; i++) {
        final q = await repo.next(workspaceId: 'wsp_demo');
        types.add(q.questionType);
      }
      // All four configured fixture types should appear.
      expect(types, {
        QuestionType.mcq,
        QuestionType.shortAnswer,
        QuestionType.trueFalse,
        QuestionType.longAnswer,
      });
    });

    test('MCQ fixture exposes four options without is_correct leakage',
        () async {
      final repo = DemoQuestionsRepository();
      // First fixture is the MCQ.
      final q = await repo.next(workspaceId: 'wsp_demo');
      expect(q.questionType, QuestionType.mcq);
      expect(q.options, hasLength(4));
      // The Flutter McqOption model deliberately has no isCorrect
      // field — verify the JSON shape doesn't include it either.
      final raw = q.options.first.toJson();
      expect(raw.containsKey('is_correct'), isFalse);
    });
  });

  group('DemoQuestionsRepository.submitAnswer', () {
    test('correct answer returns isCorrect=true with bonus XP', () async {
      final repo = DemoQuestionsRepository();
      // Fixture 0 is the MCQ with correct answer "B".
      final q = await repo.next(workspaceId: 'wsp_demo');
      final feedback = await repo.submitAnswer(
        workspaceId: 'wsp_demo',
        questionId: q.id,
        submission: const AnswerSubmission(answer: 'B'),
      );
      expect(feedback.isCorrect, isTrue);
      // Attempt (10) + beginner bonus (5) = 15.
      expect(feedback.xpEarned, 15);
      expect(feedback.canonicalAnswer, 'B');
      expect(feedback.explanation, isNotEmpty);
    });

    test('wrong answer awards attempt XP only', () async {
      final repo = DemoQuestionsRepository();
      final q = await repo.next(workspaceId: 'wsp_demo');
      final feedback = await repo.submitAnswer(
        workspaceId: 'wsp_demo',
        questionId: q.id,
        submission: const AnswerSubmission(answer: 'A'),
      );
      expect(feedback.isCorrect, isFalse);
      expect(feedback.xpEarned, 10);
    });

    test('answer matching is case-insensitive', () async {
      final repo = DemoQuestionsRepository();
      await repo.next(workspaceId: 'wsp_demo'); // mcq
      final q = await repo.next(workspaceId: 'wsp_demo'); // short_answer
      // Fixture 1's correct answer is "oxygen" — submit uppercase.
      final feedback = await repo.submitAnswer(
        workspaceId: 'wsp_demo',
        questionId: q.id,
        submission: const AnswerSubmission(answer: 'OXYGEN'),
      );
      expect(feedback.isCorrect, isTrue);
    });

    test('unknown question id raises QuestionNotFoundException', () async {
      final repo = DemoQuestionsRepository();
      expect(
        () => repo.submitAnswer(
          workspaceId: 'wsp_demo',
          questionId: 'qst_never_served',
          submission: const AnswerSubmission(answer: 'B'),
        ),
        throwsA(isA<QuestionNotFoundException>()),
      );
    });

    test('repeated correct answers bump topic mastery monotonically',
        () async {
      final repo = DemoQuestionsRepository();
      double? lastMastery;
      // Answer the MCQ fixture twice (it'll come up at indices 0 and 4).
      for (var pass = 0; pass < 2; pass++) {
        // Rotate through 4 fixtures to land back on MCQ.
        Question q = await repo.next(workspaceId: 'wsp_demo');
        for (var skip = 1; skip < 4; skip++) {
          // Don't grade — just advance the rotation. We need to
          // submit *something* though, otherwise the demo's served
          // map fills up unnecessarily. Submit a wrong answer to a
          // non-MCQ to avoid bumping unrelated mastery.
          await repo.next(workspaceId: 'wsp_demo');
        }
        final feedback = await repo.submitAnswer(
          workspaceId: 'wsp_demo',
          questionId: q.id,
          submission: const AnswerSubmission(answer: 'B'),
        );
        if (lastMastery != null) {
          expect(feedback.newTopicMastery, greaterThan(lastMastery));
        }
        lastMastery = feedback.newTopicMastery;
      }
    });
  });
}
