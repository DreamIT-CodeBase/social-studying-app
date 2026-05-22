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
    );

Map<String, dynamic> _$$FlashcardRatingSubmissionImplToJson(
        _$FlashcardRatingSubmissionImpl instance) =>
    <String, dynamic>{
      'rating': _$FlashcardRatingEnumMap[instance.rating]!,
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
    );

Map<String, dynamic> _$$FlashcardRatingResponseImplToJson(
        _$FlashcardRatingResponseImpl instance) =>
    <String, dynamic>{
      'flashcard_id': instance.flashcardId,
      'rating': _$FlashcardRatingEnumMap[instance.rating]!,
      'rated_at': instance.ratedAt,
    };
