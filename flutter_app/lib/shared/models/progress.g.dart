// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TopicMasteryImpl _$$TopicMasteryImplFromJson(Map<String, dynamic> json) =>
    _$TopicMasteryImpl(
      topicId: json['topic_id'] as String,
      topicName: json['topic_name'] as String,
      mastery: (json['mastery'] as num).toDouble(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      successRate: (json['success_rate'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$TopicMasteryImplToJson(_$TopicMasteryImpl instance) =>
    <String, dynamic>{
      'topic_id': instance.topicId,
      'topic_name': instance.topicName,
      'mastery': instance.mastery,
      'attempts': instance.attempts,
      'success_rate': instance.successRate,
    };

_$ActivityEntryImpl _$$ActivityEntryImplFromJson(Map<String, dynamic> json) =>
    _$ActivityEntryImpl(
      kind: $enumDecode(_$ActivityKindEnumMap, json['kind']),
      topic: json['topic'] as String,
      isCorrect: json['is_correct'] as bool?,
      xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      occurredAt: json['occurred_at'] as String,
    );

Map<String, dynamic> _$$ActivityEntryImplToJson(_$ActivityEntryImpl instance) =>
    <String, dynamic>{
      'kind': _$ActivityKindEnumMap[instance.kind]!,
      'topic': instance.topic,
      'is_correct': instance.isCorrect,
      'xp_earned': instance.xpEarned,
      'occurred_at': instance.occurredAt,
    };

const _$ActivityKindEnumMap = {
  ActivityKind.question: 'question',
  ActivityKind.flashcard: 'flashcard',
};

_$StudentProgressImpl _$$StudentProgressImplFromJson(
        Map<String, dynamic> json) =>
    _$StudentProgressImpl(
      level: (json['level'] as num).toInt(),
      totalXp: (json['total_xp'] as num).toInt(),
      xpIntoLevel: (json['xp_into_level'] as num).toInt(),
      xpForNextLevel: (json['xp_for_next_level'] as num).toInt(),
      overallMastery: (json['overall_mastery'] as num).toDouble(),
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => TopicMastery.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TopicMastery>[],
      recentActivity: (json['recent_activity'] as List<dynamic>?)
              ?.map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ActivityEntry>[],
    );

Map<String, dynamic> _$$StudentProgressImplToJson(
        _$StudentProgressImpl instance) =>
    <String, dynamic>{
      'level': instance.level,
      'total_xp': instance.totalXp,
      'xp_into_level': instance.xpIntoLevel,
      'xp_for_next_level': instance.xpForNextLevel,
      'overall_mastery': instance.overallMastery,
      'topics': instance.topics,
      'recent_activity': instance.recentActivity,
    };
