// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TopicStats _$TopicStatsFromJson(Map<String, dynamic> json) {
  return _TopicStats.fromJson(json);
}

/// @nodoc
mixin _$TopicStats {
  String get topic => throw _privateConstructorUsedError;
  int get attempts => throw _privateConstructorUsedError;

  /// Mean mastery across students that have at least one
  /// [KnowledgeState] row for this topic. 0.0–1.0.
  @JsonKey(name: 'avg_mastery')
  double get avgMastery => throw _privateConstructorUsedError;

  /// Fraction of attempts answered correctly across all students,
  /// 0.0–1.0.
  @JsonKey(name: 'correct_rate')
  double get correctRate => throw _privateConstructorUsedError;

  /// Serializes this TopicStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TopicStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopicStatsCopyWith<TopicStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopicStatsCopyWith<$Res> {
  factory $TopicStatsCopyWith(
          TopicStats value, $Res Function(TopicStats) then) =
      _$TopicStatsCopyWithImpl<$Res, TopicStats>;
  @useResult
  $Res call(
      {String topic,
      int attempts,
      @JsonKey(name: 'avg_mastery') double avgMastery,
      @JsonKey(name: 'correct_rate') double correctRate});
}

/// @nodoc
class _$TopicStatsCopyWithImpl<$Res, $Val extends TopicStats>
    implements $TopicStatsCopyWith<$Res> {
  _$TopicStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopicStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topic = null,
    Object? attempts = null,
    Object? avgMastery = null,
    Object? correctRate = null,
  }) {
    return _then(_value.copyWith(
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      attempts: null == attempts
          ? _value.attempts
          : attempts // ignore: cast_nullable_to_non_nullable
              as int,
      avgMastery: null == avgMastery
          ? _value.avgMastery
          : avgMastery // ignore: cast_nullable_to_non_nullable
              as double,
      correctRate: null == correctRate
          ? _value.correctRate
          : correctRate // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TopicStatsImplCopyWith<$Res>
    implements $TopicStatsCopyWith<$Res> {
  factory _$$TopicStatsImplCopyWith(
          _$TopicStatsImpl value, $Res Function(_$TopicStatsImpl) then) =
      __$$TopicStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String topic,
      int attempts,
      @JsonKey(name: 'avg_mastery') double avgMastery,
      @JsonKey(name: 'correct_rate') double correctRate});
}

/// @nodoc
class __$$TopicStatsImplCopyWithImpl<$Res>
    extends _$TopicStatsCopyWithImpl<$Res, _$TopicStatsImpl>
    implements _$$TopicStatsImplCopyWith<$Res> {
  __$$TopicStatsImplCopyWithImpl(
      _$TopicStatsImpl _value, $Res Function(_$TopicStatsImpl) _then)
      : super(_value, _then);

  /// Create a copy of TopicStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? topic = null,
    Object? attempts = null,
    Object? avgMastery = null,
    Object? correctRate = null,
  }) {
    return _then(_$TopicStatsImpl(
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      attempts: null == attempts
          ? _value.attempts
          : attempts // ignore: cast_nullable_to_non_nullable
              as int,
      avgMastery: null == avgMastery
          ? _value.avgMastery
          : avgMastery // ignore: cast_nullable_to_non_nullable
              as double,
      correctRate: null == correctRate
          ? _value.correctRate
          : correctRate // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TopicStatsImpl implements _TopicStats {
  const _$TopicStatsImpl(
      {required this.topic,
      this.attempts = 0,
      @JsonKey(name: 'avg_mastery') this.avgMastery = 0.0,
      @JsonKey(name: 'correct_rate') this.correctRate = 0.0});

  factory _$TopicStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$TopicStatsImplFromJson(json);

  @override
  final String topic;
  @override
  @JsonKey()
  final int attempts;

  /// Mean mastery across students that have at least one
  /// [KnowledgeState] row for this topic. 0.0–1.0.
  @override
  @JsonKey(name: 'avg_mastery')
  final double avgMastery;

  /// Fraction of attempts answered correctly across all students,
  /// 0.0–1.0.
  @override
  @JsonKey(name: 'correct_rate')
  final double correctRate;

  @override
  String toString() {
    return 'TopicStats(topic: $topic, attempts: $attempts, avgMastery: $avgMastery, correctRate: $correctRate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopicStatsImpl &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.attempts, attempts) ||
                other.attempts == attempts) &&
            (identical(other.avgMastery, avgMastery) ||
                other.avgMastery == avgMastery) &&
            (identical(other.correctRate, correctRate) ||
                other.correctRate == correctRate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, topic, attempts, avgMastery, correctRate);

  /// Create a copy of TopicStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopicStatsImplCopyWith<_$TopicStatsImpl> get copyWith =>
      __$$TopicStatsImplCopyWithImpl<_$TopicStatsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TopicStatsImplToJson(
      this,
    );
  }
}

abstract class _TopicStats implements TopicStats {
  const factory _TopicStats(
          {required final String topic,
          final int attempts,
          @JsonKey(name: 'avg_mastery') final double avgMastery,
          @JsonKey(name: 'correct_rate') final double correctRate}) =
      _$TopicStatsImpl;

  factory _TopicStats.fromJson(Map<String, dynamic> json) =
      _$TopicStatsImpl.fromJson;

  @override
  String get topic;
  @override
  int get attempts;

  /// Mean mastery across students that have at least one
  /// [KnowledgeState] row for this topic. 0.0–1.0.
  @override
  @JsonKey(name: 'avg_mastery')
  double get avgMastery;

  /// Fraction of attempts answered correctly across all students,
  /// 0.0–1.0.
  @override
  @JsonKey(name: 'correct_rate')
  double get correctRate;

  /// Create a copy of TopicStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopicStatsImplCopyWith<_$TopicStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DifficultyStats _$DifficultyStatsFromJson(Map<String, dynamic> json) {
  return _DifficultyStats.fromJson(json);
}

/// @nodoc
mixin _$DifficultyStats {
  int get attempts => throw _privateConstructorUsedError;
  int get correct => throw _privateConstructorUsedError;

  /// Serializes this DifficultyStats to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DifficultyStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DifficultyStatsCopyWith<DifficultyStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DifficultyStatsCopyWith<$Res> {
  factory $DifficultyStatsCopyWith(
          DifficultyStats value, $Res Function(DifficultyStats) then) =
      _$DifficultyStatsCopyWithImpl<$Res, DifficultyStats>;
  @useResult
  $Res call({int attempts, int correct});
}

/// @nodoc
class _$DifficultyStatsCopyWithImpl<$Res, $Val extends DifficultyStats>
    implements $DifficultyStatsCopyWith<$Res> {
  _$DifficultyStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DifficultyStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? attempts = null,
    Object? correct = null,
  }) {
    return _then(_value.copyWith(
      attempts: null == attempts
          ? _value.attempts
          : attempts // ignore: cast_nullable_to_non_nullable
              as int,
      correct: null == correct
          ? _value.correct
          : correct // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DifficultyStatsImplCopyWith<$Res>
    implements $DifficultyStatsCopyWith<$Res> {
  factory _$$DifficultyStatsImplCopyWith(_$DifficultyStatsImpl value,
          $Res Function(_$DifficultyStatsImpl) then) =
      __$$DifficultyStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int attempts, int correct});
}

/// @nodoc
class __$$DifficultyStatsImplCopyWithImpl<$Res>
    extends _$DifficultyStatsCopyWithImpl<$Res, _$DifficultyStatsImpl>
    implements _$$DifficultyStatsImplCopyWith<$Res> {
  __$$DifficultyStatsImplCopyWithImpl(
      _$DifficultyStatsImpl _value, $Res Function(_$DifficultyStatsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DifficultyStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? attempts = null,
    Object? correct = null,
  }) {
    return _then(_$DifficultyStatsImpl(
      attempts: null == attempts
          ? _value.attempts
          : attempts // ignore: cast_nullable_to_non_nullable
              as int,
      correct: null == correct
          ? _value.correct
          : correct // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DifficultyStatsImpl implements _DifficultyStats {
  const _$DifficultyStatsImpl({this.attempts = 0, this.correct = 0});

  factory _$DifficultyStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$DifficultyStatsImplFromJson(json);

  @override
  @JsonKey()
  final int attempts;
  @override
  @JsonKey()
  final int correct;

  @override
  String toString() {
    return 'DifficultyStats(attempts: $attempts, correct: $correct)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DifficultyStatsImpl &&
            (identical(other.attempts, attempts) ||
                other.attempts == attempts) &&
            (identical(other.correct, correct) || other.correct == correct));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, attempts, correct);

  /// Create a copy of DifficultyStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DifficultyStatsImplCopyWith<_$DifficultyStatsImpl> get copyWith =>
      __$$DifficultyStatsImplCopyWithImpl<_$DifficultyStatsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DifficultyStatsImplToJson(
      this,
    );
  }
}

abstract class _DifficultyStats implements DifficultyStats {
  const factory _DifficultyStats({final int attempts, final int correct}) =
      _$DifficultyStatsImpl;

  factory _DifficultyStats.fromJson(Map<String, dynamic> json) =
      _$DifficultyStatsImpl.fromJson;

  @override
  int get attempts;
  @override
  int get correct;

  /// Create a copy of DifficultyStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DifficultyStatsImplCopyWith<_$DifficultyStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HeatmapCell _$HeatmapCellFromJson(Map<String, dynamic> json) {
  return _HeatmapCell.fromJson(json);
}

/// @nodoc
mixin _$HeatmapCell {
  String get date => throw _privateConstructorUsedError;
  int get events => throw _privateConstructorUsedError;

  /// Serializes this HeatmapCell to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HeatmapCell
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HeatmapCellCopyWith<HeatmapCell> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HeatmapCellCopyWith<$Res> {
  factory $HeatmapCellCopyWith(
          HeatmapCell value, $Res Function(HeatmapCell) then) =
      _$HeatmapCellCopyWithImpl<$Res, HeatmapCell>;
  @useResult
  $Res call({String date, int events});
}

/// @nodoc
class _$HeatmapCellCopyWithImpl<$Res, $Val extends HeatmapCell>
    implements $HeatmapCellCopyWith<$Res> {
  _$HeatmapCellCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HeatmapCell
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? events = null,
  }) {
    return _then(_value.copyWith(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      events: null == events
          ? _value.events
          : events // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HeatmapCellImplCopyWith<$Res>
    implements $HeatmapCellCopyWith<$Res> {
  factory _$$HeatmapCellImplCopyWith(
          _$HeatmapCellImpl value, $Res Function(_$HeatmapCellImpl) then) =
      __$$HeatmapCellImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String date, int events});
}

/// @nodoc
class __$$HeatmapCellImplCopyWithImpl<$Res>
    extends _$HeatmapCellCopyWithImpl<$Res, _$HeatmapCellImpl>
    implements _$$HeatmapCellImplCopyWith<$Res> {
  __$$HeatmapCellImplCopyWithImpl(
      _$HeatmapCellImpl _value, $Res Function(_$HeatmapCellImpl) _then)
      : super(_value, _then);

  /// Create a copy of HeatmapCell
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? events = null,
  }) {
    return _then(_$HeatmapCellImpl(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      events: null == events
          ? _value.events
          : events // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$HeatmapCellImpl implements _HeatmapCell {
  const _$HeatmapCellImpl({required this.date, this.events = 0});

  factory _$HeatmapCellImpl.fromJson(Map<String, dynamic> json) =>
      _$$HeatmapCellImplFromJson(json);

  @override
  final String date;
  @override
  @JsonKey()
  final int events;

  @override
  String toString() {
    return 'HeatmapCell(date: $date, events: $events)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HeatmapCellImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.events, events) || other.events == events));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, events);

  /// Create a copy of HeatmapCell
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HeatmapCellImplCopyWith<_$HeatmapCellImpl> get copyWith =>
      __$$HeatmapCellImplCopyWithImpl<_$HeatmapCellImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HeatmapCellImplToJson(
      this,
    );
  }
}

abstract class _HeatmapCell implements HeatmapCell {
  const factory _HeatmapCell({required final String date, final int events}) =
      _$HeatmapCellImpl;

  factory _HeatmapCell.fromJson(Map<String, dynamic> json) =
      _$HeatmapCellImpl.fromJson;

  @override
  String get date;
  @override
  int get events;

  /// Create a copy of HeatmapCell
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HeatmapCellImplCopyWith<_$HeatmapCellImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WorkspaceAnalytics _$WorkspaceAnalyticsFromJson(Map<String, dynamic> json) {
  return _WorkspaceAnalytics.fromJson(json);
}

/// @nodoc
mixin _$WorkspaceAnalytics {
  @JsonKey(name: 'workspace_id')
  String get workspaceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_students')
  int get totalStudents => throw _privateConstructorUsedError;
  @JsonKey(name: 'active_students_7d')
  int get activeStudents7d => throw _privateConstructorUsedError;
  @JsonKey(name: 'avg_overall_mastery')
  double get avgOverallMastery => throw _privateConstructorUsedError;
  @JsonKey(name: 'avg_questions_per_student')
  double get avgQuestionsPerStudent => throw _privateConstructorUsedError;
  @JsonKey(name: 'avg_correct_rate')
  double get avgCorrectRate => throw _privateConstructorUsedError;
  @JsonKey(name: 'topic_distribution')
  List<TopicStats> get topicDistribution => throw _privateConstructorUsedError;
  @JsonKey(name: 'difficulty_distribution')
  Map<String, DifficultyStats> get difficultyDistribution =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'engagement_heatmap')
  List<HeatmapCell> get engagementHeatmap => throw _privateConstructorUsedError;

  /// Serializes this WorkspaceAnalytics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkspaceAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkspaceAnalyticsCopyWith<WorkspaceAnalytics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkspaceAnalyticsCopyWith<$Res> {
  factory $WorkspaceAnalyticsCopyWith(
          WorkspaceAnalytics value, $Res Function(WorkspaceAnalytics) then) =
      _$WorkspaceAnalyticsCopyWithImpl<$Res, WorkspaceAnalytics>;
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      @JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'active_students_7d') int activeStudents7d,
      @JsonKey(name: 'avg_overall_mastery') double avgOverallMastery,
      @JsonKey(name: 'avg_questions_per_student') double avgQuestionsPerStudent,
      @JsonKey(name: 'avg_correct_rate') double avgCorrectRate,
      @JsonKey(name: 'topic_distribution') List<TopicStats> topicDistribution,
      @JsonKey(name: 'difficulty_distribution')
      Map<String, DifficultyStats> difficultyDistribution,
      @JsonKey(name: 'engagement_heatmap')
      List<HeatmapCell> engagementHeatmap});
}

/// @nodoc
class _$WorkspaceAnalyticsCopyWithImpl<$Res, $Val extends WorkspaceAnalytics>
    implements $WorkspaceAnalyticsCopyWith<$Res> {
  _$WorkspaceAnalyticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkspaceAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? totalStudents = null,
    Object? activeStudents7d = null,
    Object? avgOverallMastery = null,
    Object? avgQuestionsPerStudent = null,
    Object? avgCorrectRate = null,
    Object? topicDistribution = null,
    Object? difficultyDistribution = null,
    Object? engagementHeatmap = null,
  }) {
    return _then(_value.copyWith(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      activeStudents7d: null == activeStudents7d
          ? _value.activeStudents7d
          : activeStudents7d // ignore: cast_nullable_to_non_nullable
              as int,
      avgOverallMastery: null == avgOverallMastery
          ? _value.avgOverallMastery
          : avgOverallMastery // ignore: cast_nullable_to_non_nullable
              as double,
      avgQuestionsPerStudent: null == avgQuestionsPerStudent
          ? _value.avgQuestionsPerStudent
          : avgQuestionsPerStudent // ignore: cast_nullable_to_non_nullable
              as double,
      avgCorrectRate: null == avgCorrectRate
          ? _value.avgCorrectRate
          : avgCorrectRate // ignore: cast_nullable_to_non_nullable
              as double,
      topicDistribution: null == topicDistribution
          ? _value.topicDistribution
          : topicDistribution // ignore: cast_nullable_to_non_nullable
              as List<TopicStats>,
      difficultyDistribution: null == difficultyDistribution
          ? _value.difficultyDistribution
          : difficultyDistribution // ignore: cast_nullable_to_non_nullable
              as Map<String, DifficultyStats>,
      engagementHeatmap: null == engagementHeatmap
          ? _value.engagementHeatmap
          : engagementHeatmap // ignore: cast_nullable_to_non_nullable
              as List<HeatmapCell>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WorkspaceAnalyticsImplCopyWith<$Res>
    implements $WorkspaceAnalyticsCopyWith<$Res> {
  factory _$$WorkspaceAnalyticsImplCopyWith(_$WorkspaceAnalyticsImpl value,
          $Res Function(_$WorkspaceAnalyticsImpl) then) =
      __$$WorkspaceAnalyticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      @JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'active_students_7d') int activeStudents7d,
      @JsonKey(name: 'avg_overall_mastery') double avgOverallMastery,
      @JsonKey(name: 'avg_questions_per_student') double avgQuestionsPerStudent,
      @JsonKey(name: 'avg_correct_rate') double avgCorrectRate,
      @JsonKey(name: 'topic_distribution') List<TopicStats> topicDistribution,
      @JsonKey(name: 'difficulty_distribution')
      Map<String, DifficultyStats> difficultyDistribution,
      @JsonKey(name: 'engagement_heatmap')
      List<HeatmapCell> engagementHeatmap});
}

