// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'taxonomy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CanonicalTopic _$CanonicalTopicFromJson(Map<String, dynamic> json) {
  return _CanonicalTopic.fromJson(json);
}

/// @nodoc
mixin _$CanonicalTopic {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<String> get aliases => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'complexity_level')
  double? get complexityLevel => throw _privateConstructorUsedError;
  @JsonKey(name: 'parent_id')
  String? get parentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_document_ids')
  List<String> get sourceDocumentIds => throw _privateConstructorUsedError;

  /// Serializes this CanonicalTopic to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CanonicalTopic
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CanonicalTopicCopyWith<CanonicalTopic> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CanonicalTopicCopyWith<$Res> {
  factory $CanonicalTopicCopyWith(
          CanonicalTopic value, $Res Function(CanonicalTopic) then) =
      _$CanonicalTopicCopyWithImpl<$Res, CanonicalTopic>;
  @useResult
  $Res call(
      {String id,
      String name,
      List<String> aliases,
      String? description,
      @JsonKey(name: 'complexity_level') double? complexityLevel,
      @JsonKey(name: 'parent_id') String? parentId,
      @JsonKey(name: 'source_document_ids') List<String> sourceDocumentIds});
}

/// @nodoc
class _$CanonicalTopicCopyWithImpl<$Res, $Val extends CanonicalTopic>
    implements $CanonicalTopicCopyWith<$Res> {
  _$CanonicalTopicCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CanonicalTopic
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? aliases = null,
    Object? description = freezed,
    Object? complexityLevel = freezed,
    Object? parentId = freezed,
    Object? sourceDocumentIds = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      aliases: null == aliases
          ? _value.aliases
          : aliases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      complexityLevel: freezed == complexityLevel
          ? _value.complexityLevel
          : complexityLevel // ignore: cast_nullable_to_non_nullable
              as double?,
      parentId: freezed == parentId
          ? _value.parentId
          : parentId // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceDocumentIds: null == sourceDocumentIds
          ? _value.sourceDocumentIds
          : sourceDocumentIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CanonicalTopicImplCopyWith<$Res>
    implements $CanonicalTopicCopyWith<$Res> {
  factory _$$CanonicalTopicImplCopyWith(_$CanonicalTopicImpl value,
          $Res Function(_$CanonicalTopicImpl) then) =
      __$$CanonicalTopicImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      List<String> aliases,
      String? description,
      @JsonKey(name: 'complexity_level') double? complexityLevel,
      @JsonKey(name: 'parent_id') String? parentId,
      @JsonKey(name: 'source_document_ids') List<String> sourceDocumentIds});
}

