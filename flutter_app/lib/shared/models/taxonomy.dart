// JsonKey lives on the constructor params (Freezed pattern) so the
// analyzer's invalid_annotation_target lint fires falsely. The model
// works at runtime — JsonSerializable picks up the keys correctly.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'taxonomy.freezed.dart';
part 'taxonomy.g.dart';

/// Mirrors ``app.models.workspace.CanonicalTopic`` on the backend.
///
/// One row in the workspace's canonical taxonomy. Sprint 2.6 builds these
/// by merging per-document TopicTags; Sprint 2.7 sets ``parent_id`` via
/// the dep-inference pass. The Flutter viewer (2.13) renders them as an
/// indented tree.
@freezed
class CanonicalTopic with _$CanonicalTopic {
  const factory CanonicalTopic({
    required String id,
    required String name,
    @Default(<String>[]) List<String> aliases,
    String? description,
    @JsonKey(name: 'complexity_level') double? complexityLevel,
    @JsonKey(name: 'parent_id') String? parentId,
    @JsonKey(name: 'source_document_ids')
    @Default(<String>[])
    List<String> sourceDocumentIds,
  }) = _CanonicalTopic;

  factory CanonicalTopic.fromJson(Map<String, dynamic> json) =>
      _$CanonicalTopicFromJson(json);
}

/// Mirrors ``app.models.workspace.TaxonomyResponse`` from the backend's
/// GET /workspaces/{ws}/taxonomy endpoint.
///
/// The version is the source of truth for optimistic concurrency on
/// edits (Sprint 4.3) and serves as the polling signal for the
/// regenerate flow — when the version bumps after a POST /regenerate,
/// the rebuild has completed.
@freezed
class Taxonomy with _$Taxonomy {
  const factory Taxonomy({
    @Default(<CanonicalTopic>[]) List<CanonicalTopic> topics,
    @JsonKey(name: 'taxonomy_version') @Default(0) int taxonomyVersion,
    @JsonKey(name: 'last_merged_at') String? lastMergedAt,
  }) = _Taxonomy;

  factory Taxonomy.fromJson(Map<String, dynamic> json) =>
      _$TaxonomyFromJson(json);
}
