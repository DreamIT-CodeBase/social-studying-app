// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'moderation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FlaggedItem _$FlaggedItemFromJson(Map<String, dynamic> json) {
  return _FlaggedItem.fromJson(json);
}

/// @nodoc
mixin _$FlaggedItem {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'content_kind')
  FlaggedContentKind get contentKind => throw _privateConstructorUsedError;

  /// The topic the flagged content belongs to.
  String get topic => throw _privateConstructorUsedError;

  /// A short snippet of the flagged content for the admin to judge —
  /// never the full document text.
  String get excerpt => throw _privateConstructorUsedError;

  /// Human-readable reason — the Content Safety category that tripped
  /// (e.g. "Violence", "Hate").
  String get reason => throw _privateConstructorUsedError;

  /// Azure Content Safety severity, 0–6. Higher is more severe.
  int get severity => throw _privateConstructorUsedError;
  @JsonKey(name: 'flagged_at')
  String get flaggedAt => throw _privateConstructorUsedError;
  ModerationVerdict get verdict => throw _privateConstructorUsedError;

  /// Serializes this FlaggedItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlaggedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlaggedItemCopyWith<FlaggedItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlaggedItemCopyWith<$Res> {
  factory $FlaggedItemCopyWith(
          FlaggedItem value, $Res Function(FlaggedItem) then) =
      _$FlaggedItemCopyWithImpl<$Res, FlaggedItem>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'content_kind') FlaggedContentKind contentKind,
      String topic,
      String excerpt,
      String reason,
      int severity,
      @JsonKey(name: 'flagged_at') String flaggedAt,
      ModerationVerdict verdict});
}

/// @nodoc
class _$FlaggedItemCopyWithImpl<$Res, $Val extends FlaggedItem>
    implements $FlaggedItemCopyWith<$Res> {
  _$FlaggedItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlaggedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? contentKind = null,
    Object? topic = null,
    Object? excerpt = null,
    Object? reason = null,
    Object? severity = null,
    Object? flaggedAt = null,
    Object? verdict = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      contentKind: null == contentKind
          ? _value.contentKind
          : contentKind // ignore: cast_nullable_to_non_nullable
              as FlaggedContentKind,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      excerpt: null == excerpt
          ? _value.excerpt
          : excerpt // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as int,
      flaggedAt: null == flaggedAt
          ? _value.flaggedAt
          : flaggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      verdict: null == verdict
          ? _value.verdict
          : verdict // ignore: cast_nullable_to_non_nullable
              as ModerationVerdict,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlaggedItemImplCopyWith<$Res>
    implements $FlaggedItemCopyWith<$Res> {
  factory _$$FlaggedItemImplCopyWith(
          _$FlaggedItemImpl value, $Res Function(_$FlaggedItemImpl) then) =
      __$$FlaggedItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'content_kind') FlaggedContentKind contentKind,
      String topic,
      String excerpt,
      String reason,
      int severity,
      @JsonKey(name: 'flagged_at') String flaggedAt,
      ModerationVerdict verdict});
}

/// @nodoc
class __$$FlaggedItemImplCopyWithImpl<$Res>
    extends _$FlaggedItemCopyWithImpl<$Res, _$FlaggedItemImpl>
    implements _$$FlaggedItemImplCopyWith<$Res> {
  __$$FlaggedItemImplCopyWithImpl(
      _$FlaggedItemImpl _value, $Res Function(_$FlaggedItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlaggedItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? contentKind = null,
    Object? topic = null,
    Object? excerpt = null,
    Object? reason = null,
    Object? severity = null,
    Object? flaggedAt = null,
    Object? verdict = null,
  }) {
    return _then(_$FlaggedItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      contentKind: null == contentKind
          ? _value.contentKind
          : contentKind // ignore: cast_nullable_to_non_nullable
              as FlaggedContentKind,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      excerpt: null == excerpt
          ? _value.excerpt
          : excerpt // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as int,
      flaggedAt: null == flaggedAt
          ? _value.flaggedAt
          : flaggedAt // ignore: cast_nullable_to_non_nullable
              as String,
      verdict: null == verdict
          ? _value.verdict
          : verdict // ignore: cast_nullable_to_non_nullable
              as ModerationVerdict,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlaggedItemImpl extends _FlaggedItem {
  const _$FlaggedItemImpl(
      {required this.id,
      @JsonKey(name: 'content_kind') required this.contentKind,
      required this.topic,
      required this.excerpt,
      required this.reason,
      this.severity = 0,
      @JsonKey(name: 'flagged_at') required this.flaggedAt,
      this.verdict = ModerationVerdict.pending})
      : super._();

  factory _$FlaggedItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlaggedItemImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'content_kind')
  final FlaggedContentKind contentKind;

  /// The topic the flagged content belongs to.
  @override
  final String topic;

  /// A short snippet of the flagged content for the admin to judge —
  /// never the full document text.
  @override
  final String excerpt;

  /// Human-readable reason — the Content Safety category that tripped
  /// (e.g. "Violence", "Hate").
  @override
  final String reason;

  /// Azure Content Safety severity, 0–6. Higher is more severe.
  @override
  @JsonKey()
  final int severity;
  @override
  @JsonKey(name: 'flagged_at')
  final String flaggedAt;
  @override
  @JsonKey()
  final ModerationVerdict verdict;

  @override
  String toString() {
    return 'FlaggedItem(id: $id, contentKind: $contentKind, topic: $topic, excerpt: $excerpt, reason: $reason, severity: $severity, flaggedAt: $flaggedAt, verdict: $verdict)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlaggedItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.contentKind, contentKind) ||
                other.contentKind == contentKind) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.excerpt, excerpt) || other.excerpt == excerpt) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.flaggedAt, flaggedAt) ||
                other.flaggedAt == flaggedAt) &&
            (identical(other.verdict, verdict) || other.verdict == verdict));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, contentKind, topic, excerpt,
      reason, severity, flaggedAt, verdict);

  /// Create a copy of FlaggedItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlaggedItemImplCopyWith<_$FlaggedItemImpl> get copyWith =>
      __$$FlaggedItemImplCopyWithImpl<_$FlaggedItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlaggedItemImplToJson(
      this,
    );
  }
}

abstract class _FlaggedItem extends FlaggedItem {
  const factory _FlaggedItem(
      {required final String id,
      @JsonKey(name: 'content_kind')
      required final FlaggedContentKind contentKind,
      required final String topic,
      required final String excerpt,
      required final String reason,
      final int severity,
      @JsonKey(name: 'flagged_at') required final String flaggedAt,
      final ModerationVerdict verdict}) = _$FlaggedItemImpl;
  const _FlaggedItem._() : super._();

  factory _FlaggedItem.fromJson(Map<String, dynamic> json) =
      _$FlaggedItemImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'content_kind')
  FlaggedContentKind get contentKind;

  /// The topic the flagged content belongs to.
  @override
  String get topic;

  /// A short snippet of the flagged content for the admin to judge —
  /// never the full document text.
  @override
  String get excerpt;

  /// Human-readable reason — the Content Safety category that tripped
  /// (e.g. "Violence", "Hate").
  @override
  String get reason;

  /// Azure Content Safety severity, 0–6. Higher is more severe.
  @override
  int get severity;
  @override
  @JsonKey(name: 'flagged_at')
  String get flaggedAt;
  @override
  ModerationVerdict get verdict;

  /// Create a copy of FlaggedItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlaggedItemImplCopyWith<_$FlaggedItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