/// @nodoc
class __$$WorkspaceAnalyticsImplCopyWithImpl<$Res>
    extends _$WorkspaceAnalyticsCopyWithImpl<$Res, _$WorkspaceAnalyticsImpl>
    implements _$$WorkspaceAnalyticsImplCopyWith<$Res> {
  __$$WorkspaceAnalyticsImplCopyWithImpl(_$WorkspaceAnalyticsImpl _value,
      $Res Function(_$WorkspaceAnalyticsImpl) _then)
      : super(_value, _then);

  /// Create a copy of WorkspaceAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? totalStudents = null,
    Object? activeStudents7d = null,
    Object? avgOverallMastery = null,
    Object? avgQuestionsPerStudent = null,
    Object? avgCorrectRate = null,
    Object? topicDistribution = null,
    Object? difficultyDistribution = null,
    Object? engagementHeatmap = null,
  }) {
    return _then(_$WorkspaceAnalyticsImpl(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      activeStudents7d: null == activeStudents7d
          ? _value.activeStudents7d
          : activeStudents7d // ignore: cast_nullable_to_non_nullable
              as int,
      avgOverallMastery: null == avgOverallMastery
          ? _value.avgOverallMastery
          : avgOverallMastery // ignore: cast_nullable_to_non_nullable
              as double,
      avgQuestionsPerStudent: null == avgQuestionsPerStudent
          ? _value.avgQuestionsPerStudent
          : avgQuestionsPerStudent // ignore: cast_nullable_to_non_nullable
              as double,
      avgCorrectRate: null == avgCorrectRate
          ? _value.avgCorrectRate
          : avgCorrectRate // ignore: cast_nullable_to_non_nullable
              as double,
      topicDistribution: null == topicDistribution
          ? _value._topicDistribution
          : topicDistribution // ignore: cast_nullable_to_non_nullable
              as List<TopicStats>,
      difficultyDistribution: null == difficultyDistribution
          ? _value._difficultyDistribution
          : difficultyDistribution // ignore: cast_nullable_to_non_nullable
              as Map<String, DifficultyStats>,
      engagementHeatmap: null == engagementHeatmap
          ? _value._engagementHeatmap
          : engagementHeatmap // ignore: cast_nullable_to_non_nullable
              as List<HeatmapCell>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkspaceAnalyticsImpl extends _WorkspaceAnalytics {
  const _$WorkspaceAnalyticsImpl(
      {@JsonKey(name: 'workspace_id') required this.workspaceId,
      @JsonKey(name: 'total_students') this.totalStudents = 0,
      @JsonKey(name: 'active_students_7d') this.activeStudents7d = 0,
      @JsonKey(name: 'avg_overall_mastery') this.avgOverallMastery = 0.0,
      @JsonKey(name: 'avg_questions_per_student')
      this.avgQuestionsPerStudent = 0.0,
      @JsonKey(name: 'avg_correct_rate') this.avgCorrectRate = 0.0,
      @JsonKey(name: 'topic_distribution')
      final List<TopicStats> topicDistribution = const <TopicStats>[],
      @JsonKey(name: 'difficulty_distribution')
      final Map<String, DifficultyStats> difficultyDistribution =
          const <String, DifficultyStats>{},
      @JsonKey(name: 'engagement_heatmap')
      final List<HeatmapCell> engagementHeatmap = const <HeatmapCell>[]})
      : _topicDistribution = topicDistribution,
        _difficultyDistribution = difficultyDistribution,
        _engagementHeatmap = engagementHeatmap,
        super._();

  factory _$WorkspaceAnalyticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkspaceAnalyticsImplFromJson(json);

  @override
  @JsonKey(name: 'workspace_id')
  final String workspaceId;
  @override
  @JsonKey(name: 'total_students')
  final int totalStudents;
  @override
  @JsonKey(name: 'active_students_7d')
  final int activeStudents7d;
  @override
  @JsonKey(name: 'avg_overall_mastery')
  final double avgOverallMastery;
  @override
  @JsonKey(name: 'avg_questions_per_student')
  final double avgQuestionsPerStudent;
  @override
  @JsonKey(name: 'avg_correct_rate')
  final double avgCorrectRate;
  final List<TopicStats> _topicDistribution;
  @override
  @JsonKey(name: 'topic_distribution')
  List<TopicStats> get topicDistribution {
    if (_topicDistribution is EqualUnmodifiableListView)
      return _topicDistribution;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topicDistribution);
  }

  final Map<String, DifficultyStats> _difficultyDistribution;
  @override
  @JsonKey(name: 'difficulty_distribution')
  Map<String, DifficultyStats> get difficultyDistribution {
    if (_difficultyDistribution is EqualUnmodifiableMapView)
      return _difficultyDistribution;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_difficultyDistribution);
  }

  final List<HeatmapCell> _engagementHeatmap;
  @override
  @JsonKey(name: 'engagement_heatmap')
  List<HeatmapCell> get engagementHeatmap {
    if (_engagementHeatmap is EqualUnmodifiableListView)
      return _engagementHeatmap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_engagementHeatmap);
  }

  @override
  String toString() {
    return 'WorkspaceAnalytics(workspaceId: $workspaceId, totalStudents: $totalStudents, activeStudents7d: $activeStudents7d, avgOverallMastery: $avgOverallMastery, avgQuestionsPerStudent: $avgQuestionsPerStudent, avgCorrectRate: $avgCorrectRate, topicDistribution: $topicDistribution, difficultyDistribution: $difficultyDistribution, engagementHeatmap: $engagementHeatmap)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkspaceAnalyticsImpl &&
            (identical(other.workspaceId, workspaceId) ||
                other.workspaceId == workspaceId) &&
            (identical(other.totalStudents, totalStudents) ||
                other.totalStudents == totalStudents) &&
            (identical(other.activeStudents7d, activeStudents7d) ||
                other.activeStudents7d == activeStudents7d) &&
            (identical(other.avgOverallMastery, avgOverallMastery) ||
                other.avgOverallMastery == avgOverallMastery) &&
            (identical(other.avgQuestionsPerStudent, avgQuestionsPerStudent) ||
                other.avgQuestionsPerStudent == avgQuestionsPerStudent) &&
            (identical(other.avgCorrectRate, avgCorrectRate) ||
                other.avgCorrectRate == avgCorrectRate) &&
            const DeepCollectionEquality()
                .equals(other._topicDistribution, _topicDistribution) &&
            const DeepCollectionEquality().equals(
                other._difficultyDistribution, _difficultyDistribution) &&
            const DeepCollectionEquality()
                .equals(other._engagementHeatmap, _engagementHeatmap));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      workspaceId,
      totalStudents,
      activeStudents7d,
      avgOverallMastery,
      avgQuestionsPerStudent,
      avgCorrectRate,
      const DeepCollectionEquality().hash(_topicDistribution),
      const DeepCollectionEquality().hash(_difficultyDistribution),
      const DeepCollectionEquality().hash(_engagementHeatmap));

  /// Create a copy of WorkspaceAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkspaceAnalyticsImplCopyWith<_$WorkspaceAnalyticsImpl> get copyWith =>
      __$$WorkspaceAnalyticsImplCopyWithImpl<_$WorkspaceAnalyticsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkspaceAnalyticsImplToJson(
      this,
    );
  }
}

