// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TopicMastery _$TopicMasteryFromJson(Map<String, dynamic> json) {
  return _TopicMastery.fromJson(json);
}

/// @nodoc
mixin _$TopicMastery {
  @JsonKey(name: 'topic_id')
  String get topicId => throw _privateConstructorUsedError;
  @JsonKey(name: 'topic_name')
  String get topicName => throw _privateConstructorUsedError;

  /// Mastery as a 0.0–1.0 fraction (the backend stores 0–100; the
  /// repository normalizes so the UI never has to remember the scale).
  double get mastery => throw _privateConstructorUsedError;
  int get attempts => throw _privateConstructorUsedError;

  /// Fraction of attempts answered correctly, 0.0–1.0.
  @JsonKey(name: 'success_rate')
  double get successRate => throw _privateConstructorUsedError;

  /// Serializes this TopicMastery to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TopicMastery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopicMasteryCopyWith<TopicMastery> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopicMasteryCopyWith<$Res> {
  factory $TopicMasteryCopyWith(
          TopicMastery value, $Res Function(TopicMastery) then) =
      _$TopicMasteryCopyWithImpl<$Res, TopicMastery>;
  @useResult
  $Res call(
      {@JsonKey(name: 'topic_id') String topicId,
      @JsonKey(name: 'topic_name') String topicName,
      double mastery,
      int attempts,
      @JsonKey(name: 'success_rate') double successRate});
}

/// @nodoc
class _$TopicMasteryCopyWithImpl<$Res, $Val extends TopicMastery>
    implements $TopicMasteryCopyWith<$Res> {
  _$TopicMasteryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopicMastery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topicId = null,
    Object? topicName = null,
    Object? mastery = null,
    Object? attempts = null,
    Object? successRate = null,
  }) {
    return _then(_value.copyWith(
      topicId: null == topicId
          ? _value.topicId
          : topicId // ignore: cast_nullable_to_non_nullable
              as String,
      topicName: null == topicName
          ? _value.topicName
          : topicName // ignore: cast_nullable_to_non_nullable
              as String,
      mastery: null == mastery
          ? _value.mastery
          : mastery // ignore: cast_nullable_to_non_nullable
              as double,
      attempts: null == attempts
          ? _value.attempts
          : attempts // ignore: cast_nullable_to_non_nullable
              as int,
      successRate: null == successRate
          ? _value.successRate
          : successRate // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TopicMasteryImplCopyWith<$Res>
    implements $TopicMasteryCopyWith<$Res> {
  factory _$$TopicMasteryImplCopyWith(
          _$TopicMasteryImpl value, $Res Function(_$TopicMasteryImpl) then) =
      __$$TopicMasteryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'topic_id') String topicId,
      @JsonKey(name: 'topic_name') String topicName,
      double mastery,
      int attempts,
      @JsonKey(name: 'success_rate') double successRate});
}

