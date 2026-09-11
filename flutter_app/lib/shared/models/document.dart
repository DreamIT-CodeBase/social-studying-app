// JsonKey lives on the constructor params (Freezed pattern) so the
// analyzer's invalid_annotation_target lint fires falsely. The model
// works at runtime — JsonSerializable picks up the keys correctly.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';
part 'document.g.dart';

/// Mirrors `app.models.document.DocumentStatus` on the backend.
///
/// Names use snake_case to match the Python enum's wire format. The
/// `@JsonValue` annotations are explicit so a backend rename can't
/// silently break Flutter parsing.
enum DocumentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('extracting')
  extracting,
  @JsonValue('text_extracted')
  textExtracted,
  @JsonValue('extracting_topics')
  extractingTopics,
  @JsonValue('topics_extracted')
  topicsExtracted,
  @JsonValue('chunking')
  chunking,
  @JsonValue('chunked')
  chunked,
  @JsonValue('vectorizing')
  vectorizing,
  @JsonValue('ready')
  ready,
  @JsonValue('flagged')
  flagged,
  @JsonValue('failed')
  failed;

  /// Polling stops once status reaches a terminal value. Using a single
  /// switch instead of a Set keeps the compiler honest when new statuses
  /// land — adding a value forces the switch to be revisited.
  bool get isTerminal => switch (this) {
        DocumentStatus.ready => true,
        DocumentStatus.flagged => true,
        DocumentStatus.failed => true,
        DocumentStatus.pending ||
        DocumentStatus.extracting ||
        DocumentStatus.textExtracted ||
        DocumentStatus.extractingTopics ||
        DocumentStatus.topicsExtracted ||
        DocumentStatus.chunking ||
        DocumentStatus.chunked ||
        DocumentStatus.vectorizing =>
          false,
      };

  /// Returns true if document is ready or has topics/chunks available for study sessions.
  bool get isUsableForStudy => switch (this) {
        DocumentStatus.ready ||
        DocumentStatus.vectorizing ||
        DocumentStatus.chunked ||
        DocumentStatus.topicsExtracted =>
          true,
        _ => false,
      };
}

enum DocumentType {
  @JsonValue('pdf')
  pdf,
  @JsonValue('docx')
  docx,
  @JsonValue('image')
  image,
  @JsonValue('text')
  text,
}

@freezed
class TopicTag with _$TopicTag {
  const factory TopicTag({
    required String name,
    @Default(1.0) double confidence,
    @Default('ai') String source,
    String? description,
    @JsonKey(name: 'complexity_level') int? complexityLevel,
    @Default(<int>[]) @JsonKey(name: 'page_refs') List<int> pageRefs,
  }) = _TopicTag;

  factory TopicTag.fromJson(Map<String, dynamic> json) =>
      _$TopicTagFromJson(json);
}

@freezed
class Document with _$Document {
  const factory Document({
    required String id,
    @JsonKey(name: 'workspace_id') required String workspaceId,
    required String filename,
    @JsonKey(name: 'doc_type') required DocumentType docType,
    required DocumentStatus status,
    @JsonKey(name: 'chunk_count') @Default(0) int chunkCount,
    @JsonKey(name: 'topic_tags')
    @Default(<TopicTag>[])
    List<TopicTag> topicTags,
    @JsonKey(name: 'moderation_flagged') @Default(false) bool moderationFlagged,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'page_count') int? pageCount,
    @JsonKey(name: 'text_char_count') int? textCharCount,
    @Default(<String>[]) List<String> languages,
    @JsonKey(name: 'processing_error') String? processingError,
    String? category,
    String? subcategory,
  }) = _Document;

  factory Document.fromJson(Map<String, dynamic> json) =>
      _$DocumentFromJson(json);
}