abstract class _WorkspaceAnalytics extends WorkspaceAnalytics {
  const factory _WorkspaceAnalytics(
      {@JsonKey(name: 'workspace_id') required final String workspaceId,
      @JsonKey(name: 'total_students') final int totalStudents,
      @JsonKey(name: 'active_students_7d') final int activeStudents7d,
      @JsonKey(name: 'avg_overall_mastery') final double avgOverallMastery,
      @JsonKey(name: 'avg_questions_per_student')
      final double avgQuestionsPerStudent,
      @JsonKey(name: 'avg_correct_rate') final double avgCorrectRate,
      @JsonKey(name: 'topic_distribution')
      final List<TopicStats> topicDistribution,
      @JsonKey(name: 'difficulty_distribution')
      final Map<String, DifficultyStats> difficultyDistribution,
      @JsonKey(name: 'engagement_heatmap')
      final List<HeatmapCell> engagementHeatmap}) = _$WorkspaceAnalyticsImpl;
  const _WorkspaceAnalytics._() : super._();

  factory _WorkspaceAnalytics.fromJson(Map<String, dynamic> json) =
      _$WorkspaceAnalyticsImpl.fromJson;

  @override
  @JsonKey(name: 'workspace_id')
  String get workspaceId;
  @override
  @JsonKey(name: 'total_students')
  int get totalStudents;
  @override
  @JsonKey(name: 'active_students_7d')
  int get activeStudents7d;
  @override
  @JsonKey(name: 'avg_overall_mastery')
  double get avgOverallMastery;
  @override
  @JsonKey(name: 'avg_questions_per_student')
  double get avgQuestionsPerStudent;
  @override
  @JsonKey(name: 'avg_correct_rate')
  double get avgCorrectRate;
  @override
  @JsonKey(name: 'topic_distribution')
  List<TopicStats> get topicDistribution;
  @override
  @JsonKey(name: 'difficulty_distribution')
  Map<String, DifficultyStats> get difficultyDistribution;
  @override
  @JsonKey(name: 'engagement_heatmap')
  List<HeatmapCell> get engagementHeatmap;

