// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TopicTag _$TopicTagFromJson(Map<String, dynamic> json) {
  return _TopicTag.fromJson(json);
}

/// @nodoc
mixin _$TopicTag {
  String get name => throw _privateConstructorUsedError;
  double get confidence => throw _privateConstructorUsedError;
  String get source => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'complexity_level')
  int? get complexityLevel => throw _privateConstructorUsedError;
  @JsonKey(name: 'page_refs')
  List<int> get pageRefs => throw _privateConstructorUsedError;

  /// Serializes this TopicTag to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TopicTag
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopicTagCopyWith<TopicTag> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopicTagCopyWith<$Res> {
  factory $TopicTagCopyWith(TopicTag value, $Res Function(TopicTag) then) =
      _$TopicTagCopyWithImpl<$Res, TopicTag>;
  @useResult
  $Res call(
      {String name,
      double confidence,
      String source,
      String? description,
      @JsonKey(name: 'complexity_level') int? complexityLevel,
      @JsonKey(name: 'page_refs') List<int> pageRefs});
}

/// @nodoc
class _$TopicTagCopyWithImpl<$Res, $Val extends TopicTag>
    implements $TopicTagCopyWith<$Res> {
  _$TopicTagCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopicTag
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? confidence = null,
    Object? source = null,
    Object? description = freezed,
    Object? complexityLevel = freezed,
    Object? pageRefs = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      complexityLevel: freezed == complexityLevel
          ? _value.complexityLevel
          : complexityLevel // ignore: cast_nullable_to_non_nullable
              as int?,
      pageRefs: null == pageRefs
          ? _value.pageRefs
          : pageRefs // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TopicTagImplCopyWith<$Res>
    implements $TopicTagCopyWith<$Res> {
  factory _$$TopicTagImplCopyWith(
          _$TopicTagImpl value, $Res Function(_$TopicTagImpl) then) =
      __$$TopicTagImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      double confidence,
      String source,
      String? description,
      @JsonKey(name: 'complexity_level') int? complexityLevel,
      @JsonKey(name: 'page_refs') List<int> pageRefs});
}

/// @nodoc
class __$$TopicTagImplCopyWithImpl<$Res>
    extends _$TopicTagCopyWithImpl<$Res, _$TopicTagImpl>
    implements _$$TopicTagImplCopyWith<$Res> {
  __$$TopicTagImplCopyWithImpl(
      _$TopicTagImpl _value, $Res Function(_$TopicTagImpl) _then)
      : super(_value, _then);

  /// Create a copy of TopicTag
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? confidence = null,
    Object? source = null,
    Object? description = freezed,
    Object? complexityLevel = freezed,
    Object? pageRefs = null,
  }) {
    return _then(_$TopicTagImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
      source: null == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      complexityLevel: freezed == complexityLevel
          ? _value.complexityLevel
          : complexityLevel // ignore: cast_nullable_to_non_nullable
              as int?,
      pageRefs: null == pageRefs
          ? _value._pageRefs
          : pageRefs // ignore: cast_nullable_to_non_nullable
              as List<int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TopicTagImpl implements _TopicTag {
  const _$TopicTagImpl(
      {required this.name,
      this.confidence = 1.0,
      this.source = 'ai',
      this.description,
      @JsonKey(name: 'complexity_level') this.complexityLevel,
      @JsonKey(name: 'page_refs') final List<int> pageRefs = const <int>[]})
      : _pageRefs = pageRefs;

  factory _$TopicTagImpl.fromJson(Map<String, dynamic> json) =>
      _$$TopicTagImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey()
  final double confidence;
  @override
  @JsonKey()
  final String source;
  @override
  final String? description;
  @override
  @JsonKey(name: 'complexity_level')
  final int? complexityLevel;
  final List<int> _pageRefs;
  @override
  @JsonKey(name: 'page_refs')
  List<int> get pageRefs {
    if (_pageRefs is EqualUnmodifiableListView) return _pageRefs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pageRefs);
  }

  @override
  String toString() {
    return 'TopicTag(name: $name, confidence: $confidence, source: $source, description: $description, complexityLevel: $complexityLevel, pageRefs: $pageRefs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopicTagImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.complexityLevel, complexityLevel) ||
                other.complexityLevel == complexityLevel) &&
            const DeepCollectionEquality().equals(other._pageRefs, _pageRefs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      confidence,
      source,
      description,
      complexityLevel,
      const DeepCollectionEquality().hash(_pageRefs));

  /// Create a copy of TopicTag
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopicTagImplCopyWith<_$TopicTagImpl> get copyWith =>
      __$$TopicTagImplCopyWithImpl<_$TopicTagImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TopicTagImplToJson(
      this,
    );
  }
}

