// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moderation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FlaggedItemImpl _$$FlaggedItemImplFromJson(Map<String, dynamic> json) =>
    _$FlaggedItemImpl(
      id: json['id'] as String,
      contentKind:
          $enumDecode(_$FlaggedContentKindEnumMap, json['content_kind']),
      topic: json['topic'] as String,
      excerpt: json['excerpt'] as String,
      reason: json['reason'] as String,
      severity: (json['severity'] as num?)?.toInt() ?? 0,
      flaggedAt: json['flagged_at'] as String,
      verdict:
          $enumDecodeNullable(_$ModerationVerdictEnumMap, json['verdict']) ??
              ModerationVerdict.pending,
    );

Map<String, dynamic> _$$FlaggedItemImplToJson(_$FlaggedItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content_kind': _$FlaggedContentKindEnumMap[instance.contentKind]!,
      'topic': instance.topic,
      'excerpt': instance.excerpt,
      'reason': instance.reason,
      'severity': instance.severity,
      'flagged_at': instance.flaggedAt,
      'verdict': _$ModerationVerdictEnumMap[instance.verdict]!,
    };

const _$FlaggedContentKindEnumMap = {
  FlaggedContentKind.question: 'question',
  FlaggedContentKind.flashcard: 'flashcard',
  FlaggedContentKind.document: 'document',
};

const _$ModerationVerdictEnumMap = {
  ModerationVerdict.pending: 'pending',
  ModerationVerdict.approved: 'approved',
  ModerationVerdict.rejected: 'rejected',
};