  /// Create a copy of WorkspaceAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkspaceAnalyticsImplCopyWith<_$WorkspaceAnalyticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TenantWorkspaceSummary _$TenantWorkspaceSummaryFromJson(
    Map<String, dynamic> json) {
  return _TenantWorkspaceSummary.fromJson(json);
}

/// @nodoc
mixin _$TenantWorkspaceSummary {
  @JsonKey(name: 'workspace_id')
  String get workspaceId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_students')
  int get totalStudents => throw _privateConstructorUsedError;
  @JsonKey(name: 'active_students_7d')
  int get activeStudents7d => throw _privateConstructorUsedError;
  @JsonKey(name: 'avg_mastery')
  double get avgMastery => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_questions_answered')
  int get totalQuestionsAnswered => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_flashcards_reviewed')
  int get totalFlashcardsReviewed => throw _privateConstructorUsedError;

  /// Serializes this TenantWorkspaceSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TenantWorkspaceSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TenantWorkspaceSummaryCopyWith<TenantWorkspaceSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TenantWorkspaceSummaryCopyWith<$Res> {
  factory $TenantWorkspaceSummaryCopyWith(TenantWorkspaceSummary value,
          $Res Function(TenantWorkspaceSummary) then) =
      _$TenantWorkspaceSummaryCopyWithImpl<$Res, TenantWorkspaceSummary>;
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      String name,
      @JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'active_students_7d') int activeStudents7d,
      @JsonKey(name: 'avg_mastery') double avgMastery,
      @JsonKey(name: 'total_questions_answered') int totalQuestionsAnswered,
      @JsonKey(name: 'total_flashcards_reviewed') int totalFlashcardsReviewed});
}

