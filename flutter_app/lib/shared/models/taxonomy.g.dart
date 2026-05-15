// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taxonomy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CanonicalTopicImpl _$$CanonicalTopicImplFromJson(Map<String, dynamic> json) =>
    _$CanonicalTopicImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      aliases: (json['aliases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      description: json['description'] as String?,
      complexityLevel: (json['complexity_level'] as num?)?.toDouble(),
      parentId: json['parent_id'] as String?,
      sourceDocumentIds: (json['source_document_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$$CanonicalTopicImplToJson(
        _$CanonicalTopicImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'aliases': instance.aliases,
      'description': instance.description,
      'complexity_level': instance.complexityLevel,
      'parent_id': instance.parentId,
      'source_document_ids': instance.sourceDocumentIds,
    };

_$TaxonomyImpl _$$TaxonomyImplFromJson(Map<String, dynamic> json) =>
    _$TaxonomyImpl(
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => CanonicalTopic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CanonicalTopic>[],
      taxonomyVersion: (json['taxonomy_version'] as num?)?.toInt() ?? 0,
      lastMergedAt: json['last_merged_at'] as String?,
    );

Map<String, dynamic> _$$TaxonomyImplToJson(_$TaxonomyImpl instance) =>
    <String, dynamic>{
      'topics': instance.topics,
      'taxonomy_version': instance.taxonomyVersion,
      'last_merged_at': instance.lastMergedAt,
    };
