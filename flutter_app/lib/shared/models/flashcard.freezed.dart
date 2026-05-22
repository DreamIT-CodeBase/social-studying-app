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
  $Res call({FlashcardRating rating});
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
  }) {
    return _then(_value.copyWith(
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
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
  $Res call({FlashcardRating rating});
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
  }) {
    return _then(_$FlashcardRatingSubmissionImpl(
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlashcardRatingSubmissionImpl implements _FlashcardRatingSubmission {
  const _$FlashcardRatingSubmissionImpl({required this.rating});

  factory _$FlashcardRatingSubmissionImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlashcardRatingSubmissionImplFromJson(json);

  @override
  final FlashcardRating rating;

  @override
  String toString() {
    return 'FlashcardRatingSubmission(rating: $rating)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardRatingSubmissionImpl &&
            (identical(other.rating, rating) || other.rating == rating));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, rating);

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
          {required final FlashcardRating rating}) =
      _$FlashcardRatingSubmissionImpl;

  factory _FlashcardRatingSubmission.fromJson(Map<String, dynamic> json) =
      _$FlashcardRatingSubmissionImpl.fromJson;

  @override
  FlashcardRating get rating;

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
  String get ratedAt => throw _privateConstructorUsedError;

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
      @JsonKey(name: 'rated_at') String ratedAt});
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
      @JsonKey(name: 'rated_at') String ratedAt});
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlashcardRatingResponseImpl implements _FlashcardRatingResponse {
  const _$FlashcardRatingResponseImpl(
      {@JsonKey(name: 'flashcard_id') required this.flashcardId,
      required this.rating,
      @JsonKey(name: 'rated_at') required this.ratedAt});

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

  @override
  String toString() {
    return 'FlashcardRatingResponse(flashcardId: $flashcardId, rating: $rating, ratedAt: $ratedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardRatingResponseImpl &&
            (identical(other.flashcardId, flashcardId) ||
                other.flashcardId == flashcardId) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.ratedAt, ratedAt) || other.ratedAt == ratedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, flashcardId, rating, ratedAt);

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
          @JsonKey(name: 'rated_at') required final String ratedAt}) =
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
  String get ratedAt;

  /// Create a copy of FlashcardRatingResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardRatingResponseImplCopyWith<_$FlashcardRatingResponseImpl>
      get copyWith => throw _privateConstructorUsedError;
}