/// @nodoc
class _$TenantWorkspaceSummaryCopyWithImpl<$Res,
        $Val extends TenantWorkspaceSummary>
    implements $TenantWorkspaceSummaryCopyWith<$Res> {
  _$TenantWorkspaceSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TenantWorkspaceSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? name = null,
    Object? totalStudents = null,
    Object? activeStudents7d = null,
    Object? avgMastery = null,
    Object? totalQuestionsAnswered = null,
    Object? totalFlashcardsReviewed = null,
  }) {
    return _then(_value.copyWith(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      activeStudents7d: null == activeStudents7d
          ? _value.activeStudents7d
          : activeStudents7d // ignore: cast_nullable_to_non_nullable
              as int,
      avgMastery: null == avgMastery
          ? _value.avgMastery
          : avgMastery // ignore: cast_nullable_to_non_nullable
              as double,
      totalQuestionsAnswered: null == totalQuestionsAnswered
          ? _value.totalQuestionsAnswered
          : totalQuestionsAnswered // ignore: cast_nullable_to_non_nullable
              as int,
      totalFlashcardsReviewed: null == totalFlashcardsReviewed
          ? _value.totalFlashcardsReviewed
          : totalFlashcardsReviewed // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TenantWorkspaceSummaryImplCopyWith<$Res>
    implements $TenantWorkspaceSummaryCopyWith<$Res> {
  factory _$$TenantWorkspaceSummaryImplCopyWith(
          _$TenantWorkspaceSummaryImpl value,
          $Res Function(_$TenantWorkspaceSummaryImpl) then) =
      __$$TenantWorkspaceSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      String name,
      @JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'active_students_7d') int activeStudents7d,
      @JsonKey(name: 'avg_mastery') double avgMastery,
      @JsonKey(name: 'total_questions_answered') int totalQuestionsAnswered,
      @JsonKey(name: 'total_flashcards_reviewed') int totalFlashcardsReviewed});
}