abstract class _TopicTag implements TopicTag {
  const factory _TopicTag(
      {required final String name,
      final double confidence,
      final String source,
      final String? description,
      @JsonKey(name: 'complexity_level') final int? complexityLevel,
      @JsonKey(name: 'page_refs') final List<int> pageRefs}) = _$TopicTagImpl;

  factory _TopicTag.fromJson(Map<String, dynamic> json) =
      _$TopicTagImpl.fromJson;

  @override
  String get name;
  @override
  double get confidence;
  @override
  String get source;
  @override
  String? get description;
  @override
  @JsonKey(name: 'complexity_level')
  int? get complexityLevel;
  @override
  @JsonKey(name: 'page_refs')
  List<int> get pageRefs;

  /// Create a copy of TopicTag
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopicTagImplCopyWith<_$TopicTagImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Document _$DocumentFromJson(Map<String, dynamic> json) {
  return _Document.fromJson(json);
}

/// @nodoc
mixin _$Document {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'workspace_id')
  String get workspaceId => throw _privateConstructorUsedError;
  String get filename => throw _privateConstructorUsedError;
  @JsonKey(name: 'doc_type')
  DocumentType get docType => throw _privateConstructorUsedError;
  DocumentStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'chunk_count')
  int get chunkCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'topic_tags')
  List<TopicTag> get topicTags => throw _privateConstructorUsedError;
  @JsonKey(name: 'moderation_flagged')
  bool get moderationFlagged => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'page_count')
  int? get pageCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'text_char_count')
  int? get textCharCount => throw _privateConstructorUsedError;
  List<String> get languages => throw _privateConstructorUsedError;
  @JsonKey(name: 'processing_error')
  String? get processingError => throw _privateConstructorUsedError;
  String? get category => throw _privateConstructorUsedError;
  String? get subcategory => throw _privateConstructorUsedError;

  /// Serializes this Document to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentCopyWith<Document> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentCopyWith<$Res> {
  factory $DocumentCopyWith(Document value, $Res Function(Document) then) =
      _$DocumentCopyWithImpl<$Res, Document>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'workspace_id') String workspaceId,
      String filename,
      @JsonKey(name: 'doc_type') DocumentType docType,
      DocumentStatus status,
      @JsonKey(name: 'chunk_count') int chunkCount,
      @JsonKey(name: 'topic_tags') List<TopicTag> topicTags,
      @JsonKey(name: 'moderation_flagged') bool moderationFlagged,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'page_count') int? pageCount,
      @JsonKey(name: 'text_char_count') int? textCharCount,
      List<String> languages,
      @JsonKey(name: 'processing_error') String? processingError,
      String? category,
      String? subcategory});
}

/// @nodoc
class _$DocumentCopyWithImpl<$Res, $Val extends Document>
    implements $DocumentCopyWith<$Res> {
  _$DocumentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workspaceId = null,
    Object? filename = null,
    Object? docType = null,
    Object? status = null,
    Object? chunkCount = null,
    Object? topicTags = null,
    Object? moderationFlagged = null,
    Object? createdAt = null,
    Object? pageCount = freezed,
    Object? textCharCount = freezed,
    Object? languages = null,
    Object? processingError = freezed,
    Object? category = freezed,
    Object? subcategory = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      filename: null == filename
          ? _value.filename
          : filename // ignore: cast_nullable_to_non_nullable
              as String,
      docType: null == docType
          ? _value.docType
          : docType // ignore: cast_nullable_to_non_nullable
              as DocumentType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as DocumentStatus,
      chunkCount: null == chunkCount
          ? _value.chunkCount
          : chunkCount // ignore: cast_nullable_to_non_nullable
              as int,
      topicTags: null == topicTags
          ? _value.topicTags
          : topicTags // ignore: cast_nullable_to_non_nullable
              as List<TopicTag>,
      moderationFlagged: null == moderationFlagged
          ? _value.moderationFlagged
          : moderationFlagged // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      pageCount: freezed == pageCount
          ? _value.pageCount
          : pageCount // ignore: cast_nullable_to_non_nullable
              as int?,
      textCharCount: freezed == textCharCount
          ? _value.textCharCount
          : textCharCount // ignore: cast_nullable_to_non_nullable
              as int?,
      languages: null == languages
          ? _value.languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>,
      processingError: freezed == processingError
          ? _value.processingError
          : processingError // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      subcategory: freezed == subcategory
          ? _value.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DocumentImplCopyWith<$Res>
    implements $DocumentCopyWith<$Res> {
  factory _$$DocumentImplCopyWith(
          _$DocumentImpl value, $Res Function(_$DocumentImpl) then) =
      __$$DocumentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'workspace_id') String workspaceId,
      String filename,
      @JsonKey(name: 'doc_type') DocumentType docType,
      DocumentStatus status,
      @JsonKey(name: 'chunk_count') int chunkCount,
      @JsonKey(name: 'topic_tags') List<TopicTag> topicTags,
      @JsonKey(name: 'moderation_flagged') bool moderationFlagged,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'page_count') int? pageCount,
      @JsonKey(name: 'text_char_count') int? textCharCount,
      List<String> languages,
      @JsonKey(name: 'processing_error') String? processingError,
      String? category,
      String? subcategory});
}