/// @nodoc
class __$$TopicMasteryImplCopyWithImpl<$Res>
    extends _$TopicMasteryCopyWithImpl<$Res, _$TopicMasteryImpl>
    implements _$$TopicMasteryImplCopyWith<$Res> {
  __$$TopicMasteryImplCopyWithImpl(
      _$TopicMasteryImpl _value, $Res Function(_$TopicMasteryImpl) _then)
      : super(_value, _then);

  /// Create a copy of TopicMastery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topicId = null,
    Object? topicName = null,
    Object? mastery = null,
    Object? attempts = null,
    Object? successRate = null,
  }) {
    return _then(_$TopicMasteryImpl(
      topicId: null == topicId
          ? _value.topicId
          : topicId // ignore: cast_nullable_to_non_nullable
              as String,
      topicName: null == topicName
          ? _value.topicName
          : topicName // ignore: cast_nullable_to_non_nullable
              as String,
      mastery: null == mastery
          ? _value.mastery
          : mastery // ignore: cast_nullable_to_non_nullable
              as double,
      attempts: null == attempts
          ? _value.attempts
          : attempts // ignore: cast_nullable_to_non_nullable
              as int,
      successRate: null == successRate
          ? _value.successRate
          : successRate // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TopicMasteryImpl implements _TopicMastery {
  const _$TopicMasteryImpl(
      {@JsonKey(name: 'topic_id') required this.topicId,
      @JsonKey(name: 'topic_name') required this.topicName,
      required this.mastery,
      this.attempts = 0,
      @JsonKey(name: 'success_rate') this.successRate = 0.0});

  factory _$TopicMasteryImpl.fromJson(Map<String, dynamic> json) =>
      _$$TopicMasteryImplFromJson(json);

  @override
  @JsonKey(name: 'topic_id')
  final String topicId;
  @override
  @JsonKey(name: 'topic_name')
  final String topicName;

  /// Mastery as a 0.0–1.0 fraction (the backend stores 0–100; the
  /// repository normalizes so the UI never has to remember the scale).
  @override
  final double mastery;
  @override
  @JsonKey()
  final int attempts;

  /// Fraction of attempts answered correctly, 0.0–1.0.
  @override
  @JsonKey(name: 'success_rate')
  final double successRate;

  @override
  String toString() {
    return 'TopicMastery(topicId: $topicId, topicName: $topicName, mastery: $mastery, attempts: $attempts, successRate: $successRate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopicMasteryImpl &&
            (identical(other.topicId, topicId) || other.topicId == topicId) &&
            (identical(other.topicName, topicName) ||
                other.topicName == topicName) &&
            (identical(other.mastery, mastery) || other.mastery == mastery) &&
            (identical(other.attempts, attempts) ||
                other.attempts == attempts) &&
            (identical(other.successRate, successRate) ||
                other.successRate == successRate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, topicId, topicName, mastery, attempts, successRate);

  /// Create a copy of TopicMastery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopicMasteryImplCopyWith<_$TopicMasteryImpl> get copyWith =>
      __$$TopicMasteryImplCopyWithImpl<_$TopicMasteryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TopicMasteryImplToJson(
      this,
    );
  }
}

abstract class _TopicMastery implements TopicMastery {
  const factory _TopicMastery(
          {@JsonKey(name: 'topic_id') required final String topicId,
          @JsonKey(name: 'topic_name') required final String topicName,
          required final double mastery,
          final int attempts,
          @JsonKey(name: 'success_rate') final double successRate}) =
      _$TopicMasteryImpl;

  factory _TopicMastery.fromJson(Map<String, dynamic> json) =
      _$TopicMasteryImpl.fromJson;

  @override
  @JsonKey(name: 'topic_id')
  String get topicId;
  @override
  @JsonKey(name: 'topic_name')
  String get topicName;

  /// Mastery as a 0.0–1.0 fraction (the backend stores 0–100; the
  /// repository normalizes so the UI never has to remember the scale).
  @override
  double get mastery;
  @override
  int get attempts;

  /// Fraction of attempts answered correctly, 0.0–1.0.
  @override
  @JsonKey(name: 'success_rate')
  double get successRate;

  /// Create a copy of TopicMastery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopicMasteryImplCopyWith<_$TopicMasteryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ActivityEntry _$ActivityEntryFromJson(Map<String, dynamic> json) {
  return _ActivityEntry.fromJson(json);
}

/// @nodoc
mixin _$ActivityEntry {
  ActivityKind get kind => throw _privateConstructorUsedError;
  String get topic => throw _privateConstructorUsedError;

  /// True/false for a graded question; `null` for a flashcard, which
  /// is self-rated and has no correctness verdict.
  @JsonKey(name: 'is_correct')
  bool? get isCorrect => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_earned')
  int get xpEarned => throw _privateConstructorUsedError;

  /// ISO 8601 UTC timestamp of the interaction.
  @JsonKey(name: 'occurred_at')
  String get occurredAt => throw _privateConstructorUsedError;

  /// Serializes this ActivityEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ActivityEntryCopyWith<ActivityEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActivityEntryCopyWith<$Res> {
  factory $ActivityEntryCopyWith(
          ActivityEntry value, $Res Function(ActivityEntry) then) =
      _$ActivityEntryCopyWithImpl<$Res, ActivityEntry>;
  @useResult
  $Res call(
      {ActivityKind kind,
      String topic,
      @JsonKey(name: 'is_correct') bool? isCorrect,
      @JsonKey(name: 'xp_earned') int xpEarned,
      @JsonKey(name: 'occurred_at') String occurredAt});
}

/// @nodoc
class _$ActivityEntryCopyWithImpl<$Res, $Val extends ActivityEntry>
    implements $ActivityEntryCopyWith<$Res> {
  _$ActivityEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kind = null,
    Object? topic = null,
    Object? isCorrect = freezed,
    Object? xpEarned = null,
    Object? occurredAt = null,
  }) {
    return _then(_value.copyWith(
      kind: null == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as ActivityKind,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      isCorrect: freezed == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool?,
      xpEarned: null == xpEarned
          ? _value.xpEarned
          : xpEarned // ignore: cast_nullable_to_non_nullable
              as int,
      occurredAt: null == occurredAt
          ? _value.occurredAt
          : occurredAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ActivityEntryImplCopyWith<$Res>
    implements $ActivityEntryCopyWith<$Res> {
  factory _$$ActivityEntryImplCopyWith(
          _$ActivityEntryImpl value, $Res Function(_$ActivityEntryImpl) then) =
      __$$ActivityEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ActivityKind kind,
      String topic,
      @JsonKey(name: 'is_correct') bool? isCorrect,
      @JsonKey(name: 'xp_earned') int xpEarned,
      @JsonKey(name: 'occurred_at') String occurredAt});
}

/// @nodoc
class __$$ActivityEntryImplCopyWithImpl<$Res>
    extends _$ActivityEntryCopyWithImpl<$Res, _$ActivityEntryImpl>
    implements _$$ActivityEntryImplCopyWith<$Res> {
  __$$ActivityEntryImplCopyWithImpl(
      _$ActivityEntryImpl _value, $Res Function(_$ActivityEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kind = null,
    Object? topic = null,
    Object? isCorrect = freezed,
    Object? xpEarned = null,
    Object? occurredAt = null,
  }) {
    return _then(_$ActivityEntryImpl(
      kind: null == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as ActivityKind,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      isCorrect: freezed == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool?,
      xpEarned: null == xpEarned
          ? _value.xpEarned
          : xpEarned // ignore: cast_nullable_to_non_nullable
              as int,
      occurredAt: null == occurredAt
          ? _value.occurredAt
          : occurredAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ActivityEntryImpl implements _ActivityEntry {
  const _$ActivityEntryImpl(
      {required this.kind,
      required this.topic,
      @JsonKey(name: 'is_correct') this.isCorrect,
      @JsonKey(name: 'xp_earned') this.xpEarned = 0,
      @JsonKey(name: 'occurred_at') required this.occurredAt});

  factory _$ActivityEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$ActivityEntryImplFromJson(json);

  @override
  final ActivityKind kind;
  @override
  final String topic;

  /// True/false for a graded question; `null` for a flashcard, which
  /// is self-rated and has no correctness verdict.
  @override
  @JsonKey(name: 'is_correct')
  final bool? isCorrect;
  @override
  @JsonKey(name: 'xp_earned')
  final int xpEarned;

  /// ISO 8601 UTC timestamp of the interaction.
  @override
  @JsonKey(name: 'occurred_at')
  final String occurredAt;

  @override
  String toString() {
    return 'ActivityEntry(kind: $kind, topic: $topic, isCorrect: $isCorrect, xpEarned: $xpEarned, occurredAt: $occurredAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActivityEntryImpl &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.isCorrect, isCorrect) ||
                other.isCorrect == isCorrect) &&
            (identical(other.xpEarned, xpEarned) ||
                other.xpEarned == xpEarned) &&
            (identical(other.occurredAt, occurredAt) ||
                other.occurredAt == occurredAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, kind, topic, isCorrect, xpEarned, occurredAt);

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ActivityEntryImplCopyWith<_$ActivityEntryImpl> get copyWith =>
      __$$ActivityEntryImplCopyWithImpl<_$ActivityEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ActivityEntryImplToJson(
      this,
    );
  }
}

abstract class _ActivityEntry implements ActivityEntry {
  const factory _ActivityEntry(
          {required final ActivityKind kind,
          required final String topic,
          @JsonKey(name: 'is_correct') final bool? isCorrect,
          @JsonKey(name: 'xp_earned') final int xpEarned,
          @JsonKey(name: 'occurred_at') required final String occurredAt}) =
      _$ActivityEntryImpl;

  factory _ActivityEntry.fromJson(Map<String, dynamic> json) =
      _$ActivityEntryImpl.fromJson;

  @override
  ActivityKind get kind;
  @override
  String get topic;

  /// True/false for a graded question; `null` for a flashcard, which
  /// is self-rated and has no correctness verdict.
  @override
  @JsonKey(name: 'is_correct')
  bool? get isCorrect;
  @override
  @JsonKey(name: 'xp_earned')
  int get xpEarned;

  /// ISO 8601 UTC timestamp of the interaction.
  @override
  @JsonKey(name: 'occurred_at')
  String get occurredAt;

  /// Create a copy of ActivityEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ActivityEntryImplCopyWith<_$ActivityEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StudentProgress _$StudentProgressFromJson(Map<String, dynamic> json) {
  return _StudentProgress.fromJson(json);
}

/// @nodoc
mixin _$StudentProgress {
  int get level => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_xp')
  int get totalXp => throw _privateConstructorUsedError;

  /// XP accumulated within the current level (resets to 0 on level-up).
  @JsonKey(name: 'xp_into_level')
  int get xpIntoLevel => throw _privateConstructorUsedError;

  /// XP span of the current level — `xpIntoLevel / xpForNextLevel` is
  /// the progress-bar fraction. Always > 0 so the UI can divide safely.
  @JsonKey(name: 'xp_for_next_level')
  int get xpForNextLevel => throw _privateConstructorUsedError;

  /// Overall mastery across all topics, 0.0–1.0.
  @JsonKey(name: 'overall_mastery')
  double get overallMastery => throw _privateConstructorUsedError;
  List<TopicMastery> get topics => throw _privateConstructorUsedError;
  @JsonKey(name: 'recent_activity')
  List<ActivityEntry> get recentActivity => throw _privateConstructorUsedError;

  /// Serializes this StudentProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudentProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudentProgressCopyWith<StudentProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudentProgressCopyWith<$Res> {
  factory $StudentProgressCopyWith(
          StudentProgress value, $Res Function(StudentProgress) then) =
      _$StudentProgressCopyWithImpl<$Res, StudentProgress>;
  @useResult
  $Res call(
      {int level,
      @JsonKey(name: 'total_xp') int totalXp,
      @JsonKey(name: 'xp_into_level') int xpIntoLevel,
      @JsonKey(name: 'xp_for_next_level') int xpForNextLevel,
      @JsonKey(name: 'overall_mastery') double overallMastery,
      List<TopicMastery> topics,
      @JsonKey(name: 'recent_activity') List<ActivityEntry> recentActivity});
}

/// @nodoc
class _$StudentProgressCopyWithImpl<$Res, $Val extends StudentProgress>
    implements $StudentProgressCopyWith<$Res> {
  _$StudentProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudentProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? level = null,
    Object? totalXp = null,
    Object? xpIntoLevel = null,
    Object? xpForNextLevel = null,
    Object? overallMastery = null,
    Object? topics = null,
    Object? recentActivity = null,
  }) {
    return _then(_value.copyWith(
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      totalXp: null == totalXp
          ? _value.totalXp
          : totalXp // ignore: cast_nullable_to_non_nullable
              as int,
      xpIntoLevel: null == xpIntoLevel
          ? _value.xpIntoLevel
          : xpIntoLevel // ignore: cast_nullable_to_non_nullable
              as int,
      xpForNextLevel: null == xpForNextLevel
          ? _value.xpForNextLevel
          : xpForNextLevel // ignore: cast_nullable_to_non_nullable
              as int,
      overallMastery: null == overallMastery
          ? _value.overallMastery
          : overallMastery // ignore: cast_nullable_to_non_nullable
              as double,
      topics: null == topics
          ? _value.topics
          : topics // ignore: cast_nullable_to_non_nullable
              as List<TopicMastery>,
      recentActivity: null == recentActivity
          ? _value.recentActivity
          : recentActivity // ignore: cast_nullable_to_non_nullable
              as List<ActivityEntry>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudentProgressImplCopyWith<$Res>
    implements $StudentProgressCopyWith<$Res> {
  factory _$$StudentProgressImplCopyWith(_$StudentProgressImpl value,
          $Res Function(_$StudentProgressImpl) then) =
      __$$StudentProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int level,
      @JsonKey(name: 'total_xp') int totalXp,
      @JsonKey(name: 'xp_into_level') int xpIntoLevel,
      @JsonKey(name: 'xp_for_next_level') int xpForNextLevel,
      @JsonKey(name: 'overall_mastery') double overallMastery,
      List<TopicMastery> topics,
      @JsonKey(name: 'recent_activity') List<ActivityEntry> recentActivity});
}

/// @nodoc
class __$$StudentProgressImplCopyWithImpl<$Res>
    extends _$StudentProgressCopyWithImpl<$Res, _$StudentProgressImpl>
    implements _$$StudentProgressImplCopyWith<$Res> {
  __$$StudentProgressImplCopyWithImpl(
      _$StudentProgressImpl _value, $Res Function(_$StudentProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudentProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? level = null,
    Object? totalXp = null,
    Object? xpIntoLevel = null,
    Object? xpForNextLevel = null,
    Object? overallMastery = null,
    Object? topics = null,
    Object? recentActivity = null,
  }) {
    return _then(_$StudentProgressImpl(
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      totalXp: null == totalXp
          ? _value.totalXp
          : totalXp // ignore: cast_nullable_to_non_nullable
              as int,
      xpIntoLevel: null == xpIntoLevel
          ? _value.xpIntoLevel
          : xpIntoLevel // ignore: cast_nullable_to_non_nullable
              as int,
      xpForNextLevel: null == xpForNextLevel
          ? _value.xpForNextLevel
          : xpForNextLevel // ignore: cast_nullable_to_non_nullable
              as int,
      overallMastery: null == overallMastery
          ? _value.overallMastery
          : overallMastery // ignore: cast_nullable_to_non_nullable
              as double,
      topics: null == topics
          ? _value._topics
          : topics // ignore: cast_nullable_to_non_nullable
              as List<TopicMastery>,
      recentActivity: null == recentActivity
          ? _value._recentActivity
          : recentActivity // ignore: cast_nullable_to_non_nullable
              as List<ActivityEntry>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudentProgressImpl extends _StudentProgress {
  const _$StudentProgressImpl(
      {required this.level,
      @JsonKey(name: 'total_xp') required this.totalXp,
      @JsonKey(name: 'xp_into_level') required this.xpIntoLevel,
      @JsonKey(name: 'xp_for_next_level') required this.xpForNextLevel,
      @JsonKey(name: 'overall_mastery') required this.overallMastery,
      final List<TopicMastery> topics = const <TopicMastery>[],
      @JsonKey(name: 'recent_activity')
      final List<ActivityEntry> recentActivity = const <ActivityEntry>[]})
      : _topics = topics,
        _recentActivity = recentActivity,
        super._();

  factory _$StudentProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudentProgressImplFromJson(json);

  @override
  final int level;
  @override
  @JsonKey(name: 'total_xp')
  final int totalXp;

  /// XP accumulated within the current level (resets to 0 on level-up).
  @override
  @JsonKey(name: 'xp_into_level')
  final int xpIntoLevel;

  /// XP span of the current level — `xpIntoLevel / xpForNextLevel` is
  /// the progress-bar fraction. Always > 0 so the UI can divide safely.
  @override
  @JsonKey(name: 'xp_for_next_level')
  final int xpForNextLevel;

  /// Overall mastery across all topics, 0.0–1.0.
  @override
  @JsonKey(name: 'overall_mastery')
  final double overallMastery;
  final List<TopicMastery> _topics;
  @override
  @JsonKey()
  List<TopicMastery> get topics {
    if (_topics is EqualUnmodifiableListView) return _topics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topics);
  }

  final List<ActivityEntry> _recentActivity;
  @override
  @JsonKey(name: 'recent_activity')
  List<ActivityEntry> get recentActivity {
    if (_recentActivity is EqualUnmodifiableListView) return _recentActivity;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentActivity);
  }

  @override
  String toString() {
    return 'StudentProgress(level: $level, totalXp: $totalXp, xpIntoLevel: $xpIntoLevel, xpForNextLevel: $xpForNextLevel, overallMastery: $overallMastery, topics: $topics, recentActivity: $recentActivity)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudentProgressImpl &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.totalXp, totalXp) || other.totalXp == totalXp) &&
            (identical(other.xpIntoLevel, xpIntoLevel) ||
                other.xpIntoLevel == xpIntoLevel) &&
            (identical(other.xpForNextLevel, xpForNextLevel) ||
                other.xpForNextLevel == xpForNextLevel) &&
            (identical(other.overallMastery, overallMastery) ||
                other.overallMastery == overallMastery) &&
            const DeepCollectionEquality().equals(other._topics, _topics) &&
            const DeepCollectionEquality()
                .equals(other._recentActivity, _recentActivity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      level,
      totalXp,
      xpIntoLevel,
      xpForNextLevel,
      overallMastery,
      const DeepCollectionEquality().hash(_topics),
      const DeepCollectionEquality().hash(_recentActivity));

  /// Create a copy of StudentProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudentProgressImplCopyWith<_$StudentProgressImpl> get copyWith =>
      __$$StudentProgressImplCopyWithImpl<_$StudentProgressImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudentProgressImplToJson(
      this,
    );
  }
}

abstract class _StudentProgress extends StudentProgress {
  const factory _StudentProgress(
      {required final int level,
      @JsonKey(name: 'total_xp') required final int totalXp,
      @JsonKey(name: 'xp_into_level') required final int xpIntoLevel,
      @JsonKey(name: 'xp_for_next_level') required final int xpForNextLevel,
      @JsonKey(name: 'overall_mastery') required final double overallMastery,
      final List<TopicMastery> topics,
      @JsonKey(name: 'recent_activity')
      final List<ActivityEntry> recentActivity}) = _$StudentProgressImpl;
  const _StudentProgress._() : super._();

  factory _StudentProgress.fromJson(Map<String, dynamic> json) =
      _$StudentProgressImpl.fromJson;

  @override
  int get level;
  @override
  @JsonKey(name: 'total_xp')
  int get totalXp;

  /// XP accumulated within the current level (resets to 0 on level-up).
  @override
  @JsonKey(name: 'xp_into_level')
  int get xpIntoLevel;

  /// XP span of the current level — `xpIntoLevel / xpForNextLevel` is
  /// the progress-bar fraction. Always > 0 so the UI can divide safely.
  @override
  @JsonKey(name: 'xp_for_next_level')
  int get xpForNextLevel;

  /// Overall mastery across all topics, 0.0–1.0.
  @override
  @JsonKey(name: 'overall_mastery')
  double get overallMastery;
  @override
  List<TopicMastery> get topics;
  @override
  @JsonKey(name: 'recent_activity')
  List<ActivityEntry> get recentActivity;

  /// Create a copy of StudentProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudentProgressImplCopyWith<_$StudentProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