/// @nodoc
class __$$TenantWorkspaceSummaryImplCopyWithImpl<$Res>
    extends _$TenantWorkspaceSummaryCopyWithImpl<$Res,
        _$TenantWorkspaceSummaryImpl>
    implements _$$TenantWorkspaceSummaryImplCopyWith<$Res> {
  __$$TenantWorkspaceSummaryImplCopyWithImpl(
      _$TenantWorkspaceSummaryImpl _value,
      $Res Function(_$TenantWorkspaceSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of TenantWorkspaceSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? name = null,
    Object? totalStudents = null,
    Object? activeStudents7d = null,
    Object? avgMastery = null,
    Object? totalQuestionsAnswered = null,
    Object? totalFlashcardsReviewed = null,
  }) {
    return _then(_$TenantWorkspaceSummaryImpl(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      activeStudents7d: null == activeStudents7d
          ? _value.activeStudents7d
          : activeStudents7d // ignore: cast_nullable_to_non_nullable
              as int,
      avgMastery: null == avgMastery
          ? _value.avgMastery
          : avgMastery // ignore: cast_nullable_to_non_nullable
              as double,
      totalQuestionsAnswered: null == totalQuestionsAnswered
          ? _value.totalQuestionsAnswered
          : totalQuestionsAnswered // ignore: cast_nullable_to_non_nullable
              as int,
      totalFlashcardsReviewed: null == totalFlashcardsReviewed
          ? _value.totalFlashcardsReviewed
          : totalFlashcardsReviewed // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TenantWorkspaceSummaryImpl implements _TenantWorkspaceSummary {
  const _$TenantWorkspaceSummaryImpl(
      {@JsonKey(name: 'workspace_id') required this.workspaceId,
      required this.name,
      @JsonKey(name: 'total_students') this.totalStudents = 0,
      @JsonKey(name: 'active_students_7d') this.activeStudents7d = 0,
      @JsonKey(name: 'avg_mastery') this.avgMastery = 0.0,
      @JsonKey(name: 'total_questions_answered')
      this.totalQuestionsAnswered = 0,
      @JsonKey(name: 'total_flashcards_reviewed')
      this.totalFlashcardsReviewed = 0});

  factory _$TenantWorkspaceSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$TenantWorkspaceSummaryImplFromJson(json);

  @override
  @JsonKey(name: 'workspace_id')
  final String workspaceId;
  @override
  final String name;
  @override
  @JsonKey(name: 'total_students')
  final int totalStudents;
  @override
  @JsonKey(name: 'active_students_7d')
  final int activeStudents7d;
  @override
  @JsonKey(name: 'avg_mastery')
  final double avgMastery;
  @override
  @JsonKey(name: 'total_questions_answered')
  final int totalQuestionsAnswered;
  @override
  @JsonKey(name: 'total_flashcards_reviewed')
  final int totalFlashcardsReviewed;

  @override
  String toString() {
    return 'TenantWorkspaceSummary(workspaceId: $workspaceId, name: $name, totalStudents: $totalStudents, activeStudents7d: $activeStudents7d, avgMastery: $avgMastery, totalQuestionsAnswered: $totalQuestionsAnswered, totalFlashcardsReviewed: $totalFlashcardsReviewed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TenantWorkspaceSummaryImpl &&
            (identical(other.workspaceId, workspaceId) ||
                other.workspaceId == workspaceId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.totalStudents, totalStudents) ||
                other.totalStudents == totalStudents) &&
            (identical(other.activeStudents7d, activeStudents7d) ||
                other.activeStudents7d == activeStudents7d) &&
            (identical(other.avgMastery, avgMastery) ||
                other.avgMastery == avgMastery) &&
            (identical(other.totalQuestionsAnswered, totalQuestionsAnswered) ||
                other.totalQuestionsAnswered == totalQuestionsAnswered) &&
            (identical(
                    other.totalFlashcardsReviewed, totalFlashcardsReviewed) ||
                other.totalFlashcardsReviewed == totalFlashcardsReviewed));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      workspaceId,
      name,
      totalStudents,
      activeStudents7d,
      avgMastery,
      totalQuestionsAnswered,
      totalFlashcardsReviewed);

  /// Create a copy of TenantWorkspaceSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TenantWorkspaceSummaryImplCopyWith<_$TenantWorkspaceSummaryImpl>
      get copyWith => __$$TenantWorkspaceSummaryImplCopyWithImpl<
          _$TenantWorkspaceSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TenantWorkspaceSummaryImplToJson(
      this,
    );
  }
}

