// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flashcard_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$FlashcardSession {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlashcardSessionCopyWith<$Res> {
  factory $FlashcardSessionCopyWith(
          FlashcardSession value, $Res Function(FlashcardSession) then) =
      _$FlashcardSessionCopyWithImpl<$Res, FlashcardSession>;
}

/// @nodoc
class _$FlashcardSessionCopyWithImpl<$Res, $Val extends FlashcardSession>
    implements $FlashcardSessionCopyWith<$Res> {
  _$FlashcardSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$FlashcardSessionIdleImplCopyWith<$Res> {
  factory _$$FlashcardSessionIdleImplCopyWith(_$FlashcardSessionIdleImpl value,
          $Res Function(_$FlashcardSessionIdleImpl) then) =
      __$$FlashcardSessionIdleImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$FlashcardSessionIdleImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res, _$FlashcardSessionIdleImpl>
    implements _$$FlashcardSessionIdleImplCopyWith<$Res> {
  __$$FlashcardSessionIdleImplCopyWithImpl(_$FlashcardSessionIdleImpl _value,
      $Res Function(_$FlashcardSessionIdleImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$FlashcardSessionIdleImpl implements FlashcardSessionIdle {
  const _$FlashcardSessionIdleImpl();

  @override
  String toString() {
    return 'FlashcardSession.idle()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionIdleImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return idle();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return idle?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return idle(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return idle?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionIdle implements FlashcardSession {
  const factory FlashcardSessionIdle() = _$FlashcardSessionIdleImpl;
}

/// @nodoc
abstract class _$$FlashcardSessionLoadingImplCopyWith<$Res> {
  factory _$$FlashcardSessionLoadingImplCopyWith(
          _$FlashcardSessionLoadingImpl value,
          $Res Function(_$FlashcardSessionLoadingImpl) then) =
      __$$FlashcardSessionLoadingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$FlashcardSessionLoadingImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res, _$FlashcardSessionLoadingImpl>
    implements _$$FlashcardSessionLoadingImplCopyWith<$Res> {
  __$$FlashcardSessionLoadingImplCopyWithImpl(
      _$FlashcardSessionLoadingImpl _value,
      $Res Function(_$FlashcardSessionLoadingImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$FlashcardSessionLoadingImpl implements FlashcardSessionLoading {
  const _$FlashcardSessionLoadingImpl();

  @override
  String toString() {
    return 'FlashcardSession.loading()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionLoadingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionLoading implements FlashcardSession {
  const factory FlashcardSessionLoading() = _$FlashcardSessionLoadingImpl;
}

/// @nodoc
abstract class _$$FlashcardSessionViewingFrontImplCopyWith<$Res> {
  factory _$$FlashcardSessionViewingFrontImplCopyWith(
          _$FlashcardSessionViewingFrontImpl value,
          $Res Function(_$FlashcardSessionViewingFrontImpl) then) =
      __$$FlashcardSessionViewingFrontImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Flashcard card});

  $FlashcardCopyWith<$Res> get card;
}

/// @nodoc
class __$$FlashcardSessionViewingFrontImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res,
        _$FlashcardSessionViewingFrontImpl>
    implements _$$FlashcardSessionViewingFrontImplCopyWith<$Res> {
  __$$FlashcardSessionViewingFrontImplCopyWithImpl(
      _$FlashcardSessionViewingFrontImpl _value,
      $Res Function(_$FlashcardSessionViewingFrontImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? card = null,
  }) {
    return _then(_$FlashcardSessionViewingFrontImpl(
      card: null == card
          ? _value.card
          : card // ignore: cast_nullable_to_non_nullable
              as Flashcard,
    ));
  }

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardCopyWith<$Res> get card {
    return $FlashcardCopyWith<$Res>(_value.card, (value) {
      return _then(_value.copyWith(card: value));
    });
  }
}

/// @nodoc

class _$FlashcardSessionViewingFrontImpl
    implements FlashcardSessionViewingFront {
  const _$FlashcardSessionViewingFrontImpl({required this.card});

  @override
  final Flashcard card;

  @override
  String toString() {
    return 'FlashcardSession.viewingFront(card: $card)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionViewingFrontImpl &&
            (identical(other.card, card) || other.card == card));
  }

  @override
  int get hashCode => Object.hash(runtimeType, card);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardSessionViewingFrontImplCopyWith<
          _$FlashcardSessionViewingFrontImpl>
      get copyWith => __$$FlashcardSessionViewingFrontImplCopyWithImpl<
          _$FlashcardSessionViewingFrontImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return viewingFront(card);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return viewingFront?.call(card);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (viewingFront != null) {
      return viewingFront(card);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return viewingFront(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return viewingFront?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (viewingFront != null) {
      return viewingFront(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionViewingFront implements FlashcardSession {
  const factory FlashcardSessionViewingFront({required final Flashcard card}) =
      _$FlashcardSessionViewingFrontImpl;

  Flashcard get card;

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardSessionViewingFrontImplCopyWith<
          _$FlashcardSessionViewingFrontImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FlashcardSessionRevealedImplCopyWith<$Res> {
  factory _$$FlashcardSessionRevealedImplCopyWith(
          _$FlashcardSessionRevealedImpl value,
          $Res Function(_$FlashcardSessionRevealedImpl) then) =
      __$$FlashcardSessionRevealedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Flashcard card});

  $FlashcardCopyWith<$Res> get card;
}

/// @nodoc
class __$$FlashcardSessionRevealedImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res, _$FlashcardSessionRevealedImpl>
    implements _$$FlashcardSessionRevealedImplCopyWith<$Res> {
  __$$FlashcardSessionRevealedImplCopyWithImpl(
      _$FlashcardSessionRevealedImpl _value,
      $Res Function(_$FlashcardSessionRevealedImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? card = null,
  }) {
    return _then(_$FlashcardSessionRevealedImpl(
      card: null == card
          ? _value.card
          : card // ignore: cast_nullable_to_non_nullable
              as Flashcard,
    ));
  }

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardCopyWith<$Res> get card {
    return $FlashcardCopyWith<$Res>(_value.card, (value) {
      return _then(_value.copyWith(card: value));
    });
  }
}

/// @nodoc

class _$FlashcardSessionRevealedImpl implements FlashcardSessionRevealed {
  const _$FlashcardSessionRevealedImpl({required this.card});

  @override
  final Flashcard card;

  @override
  String toString() {
    return 'FlashcardSession.revealed(card: $card)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionRevealedImpl &&
            (identical(other.card, card) || other.card == card));
  }

  @override
  int get hashCode => Object.hash(runtimeType, card);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardSessionRevealedImplCopyWith<_$FlashcardSessionRevealedImpl>
      get copyWith => __$$FlashcardSessionRevealedImplCopyWithImpl<
          _$FlashcardSessionRevealedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return revealed(card);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return revealed?.call(card);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (revealed != null) {
      return revealed(card);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return revealed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return revealed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (revealed != null) {
      return revealed(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionRevealed implements FlashcardSession {
  const factory FlashcardSessionRevealed({required final Flashcard card}) =
      _$FlashcardSessionRevealedImpl;

  Flashcard get card;

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardSessionRevealedImplCopyWith<_$FlashcardSessionRevealedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FlashcardSessionRatingImplCopyWith<$Res> {
  factory _$$FlashcardSessionRatingImplCopyWith(
          _$FlashcardSessionRatingImpl value,
          $Res Function(_$FlashcardSessionRatingImpl) then) =
      __$$FlashcardSessionRatingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Flashcard card, FlashcardRating rating});

  $FlashcardCopyWith<$Res> get card;
}

/// @nodoc
class __$$FlashcardSessionRatingImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res, _$FlashcardSessionRatingImpl>
    implements _$$FlashcardSessionRatingImplCopyWith<$Res> {
  __$$FlashcardSessionRatingImplCopyWithImpl(
      _$FlashcardSessionRatingImpl _value,
      $Res Function(_$FlashcardSessionRatingImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? card = null,
    Object? rating = null,
  }) {
    return _then(_$FlashcardSessionRatingImpl(
      card: null == card
          ? _value.card
          : card // ignore: cast_nullable_to_non_nullable
              as Flashcard,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
    ));
  }

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardCopyWith<$Res> get card {
    return $FlashcardCopyWith<$Res>(_value.card, (value) {
      return _then(_value.copyWith(card: value));
    });
  }
}

/// @nodoc

class _$FlashcardSessionRatingImpl implements FlashcardSessionRating {
  const _$FlashcardSessionRatingImpl(
      {required this.card, required this.rating});

  @override
  final Flashcard card;
  @override
  final FlashcardRating rating;

  @override
  String toString() {
    return 'FlashcardSession.rating(card: $card, rating: $rating)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionRatingImpl &&
            (identical(other.card, card) || other.card == card) &&
            (identical(other.rating, rating) || other.rating == rating));
  }

  @override
  int get hashCode => Object.hash(runtimeType, card, rating);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardSessionRatingImplCopyWith<_$FlashcardSessionRatingImpl>
      get copyWith => __$$FlashcardSessionRatingImplCopyWithImpl<
          _$FlashcardSessionRatingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return rating(card, this.rating);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return rating?.call(card, this.rating);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (rating != null) {
      return rating(card, this.rating);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return rating(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return rating?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (rating != null) {
      return rating(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionRating implements FlashcardSession {
  const factory FlashcardSessionRating(
      {required final Flashcard card,
      required final FlashcardRating rating}) = _$FlashcardSessionRatingImpl;

  Flashcard get card;
  FlashcardRating get rating;

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardSessionRatingImplCopyWith<_$FlashcardSessionRatingImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FlashcardSessionRatedImplCopyWith<$Res> {
  factory _$$FlashcardSessionRatedImplCopyWith(
          _$FlashcardSessionRatedImpl value,
          $Res Function(_$FlashcardSessionRatedImpl) then) =
      __$$FlashcardSessionRatedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Flashcard card, FlashcardRatingResponse response});

  $FlashcardCopyWith<$Res> get card;
  $FlashcardRatingResponseCopyWith<$Res> get response;
}

/// @nodoc
class __$$FlashcardSessionRatedImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res, _$FlashcardSessionRatedImpl>
    implements _$$FlashcardSessionRatedImplCopyWith<$Res> {
  __$$FlashcardSessionRatedImplCopyWithImpl(_$FlashcardSessionRatedImpl _value,
      $Res Function(_$FlashcardSessionRatedImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? card = null,
    Object? response = null,
  }) {
    return _then(_$FlashcardSessionRatedImpl(
      card: null == card
          ? _value.card
          : card // ignore: cast_nullable_to_non_nullable
              as Flashcard,
      response: null == response
          ? _value.response
          : response // ignore: cast_nullable_to_non_nullable
              as FlashcardRatingResponse,
    ));
  }

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardCopyWith<$Res> get card {
    return $FlashcardCopyWith<$Res>(_value.card, (value) {
      return _then(_value.copyWith(card: value));
    });
  }

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardRatingResponseCopyWith<$Res> get response {
    return $FlashcardRatingResponseCopyWith<$Res>(_value.response, (value) {
      return _then(_value.copyWith(response: value));
    });
  }
}

/// @nodoc

class _$FlashcardSessionRatedImpl implements FlashcardSessionRated {
  const _$FlashcardSessionRatedImpl(
      {required this.card, required this.response});

  @override
  final Flashcard card;
  @override
  final FlashcardRatingResponse response;

  @override
  String toString() {
    return 'FlashcardSession.rated(card: $card, response: $response)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionRatedImpl &&
            (identical(other.card, card) || other.card == card) &&
            (identical(other.response, response) ||
                other.response == response));
  }

  @override
  int get hashCode => Object.hash(runtimeType, card, response);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardSessionRatedImplCopyWith<_$FlashcardSessionRatedImpl>
      get copyWith => __$$FlashcardSessionRatedImplCopyWithImpl<
          _$FlashcardSessionRatedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return rated(card, response);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return rated?.call(card, response);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (rated != null) {
      return rated(card, response);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return rated(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return rated?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (rated != null) {
      return rated(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionRated implements FlashcardSession {
  const factory FlashcardSessionRated(
          {required final Flashcard card,
          required final FlashcardRatingResponse response}) =
      _$FlashcardSessionRatedImpl;

  Flashcard get card;
  FlashcardRatingResponse get response;

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardSessionRatedImplCopyWith<_$FlashcardSessionRatedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FlashcardSessionUnavailableImplCopyWith<$Res> {
  factory _$$FlashcardSessionUnavailableImplCopyWith(
          _$FlashcardSessionUnavailableImpl value,
          $Res Function(_$FlashcardSessionUnavailableImpl) then) =
      __$$FlashcardSessionUnavailableImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message, bool isNoTopics, int? retryAfterSeconds});
}

/// @nodoc
class __$$FlashcardSessionUnavailableImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res,
        _$FlashcardSessionUnavailableImpl>
    implements _$$FlashcardSessionUnavailableImplCopyWith<$Res> {
  __$$FlashcardSessionUnavailableImplCopyWithImpl(
      _$FlashcardSessionUnavailableImpl _value,
      $Res Function(_$FlashcardSessionUnavailableImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? isNoTopics = null,
    Object? retryAfterSeconds = freezed,
  }) {
    return _then(_$FlashcardSessionUnavailableImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      isNoTopics: null == isNoTopics
          ? _value.isNoTopics
          : isNoTopics // ignore: cast_nullable_to_non_nullable
              as bool,
      retryAfterSeconds: freezed == retryAfterSeconds
          ? _value.retryAfterSeconds
          : retryAfterSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$FlashcardSessionUnavailableImpl implements FlashcardSessionUnavailable {
  const _$FlashcardSessionUnavailableImpl(
      {required this.message,
      required this.isNoTopics,
      this.retryAfterSeconds});

  @override
  final String message;
  @override
  final bool isNoTopics;
  @override
  final int? retryAfterSeconds;

  @override
  String toString() {
    return 'FlashcardSession.unavailable(message: $message, isNoTopics: $isNoTopics, retryAfterSeconds: $retryAfterSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionUnavailableImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.isNoTopics, isNoTopics) ||
                other.isNoTopics == isNoTopics) &&
            (identical(other.retryAfterSeconds, retryAfterSeconds) ||
                other.retryAfterSeconds == retryAfterSeconds));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, isNoTopics, retryAfterSeconds);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardSessionUnavailableImplCopyWith<_$FlashcardSessionUnavailableImpl>
      get copyWith => __$$FlashcardSessionUnavailableImplCopyWithImpl<
          _$FlashcardSessionUnavailableImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return unavailable(message, isNoTopics, retryAfterSeconds);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return unavailable?.call(message, isNoTopics, retryAfterSeconds);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (unavailable != null) {
      return unavailable(message, isNoTopics, retryAfterSeconds);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return unavailable(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return unavailable?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (unavailable != null) {
      return unavailable(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionUnavailable implements FlashcardSession {
  const factory FlashcardSessionUnavailable(
      {required final String message,
      required final bool isNoTopics,
      final int? retryAfterSeconds}) = _$FlashcardSessionUnavailableImpl;

  String get message;
  bool get isNoTopics;
  int? get retryAfterSeconds;

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardSessionUnavailableImplCopyWith<_$FlashcardSessionUnavailableImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FlashcardSessionErrorImplCopyWith<$Res> {
  factory _$$FlashcardSessionErrorImplCopyWith(
          _$FlashcardSessionErrorImpl value,
          $Res Function(_$FlashcardSessionErrorImpl) then) =
      __$$FlashcardSessionErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$FlashcardSessionErrorImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res, _$FlashcardSessionErrorImpl>
    implements _$$FlashcardSessionErrorImplCopyWith<$Res> {
  __$$FlashcardSessionErrorImplCopyWithImpl(_$FlashcardSessionErrorImpl _value,
      $Res Function(_$FlashcardSessionErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$FlashcardSessionErrorImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$FlashcardSessionErrorImpl implements FlashcardSessionError {
  const _$FlashcardSessionErrorImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'FlashcardSession.error(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardSessionErrorImplCopyWith<_$FlashcardSessionErrorImpl>
      get copyWith => __$$FlashcardSessionErrorImplCopyWithImpl<
          _$FlashcardSessionErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionError implements FlashcardSession {
  const factory FlashcardSessionError({required final String message}) =
      _$FlashcardSessionErrorImpl;

  String get message;

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardSessionErrorImplCopyWith<_$FlashcardSessionErrorImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FlashcardSessionCompletedImplCopyWith<$Res> {
  factory _$$FlashcardSessionCompletedImplCopyWith(
          _$FlashcardSessionCompletedImpl value,
          $Res Function(_$FlashcardSessionCompletedImpl) then) =
      __$$FlashcardSessionCompletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int easyCount, int mediumCount, int hardCount});
}

/// @nodoc
class __$$FlashcardSessionCompletedImplCopyWithImpl<$Res>
    extends _$FlashcardSessionCopyWithImpl<$Res,
        _$FlashcardSessionCompletedImpl>
    implements _$$FlashcardSessionCompletedImplCopyWith<$Res> {
  __$$FlashcardSessionCompletedImplCopyWithImpl(
      _$FlashcardSessionCompletedImpl _value,
      $Res Function(_$FlashcardSessionCompletedImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? easyCount = null,
    Object? mediumCount = null,
    Object? hardCount = null,
  }) {
    return _then(_$FlashcardSessionCompletedImpl(
      easyCount: null == easyCount
          ? _value.easyCount
          : easyCount // ignore: cast_nullable_to_non_nullable
              as int,
      mediumCount: null == mediumCount
          ? _value.mediumCount
          : mediumCount // ignore: cast_nullable_to_non_nullable
              as int,
      hardCount: null == hardCount
          ? _value.hardCount
          : hardCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$FlashcardSessionCompletedImpl implements FlashcardSessionCompleted {
  const _$FlashcardSessionCompletedImpl(
      {required this.easyCount,
      required this.mediumCount,
      required this.hardCount});

  @override
  final int easyCount;
  @override
  final int mediumCount;
  @override
  final int hardCount;

  @override
  String toString() {
    return 'FlashcardSession.completed(easyCount: $easyCount, mediumCount: $mediumCount, hardCount: $hardCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlashcardSessionCompletedImpl &&
            (identical(other.easyCount, easyCount) ||
                other.easyCount == easyCount) &&
            (identical(other.mediumCount, mediumCount) ||
                other.mediumCount == mediumCount) &&
            (identical(other.hardCount, hardCount) ||
                other.hardCount == hardCount));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, easyCount, mediumCount, hardCount);

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlashcardSessionCompletedImplCopyWith<_$FlashcardSessionCompletedImpl>
      get copyWith => __$$FlashcardSessionCompletedImplCopyWithImpl<
          _$FlashcardSessionCompletedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Flashcard card) viewingFront,
    required TResult Function(Flashcard card) revealed,
    required TResult Function(Flashcard card, FlashcardRating rating) rating,
    required TResult Function(Flashcard card, FlashcardRatingResponse response)
        rated,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int easyCount, int mediumCount, int hardCount)
        completed,
  }) {
    return completed(easyCount, mediumCount, hardCount);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Flashcard card)? viewingFront,
    TResult? Function(Flashcard card)? revealed,
    TResult? Function(Flashcard card, FlashcardRating rating)? rating,
    TResult? Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int easyCount, int mediumCount, int hardCount)? completed,
  }) {
    return completed?.call(easyCount, mediumCount, hardCount);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Flashcard card)? viewingFront,
    TResult Function(Flashcard card)? revealed,
    TResult Function(Flashcard card, FlashcardRating rating)? rating,
    TResult Function(Flashcard card, FlashcardRatingResponse response)? rated,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int easyCount, int mediumCount, int hardCount)? completed,
    required TResult orElse(),
  }) {
    if (completed != null) {
      return completed(easyCount, mediumCount, hardCount);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FlashcardSessionIdle value) idle,
    required TResult Function(FlashcardSessionLoading value) loading,
    required TResult Function(FlashcardSessionViewingFront value) viewingFront,
    required TResult Function(FlashcardSessionRevealed value) revealed,
    required TResult Function(FlashcardSessionRating value) rating,
    required TResult Function(FlashcardSessionRated value) rated,
    required TResult Function(FlashcardSessionUnavailable value) unavailable,
    required TResult Function(FlashcardSessionError value) error,
    required TResult Function(FlashcardSessionCompleted value) completed,
  }) {
    return completed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FlashcardSessionIdle value)? idle,
    TResult? Function(FlashcardSessionLoading value)? loading,
    TResult? Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult? Function(FlashcardSessionRevealed value)? revealed,
    TResult? Function(FlashcardSessionRating value)? rating,
    TResult? Function(FlashcardSessionRated value)? rated,
    TResult? Function(FlashcardSessionUnavailable value)? unavailable,
    TResult? Function(FlashcardSessionError value)? error,
    TResult? Function(FlashcardSessionCompleted value)? completed,
  }) {
    return completed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FlashcardSessionIdle value)? idle,
    TResult Function(FlashcardSessionLoading value)? loading,
    TResult Function(FlashcardSessionViewingFront value)? viewingFront,
    TResult Function(FlashcardSessionRevealed value)? revealed,
    TResult Function(FlashcardSessionRating value)? rating,
    TResult Function(FlashcardSessionRated value)? rated,
    TResult Function(FlashcardSessionUnavailable value)? unavailable,
    TResult Function(FlashcardSessionError value)? error,
    TResult Function(FlashcardSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (completed != null) {
      return completed(this);
    }
    return orElse();
  }
}

abstract class FlashcardSessionCompleted implements FlashcardSession {
  const factory FlashcardSessionCompleted(
      {required final int easyCount,
      required final int mediumCount,
      required final int hardCount}) = _$FlashcardSessionCompletedImpl;

  int get easyCount;
  int get mediumCount;
  int get hardCount;

  /// Create a copy of FlashcardSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlashcardSessionCompletedImplCopyWith<_$FlashcardSessionCompletedImpl>
      get copyWith => throw _privateConstructorUsedError;
}
