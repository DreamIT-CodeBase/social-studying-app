// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FlashcardImpl _$$FlashcardImplFromJson(Map<String, dynamic> json) =>
    _$FlashcardImpl(
      id: json['id'] as String,
      topic: json['topic'] as String,
      front: json['front'] as String,
      back: json['back'] as String,
      explanation: json['explanation'] as String? ?? '',
    );

Map<String, dynamic> _$$FlashcardImplToJson(_$FlashcardImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'topic': instance.topic,
      'front': instance.front,
      'back': instance.back,
      'explanation': instance.explanation,
    };

_$FlashcardRatingSubmissionImpl _$$FlashcardRatingSubmissionImplFromJson(
        Map<String, dynamic> json) =>
    _$FlashcardRatingSubmissionImpl(
      rating: $enumDecode(_$FlashcardRatingEnumMap, json['rating']),
      selectedOption: json['selected_option'] as String?,
      isCorrect: json['is_correct'] as bool?,
      responseTimeMs: (json['response_time_ms'] as num?)?.toInt(),
      sessionProgress: (json['session_progress'] as num?)?.toInt(),
      accuracyPercentage: (json['accuracy_percentage'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$FlashcardRatingSubmissionImplToJson(
        _$FlashcardRatingSubmissionImpl instance) =>
    <String, dynamic>{
      'rating': _$FlashcardRatingEnumMap[instance.rating]!,
      'selected_option': instance.selectedOption,
      'is_correct': instance.isCorrect,
      'response_time_ms': instance.responseTimeMs,
      'session_progress': instance.sessionProgress,
      'accuracy_percentage': instance.accuracyPercentage,
    };

const _$FlashcardRatingEnumMap = {
  FlashcardRating.easy: 'easy',
  FlashcardRating.medium: 'medium',
  FlashcardRating.hard: 'hard',
};

_$FlashcardRatingResponseImpl _$$FlashcardRatingResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$FlashcardRatingResponseImpl(
      flashcardId: json['flashcard_id'] as String,
      rating: $enumDecode(_$FlashcardRatingEnumMap, json['rating']),
      ratedAt: json['rated_at'] as String,
      xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      newLevel: (json['new_level'] as num?)?.toInt() ?? 1,
      leveledUp: json['leveled_up'] as bool? ?? false,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      streakExtended: json['streak_extended'] as bool? ?? false,
      badgesUnlocked: (json['badges_unlocked'] as List<dynamic>?)
              ?.map((e) =>
                  FlashcardBadgeUnlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <FlashcardBadgeUnlock>[],
    );

Map<String, dynamic> _$$FlashcardRatingResponseImplToJson(
        _$FlashcardRatingResponseImpl instance) =>
    <String, dynamic>{
      'flashcard_id': instance.flashcardId,
      'rating': _$FlashcardRatingEnumMap[instance.rating]!,
      'rated_at': instance.ratedAt,
      'xp_earned': instance.xpEarned,
      'new_level': instance.newLevel,
      'leveled_up': instance.leveledUp,
      'streak_days': instance.streakDays,
      'streak_extended': instance.streakExtended,
      'badges_unlocked': instance.badgesUnlocked,
    };

_$FlashcardBadgeUnlockImpl _$$FlashcardBadgeUnlockImplFromJson(
        Map<String, dynamic> json) =>
    _$FlashcardBadgeUnlockImpl(
      badgeId: json['badge_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
    );

Map<String, dynamic> _$$FlashcardBadgeUnlockImplToJson(
        _$FlashcardBadgeUnlockImpl instance) =>
    <String, dynamic>{
      'badge_id': instance.badgeId,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
    };