abstract class _TenantWorkspaceSummary implements TenantWorkspaceSummary {
  const factory _TenantWorkspaceSummary(
      {@JsonKey(name: 'workspace_id') required final String workspaceId,
      required final String name,
      @JsonKey(name: 'total_students') final int totalStudents,
      @JsonKey(name: 'active_students_7d') final int activeStudents7d,
      @JsonKey(name: 'avg_mastery') final double avgMastery,
      @JsonKey(name: 'total_questions_answered')
      final int totalQuestionsAnswered,
      @JsonKey(name: 'total_flashcards_reviewed')
      final int totalFlashcardsReviewed}) = _$TenantWorkspaceSummaryImpl;

  factory _TenantWorkspaceSummary.fromJson(Map<String, dynamic> json) =
      _$TenantWorkspaceSummaryImpl.fromJson;

  @override
  @JsonKey(name: 'workspace_id')
  String get workspaceId;
  @override
  String get name;
  @override
  @JsonKey(name: 'total_students')
  int get totalStudents;
  @override
  @JsonKey(name: 'active_students_7d')
  int get activeStudents7d;
  @override
  @JsonKey(name: 'avg_mastery')
  double get avgMastery;
  @override
  @JsonKey(name: 'total_questions_answered')
  int get totalQuestionsAnswered;
  @override
  @JsonKey(name: 'total_flashcards_reviewed')
  int get totalFlashcardsReviewed;

  /// Create a copy of TenantWorkspaceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TenantWorkspaceSummaryImplCopyWith<_$TenantWorkspaceSummaryImpl>
      get copyWith => throw _privateConstructorUsedError;
}

TenantAnalytics _$TenantAnalyticsFromJson(Map<String, dynamic> json) {
  return _TenantAnalytics.fromJson(json);
}

/// @nodoc
mixin _$TenantAnalytics {
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_workspaces')
  int get totalWorkspaces => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_students')
  int get totalStudents => throw _privateConstructorUsedError;
  @JsonKey(name: 'active_students_7d')
  int get activeStudents7d => throw _privateConstructorUsedError;
  List<TenantWorkspaceSummary> get workspaces =>
      throw _privateConstructorUsedError;

  /// Serializes this TenantAnalytics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TenantAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TenantAnalyticsCopyWith<TenantAnalytics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TenantAnalyticsCopyWith<$Res> {
  factory $TenantAnalyticsCopyWith(
          TenantAnalytics value, $Res Function(TenantAnalytics) then) =
      _$TenantAnalyticsCopyWithImpl<$Res, TenantAnalytics>;
  @useResult
  $Res call(
      {@JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'total_workspaces') int totalWorkspaces,
      @JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'active_students_7d') int activeStudents7d,
      List<TenantWorkspaceSummary> workspaces});
}

/// @nodoc
class _$TenantAnalyticsCopyWithImpl<$Res, $Val extends TenantAnalytics>
    implements $TenantAnalyticsCopyWith<$Res> {
  _$TenantAnalyticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TenantAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tenantId = null,
    Object? totalWorkspaces = null,
    Object? totalStudents = null,
    Object? activeStudents7d = null,
    Object? workspaces = null,
  }) {
    return _then(_value.copyWith(
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      totalWorkspaces: null == totalWorkspaces
          ? _value.totalWorkspaces
          : totalWorkspaces // ignore: cast_nullable_to_non_nullable
              as int,
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      activeStudents7d: null == activeStudents7d
          ? _value.activeStudents7d
          : activeStudents7d // ignore: cast_nullable_to_non_nullable
              as int,
      workspaces: null == workspaces
          ? _value.workspaces
          : workspaces // ignore: cast_nullable_to_non_nullable
              as List<TenantWorkspaceSummary>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TenantAnalyticsImplCopyWith<$Res>
    implements $TenantAnalyticsCopyWith<$Res> {
  factory _$$TenantAnalyticsImplCopyWith(_$TenantAnalyticsImpl value,
          $Res Function(_$TenantAnalyticsImpl) then) =
      __$$TenantAnalyticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'tenant_id') String tenantId,
      @JsonKey(name: 'total_workspaces') int totalWorkspaces,
      @JsonKey(name: 'total_students') int totalStudents,
      @JsonKey(name: 'active_students_7d') int activeStudents7d,
      List<TenantWorkspaceSummary> workspaces});
}