/// @nodoc
class __$$CanonicalTopicImplCopyWithImpl<$Res>
    extends _$CanonicalTopicCopyWithImpl<$Res, _$CanonicalTopicImpl>
    implements _$$CanonicalTopicImplCopyWith<$Res> {
  __$$CanonicalTopicImplCopyWithImpl(
      _$CanonicalTopicImpl _value, $Res Function(_$CanonicalTopicImpl) _then)
      : super(_value, _then);

  /// Create a copy of CanonicalTopic
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? aliases = null,
    Object? description = freezed,
    Object? complexityLevel = freezed,
    Object? parentId = freezed,
    Object? sourceDocumentIds = null,
  }) {
    return _then(_$CanonicalTopicImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      aliases: null == aliases
          ? _value._aliases
          : aliases // ignore: cast_nullable_to_non_nullable
              as List<String>,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      complexityLevel: freezed == complexityLevel
          ? _value.complexityLevel
          : complexityLevel // ignore: cast_nullable_to_non_nullable
              as double?,
      parentId: freezed == parentId
          ? _value.parentId
          : parentId // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceDocumentIds: null == sourceDocumentIds
          ? _value._sourceDocumentIds
          : sourceDocumentIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CanonicalTopicImpl implements _CanonicalTopic {
  const _$CanonicalTopicImpl(
      {required this.id,
      required this.name,
      final List<String> aliases = const <String>[],
      this.description,
      @JsonKey(name: 'complexity_level') this.complexityLevel,
      @JsonKey(name: 'parent_id') this.parentId,
      @JsonKey(name: 'source_document_ids')
      final List<String> sourceDocumentIds = const <String>[]})
      : _aliases = aliases,
        _sourceDocumentIds = sourceDocumentIds;

  factory _$CanonicalTopicImpl.fromJson(Map<String, dynamic> json) =>
      _$$CanonicalTopicImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final List<String> _aliases;
  @override
  @JsonKey()
  List<String> get aliases {
    if (_aliases is EqualUnmodifiableListView) return _aliases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_aliases);
  }

  @override
  final String? description;
  @override
  @JsonKey(name: 'complexity_level')
  final double? complexityLevel;
  @override
  @JsonKey(name: 'parent_id')
  final String? parentId;
  final List<String> _sourceDocumentIds;
  @override
  @JsonKey(name: 'source_document_ids')
  List<String> get sourceDocumentIds {
    if (_sourceDocumentIds is EqualUnmodifiableListView)
      return _sourceDocumentIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sourceDocumentIds);
  }

  @override
  String toString() {
    return 'CanonicalTopic(id: $id, name: $name, aliases: $aliases, description: $description, complexityLevel: $complexityLevel, parentId: $parentId, sourceDocumentIds: $sourceDocumentIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CanonicalTopicImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._aliases, _aliases) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.complexityLevel, complexityLevel) ||
                other.complexityLevel == complexityLevel) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            const DeepCollectionEquality()
                .equals(other._sourceDocumentIds, _sourceDocumentIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      const DeepCollectionEquality().hash(_aliases),
      description,
      complexityLevel,
      parentId,
      const DeepCollectionEquality().hash(_sourceDocumentIds));

  /// Create a copy of CanonicalTopic
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CanonicalTopicImplCopyWith<_$CanonicalTopicImpl> get copyWith =>
      __$$CanonicalTopicImplCopyWithImpl<_$CanonicalTopicImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CanonicalTopicImplToJson(
      this,
    );
  }
}

abstract class _CanonicalTopic implements CanonicalTopic {
  const factory _CanonicalTopic(
      {required final String id,
      required final String name,
      final List<String> aliases,
      final String? description,
      @JsonKey(name: 'complexity_level') final double? complexityLevel,
      @JsonKey(name: 'parent_id') final String? parentId,
      @JsonKey(name: 'source_document_ids')
      final List<String> sourceDocumentIds}) = _$CanonicalTopicImpl;

  factory _CanonicalTopic.fromJson(Map<String, dynamic> json) =
      _$CanonicalTopicImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  List<String> get aliases;
  @override
  String? get description;
  @override
  @JsonKey(name: 'complexity_level')
  double? get complexityLevel;
  @override
  @JsonKey(name: 'parent_id')
  String? get parentId;
  @override
  @JsonKey(name: 'source_document_ids')
  List<String> get sourceDocumentIds;

