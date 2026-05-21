// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime —
// JsonSerializable picks up the keys correctly.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'question.freezed.dart';
part 'question.g.dart';

/// Mirrors `app.models.question.QuestionType` on the backend.
///
/// Wire-format strings use snake_case. The `@JsonValue` annotations are
/// explicit so a backend rename can't silently break Flutter parsing.
enum QuestionType {
  @JsonValue('mcq')
  mcq,
  @JsonValue('short_answer')
  shortAnswer,
  @JsonValue('long_answer')
  longAnswer,
  @JsonValue('true_false')
  trueFalse,
  @JsonValue('mathematical')
  mathematical,
}

/// Mirrors `app.models.question.DifficultyLevel` on the backend.
enum DifficultyLevel {
  @JsonValue('beginner')
  beginner,
  @JsonValue('intermediate')
  intermediate,
  @JsonValue('advanced')
  advanced,
}

/// One option in an MCQ as the student sees it.
///
/// **Important:** this mirrors the backend's `StudentMcqOption`, not
/// `McqOption`. The student-facing API deliberately strips the
/// `is_correct` field — the answer is revealed only after the
/// student submits via `POST /questions/{id}/answer`. If you're
/// tempted to reach for an `isCorrect` field on the client, that's a
/// leak; route through `AnswerFeedback` instead.
@freezed
class McqOption with _$McqOption {
  const factory McqOption({
    required String key,
    required String text,
  }) = _McqOption;

  factory McqOption.fromJson(Map<String, dynamic> json) =>
      _$McqOptionFromJson(json);
}

/// The student-facing view of a generated question.
///
/// Mirrors `app.models.question.QuestionForStudent` exactly. Fields
/// deliberately omitted from this shape (because they'd reveal the
/// answer): `answer`, `explanation`, `gradingHints`. Those show up in
/// `AnswerFeedback` instead, returned by the answer-submission endpoint.
@freezed
class Question with _$Question {
  const factory Question({
    required String id,
    required String topic,
    @JsonKey(name: 'question_type') required QuestionType questionType,
    required DifficultyLevel difficulty,
    required String body,
    @Default(<McqOption>[]) List<McqOption> options,
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}

/// Request body for `POST /questions/{question_id}/answer`.
///
/// `answer` is the student's response in type-specific format:
/// - mcq:           the option key — `"A"`, `"B"`, `"C"`, or `"D"`
/// - true_false:    `"true"` or `"false"`
/// - short_answer:  the 1-10 word recall response
/// - long_answer:   the essay-style response
/// - mathematical:  the final answer (LaTeX OK)
///
/// `timeSpentSeconds` is optional and feeds Sprint 5's XP boost. Set
/// it from a stopwatch on the question screen; default 0 if not
/// tracked.
@freezed
class AnswerSubmission with _$AnswerSubmission {
  const factory AnswerSubmission({
    required String answer,
    @JsonKey(name: 'time_spent_seconds') @Default(0) int timeSpentSeconds,
  }) = _AnswerSubmission;

  factory AnswerSubmission.fromJson(Map<String, dynamic> json) =>
      _$AnswerSubmissionFromJson(json);
}

/// Response body for `POST /questions/{question_id}/answer`.
///
/// This is where the answer + explanation are revealed — never on
/// the question fetch. `rubricScore` and `matchedHints` are populated
/// only for rubric-scored types (`long_answer`, `mathematical`); the
/// UI should hide that row for MCQ / T-F / short_answer where the
/// boolean is the full picture.
@freezed
class AnswerFeedback with _$AnswerFeedback {
  const factory AnswerFeedback({
    @JsonKey(name: 'question_id') required String questionId,
    @JsonKey(name: 'is_correct') required bool isCorrect,
    @JsonKey(name: 'canonical_answer') required String canonicalAnswer,
    required String explanation,
    @JsonKey(name: 'xp_earned') required int xpEarned,
    @JsonKey(name: 'new_topic_mastery') required double newTopicMastery,
    @JsonKey(name: 'new_overall_mastery') required double newOverallMastery,
    @JsonKey(name: 'rubric_score') double? rubricScore,
    @JsonKey(name: 'matched_hints')
    @Default(<String>[])
    List<String> matchedHints,
  }) = _AnswerFeedback;

  factory AnswerFeedback.fromJson(Map<String, dynamic> json) =>
      _$AnswerFeedbackFromJson(json);
}
