// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flashcard.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Flashcard _$FlashcardFromJson(Map<String, dynamic> json) {
  return _Flashcard.fromJson(json);
}

/// @nodoc
mixin _$Flashcard {
  String get id => throw _privateConstructorUsedError;
  String get topic => throw _privateConstructorUsedError;

  /// The cue side — shown first, what the student tries to recall from.
  String get front => throw _privateConstructorUsedError;

  /// The recall target — revealed after the flip gesture.
  String get back => throw _privateConstructorUsedError;

  /// Optional extra context shown alongside the back after the flip.
  String get explanation => throw _privateConstructorUsedError;

  /// Serializes this Flashcard to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Flashcard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlashcardCopyWith<Flashcard> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlashcardCopyWith<$Res> {
  factory $FlashcardCopyWith(Flashcard value, $Res Function(Flashcard) then) =
      _$FlashcardCopyWithImpl<$Res, Flashcard>;
  @useResult
  $Res call(
      {String id, String topic, String front, String back, String explanation});
}

/// @nodoc
class _$FlashcardCopyWithImpl<$Res, $Val extends Flashcard>
    implements $FlashcardCopyWith<$Res> {
  _$FlashcardCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Flashcard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? topic = null,
    Object? front = null,
    Object? back = null,
    Object? explanation = null,
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
      front: null == front
          ? _value.front
          : front // ignore: cast_nullable_to_non_nullable
              as String,
      back: null == back
          ? _value.back
          : back // ignore: cast_nullable_to_non_nullable
              as String,
      explanation: null == explanation
          ? _value.explanation
          : explanation // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlashcardImplCopyWith<$Res>
    implements $FlashcardCopyWith<$Res> {
  factory _$$FlashcardImplCopyWith(
          _$FlashcardImpl value, $Res Function(_$FlashcardImpl) then) =
      __$$FlashcardImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id, String topic, String front, String back, String explanation});
}