/// @nodoc
class __$$DocumentImplCopyWithImpl<$Res>
    extends _$DocumentCopyWithImpl<$Res, _$DocumentImpl>
    implements _$$DocumentImplCopyWith<$Res> {
  __$$DocumentImplCopyWithImpl(
      _$DocumentImpl _value, $Res Function(_$DocumentImpl) _then)
      : super(_value, _then);

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workspaceId = null,
    Object? filename = null,
    Object? docType = null,
    Object? status = null,
    Object? chunkCount = null,
    Object? topicTags = null,
    Object? moderationFlagged = null,
    Object? createdAt = null,
    Object? pageCount = freezed,
    Object? textCharCount = freezed,
    Object? languages = null,
    Object? processingError = freezed,
    Object? category = freezed,
    Object? subcategory = freezed,
  }) {
    return _then(_$DocumentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      filename: null == filename
          ? _value.filename
          : filename // ignore: cast_nullable_to_non_nullable
              as String,
      docType: null == docType
          ? _value.docType
          : docType // ignore: cast_nullable_to_non_nullable
              as DocumentType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as DocumentStatus,
      chunkCount: null == chunkCount
          ? _value.chunkCount
          : chunkCount // ignore: cast_nullable_to_non_nullable
              as int,
      topicTags: null == topicTags
          ? _value._topicTags
          : topicTags // ignore: cast_nullable_to_non_nullable
              as List<TopicTag>,
      moderationFlagged: null == moderationFlagged
          ? _value.moderationFlagged
          : moderationFlagged // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String,
      pageCount: freezed == pageCount
          ? _value.pageCount
          : pageCount // ignore: cast_nullable_to_non_nullable
              as int?,
      textCharCount: freezed == textCharCount
          ? _value.textCharCount
          : textCharCount // ignore: cast_nullable_to_non_nullable
              as int?,
      languages: null == languages
          ? _value._languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>,
      processingError: freezed == processingError
          ? _value.processingError
          : processingError // ignore: cast_nullable_to_non_nullable
              as String?,
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String?,
      subcategory: freezed == subcategory
          ? _value.subcategory
          : subcategory // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DocumentImpl implements _Document {
  const _$DocumentImpl(
      {required this.id,
      @JsonKey(name: 'workspace_id') required this.workspaceId,
      required this.filename,
      @JsonKey(name: 'doc_type') required this.docType,
      required this.status,
      @JsonKey(name: 'chunk_count') this.chunkCount = 0,
      @JsonKey(name: 'topic_tags')
      final List<TopicTag> topicTags = const <TopicTag>[],
      @JsonKey(name: 'moderation_flagged') this.moderationFlagged = false,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'page_count') this.pageCount,
      @JsonKey(name: 'text_char_count') this.textCharCount,
      final List<String> languages = const <String>[],
      @JsonKey(name: 'processing_error') this.processingError,
      this.category,
      this.subcategory})
      : _topicTags = topicTags,
        _languages = languages;

  factory _$DocumentImpl.fromJson(Map<String, dynamic> json) =>
      _$$DocumentImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'workspace_id')
  final String workspaceId;
  @override
  final String filename;
  @override
  @JsonKey(name: 'doc_type')
  final DocumentType docType;
  @override
  final DocumentStatus status;
  @override
  @JsonKey(name: 'chunk_count')
  final int chunkCount;
  final List<TopicTag> _topicTags;
  @override
  @JsonKey(name: 'topic_tags')
  List<TopicTag> get topicTags {
    if (_topicTags is EqualUnmodifiableListView) return _topicTags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topicTags);
  }

  @override
  @JsonKey(name: 'moderation_flagged')
  final bool moderationFlagged;
  @override
  @JsonKey(name: 'created_at')
  final String createdAt;
  @override
  @JsonKey(name: 'page_count')
  final int? pageCount;
  @override
  @JsonKey(name: 'text_char_count')
  final int? textCharCount;
  final List<String> _languages;
  @override
  @JsonKey()
  List<String> get languages {
    if (_languages is EqualUnmodifiableListView) return _languages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_languages);
  }

  @override
  @JsonKey(name: 'processing_error')
  final String? processingError;
  @override
  final String? category;
  @override
  final String? subcategory;

  @override
  String toString() {
    return 'Document(id: $id, workspaceId: $workspaceId, filename: $filename, docType: $docType, status: $status, chunkCount: $chunkCount, topicTags: $topicTags, moderationFlagged: $moderationFlagged, createdAt: $createdAt, pageCount: $pageCount, textCharCount: $textCharCount, languages: $languages, processingError: $processingError, category: $category, subcategory: $subcategory)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workspaceId, workspaceId) ||
                other.workspaceId == workspaceId) &&
            (identical(other.filename, filename) ||
                other.filename == filename) &&
            (identical(other.docType, docType) || other.docType == docType) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.chunkCount, chunkCount) ||
                other.chunkCount == chunkCount) &&
            const DeepCollectionEquality()
                .equals(other._topicTags, _topicTags) &&
            (identical(other.moderationFlagged, moderationFlagged) ||
                other.moderationFlagged == moderationFlagged) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.pageCount, pageCount) ||
                other.pageCount == pageCount) &&
            (identical(other.textCharCount, textCharCount) ||
                other.textCharCount == textCharCount) &&
            const DeepCollectionEquality()
                .equals(other._languages, _languages) &&
            (identical(other.processingError, processingError) ||
                other.processingError == processingError) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.subcategory, subcategory) ||
                other.subcategory == subcategory));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      workspaceId,
      filename,
      docType,
      status,
      chunkCount,
      const DeepCollectionEquality().hash(_topicTags),
      moderationFlagged,
      createdAt,
      pageCount,
      textCharCount,
      const DeepCollectionEquality().hash(_languages),
      processingError,
      category,
      subcategory);

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentImplCopyWith<_$DocumentImpl> get copyWith =>
      __$$DocumentImplCopyWithImpl<_$DocumentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DocumentImplToJson(
      this,
    );
  }
}