  /// Create a copy of CanonicalTopic
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CanonicalTopicImplCopyWith<_$CanonicalTopicImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Taxonomy _$TaxonomyFromJson(Map<String, dynamic> json) {
  return _Taxonomy.fromJson(json);
}

/// @nodoc
mixin _$Taxonomy {
  List<CanonicalTopic> get topics => throw _privateConstructorUsedError;
  @JsonKey(name: 'taxonomy_version')
  int get taxonomyVersion => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_merged_at')
  String? get lastMergedAt => throw _privateConstructorUsedError;

  /// Serializes this Taxonomy to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Taxonomy
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaxonomyCopyWith<Taxonomy> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaxonomyCopyWith<$Res> {
  factory $TaxonomyCopyWith(Taxonomy value, $Res Function(Taxonomy) then) =
      _$TaxonomyCopyWithImpl<$Res, Taxonomy>;
  @useResult
  $Res call(
      {List<CanonicalTopic> topics,
      @JsonKey(name: 'taxonomy_version') int taxonomyVersion,
      @JsonKey(name: 'last_merged_at') String? lastMergedAt});
}

/// @nodoc
class _$TaxonomyCopyWithImpl<$Res, $Val extends Taxonomy>
    implements $TaxonomyCopyWith<$Res> {
  _$TaxonomyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Taxonomy
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topics = null,
    Object? taxonomyVersion = null,
    Object? lastMergedAt = freezed,
  }) {
    return _then(_value.copyWith(
      topics: null == topics
          ? _value.topics
          : topics // ignore: cast_nullable_to_non_nullable
              as List<CanonicalTopic>,
      taxonomyVersion: null == taxonomyVersion
          ? _value.taxonomyVersion
          : taxonomyVersion // ignore: cast_nullable_to_non_nullable
              as int,
      lastMergedAt: freezed == lastMergedAt
          ? _value.lastMergedAt
          : lastMergedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaxonomyImplCopyWith<$Res>
    implements $TaxonomyCopyWith<$Res> {
  factory _$$TaxonomyImplCopyWith(
          _$TaxonomyImpl value, $Res Function(_$TaxonomyImpl) then) =
      __$$TaxonomyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<CanonicalTopic> topics,
      @JsonKey(name: 'taxonomy_version') int taxonomyVersion,
      @JsonKey(name: 'last_merged_at') String? lastMergedAt});
}

/// @nodoc
class __$$TaxonomyImplCopyWithImpl<$Res>
    extends _$TaxonomyCopyWithImpl<$Res, _$TaxonomyImpl>
    implements _$$TaxonomyImplCopyWith<$Res> {
  __$$TaxonomyImplCopyWithImpl(
      _$TaxonomyImpl _value, $Res Function(_$TaxonomyImpl) _then)
      : super(_value, _then);

  /// Create a copy of Taxonomy
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topics = null,
    Object? taxonomyVersion = null,
    Object? lastMergedAt = freezed,
  }) {
    return _then(_$TaxonomyImpl(
      topics: null == topics
          ? _value._topics
          : topics // ignore: cast_nullable_to_non_nullable
              as List<CanonicalTopic>,
      taxonomyVersion: null == taxonomyVersion
          ? _value.taxonomyVersion
          : taxonomyVersion // ignore: cast_nullable_to_non_nullable
              as int,
      lastMergedAt: freezed == lastMergedAt
          ? _value.lastMergedAt
          : lastMergedAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaxonomyImpl implements _Taxonomy {
  const _$TaxonomyImpl(
      {final List<CanonicalTopic> topics = const <CanonicalTopic>[],
      @JsonKey(name: 'taxonomy_version') this.taxonomyVersion = 0,
      @JsonKey(name: 'last_merged_at') this.lastMergedAt})
      : _topics = topics;

  factory _$TaxonomyImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaxonomyImplFromJson(json);

  final List<CanonicalTopic> _topics;
  @override
  @JsonKey()
  List<CanonicalTopic> get topics {
    if (_topics is EqualUnmodifiableListView) return _topics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topics);
  }

  @override
  @JsonKey(name: 'taxonomy_version')
  final int taxonomyVersion;
  @override
  @JsonKey(name: 'last_merged_at')
  final String? lastMergedAt;

  @override
  String toString() {
    return 'Taxonomy(topics: $topics, taxonomyVersion: $taxonomyVersion, lastMergedAt: $lastMergedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaxonomyImpl &&
            const DeepCollectionEquality().equals(other._topics, _topics) &&
            (identical(other.taxonomyVersion, taxonomyVersion) ||
                other.taxonomyVersion == taxonomyVersion) &&
            (identical(other.lastMergedAt, lastMergedAt) ||
                other.lastMergedAt == lastMergedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_topics),
      taxonomyVersion,
      lastMergedAt);

  /// Create a copy of Taxonomy
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaxonomyImplCopyWith<_$TaxonomyImpl> get copyWith =>
      __$$TaxonomyImplCopyWithImpl<_$TaxonomyImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaxonomyImplToJson(
      this,
    );
  }
}

abstract class _Taxonomy implements Taxonomy {
  const factory _Taxonomy(
          {final List<CanonicalTopic> topics,
          @JsonKey(name: 'taxonomy_version') final int taxonomyVersion,
          @JsonKey(name: 'last_merged_at') final String? lastMergedAt}) =
      _$TaxonomyImpl;

  factory _Taxonomy.fromJson(Map<String, dynamic> json) =
      _$TaxonomyImpl.fromJson;

  @override
  List<CanonicalTopic> get topics;
  @override
  @JsonKey(name: 'taxonomy_version')
  int get taxonomyVersion;
  @override
  @JsonKey(name: 'last_merged_at')
  String? get lastMergedAt;

  /// Create a copy of Taxonomy
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaxonomyImplCopyWith<_$TaxonomyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