/// @nodoc
class __$$FlashcardImplCopyWithImpl<$Res>
    extends _$FlashcardCopyWithImpl<$Res, _$FlashcardImpl>
    implements _$$FlashcardImplCopyWith<$Res> {
  __$$FlashcardImplCopyWithImpl(
      _$FlashcardImpl _value, $Res Function(_$FlashcardImpl) _then)
      : super(_value, _then);

  /// Create a copy of Flashcard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? topic = null,
    Object? front = null,
    Object? back = null,
    Object? explanation = null,
  }) {
    return _then(_$FlashcardImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      front: null == front
          ? _value.front
          : front // ignore: cast_nullable_to_non_nullable
              as String,
      back: null == back
          ? _value.back
          : back // ignore: cast_nullable_to_non_nullable
              as String,
      explanation: null == explanation
          ? _value.explanation
          : explanation // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlashcardImpl implements _Flashcard {
  const _$FlashcardImpl(
      {required this.id,
      required this.topic,
      required this.front,
      required this.back,
      this.explanation = ''});

  factory _$FlashcardImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlashcardImplFromJson(json);

  @override
  final String id;
  @override
  final String topic;

  /// The cue side — shown first, what the student tries to recall from.
  @override
  final String front;

  /// The recall target — revealed after the flip gesture.
  @override
  final String back;

  /// Optional extra context shown alongside the back after the flip.
  @override
  @JsonKey()
  final String explanation;

  @override
  String toString() {
    return 'Flashcard(id: $id, topic: $topic, front: $front, back: $back, explanation: $explanation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.front, front) || other.front == front) &&
            (identical(other.back, back) || other.back == back) &&
            (identical(other.explanation, explanation) ||
                other.explanation == explanation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, topic, front, back, explanation);

  /// Create a copy of Flashcard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardImplCopyWith<_$FlashcardImpl> get copyWith =>
      __$$FlashcardImplCopyWithImpl<_$FlashcardImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlashcardImplToJson(
      this,
    );
  }
}

abstract class _Flashcard implements Flashcard {
  const factory _Flashcard(
      {required final String id,
      required final String topic,
      required final String front,
      required final String back,
      final String explanation}) = _$FlashcardImpl;

  factory _Flashcard.fromJson(Map<String, dynamic> json) =
      _$FlashcardImpl.fromJson;

  @override
  String get id;
  @override
  String get topic;

  /// The cue side — shown first, what the student tries to recall from.
  @override
  String get front;

  /// The recall target — revealed after the flip gesture.
  @override
  String get back;

  /// Optional extra context shown alongside the back after the flip.
  @override
  String get explanation;

  /// Create a copy of Flashcard
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardImplCopyWith<_$FlashcardImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FlashcardRatingSubmission _$FlashcardRatingSubmissionFromJson(
    Map<String, dynamic> json) {
  return _FlashcardRatingSubmission.fromJson(json);
}

/// @nodoc
mixin _$FlashcardRatingSubmission {
  FlashcardRating get rating => throw _privateConstructorUsedError;
  @JsonKey(name: 'selected_option')
  String? get selectedOption => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_correct')
  bool? get isCorrect => throw _privateConstructorUsedError;
  @JsonKey(name: 'response_time_ms')
  int? get responseTimeMs => throw _privateConstructorUsedError;
  @JsonKey(name: 'session_progress')
  int? get sessionProgress => throw _privateConstructorUsedError;
  @JsonKey(name: 'accuracy_percentage')
  double? get accuracyPercentage => throw _privateConstructorUsedError;

  /// Serializes this FlashcardRatingSubmission to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlashcardRatingSubmission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlashcardRatingSubmissionCopyWith<FlashcardRatingSubmission> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlashcardRatingSubmissionCopyWith<$Res> {
  factory $FlashcardRatingSubmissionCopyWith(FlashcardRatingSubmission value,
          $Res Function(FlashcardRatingSubmission) then) =
      _$FlashcardRatingSubmissionCopyWithImpl<$Res, FlashcardRatingSubmission>;
  @useResult
  $Res call(
      {FlashcardRating rating,
      @JsonKey(name: 'selected_option') String? selectedOption,
      @JsonKey(name: 'is_correct') bool? isCorrect,
      @JsonKey(name: 'response_time_ms') int? responseTimeMs,
      @JsonKey(name: 'session_progress') int? sessionProgress,
      @JsonKey(name: 'accuracy_percentage') double? accuracyPercentage});
}

/// @nodoc
class _$FlashcardRatingSubmissionCopyWithImpl<$Res,
        $Val extends FlashcardRatingSubmission>
    implements $FlashcardRatingSubmissionCopyWith<$Res> {
  _$FlashcardRatingSubmissionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlashcardRatingSubmission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rating = null,
    Object? selectedOption = freezed,
    Object? isCorrect = freezed,
    Object? responseTimeMs = freezed,
    Object? sessionProgress = freezed,
    Object? accuracyPercentage = freezed,
  }) {
    return _then(_value.copyWith(
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
      selectedOption: freezed == selectedOption
          ? _value.selectedOption
          : selectedOption // ignore: cast_nullable_to_non_nullable
              as String?,
      isCorrect: freezed == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool?,
      responseTimeMs: freezed == responseTimeMs
          ? _value.responseTimeMs
          : responseTimeMs // ignore: cast_nullable_to_non_nullable
              as int?,
      sessionProgress: freezed == sessionProgress
          ? _value.sessionProgress
          : sessionProgress // ignore: cast_nullable_to_non_nullable
              as int?,
      accuracyPercentage: freezed == accuracyPercentage
          ? _value.accuracyPercentage
          : accuracyPercentage // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlashcardRatingSubmissionImplCopyWith<$Res>
    implements $FlashcardRatingSubmissionCopyWith<$Res> {
  factory _$$FlashcardRatingSubmissionImplCopyWith(
          _$FlashcardRatingSubmissionImpl value,
          $Res Function(_$FlashcardRatingSubmissionImpl) then) =
      __$$FlashcardRatingSubmissionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {FlashcardRating rating,
      @JsonKey(name: 'selected_option') String? selectedOption,
      @JsonKey(name: 'is_correct') bool? isCorrect,
      @JsonKey(name: 'response_time_ms') int? responseTimeMs,
      @JsonKey(name: 'session_progress') int? sessionProgress,
      @JsonKey(name: 'accuracy_percentage') double? accuracyPercentage});
}

/// @nodoc
class __$$FlashcardRatingSubmissionImplCopyWithImpl<$Res>
    extends _$FlashcardRatingSubmissionCopyWithImpl<$Res,
        _$FlashcardRatingSubmissionImpl>
    implements _$$FlashcardRatingSubmissionImplCopyWith<$Res> {
  __$$FlashcardRatingSubmissionImplCopyWithImpl(
      _$FlashcardRatingSubmissionImpl _value,
      $Res Function(_$FlashcardRatingSubmissionImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardRatingSubmission
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rating = null,
    Object? selectedOption = freezed,
    Object? isCorrect = freezed,
    Object? responseTimeMs = freezed,
    Object? sessionProgress = freezed,
    Object? accuracyPercentage = freezed,
  }) {
    return _then(_$FlashcardRatingSubmissionImpl(
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
      selectedOption: freezed == selectedOption
          ? _value.selectedOption
          : selectedOption // ignore: cast_nullable_to_non_nullable
              as String?,
      isCorrect: freezed == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool?,
      responseTimeMs: freezed == responseTimeMs
          ? _value.responseTimeMs
          : responseTimeMs // ignore: cast_nullable_to_non_nullable
              as int?,
      sessionProgress: freezed == sessionProgress
          ? _value.sessionProgress
          : sessionProgress // ignore: cast_nullable_to_non_nullable
              as int?,
      accuracyPercentage: freezed == accuracyPercentage
          ? _value.accuracyPercentage
          : accuracyPercentage // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlashcardRatingSubmissionImpl implements _FlashcardRatingSubmission {
  const _$FlashcardRatingSubmissionImpl(
      {required this.rating,
      @JsonKey(name: 'selected_option') this.selectedOption,
      @JsonKey(name: 'is_correct') this.isCorrect,
      @JsonKey(name: 'response_time_ms') this.responseTimeMs,
      @JsonKey(name: 'session_progress') this.sessionProgress,
      @JsonKey(name: 'accuracy_percentage') this.accuracyPercentage});

  factory _$FlashcardRatingSubmissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlashcardRatingSubmissionImplFromJson(json);

  @override
  final FlashcardRating rating;
  @override
  @JsonKey(name: 'selected_option')
  final String? selectedOption;
  @override
  @JsonKey(name: 'is_correct')
  final bool? isCorrect;
  @override
  @JsonKey(name: 'response_time_ms')
  final int? responseTimeMs;
  @override
  @JsonKey(name: 'session_progress')
  final int? sessionProgress;
  @override
  @JsonKey(name: 'accuracy_percentage')
  final double? accuracyPercentage;

  @override
  String toString() {
    return 'FlashcardRatingSubmission(rating: $rating, selectedOption: $selectedOption, isCorrect: $isCorrect, responseTimeMs: $responseTimeMs, sessionProgress: $sessionProgress, accuracyPercentage: $accuracyPercentage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardRatingSubmissionImpl &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.selectedOption, selectedOption) ||
                other.selectedOption == selectedOption) &&
            (identical(other.isCorrect, isCorrect) ||
                other.isCorrect == isCorrect) &&
            (identical(other.responseTimeMs, responseTimeMs) ||
                other.responseTimeMs == responseTimeMs) &&
            (identical(other.sessionProgress, sessionProgress) ||
                other.sessionProgress == sessionProgress) &&
            (identical(other.accuracyPercentage, accuracyPercentage) ||
                other.accuracyPercentage == accuracyPercentage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, rating, selectedOption,
      isCorrect, responseTimeMs, sessionProgress, accuracyPercentage);

  /// Create a copy of FlashcardRatingSubmission
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardRatingSubmissionImplCopyWith<_$FlashcardRatingSubmissionImpl>
      get copyWith => __$$FlashcardRatingSubmissionImplCopyWithImpl<
          _$FlashcardRatingSubmissionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlashcardRatingSubmissionImplToJson(
      this,
    );
  }
}

abstract class _FlashcardRatingSubmission implements FlashcardRatingSubmission {
  const factory _FlashcardRatingSubmission(
      {required final FlashcardRating rating,
      @JsonKey(name: 'selected_option') final String? selectedOption,
      @JsonKey(name: 'is_correct') final bool? isCorrect,
      @JsonKey(name: 'response_time_ms') final int? responseTimeMs,
      @JsonKey(name: 'session_progress') final int? sessionProgress,
      @JsonKey(name: 'accuracy_percentage')
      final double? accuracyPercentage}) = _$FlashcardRatingSubmissionImpl;

  factory _FlashcardRatingSubmission.fromJson(Map<String, dynamic> json) =
      _$FlashcardRatingSubmissionImpl.fromJson;

  @override
  FlashcardRating get rating;
  @override
  @JsonKey(name: 'selected_option')
  String? get selectedOption;
  @override
  @JsonKey(name: 'is_correct')
  bool? get isCorrect;
  @override
  @JsonKey(name: 'response_time_ms')
  int? get responseTimeMs;
  @override
  @JsonKey(name: 'session_progress')
  int? get sessionProgress;
  @override
  @JsonKey(name: 'accuracy_percentage')
  double? get accuracyPercentage;

  /// Create a copy of FlashcardRatingSubmission
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardRatingSubmissionImplCopyWith<_$FlashcardRatingSubmissionImpl>
      get copyWith => throw _privateConstructorUsedError;
}

FlashcardRatingResponse _$FlashcardRatingResponseFromJson(
    Map<String, dynamic> json) {
  return _FlashcardRatingResponse.fromJson(json);
}

/// @nodoc
mixin _$FlashcardRatingResponse {
  @JsonKey(name: 'flashcard_id')
  String get flashcardId => throw _privateConstructorUsedError;
  FlashcardRating get rating => throw _privateConstructorUsedError;
  @JsonKey(name: 'rated_at')
  String get ratedAt =>
      throw _privateConstructorUsedError; // ── Sprint 5 gamification ──────────────────────────────────────────
  @JsonKey(name: 'xp_earned')
  int get xpEarned => throw _privateConstructorUsedError;
  @JsonKey(name: 'new_level')
  int get newLevel => throw _privateConstructorUsedError;
  @JsonKey(name: 'leveled_up')
  bool get leveledUp => throw _privateConstructorUsedError;
  @JsonKey(name: 'streak_days')
  int get streakDays => throw _privateConstructorUsedError;
  @JsonKey(name: 'streak_extended')
  bool get streakExtended => throw _privateConstructorUsedError;
  @JsonKey(name: 'badges_unlocked')
  List<FlashcardBadgeUnlock> get badgesUnlocked =>
      throw _privateConstructorUsedError;

  /// Serializes this FlashcardRatingResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlashcardRatingResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlashcardRatingResponseCopyWith<FlashcardRatingResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlashcardRatingResponseCopyWith<$Res> {
  factory $FlashcardRatingResponseCopyWith(FlashcardRatingResponse value,
          $Res Function(FlashcardRatingResponse) then) =
      _$FlashcardRatingResponseCopyWithImpl<$Res, FlashcardRatingResponse>;
  @useResult
  $Res call(
      {@JsonKey(name: 'flashcard_id') String flashcardId,
      FlashcardRating rating,
      @JsonKey(name: 'rated_at') String ratedAt,
      @JsonKey(name: 'xp_earned') int xpEarned,
      @JsonKey(name: 'new_level') int newLevel,
      @JsonKey(name: 'leveled_up') bool leveledUp,
      @JsonKey(name: 'streak_days') int streakDays,
      @JsonKey(name: 'streak_extended') bool streakExtended,
      @JsonKey(name: 'badges_unlocked')
      List<FlashcardBadgeUnlock> badgesUnlocked});
}

/// @nodoc
class _$FlashcardRatingResponseCopyWithImpl<$Res,
        $Val extends FlashcardRatingResponse>
    implements $FlashcardRatingResponseCopyWith<$Res> {
  _$FlashcardRatingResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlashcardRatingResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? flashcardId = null,
    Object? rating = null,
    Object? ratedAt = null,
    Object? xpEarned = null,
    Object? newLevel = null,
    Object? leveledUp = null,
    Object? streakDays = null,
    Object? streakExtended = null,
    Object? badgesUnlocked = null,
  }) {
    return _then(_value.copyWith(
      flashcardId: null == flashcardId
          ? _value.flashcardId
          : flashcardId // ignore: cast_nullable_to_non_nullable
              as String,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
      ratedAt: null == ratedAt
          ? _value.ratedAt
          : ratedAt // ignore: cast_nullable_to_non_nullable
              as String,
      xpEarned: null == xpEarned
          ? _value.xpEarned
          : xpEarned // ignore: cast_nullable_to_non_nullable
              as int,
      newLevel: null == newLevel
          ? _value.newLevel
          : newLevel // ignore: cast_nullable_to_non_nullable
              as int,
      leveledUp: null == leveledUp
          ? _value.leveledUp
          : leveledUp // ignore: cast_nullable_to_non_nullable
              as bool,
      streakDays: null == streakDays
          ? _value.streakDays
          : streakDays // ignore: cast_nullable_to_non_nullable
              as int,
      streakExtended: null == streakExtended
          ? _value.streakExtended
          : streakExtended // ignore: cast_nullable_to_non_nullable
              as bool,
      badgesUnlocked: null == badgesUnlocked
          ? _value.badgesUnlocked
          : badgesUnlocked // ignore: cast_nullable_to_non_nullable
              as List<FlashcardBadgeUnlock>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlashcardRatingResponseImplCopyWith<$Res>
    implements $FlashcardRatingResponseCopyWith<$Res> {
  factory _$$FlashcardRatingResponseImplCopyWith(
          _$FlashcardRatingResponseImpl value,
          $Res Function(_$FlashcardRatingResponseImpl) then) =
      __$$FlashcardRatingResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'flashcard_id') String flashcardId,
      FlashcardRating rating,
      @JsonKey(name: 'rated_at') String ratedAt,
      @JsonKey(name: 'xp_earned') int xpEarned,
      @JsonKey(name: 'new_level') int newLevel,
      @JsonKey(name: 'leveled_up') bool leveledUp,
      @JsonKey(name: 'streak_days') int streakDays,
      @JsonKey(name: 'streak_extended') bool streakExtended,
      @JsonKey(name: 'badges_unlocked')
      List<FlashcardBadgeUnlock> badgesUnlocked});
}

/// @nodoc
class __$$FlashcardRatingResponseImplCopyWithImpl<$Res>
    extends _$FlashcardRatingResponseCopyWithImpl<$Res,
        _$FlashcardRatingResponseImpl>
    implements _$$FlashcardRatingResponseImplCopyWith<$Res> {
  __$$FlashcardRatingResponseImplCopyWithImpl(
      _$FlashcardRatingResponseImpl _value,
      $Res Function(_$FlashcardRatingResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardRatingResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? flashcardId = null,
    Object? rating = null,
    Object? ratedAt = null,
    Object? xpEarned = null,
    Object? newLevel = null,
    Object? leveledUp = null,
    Object? streakDays = null,
    Object? streakExtended = null,
    Object? badgesUnlocked = null,
  }) {
    return _then(_$FlashcardRatingResponseImpl(
      flashcardId: null == flashcardId
          ? _value.flashcardId
          : flashcardId // ignore: cast_nullable_to_non_nullable
              as String,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
      ratedAt: null == ratedAt
          ? _value.ratedAt
          : ratedAt // ignore: cast_nullable_to_non_nullable
              as String,
      xpEarned: null == xpEarned
          ? _value.xpEarned
          : xpEarned // ignore: cast_nullable_to_non_nullable
              as int,
      newLevel: null == newLevel
          ? _value.newLevel
          : newLevel // ignore: cast_nullable_to_non_nullable
              as int,
      leveledUp: null == leveledUp
          ? _value.leveledUp
          : leveledUp // ignore: cast_nullable_to_non_nullable
              as bool,
      streakDays: null == streakDays
          ? _value.streakDays
          : streakDays // ignore: cast_nullable_to_non_nullable
              as int,
      streakExtended: null == streakExtended
          ? _value.streakExtended
          : streakExtended // ignore: cast_nullable_to_non_nullable
              as bool,
      badgesUnlocked: null == badgesUnlocked
          ? _value._badgesUnlocked
          : badgesUnlocked // ignore: cast_nullable_to_non_nullable
              as List<FlashcardBadgeUnlock>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlashcardRatingResponseImpl implements _FlashcardRatingResponse {
  const _$FlashcardRatingResponseImpl(
      {@JsonKey(name: 'flashcard_id') required this.flashcardId,
      required this.rating,
      @JsonKey(name: 'rated_at') required this.ratedAt,
      @JsonKey(name: 'xp_earned') this.xpEarned = 0,
      @JsonKey(name: 'new_level') this.newLevel = 1,
      @JsonKey(name: 'leveled_up') this.leveledUp = false,
      @JsonKey(name: 'streak_days') this.streakDays = 0,
      @JsonKey(name: 'streak_extended') this.streakExtended = false,
      @JsonKey(name: 'badges_unlocked')
      final List<FlashcardBadgeUnlock> badgesUnlocked =
          const <FlashcardBadgeUnlock>[]})
      : _badgesUnlocked = badgesUnlocked;

  factory _$FlashcardRatingResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlashcardRatingResponseImplFromJson(json);

  @override
  @JsonKey(name: 'flashcard_id')
  final String flashcardId;
  @override
  final FlashcardRating rating;
  @override
  @JsonKey(name: 'rated_at')
  final String ratedAt;
// ── Sprint 5 gamification ──────────────────────────────────────────
  @override
  @JsonKey(name: 'xp_earned')
  final int xpEarned;
  @override
  @JsonKey(name: 'new_level')
  final int newLevel;
  @override
  @JsonKey(name: 'leveled_up')
  final bool leveledUp;
  @override
  @JsonKey(name: 'streak_days')
  final int streakDays;
  @override
  @JsonKey(name: 'streak_extended')
  final bool streakExtended;
  final List<FlashcardBadgeUnlock> _badgesUnlocked;
  @override
  @JsonKey(name: 'badges_unlocked')
  List<FlashcardBadgeUnlock> get badgesUnlocked {
    if (_badgesUnlocked is EqualUnmodifiableListView) return _badgesUnlocked;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_badgesUnlocked);
  }

  @override
  String toString() {
    return 'FlashcardRatingResponse(flashcardId: $flashcardId, rating: $rating, ratedAt: $ratedAt, xpEarned: $xpEarned, newLevel: $newLevel, leveledUp: $leveledUp, streakDays: $streakDays, streakExtended: $streakExtended, badgesUnlocked: $badgesUnlocked)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardRatingResponseImpl &&
            (identical(other.flashcardId, flashcardId) ||
                other.flashcardId == flashcardId) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.ratedAt, ratedAt) || other.ratedAt == ratedAt) &&
            (identical(other.xpEarned, xpEarned) ||
                other.xpEarned == xpEarned) &&
            (identical(other.newLevel, newLevel) ||
                other.newLevel == newLevel) &&
            (identical(other.leveledUp, leveledUp) ||
                other.leveledUp == leveledUp) &&
            (identical(other.streakDays, streakDays) ||
                other.streakDays == streakDays) &&
            (identical(other.streakExtended, streakExtended) ||
                other.streakExtended == streakExtended) &&
            const DeepCollectionEquality()
                .equals(other._badgesUnlocked, _badgesUnlocked));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      flashcardId,
      rating,
      ratedAt,
      xpEarned,
      newLevel,
      leveledUp,
      streakDays,
      streakExtended,
      const DeepCollectionEquality().hash(_badgesUnlocked));

  /// Create a copy of FlashcardRatingResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardRatingResponseImplCopyWith<_$FlashcardRatingResponseImpl>
      get copyWith => __$$FlashcardRatingResponseImplCopyWithImpl<
          _$FlashcardRatingResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlashcardRatingResponseImplToJson(
      this,
    );
  }
}

abstract class _FlashcardRatingResponse implements FlashcardRatingResponse {
  const factory _FlashcardRatingResponse(
          {@JsonKey(name: 'flashcard_id') required final String flashcardId,
          required final FlashcardRating rating,
          @JsonKey(name: 'rated_at') required final String ratedAt,
          @JsonKey(name: 'xp_earned') final int xpEarned,
          @JsonKey(name: 'new_level') final int newLevel,
          @JsonKey(name: 'leveled_up') final bool leveledUp,
          @JsonKey(name: 'streak_days') final int streakDays,
          @JsonKey(name: 'streak_extended') final bool streakExtended,
          @JsonKey(name: 'badges_unlocked')
          final List<FlashcardBadgeUnlock> badgesUnlocked}) =
      _$FlashcardRatingResponseImpl;

  factory _FlashcardRatingResponse.fromJson(Map<String, dynamic> json) =
      _$FlashcardRatingResponseImpl.fromJson;

  @override
  @JsonKey(name: 'flashcard_id')
  String get flashcardId;
  @override
  FlashcardRating get rating;
  @override
  @JsonKey(name: 'rated_at')
  String
      get ratedAt; // ── Sprint 5 gamification ──────────────────────────────────────────
  @override
  @JsonKey(name: 'xp_earned')
  int get xpEarned;
  @override
  @JsonKey(name: 'new_level')
  int get newLevel;
  @override
  @JsonKey(name: 'leveled_up')
  bool get leveledUp;
  @override
  @JsonKey(name: 'streak_days')
  int get streakDays;
  @override
  @JsonKey(name: 'streak_extended')
  bool get streakExtended;
  @override
  @JsonKey(name: 'badges_unlocked')
  List<FlashcardBadgeUnlock> get badgesUnlocked;

  /// Create a copy of FlashcardRatingResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardRatingResponseImplCopyWith<_$FlashcardRatingResponseImpl>
      get copyWith => throw _privateConstructorUsedError;
}

FlashcardBadgeUnlock _$FlashcardBadgeUnlockFromJson(Map<String, dynamic> json) {
  return _FlashcardBadgeUnlock.fromJson(json);
}

/// @nodoc
mixin _$FlashcardBadgeUnlock {
  @JsonKey(name: 'badge_id')
  String get badgeId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;

  /// Serializes this FlashcardBadgeUnlock to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlashcardBadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlashcardBadgeUnlockCopyWith<FlashcardBadgeUnlock> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlashcardBadgeUnlockCopyWith<$Res> {
  factory $FlashcardBadgeUnlockCopyWith(FlashcardBadgeUnlock value,
          $Res Function(FlashcardBadgeUnlock) then) =
      _$FlashcardBadgeUnlockCopyWithImpl<$Res, FlashcardBadgeUnlock>;
  @useResult
  $Res call(
      {@JsonKey(name: 'badge_id') String badgeId,
      String name,
      String description,
      String icon});
}

/// @nodoc
class _$FlashcardBadgeUnlockCopyWithImpl<$Res,
        $Val extends FlashcardBadgeUnlock>
    implements $FlashcardBadgeUnlockCopyWith<$Res> {
  _$FlashcardBadgeUnlockCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlashcardBadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? badgeId = null,
    Object? name = null,
    Object? description = null,
    Object? icon = null,
  }) {
    return _then(_value.copyWith(
      badgeId: null == badgeId
          ? _value.badgeId
          : badgeId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlashcardBadgeUnlockImplCopyWith<$Res>
    implements $FlashcardBadgeUnlockCopyWith<$Res> {
  factory _$$FlashcardBadgeUnlockImplCopyWith(_$FlashcardBadgeUnlockImpl value,
          $Res Function(_$FlashcardBadgeUnlockImpl) then) =
      __$$FlashcardBadgeUnlockImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'badge_id') String badgeId,
      String name,
      String description,
      String icon});
}

/// @nodoc
class __$$FlashcardBadgeUnlockImplCopyWithImpl<$Res>
    extends _$FlashcardBadgeUnlockCopyWithImpl<$Res, _$FlashcardBadgeUnlockImpl>
    implements _$$FlashcardBadgeUnlockImplCopyWith<$Res> {
  __$$FlashcardBadgeUnlockImplCopyWithImpl(_$FlashcardBadgeUnlockImpl _value,
      $Res Function(_$FlashcardBadgeUnlockImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardBadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? badgeId = null,
    Object? name = null,
    Object? description = null,
    Object? icon = null,
  }) {
    return _then(_$FlashcardBadgeUnlockImpl(
      badgeId: null == badgeId
          ? _value.badgeId
          : badgeId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlashcardBadgeUnlockImpl implements _FlashcardBadgeUnlock {
  const _$FlashcardBadgeUnlockImpl(
      {@JsonKey(name: 'badge_id') required this.badgeId,
      required this.name,
      required this.description,
      required this.icon});

  factory _$FlashcardBadgeUnlockImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlashcardBadgeUnlockImplFromJson(json);

  @override
  @JsonKey(name: 'badge_id')
  final String badgeId;
  @override
  final String name;
  @override
  final String description;
  @override
  final String icon;

  @override
  String toString() {
    return 'FlashcardBadgeUnlock(badgeId: $badgeId, name: $name, description: $description, icon: $icon)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardBadgeUnlockImpl &&
            (identical(other.badgeId, badgeId) || other.badgeId == badgeId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.icon, icon) || other.icon == icon));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, badgeId, name, description, icon);

  /// Create a copy of FlashcardBadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardBadgeUnlockImplCopyWith<_$FlashcardBadgeUnlockImpl>
      get copyWith =>
          __$$FlashcardBadgeUnlockImplCopyWithImpl<_$FlashcardBadgeUnlockImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlashcardBadgeUnlockImplToJson(
      this,
    );
  }
}

abstract class _FlashcardBadgeUnlock implements FlashcardBadgeUnlock {
  const factory _FlashcardBadgeUnlock(
      {@JsonKey(name: 'badge_id') required final String badgeId,
      required final String name,
      required final String description,
      required final String icon}) = _$FlashcardBadgeUnlockImpl;

  factory _FlashcardBadgeUnlock.fromJson(Map<String, dynamic> json) =
      _$FlashcardBadgeUnlockImpl.fromJson;

  @override
  @JsonKey(name: 'badge_id')
  String get badgeId;
  @override
  String get name;
  @override
  String get description;
  @override
  String get icon;

  /// Create a copy of FlashcardBadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardBadgeUnlockImplCopyWith<_$FlashcardBadgeUnlockImpl>
      get copyWith => throw _privateConstructorUsedError;
}
