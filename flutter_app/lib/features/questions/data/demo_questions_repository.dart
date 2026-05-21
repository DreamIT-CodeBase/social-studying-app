import 'dart:async';

import 'package:social_study_app/features/questions/data/questions_repository.dart';
import 'package:social_study_app/shared/models/question.dart';

/// Typed exceptions the UI layer branches on. Mirror the HTTP status
/// codes the real repository surfaces from the backend.

class NoTopicsAvailableException implements Exception {
  const NoTopicsAvailableException([this.message = 'No topics available']);
  final String message;
  @override
  String toString() => 'NoTopicsAvailableException: $message';
}

class QuestionGenerationUnavailableException implements Exception {
  const QuestionGenerationUnavailableException({
    this.message = 'Couldn\'t generate a question right now',
    this.retryAfterSeconds = 30,
  });
  final String message;
  final int retryAfterSeconds;
  @override
  String toString() =>
      'QuestionGenerationUnavailableException(retryAfter=${retryAfterSeconds}s): $message';
}

class QuestionNotFoundException implements Exception {
  const QuestionNotFoundException([this.message = 'Question not found']);
  final String message;
  @override
  String toString() => 'QuestionNotFoundException: $message';
}

class QuestionNotAnswerableException implements Exception {
  const QuestionNotAnswerableException([
    this.message = 'Question is not in an answerable state',
  ]);
  final String message;
  @override
  String toString() => 'QuestionNotAnswerableException: $message';
}


/// Offline, deterministic implementation of the question loop.
///
/// Backs the demo user so an offline dev can exercise the full
/// question / answer interaction without a live backend.
///
/// Behaviour:
/// - Rotates through a small fixture set on every [next] call (4
///   questions covering MCQ, short_answer, true_false, long_answer
///   to give the UI variety to render).
/// - [submitAnswer] grades against the fixture's known correct answer
///   (case-insensitive) and returns a synthetic [AnswerFeedback] with
///   plausible mastery numbers so the progress UI has something to
///   show.
/// - State is in-process; restarting the app resets the rotation
///   index. That's a feature, not a bug — the demo flow is meant to
///   be reproducible.
class DemoQuestionsRepository implements QuestionsRepository {
  DemoQuestionsRepository();

  // Rotation index across calls — bumped by `next`, used to pick the
  // next fixture deterministically.
  int _index = 0;
  // Tracks the canonical answer + topic per served question so
  // submitAnswer can grade without persisting the full Question doc.
  final Map<String, _DemoQuestionState> _served = {};
  // Running mastery for the demo user, keyed by topic. Starts at 0
  // and bumps by 0.1 on correct answers; gives the progress UI
  // something non-trivial to render.
  final Map<String, double> _topicMastery = {};

  @override
  Future<Question> next({required String workspaceId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final fixture = _fixtures[_index % _fixtures.length];
    _index++;
    final id = 'qst_demo_${_index.toString().padLeft(3, '0')}';
    _served[id] = _DemoQuestionState(
      correctAnswer: fixture.correctAnswer,
      topic: fixture.topic,
      explanation: fixture.explanation,
      difficulty: fixture.question.difficulty,
    );
    return fixture.question.copyWith(id: id);
  }

  @override
  Future<AnswerFeedback> submitAnswer({
    required String workspaceId,
    required String questionId,
    required AnswerSubmission submission,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final state = _served[questionId];
    if (state == null) {
      throw const QuestionNotFoundException();
    }
    final isCorrect = state.correctAnswer.trim().toLowerCase() ==
        submission.answer.trim().toLowerCase();
    final xpBonus = switch (state.difficulty) {
      DifficultyLevel.beginner => 5,
      DifficultyLevel.intermediate => 10,
      DifficultyLevel.advanced => 20,
    };
    final xpEarned = 10 + (isCorrect ? xpBonus : 0);

    final previous = _topicMastery[state.topic] ?? 0.0;
    final delta = isCorrect ? 0.1 : -0.02;
    final next = (previous + delta).clamp(0.0, 1.0);
    _topicMastery[state.topic] = next;
    final overall =
        _topicMastery.values.fold<double>(0.0, (sum, v) => sum + v) /
            _topicMastery.length;

    return AnswerFeedback(
      questionId: questionId,
      isCorrect: isCorrect,
      canonicalAnswer: state.correctAnswer,
      explanation: state.explanation,
      xpEarned: xpEarned,
      newTopicMastery: next,
      newOverallMastery: overall,
    );
  }

  // ── Fixtures ─────────────────────────────────────────────────────────────

  static final List<_DemoFixture> _fixtures = [
    _DemoFixture(
      question: const Question(
        id: 'placeholder',
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
      ),
      correctAnswer: 'B',
      topic: 'Photosynthesis',
      explanation:
          'Chloroplasts contain chlorophyll, which captures photons during photosynthesis.',
    ),
    _DemoFixture(
      question: const Question(
        id: 'placeholder',
        topic: 'Cell Biology',
        questionType: QuestionType.shortAnswer,
        difficulty: DifficultyLevel.beginner,
        body: 'What gas do plants release during photosynthesis?',
      ),
      correctAnswer: 'oxygen',
      topic: 'Cell Biology',
      explanation:
          'Plants split water during photosynthesis and release the oxygen as a byproduct.',
    ),
    _DemoFixture(
      question: const Question(
        id: 'placeholder',
        topic: 'Cellular Respiration',
        questionType: QuestionType.trueFalse,
        difficulty: DifficultyLevel.intermediate,
        body: 'Photosynthesis and cellular respiration are the same process.',
      ),
      correctAnswer: 'false',
      topic: 'Cellular Respiration',
      explanation:
          'They are opposite processes: photosynthesis stores energy, respiration releases it.',
    ),
    _DemoFixture(
      question: const Question(
        id: 'placeholder',
        topic: 'Photosynthesis',
        questionType: QuestionType.longAnswer,
        difficulty: DifficultyLevel.intermediate,
        body:
            'Explain how plants convert sunlight into chemical energy through photosynthesis.',
      ),
      correctAnswer:
          'Plants absorb sunlight using chlorophyll in chloroplasts. The light energy splits water into oxygen, protons, and electrons, producing ATP and NADPH. The Calvin cycle uses those carriers to fix CO2 into glucose.',
      topic: 'Photosynthesis',
      explanation:
          'A complete answer covers light absorption by chlorophyll, water splitting, ATP/NADPH production, and CO2 fixation in the Calvin cycle.',
    ),
  ];
}

class _DemoQuestionState {
  _DemoQuestionState({
    required this.correctAnswer,
    required this.topic,
    required this.explanation,
    required this.difficulty,
  });

  final String correctAnswer;
  final String topic;
  final String explanation;
  final DifficultyLevel difficulty;
}

class _DemoFixture {
  _DemoFixture({
    required this.question,
    required this.correctAnswer,
    required this.topic,
    required this.explanation,
  });

  final Question question;
  final String correctAnswer;
  final String topic;
  final String explanation;
}
