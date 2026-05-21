// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$McqOptionImpl _$$McqOptionImplFromJson(Map<String, dynamic> json) =>
    _$McqOptionImpl(
      key: json['key'] as String,
      text: json['text'] as String,
    );

Map<String, dynamic> _$$McqOptionImplToJson(_$McqOptionImpl instance) =>
    <String, dynamic>{
      'key': instance.key,
      'text': instance.text,
    };

_$QuestionImpl _$$QuestionImplFromJson(Map<String, dynamic> json) =>
    _$QuestionImpl(
      id: json['id'] as String,
      topic: json['topic'] as String,
      questionType: $enumDecode(_$QuestionTypeEnumMap, json['question_type']),
      difficulty: $enumDecode(_$DifficultyLevelEnumMap, json['difficulty']),
      body: json['body'] as String,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => McqOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <McqOption>[],
    );

Map<String, dynamic> _$$QuestionImplToJson(_$QuestionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'topic': instance.topic,
      'question_type': _$QuestionTypeEnumMap[instance.questionType]!,
      'difficulty': _$DifficultyLevelEnumMap[instance.difficulty]!,
      'body': instance.body,
      'options': instance.options,
    };

const _$QuestionTypeEnumMap = {
  QuestionType.mcq: 'mcq',
  QuestionType.shortAnswer: 'short_answer',
  QuestionType.longAnswer: 'long_answer',
  QuestionType.trueFalse: 'true_false',
  QuestionType.mathematical: 'mathematical',
};

const _$DifficultyLevelEnumMap = {
  DifficultyLevel.beginner: 'beginner',
  DifficultyLevel.intermediate: 'intermediate',
  DifficultyLevel.advanced: 'advanced',
};

_$AnswerSubmissionImpl _$$AnswerSubmissionImplFromJson(
        Map<String, dynamic> json) =>
    _$AnswerSubmissionImpl(
      answer: json['answer'] as String,
      timeSpentSeconds: (json['time_spent_seconds'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$AnswerSubmissionImplToJson(
        _$AnswerSubmissionImpl instance) =>
    <String, dynamic>{
      'answer': instance.answer,
      'time_spent_seconds': instance.timeSpentSeconds,
    };

_$AnswerFeedbackImpl _$$AnswerFeedbackImplFromJson(Map<String, dynamic> json) =>
    _$AnswerFeedbackImpl(
      questionId: json['question_id'] as String,
      isCorrect: json['is_correct'] as bool,
      canonicalAnswer: json['canonical_answer'] as String,
      explanation: json['explanation'] as String,
      xpEarned: (json['xp_earned'] as num).toInt(),
      newTopicMastery: (json['new_topic_mastery'] as num).toDouble(),
      newOverallMastery: (json['new_overall_mastery'] as num).toDouble(),
      rubricScore: (json['rubric_score'] as num?)?.toDouble(),
      matchedHints: (json['matched_hints'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$$AnswerFeedbackImplToJson(
        _$AnswerFeedbackImpl instance) =>
    <String, dynamic>{
      'question_id': instance.questionId,
      'is_correct': instance.isCorrect,
      'canonical_answer': instance.canonicalAnswer,
      'explanation': instance.explanation,
      'xp_earned': instance.xpEarned,
      'new_topic_mastery': instance.newTopicMastery,
      'new_overall_mastery': instance.newOverallMastery,
      'rubric_score': instance.rubricScore,
      'matched_hints': instance.matchedHints,
    };
