// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'question.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

McqOption _$McqOptionFromJson(Map<String, dynamic> json) {
  return _McqOption.fromJson(json);
}

/// @nodoc
mixin _$McqOption {
  String get key => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;

  /// Serializes this McqOption to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of McqOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $McqOptionCopyWith<McqOption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $McqOptionCopyWith<$Res> {
  factory $McqOptionCopyWith(McqOption value, $Res Function(McqOption) then) =
      _$McqOptionCopyWithImpl<$Res, McqOption>;
  @useResult
  $Res call({String key, String text});
}

/// @nodoc
class _$McqOptionCopyWithImpl<$Res, $Val extends McqOption>
    implements $McqOptionCopyWith<$Res> {
  _$McqOptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of McqOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? text = null,
  }) {
    return _then(_value.copyWith(
      key: null == key
          ? _value.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$McqOptionImplCopyWith<$Res>
    implements $McqOptionCopyWith<$Res> {
  factory _$$McqOptionImplCopyWith(
          _$McqOptionImpl value, $Res Function(_$McqOptionImpl) then) =
      __$$McqOptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String key, String text});
}

/// @nodoc
class __$$McqOptionImplCopyWithImpl<$Res>
    extends _$McqOptionCopyWithImpl<$Res, _$McqOptionImpl>
    implements _$$McqOptionImplCopyWith<$Res> {
  __$$McqOptionImplCopyWithImpl(
      _$McqOptionImpl _value, $Res Function(_$McqOptionImpl) _then)
      : super(_value, _then);

  /// Create a copy of McqOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? text = null,
  }) {
    return _then(_$McqOptionImpl(
      key: null == key
          ? _value.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$McqOptionImpl implements _McqOption {
  const _$McqOptionImpl({required this.key, required this.text});

  factory _$McqOptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$McqOptionImplFromJson(json);

  @override
  final String key;
  @override
  final String text;

  @override
  String toString() {
    return 'McqOption(key: $key, text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$McqOptionImpl &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.text, text) || other.text == text));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, key, text);

  /// Create a copy of McqOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$McqOptionImplCopyWith<_$McqOptionImpl> get copyWith =>
      __$$McqOptionImplCopyWithImpl<_$McqOptionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$McqOptionImplToJson(
      this,
    );
  }
}

abstract class _McqOption implements McqOption {
  const factory _McqOption(
      {required final String key,
      required final String text}) = _$McqOptionImpl;

  factory _McqOption.fromJson(Map<String, dynamic> json) =
      _$McqOptionImpl.fromJson;

  @override
  String get key;
  @override
  String get text;

  /// Create a copy of McqOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$McqOptionImplCopyWith<_$McqOptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Question _$QuestionFromJson(Map<String, dynamic> json) {
  return _Question.fromJson(json);
}

/// @nodoc
mixin _$Question {
  String get id => throw _privateConstructorUsedError;
  String get topic => throw _privateConstructorUsedError;
  @JsonKey(name: 'question_type')
  QuestionType get questionType => throw _privateConstructorUsedError;
  DifficultyLevel get difficulty => throw _privateConstructorUsedError;
  String get body => throw _privateConstructorUsedError;
  List<McqOption> get options => throw _privateConstructorUsedError;

  /// Serializes this Question to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionCopyWith<Question> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionCopyWith<$Res> {
  factory $QuestionCopyWith(Question value, $Res Function(Question) then) =
      _$QuestionCopyWithImpl<$Res, Question>;
  @useResult
  $Res call(
      {String id,
      String topic,
      @JsonKey(name: 'question_type') QuestionType questionType,
      DifficultyLevel difficulty,
      String body,
      List<McqOption> options});
}

/// @nodoc
class _$QuestionCopyWithImpl<$Res, $Val extends Question>
    implements $QuestionCopyWith<$Res> {
  _$QuestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? topic = null,
    Object? questionType = null,
    Object? difficulty = null,
    Object? body = null,
    Object? options = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      questionType: null == questionType
          ? _value.questionType
          : questionType // ignore: cast_nullable_to_non_nullable
              as QuestionType,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as DifficultyLevel,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      options: null == options
          ? _value.options
          : options // ignore: cast_nullable_to_non_nullable
              as List<McqOption>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuestionImplCopyWith<$Res>
    implements $QuestionCopyWith<$Res> {
  factory _$$QuestionImplCopyWith(
          _$QuestionImpl value, $Res Function(_$QuestionImpl) then) =
      __$$QuestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String topic,
      @JsonKey(name: 'question_type') QuestionType questionType,
      DifficultyLevel difficulty,
      String body,
      List<McqOption> options});
}

/// @nodoc
class __$$QuestionImplCopyWithImpl<$Res>
    extends _$QuestionCopyWithImpl<$Res, _$QuestionImpl>
    implements _$$QuestionImplCopyWith<$Res> {
  __$$QuestionImplCopyWithImpl(
      _$QuestionImpl _value, $Res Function(_$QuestionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? topic = null,
    Object? questionType = null,
    Object? difficulty = null,
    Object? body = null,
    Object? options = null,
  }) {
    return _then(_$QuestionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      questionType: null == questionType
          ? _value.questionType
          : questionType // ignore: cast_nullable_to_non_nullable
              as QuestionType,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as DifficultyLevel,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      options: null == options
          ? _value._options
          : options // ignore: cast_nullable_to_non_nullable
              as List<McqOption>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuestionImpl implements _Question {
  const _$QuestionImpl(
      {required this.id,
      required this.topic,
      @JsonKey(name: 'question_type') required this.questionType,
      required this.difficulty,
      required this.body,
      final List<McqOption> options = const <McqOption>[]})
      : _options = options;

  factory _$QuestionImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuestionImplFromJson(json);

  @override
  final String id;
  @override
  final String topic;
  @override
  @JsonKey(name: 'question_type')
  final QuestionType questionType;
  @override
  final DifficultyLevel difficulty;
  @override
  final String body;
  final List<McqOption> _options;
  @override
  @JsonKey()
  List<McqOption> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  String toString() {
    return 'Question(id: $id, topic: $topic, questionType: $questionType, difficulty: $difficulty, body: $body, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.questionType, questionType) ||
                other.questionType == questionType) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.body, body) || other.body == body) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, topic, questionType,
      difficulty, body, const DeepCollectionEquality().hash(_options));

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionImplCopyWith<_$QuestionImpl> get copyWith =>
      __$$QuestionImplCopyWithImpl<_$QuestionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuestionImplToJson(
      this,
    );
  }
}

abstract class _Question implements Question {
  const factory _Question(
      {required final String id,
      required final String topic,
      @JsonKey(name: 'question_type') required final QuestionType questionType,
      required final DifficultyLevel difficulty,
      required final String body,
      final List<McqOption> options}) = _$QuestionImpl;

  factory _Question.fromJson(Map<String, dynamic> json) =
      _$QuestionImpl.fromJson;

  @override
  String get id;
  @override
  String get topic;
  @override
  @JsonKey(name: 'question_type')
  QuestionType get questionType;
  @override
  DifficultyLevel get difficulty;
  @override
  String get body;
  @override
  List<McqOption> get options;

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionImplCopyWith<_$QuestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AnswerSubmission _$AnswerSubmissionFromJson(Map<String, dynamic> json) {
  return _AnswerSubmission.fromJson(json);
}

/// @nodoc
mixin _$AnswerSubmission {
  String get answer => throw _privateConstructorUsedError;
  @JsonKey(name: 'time_spent_seconds')
  int get timeSpentSeconds => throw _privateConstructorUsedError;

  /// Serializes this AnswerSubmission to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnswerSubmission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnswerSubmissionCopyWith<AnswerSubmission> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnswerSubmissionCopyWith<$Res> {
  factory $AnswerSubmissionCopyWith(
          AnswerSubmission value, $Res Function(AnswerSubmission) then) =
      _$AnswerSubmissionCopyWithImpl<$Res, AnswerSubmission>;
  @useResult
  $Res call(
      {String answer,
      @JsonKey(name: 'time_spent_seconds') int timeSpentSeconds});
}

/// @nodoc
class _$AnswerSubmissionCopyWithImpl<$Res, $Val extends AnswerSubmission>
    implements $AnswerSubmissionCopyWith<$Res> {
  _$AnswerSubmissionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnswerSubmission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? answer = null,
    Object? timeSpentSeconds = null,
  }) {
    return _then(_value.copyWith(
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String,
      timeSpentSeconds: null == timeSpentSeconds
          ? _value.timeSpentSeconds
          : timeSpentSeconds // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnswerSubmissionImplCopyWith<$Res>
    implements $AnswerSubmissionCopyWith<$Res> {
  factory _$$AnswerSubmissionImplCopyWith(_$AnswerSubmissionImpl value,
          $Res Function(_$AnswerSubmissionImpl) then) =
      __$$AnswerSubmissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String answer,
      @JsonKey(name: 'time_spent_seconds') int timeSpentSeconds});
}

/// @nodoc
class __$$AnswerSubmissionImplCopyWithImpl<$Res>
    extends _$AnswerSubmissionCopyWithImpl<$Res, _$AnswerSubmissionImpl>
    implements _$$AnswerSubmissionImplCopyWith<$Res> {
  __$$AnswerSubmissionImplCopyWithImpl(_$AnswerSubmissionImpl _value,
      $Res Function(_$AnswerSubmissionImpl) _then)
      : super(_value, _then);

  /// Create a copy of AnswerSubmission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? answer = null,
    Object? timeSpentSeconds = null,
  }) {
    return _then(_$AnswerSubmissionImpl(
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String,
      timeSpentSeconds: null == timeSpentSeconds
          ? _value.timeSpentSeconds
          : timeSpentSeconds // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AnswerSubmissionImpl implements _AnswerSubmission {
  const _$AnswerSubmissionImpl(
      {required this.answer,
      @JsonKey(name: 'time_spent_seconds') this.timeSpentSeconds = 0});

  factory _$AnswerSubmissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnswerSubmissionImplFromJson(json);

  @override
  final String answer;
  @override
  @JsonKey(name: 'time_spent_seconds')
  final int timeSpentSeconds;

  @override
  String toString() {
    return 'AnswerSubmission(answer: $answer, timeSpentSeconds: $timeSpentSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnswerSubmissionImpl &&
            (identical(other.answer, answer) || other.answer == answer) &&
            (identical(other.timeSpentSeconds, timeSpentSeconds) ||
                other.timeSpentSeconds == timeSpentSeconds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, answer, timeSpentSeconds);

  /// Create a copy of AnswerSubmission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnswerSubmissionImplCopyWith<_$AnswerSubmissionImpl> get copyWith =>
      __$$AnswerSubmissionImplCopyWithImpl<_$AnswerSubmissionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnswerSubmissionImplToJson(
      this,
    );
  }
}

abstract class _AnswerSubmission implements AnswerSubmission {
  const factory _AnswerSubmission(
          {required final String answer,
          @JsonKey(name: 'time_spent_seconds') final int timeSpentSeconds}) =
      _$AnswerSubmissionImpl;

  factory _AnswerSubmission.fromJson(Map<String, dynamic> json) =
      _$AnswerSubmissionImpl.fromJson;

  @override
  String get answer;
  @override
  @JsonKey(name: 'time_spent_seconds')
  int get timeSpentSeconds;

  /// Create a copy of AnswerSubmission
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnswerSubmissionImplCopyWith<_$AnswerSubmissionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AnswerFeedback _$AnswerFeedbackFromJson(Map<String, dynamic> json) {
  return _AnswerFeedback.fromJson(json);
}

/// @nodoc
mixin _$AnswerFeedback {
  @JsonKey(name: 'question_id')
  String get questionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_correct')
  bool get isCorrect => throw _privateConstructorUsedError;
  @JsonKey(name: 'canonical_answer')
  String get canonicalAnswer => throw _privateConstructorUsedError;
  String get explanation => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_earned')
  int get xpEarned => throw _privateConstructorUsedError;
  @JsonKey(name: 'new_topic_mastery')
  double get newTopicMastery => throw _privateConstructorUsedError;
  @JsonKey(name: 'new_overall_mastery')
  double get newOverallMastery => throw _privateConstructorUsedError;
  @JsonKey(name: 'rubric_score')
  double? get rubricScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'matched_hints')
  List<String> get matchedHints => throw _privateConstructorUsedError;

  /// Serializes this AnswerFeedback to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnswerFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnswerFeedbackCopyWith<AnswerFeedback> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnswerFeedbackCopyWith<$Res> {
  factory $AnswerFeedbackCopyWith(
          AnswerFeedback value, $Res Function(AnswerFeedback) then) =
      _$AnswerFeedbackCopyWithImpl<$Res, AnswerFeedback>;
  @useResult
  $Res call(
      {@JsonKey(name: 'question_id') String questionId,
      @JsonKey(name: 'is_correct') bool isCorrect,
      @JsonKey(name: 'canonical_answer') String canonicalAnswer,
      String explanation,
      @JsonKey(name: 'xp_earned') int xpEarned,
      @JsonKey(name: 'new_topic_mastery') double newTopicMastery,
      @JsonKey(name: 'new_overall_mastery') double newOverallMastery,
      @JsonKey(name: 'rubric_score') double? rubricScore,
      @JsonKey(name: 'matched_hints') List<String> matchedHints});
}

/// @nodoc
class _$AnswerFeedbackCopyWithImpl<$Res, $Val extends AnswerFeedback>
    implements $AnswerFeedbackCopyWith<$Res> {
  _$AnswerFeedbackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnswerFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionId = null,
    Object? isCorrect = null,
    Object? canonicalAnswer = null,
    Object? explanation = null,
    Object? xpEarned = null,
    Object? newTopicMastery = null,
    Object? newOverallMastery = null,
    Object? rubricScore = freezed,
    Object? matchedHints = null,
  }) {
    return _then(_value.copyWith(
      questionId: null == questionId
          ? _value.questionId
          : questionId // ignore: cast_nullable_to_non_nullable
              as String,
      isCorrect: null == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool,
      canonicalAnswer: null == canonicalAnswer
          ? _value.canonicalAnswer
          : canonicalAnswer // ignore: cast_nullable_to_non_nullable
              as String,
      explanation: null == explanation
          ? _value.explanation
          : explanation // ignore: cast_nullable_to_non_nullable
              as String,
      xpEarned: null == xpEarned
          ? _value.xpEarned
          : xpEarned // ignore: cast_nullable_to_non_nullable
              as int,
      newTopicMastery: null == newTopicMastery
          ? _value.newTopicMastery
          : newTopicMastery // ignore: cast_nullable_to_non_nullable
              as double,
      newOverallMastery: null == newOverallMastery
          ? _value.newOverallMastery
          : newOverallMastery // ignore: cast_nullable_to_non_nullable
              as double,
      rubricScore: freezed == rubricScore
          ? _value.rubricScore
          : rubricScore // ignore: cast_nullable_to_non_nullable
              as double?,
      matchedHints: null == matchedHints
          ? _value.matchedHints
          : matchedHints // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnswerFeedbackImplCopyWith<$Res>
    implements $AnswerFeedbackCopyWith<$Res> {
  factory _$$AnswerFeedbackImplCopyWith(_$AnswerFeedbackImpl value,
          $Res Function(_$AnswerFeedbackImpl) then) =
      __$$AnswerFeedbackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'question_id') String questionId,
      @JsonKey(name: 'is_correct') bool isCorrect,
      @JsonKey(name: 'canonical_answer') String canonicalAnswer,
      String explanation,
      @JsonKey(name: 'xp_earned') int xpEarned,
      @JsonKey(name: 'new_topic_mastery') double newTopicMastery,
      @JsonKey(name: 'new_overall_mastery') double newOverallMastery,
      @JsonKey(name: 'rubric_score') double? rubricScore,
      @JsonKey(name: 'matched_hints') List<String> matchedHints});
}

/// @nodoc
class __$$AnswerFeedbackImplCopyWithImpl<$Res>
    extends _$AnswerFeedbackCopyWithImpl<$Res, _$AnswerFeedbackImpl>
    implements _$$AnswerFeedbackImplCopyWith<$Res> {
  __$$AnswerFeedbackImplCopyWithImpl(
      _$AnswerFeedbackImpl _value, $Res Function(_$AnswerFeedbackImpl) _then)
      : super(_value, _then);

  /// Create a copy of AnswerFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionId = null,
    Object? isCorrect = null,
    Object? canonicalAnswer = null,
    Object? explanation = null,
    Object? xpEarned = null,
    Object? newTopicMastery = null,
    Object? newOverallMastery = null,
    Object? rubricScore = freezed,
    Object? matchedHints = null,
  }) {
    return _then(_$AnswerFeedbackImpl(
      questionId: null == questionId
          ? _value.questionId
          : questionId // ignore: cast_nullable_to_non_nullable
              as String,
      isCorrect: null == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool,
      canonicalAnswer: null == canonicalAnswer
          ? _value.canonicalAnswer
          : canonicalAnswer // ignore: cast_nullable_to_non_nullable
              as String,
      explanation: null == explanation
          ? _value.explanation
          : explanation // ignore: cast_nullable_to_non_nullable
              as String,
      xpEarned: null == xpEarned
          ? _value.xpEarned
          : xpEarned // ignore: cast_nullable_to_non_nullable
              as int,
      newTopicMastery: null == newTopicMastery
          ? _value.newTopicMastery
          : newTopicMastery // ignore: cast_nullable_to_non_nullable
              as double,
      newOverallMastery: null == newOverallMastery
          ? _value.newOverallMastery
          : newOverallMastery // ignore: cast_nullable_to_non_nullable
              as double,
      rubricScore: freezed == rubricScore
          ? _value.rubricScore
          : rubricScore // ignore: cast_nullable_to_non_nullable
              as double?,
      matchedHints: null == matchedHints
          ? _value._matchedHints
          : matchedHints // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AnswerFeedbackImpl implements _AnswerFeedback {
  const _$AnswerFeedbackImpl(
      {@JsonKey(name: 'question_id') required this.questionId,
      @JsonKey(name: 'is_correct') required this.isCorrect,
      @JsonKey(name: 'canonical_answer') required this.canonicalAnswer,
      required this.explanation,
      @JsonKey(name: 'xp_earned') required this.xpEarned,
      @JsonKey(name: 'new_topic_mastery') required this.newTopicMastery,
      @JsonKey(name: 'new_overall_mastery') required this.newOverallMastery,
      @JsonKey(name: 'rubric_score') this.rubricScore,
      @JsonKey(name: 'matched_hints')
      final List<String> matchedHints = const <String>[]})
      : _matchedHints = matchedHints;

  factory _$AnswerFeedbackImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnswerFeedbackImplFromJson(json);

  @override
  @JsonKey(name: 'question_id')
  final String questionId;
  @override
  @JsonKey(name: 'is_correct')
  final bool isCorrect;
  @override
  @JsonKey(name: 'canonical_answer')
  final String canonicalAnswer;
  @override
  final String explanation;
  @override
  @JsonKey(name: 'xp_earned')
  final int xpEarned;
  @override
  @JsonKey(name: 'new_topic_mastery')
  final double newTopicMastery;
  @override
  @JsonKey(name: 'new_overall_mastery')
  final double newOverallMastery;
  @override
  @JsonKey(name: 'rubric_score')
  final double? rubricScore;
  final List<String> _matchedHints;
  @override
  @JsonKey(name: 'matched_hints')
  List<String> get matchedHints {
    if (_matchedHints is EqualUnmodifiableListView) return _matchedHints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_matchedHints);
  }

  @override
  String toString() {
    return 'AnswerFeedback(questionId: $questionId, isCorrect: $isCorrect, canonicalAnswer: $canonicalAnswer, explanation: $explanation, xpEarned: $xpEarned, newTopicMastery: $newTopicMastery, newOverallMastery: $newOverallMastery, rubricScore: $rubricScore, matchedHints: $matchedHints)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnswerFeedbackImpl &&
            (identical(other.questionId, questionId) ||
                other.questionId == questionId) &&
            (identical(other.isCorrect, isCorrect) ||
                other.isCorrect == isCorrect) &&
            (identical(other.canonicalAnswer, canonicalAnswer) ||
                other.canonicalAnswer == canonicalAnswer) &&
            (identical(other.explanation, explanation) ||
                other.explanation == explanation) &&
            (identical(other.xpEarned, xpEarned) ||
                other.xpEarned == xpEarned) &&
            (identical(other.newTopicMastery, newTopicMastery) ||
                other.newTopicMastery == newTopicMastery) &&
            (identical(other.newOverallMastery, newOverallMastery) ||
                other.newOverallMastery == newOverallMastery) &&
            (identical(other.rubricScore, rubricScore) ||
                other.rubricScore == rubricScore) &&
            const DeepCollectionEquality()
                .equals(other._matchedHints, _matchedHints));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      questionId,
      isCorrect,
      canonicalAnswer,
      explanation,
      xpEarned,
      newTopicMastery,
      newOverallMastery,
      rubricScore,
      const DeepCollectionEquality().hash(_matchedHints));

  /// Create a copy of AnswerFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnswerFeedbackImplCopyWith<_$AnswerFeedbackImpl> get copyWith =>
      __$$AnswerFeedbackImplCopyWithImpl<_$AnswerFeedbackImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnswerFeedbackImplToJson(
      this,
    );
  }
}