/// @nodoc
class __$$TenantAnalyticsImplCopyWithImpl<$Res>
    extends _$TenantAnalyticsCopyWithImpl<$Res, _$TenantAnalyticsImpl>
    implements _$$TenantAnalyticsImplCopyWith<$Res> {
  __$$TenantAnalyticsImplCopyWithImpl(
      _$TenantAnalyticsImpl _value, $Res Function(_$TenantAnalyticsImpl) _then)
      : super(_value, _then);

  /// Create a copy of TenantAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tenantId = null,
    Object? totalWorkspaces = null,
    Object? totalStudents = null,
    Object? activeStudents7d = null,
    Object? workspaces = null,
  }) {
    return _then(_$TenantAnalyticsImpl(
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      totalWorkspaces: null == totalWorkspaces
          ? _value.totalWorkspaces
          : totalWorkspaces // ignore: cast_nullable_to_non_nullable
              as int,
      totalStudents: null == totalStudents
          ? _value.totalStudents
          : totalStudents // ignore: cast_nullable_to_non_nullable
              as int,
      activeStudents7d: null == activeStudents7d
          ? _value.activeStudents7d
          : activeStudents7d // ignore: cast_nullable_to_non_nullable
              as int,
      workspaces: null == workspaces
          ? _value._workspaces
          : workspaces // ignore: cast_nullable_to_non_nullable
              as List<TenantWorkspaceSummary>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TenantAnalyticsImpl implements _TenantAnalytics {
  const _$TenantAnalyticsImpl(
      {@JsonKey(name: 'tenant_id') required this.tenantId,
      @JsonKey(name: 'total_workspaces') this.totalWorkspaces = 0,
      @JsonKey(name: 'total_students') this.totalStudents = 0,
      @JsonKey(name: 'active_students_7d') this.activeStudents7d = 0,
      final List<TenantWorkspaceSummary> workspaces =
          const <TenantWorkspaceSummary>[]})
      : _workspaces = workspaces;

  factory _$TenantAnalyticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$TenantAnalyticsImplFromJson(json);

  @override
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @override
  @JsonKey(name: 'total_workspaces')
  final int totalWorkspaces;
  @override
  @JsonKey(name: 'total_students')
  final int totalStudents;
  @override
  @JsonKey(name: 'active_students_7d')
  final int activeStudents7d;
  final List<TenantWorkspaceSummary> _workspaces;
  @override
  @JsonKey()
  List<TenantWorkspaceSummary> get workspaces {
    if (_workspaces is EqualUnmodifiableListView) return _workspaces;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_workspaces);
  }

  @override
  String toString() {
    return 'TenantAnalytics(tenantId: $tenantId, totalWorkspaces: $totalWorkspaces, totalStudents: $totalStudents, activeStudents7d: $activeStudents7d, workspaces: $workspaces)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TenantAnalyticsImpl &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.totalWorkspaces, totalWorkspaces) ||
                other.totalWorkspaces == totalWorkspaces) &&
            (identical(other.totalStudents, totalStudents) ||
                other.totalStudents == totalStudents) &&
            (identical(other.activeStudents7d, activeStudents7d) ||
                other.activeStudents7d == activeStudents7d) &&
            const DeepCollectionEquality()
                .equals(other._workspaces, _workspaces));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      tenantId,
      totalWorkspaces,
      totalStudents,
      activeStudents7d,
      const DeepCollectionEquality().hash(_workspaces));

  /// Create a copy of TenantAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TenantAnalyticsImplCopyWith<_$TenantAnalyticsImpl> get copyWith =>
      __$$TenantAnalyticsImplCopyWithImpl<_$TenantAnalyticsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TenantAnalyticsImplToJson(
      this,
    );
  }
}

abstract class _TenantAnalytics implements TenantAnalytics {
  const factory _TenantAnalytics(
      {@JsonKey(name: 'tenant_id') required final String tenantId,
      @JsonKey(name: 'total_workspaces') final int totalWorkspaces,
      @JsonKey(name: 'total_students') final int totalStudents,
      @JsonKey(name: 'active_students_7d') final int activeStudents7d,
      final List<TenantWorkspaceSummary> workspaces}) = _$TenantAnalyticsImpl;

  factory _TenantAnalytics.fromJson(Map<String, dynamic> json) =
      _$TenantAnalyticsImpl.fromJson;

  @override
  @JsonKey(name: 'tenant_id')
  String get tenantId;
  @override
  @JsonKey(name: 'total_workspaces')
  int get totalWorkspaces;
  @override
  @JsonKey(name: 'total_students')
  int get totalStudents;
  @override
  @JsonKey(name: 'active_students_7d')
  int get activeStudents7d;
  @override
  List<TenantWorkspaceSummary> get workspaces;

  /// Create a copy of TenantAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TenantAnalyticsImplCopyWith<_$TenantAnalyticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