abstract class _Document implements Document {
  const factory _Document(
      {required final String id,
      @JsonKey(name: 'workspace_id') required final String workspaceId,
      required final String filename,
      @JsonKey(name: 'doc_type') required final DocumentType docType,
      required final DocumentStatus status,
      @JsonKey(name: 'chunk_count') final int chunkCount,
      @JsonKey(name: 'topic_tags') final List<TopicTag> topicTags,
      @JsonKey(name: 'moderation_flagged') final bool moderationFlagged,
      @JsonKey(name: 'created_at') required final String createdAt,
      @JsonKey(name: 'page_count') final int? pageCount,
      @JsonKey(name: 'text_char_count') final int? textCharCount,
      final List<String> languages,
      @JsonKey(name: 'processing_error') final String? processingError,
      final String? category,
      final String? subcategory}) = _$DocumentImpl;

  factory _Document.fromJson(Map<String, dynamic> json) =
      _$DocumentImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'workspace_id')
  String get workspaceId;
  @override
  String get filename;
  @override
  @JsonKey(name: 'doc_type')
  DocumentType get docType;
  @override
  DocumentStatus get status;
  @override
  @JsonKey(name: 'chunk_count')
  int get chunkCount;
  @override
  @JsonKey(name: 'topic_tags')
  List<TopicTag> get topicTags;
  @override
  @JsonKey(name: 'moderation_flagged')
  bool get moderationFlagged;
  @override
  @JsonKey(name: 'created_at')
  String get createdAt;
  @override
  @JsonKey(name: 'page_count')
  int? get pageCount;
  @override
  @JsonKey(name: 'text_char_count')
  int? get textCharCount;
  @override
  List<String> get languages;
  @override
  @JsonKey(name: 'processing_error')
  String? get processingError;
  @override
  String? get category;
  @override
  String? get subcategory;

  /// Create a copy of Document
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentImplCopyWith<_$DocumentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