abstract class _AnswerFeedback implements AnswerFeedback {
  const factory _AnswerFeedback(
      {@JsonKey(name: 'question_id') required final String questionId,
      @JsonKey(name: 'is_correct') required final bool isCorrect,
      @JsonKey(name: 'canonical_answer') required final String canonicalAnswer,
      required final String explanation,
      @JsonKey(name: 'xp_earned') required final int xpEarned,
      @JsonKey(name: 'new_topic_mastery') required final double newTopicMastery,
      @JsonKey(name: 'new_overall_mastery')
      required final double newOverallMastery,
      @JsonKey(name: 'rubric_score') final double? rubricScore,
      @JsonKey(name: 'matched_hints')
      final List<String> matchedHints}) = _$AnswerFeedbackImpl;

  factory _AnswerFeedback.fromJson(Map<String, dynamic> json) =
      _$AnswerFeedbackImpl.fromJson;

  @override
  @JsonKey(name: 'question_id')
  String get questionId;
  @override
  @JsonKey(name: 'is_correct')
  bool get isCorrect;
  @override
  @JsonKey(name: 'canonical_answer')
  String get canonicalAnswer;
  @override
  String get explanation;
  @override
  @JsonKey(name: 'xp_earned')
  int get xpEarned;
  @override
  @JsonKey(name: 'new_topic_mastery')
  double get newTopicMastery;
  @override
  @JsonKey(name: 'new_overall_mastery')
  double get newOverallMastery;
  @override
  @JsonKey(name: 'rubric_score')
  double? get rubricScore;
  @override
  @JsonKey(name: 'matched_hints')
  List<String> get matchedHints;

  /// Create a copy of AnswerFeedback
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnswerFeedbackImplCopyWith<_$AnswerFeedbackImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
