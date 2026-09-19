// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TopicTagImpl _$$TopicTagImplFromJson(Map<String, dynamic> json) =>
    _$TopicTagImpl(
      name: json['name'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      source: json['source'] as String? ?? 'ai',
      description: json['description'] as String?,
      complexityLevel: (json['complexity_level'] as num?)?.toInt(),
      pageRefs: (json['page_refs'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
    );

Map<String, dynamic> _$$TopicTagImplToJson(_$TopicTagImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'confidence': instance.confidence,
      'source': instance.source,
      'description': instance.description,
      'complexity_level': instance.complexityLevel,
      'page_refs': instance.pageRefs,
    };

_$DocumentImpl _$$DocumentImplFromJson(Map<String, dynamic> json) =>
    _$DocumentImpl(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      filename: json['filename'] as String,
      docType: $enumDecode(_$DocumentTypeEnumMap, json['doc_type']),
      status: $enumDecode(_$DocumentStatusEnumMap, json['status']),
      chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 0,
      topicTags: (json['topic_tags'] as List<dynamic>?)
              ?.map((e) => TopicTag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TopicTag>[],
      moderationFlagged: json['moderation_flagged'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      pageCount: (json['page_count'] as num?)?.toInt(),
      textCharCount: (json['text_char_count'] as num?)?.toInt(),
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      processingError: json['processing_error'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
    );

Map<String, dynamic> _$$DocumentImplToJson(_$DocumentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workspace_id': instance.workspaceId,
      'filename': instance.filename,
      'doc_type': _$DocumentTypeEnumMap[instance.docType]!,
      'status': _$DocumentStatusEnumMap[instance.status]!,
      'chunk_count': instance.chunkCount,
      'topic_tags': instance.topicTags,
      'moderation_flagged': instance.moderationFlagged,
      'created_at': instance.createdAt,
      'page_count': instance.pageCount,
      'text_char_count': instance.textCharCount,
      'languages': instance.languages,
      'processing_error': instance.processingError,
      'category': instance.category,
      'subcategory': instance.subcategory,
    };

const _$DocumentTypeEnumMap = {
  DocumentType.pdf: 'pdf',
  DocumentType.docx: 'docx',
  DocumentType.image: 'image',
  DocumentType.text: 'text',
};

const _$DocumentStatusEnumMap = {
  DocumentStatus.pending: 'pending',
  DocumentStatus.extracting: 'extracting',
  DocumentStatus.textExtracted: 'text_extracted',
  DocumentStatus.extractingTopics: 'extracting_topics',
  DocumentStatus.topicsExtracted: 'topics_extracted',
  DocumentStatus.chunking: 'chunking',
  DocumentStatus.chunked: 'chunked',
  DocumentStatus.vectorizing: 'vectorizing',
  DocumentStatus.ready: 'ready',
  DocumentStatus.flagged: 'flagged',
  DocumentStatus.failed: 'failed',
};
