// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'question_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$QuestionSession {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionSessionCopyWith<$Res> {
  factory $QuestionSessionCopyWith(
          QuestionSession value, $Res Function(QuestionSession) then) =
      _$QuestionSessionCopyWithImpl<$Res, QuestionSession>;
}

/// @nodoc
class _$QuestionSessionCopyWithImpl<$Res, $Val extends QuestionSession>
    implements $QuestionSessionCopyWith<$Res> {
  _$QuestionSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$QuestionSessionIdleImplCopyWith<$Res> {
  factory _$$QuestionSessionIdleImplCopyWith(_$QuestionSessionIdleImpl value,
          $Res Function(_$QuestionSessionIdleImpl) then) =
      __$$QuestionSessionIdleImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$QuestionSessionIdleImplCopyWithImpl<$Res>
    extends _$QuestionSessionCopyWithImpl<$Res, _$QuestionSessionIdleImpl>
    implements _$$QuestionSessionIdleImplCopyWith<$Res> {
  __$$QuestionSessionIdleImplCopyWithImpl(_$QuestionSessionIdleImpl _value,
      $Res Function(_$QuestionSessionIdleImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$QuestionSessionIdleImpl implements QuestionSessionIdle {
  const _$QuestionSessionIdleImpl();

  @override
  String toString() {
    return 'QuestionSession.idle()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionSessionIdleImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) {
    return idle();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) {
    return idle?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
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
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) {
    return idle(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) {
    return idle?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle(this);
    }
    return orElse();
  }
}

abstract class QuestionSessionIdle implements QuestionSession {
  const factory QuestionSessionIdle() = _$QuestionSessionIdleImpl;
}

/// @nodoc
abstract class _$$QuestionSessionLoadingImplCopyWith<$Res> {
  factory _$$QuestionSessionLoadingImplCopyWith(
          _$QuestionSessionLoadingImpl value,
          $Res Function(_$QuestionSessionLoadingImpl) then) =
      __$$QuestionSessionLoadingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$QuestionSessionLoadingImplCopyWithImpl<$Res>
    extends _$QuestionSessionCopyWithImpl<$Res, _$QuestionSessionLoadingImpl>
    implements _$$QuestionSessionLoadingImplCopyWith<$Res> {
  __$$QuestionSessionLoadingImplCopyWithImpl(
      _$QuestionSessionLoadingImpl _value,
      $Res Function(_$QuestionSessionLoadingImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$QuestionSessionLoadingImpl implements QuestionSessionLoading {
  const _$QuestionSessionLoadingImpl();

  @override
  String toString() {
    return 'QuestionSession.loading()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionSessionLoadingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) {
    return loading();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) {
    return loading?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
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
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class QuestionSessionLoading implements QuestionSession {
  const factory QuestionSessionLoading() = _$QuestionSessionLoadingImpl;
}

/// @nodoc
abstract class _$$QuestionSessionReadyImplCopyWith<$Res> {
  factory _$$QuestionSessionReadyImplCopyWith(_$QuestionSessionReadyImpl value,
          $Res Function(_$QuestionSessionReadyImpl) then) =
      __$$QuestionSessionReadyImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Question question, String? draftAnswer});

  $QuestionCopyWith<$Res> get question;
}

/// @nodoc
class __$$QuestionSessionReadyImplCopyWithImpl<$Res>
    extends _$QuestionSessionCopyWithImpl<$Res, _$QuestionSessionReadyImpl>
    implements _$$QuestionSessionReadyImplCopyWith<$Res> {
  __$$QuestionSessionReadyImplCopyWithImpl(_$QuestionSessionReadyImpl _value,
      $Res Function(_$QuestionSessionReadyImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? draftAnswer = freezed,
  }) {
    return _then(_$QuestionSessionReadyImpl(
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as Question,
      draftAnswer: freezed == draftAnswer
          ? _value.draftAnswer
          : draftAnswer // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuestionCopyWith<$Res> get question {
    return $QuestionCopyWith<$Res>(_value.question, (value) {
      return _then(_value.copyWith(question: value));
    });
  }
}

/// @nodoc

class _$QuestionSessionReadyImpl implements QuestionSessionReady {
  const _$QuestionSessionReadyImpl({required this.question, this.draftAnswer});

  @override
  final Question question;
  @override
  final String? draftAnswer;

  @override
  String toString() {
    return 'QuestionSession.ready(question: $question, draftAnswer: $draftAnswer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionSessionReadyImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.draftAnswer, draftAnswer) ||
                other.draftAnswer == draftAnswer));
  }

  @override
  int get hashCode => Object.hash(runtimeType, question, draftAnswer);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionSessionReadyImplCopyWith<_$QuestionSessionReadyImpl>
      get copyWith =>
          __$$QuestionSessionReadyImplCopyWithImpl<_$QuestionSessionReadyImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) {
    return ready(question, draftAnswer);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) {
    return ready?.call(question, draftAnswer);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
    required TResult orElse(),
  }) {
    if (ready != null) {
      return ready(question, draftAnswer);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) {
    return ready(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) {
    return ready?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (ready != null) {
      return ready(this);
    }
    return orElse();
  }
}

abstract class QuestionSessionReady implements QuestionSession {
  const factory QuestionSessionReady(
      {required final Question question,
      final String? draftAnswer}) = _$QuestionSessionReadyImpl;

  Question get question;
  String? get draftAnswer;

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionSessionReadyImplCopyWith<_$QuestionSessionReadyImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$QuestionSessionSubmittingImplCopyWith<$Res> {
  factory _$$QuestionSessionSubmittingImplCopyWith(
          _$QuestionSessionSubmittingImpl value,
          $Res Function(_$QuestionSessionSubmittingImpl) then) =
      __$$QuestionSessionSubmittingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Question question, String draftAnswer});

  $QuestionCopyWith<$Res> get question;
}

/// @nodoc
class __$$QuestionSessionSubmittingImplCopyWithImpl<$Res>
    extends _$QuestionSessionCopyWithImpl<$Res, _$QuestionSessionSubmittingImpl>
    implements _$$QuestionSessionSubmittingImplCopyWith<$Res> {
  __$$QuestionSessionSubmittingImplCopyWithImpl(
      _$QuestionSessionSubmittingImpl _value,
      $Res Function(_$QuestionSessionSubmittingImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? draftAnswer = null,
  }) {
    return _then(_$QuestionSessionSubmittingImpl(
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as Question,
      draftAnswer: null == draftAnswer
          ? _value.draftAnswer
          : draftAnswer // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuestionCopyWith<$Res> get question {
    return $QuestionCopyWith<$Res>(_value.question, (value) {
      return _then(_value.copyWith(question: value));
    });
  }
}

/// @nodoc

class _$QuestionSessionSubmittingImpl implements QuestionSessionSubmitting {
  const _$QuestionSessionSubmittingImpl(
      {required this.question, required this.draftAnswer});

  @override
  final Question question;
  @override
  final String draftAnswer;

  @override
  String toString() {
    return 'QuestionSession.submitting(question: $question, draftAnswer: $draftAnswer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionSessionSubmittingImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.draftAnswer, draftAnswer) ||
                other.draftAnswer == draftAnswer));
  }

  @override
  int get hashCode => Object.hash(runtimeType, question, draftAnswer);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionSessionSubmittingImplCopyWith<_$QuestionSessionSubmittingImpl>
      get copyWith => __$$QuestionSessionSubmittingImplCopyWithImpl<
          _$QuestionSessionSubmittingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) {
    return submitting(question, draftAnswer);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) {
    return submitting?.call(question, draftAnswer);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
    required TResult orElse(),
  }) {
    if (submitting != null) {
      return submitting(question, draftAnswer);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) {
    return submitting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) {
    return submitting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (submitting != null) {
      return submitting(this);
    }
    return orElse();
  }
}

abstract class QuestionSessionSubmitting implements QuestionSession {
  const factory QuestionSessionSubmitting(
      {required final Question question,
      required final String draftAnswer}) = _$QuestionSessionSubmittingImpl;

  Question get question;
  String get draftAnswer;

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionSessionSubmittingImplCopyWith<_$QuestionSessionSubmittingImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$QuestionSessionFeedbackImplCopyWith<$Res> {
  factory _$$QuestionSessionFeedbackImplCopyWith(
          _$QuestionSessionFeedbackImpl value,
          $Res Function(_$QuestionSessionFeedbackImpl) then) =
      __$$QuestionSessionFeedbackImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {Question question, String submittedAnswer, AnswerFeedback feedback});

  $QuestionCopyWith<$Res> get question;
  $AnswerFeedbackCopyWith<$Res> get feedback;
}

/// @nodoc
class __$$QuestionSessionFeedbackImplCopyWithImpl<$Res>
    extends _$QuestionSessionCopyWithImpl<$Res, _$QuestionSessionFeedbackImpl>
    implements _$$QuestionSessionFeedbackImplCopyWith<$Res> {
  __$$QuestionSessionFeedbackImplCopyWithImpl(
      _$QuestionSessionFeedbackImpl _value,
      $Res Function(_$QuestionSessionFeedbackImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? submittedAnswer = null,
    Object? feedback = null,
  }) {
    return _then(_$QuestionSessionFeedbackImpl(
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as Question,
      submittedAnswer: null == submittedAnswer
          ? _value.submittedAnswer
          : submittedAnswer // ignore: cast_nullable_to_non_nullable
              as String,
      feedback: null == feedback
          ? _value.feedback
          : feedback // ignore: cast_nullable_to_non_nullable
              as AnswerFeedback,
    ));
  }

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuestionCopyWith<$Res> get question {
    return $QuestionCopyWith<$Res>(_value.question, (value) {
      return _then(_value.copyWith(question: value));
    });
  }

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AnswerFeedbackCopyWith<$Res> get feedback {
    return $AnswerFeedbackCopyWith<$Res>(_value.feedback, (value) {
      return _then(_value.copyWith(feedback: value));
    });
  }
}

/// @nodoc

class _$QuestionSessionFeedbackImpl implements QuestionSessionFeedback {
  const _$QuestionSessionFeedbackImpl(
      {required this.question,
      required this.submittedAnswer,
      required this.feedback});

  @override
  final Question question;
  @override
  final String submittedAnswer;
  @override
  final AnswerFeedback feedback;

  @override
  String toString() {
    return 'QuestionSession.feedback(question: $question, submittedAnswer: $submittedAnswer, feedback: $feedback)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionSessionFeedbackImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.submittedAnswer, submittedAnswer) ||
                other.submittedAnswer == submittedAnswer) &&
            (identical(other.feedback, feedback) ||
                other.feedback == feedback));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, question, submittedAnswer, feedback);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionSessionFeedbackImplCopyWith<_$QuestionSessionFeedbackImpl>
      get copyWith => __$$QuestionSessionFeedbackImplCopyWithImpl<
          _$QuestionSessionFeedbackImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) {
    return feedback(question, submittedAnswer, this.feedback);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) {
    return feedback?.call(question, submittedAnswer, this.feedback);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
    required TResult orElse(),
  }) {
    if (feedback != null) {
      return feedback(question, submittedAnswer, this.feedback);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) {
    return feedback(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) {
    return feedback?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (feedback != null) {
      return feedback(this);
    }
    return orElse();
  }
}

abstract class QuestionSessionFeedback implements QuestionSession {
  const factory QuestionSessionFeedback(
      {required final Question question,
      required final String submittedAnswer,
      required final AnswerFeedback feedback}) = _$QuestionSessionFeedbackImpl;

  Question get question;
  String get submittedAnswer;
  AnswerFeedback get feedback;

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionSessionFeedbackImplCopyWith<_$QuestionSessionFeedbackImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$QuestionSessionUnavailableImplCopyWith<$Res> {
  factory _$$QuestionSessionUnavailableImplCopyWith(
          _$QuestionSessionUnavailableImpl value,
          $Res Function(_$QuestionSessionUnavailableImpl) then) =
      __$$QuestionSessionUnavailableImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message, bool isNoTopics, int? retryAfterSeconds});
}

/// @nodoc
class __$$QuestionSessionUnavailableImplCopyWithImpl<$Res>
    extends _$QuestionSessionCopyWithImpl<$Res,
        _$QuestionSessionUnavailableImpl>
    implements _$$QuestionSessionUnavailableImplCopyWith<$Res> {
  __$$QuestionSessionUnavailableImplCopyWithImpl(
      _$QuestionSessionUnavailableImpl _value,
      $Res Function(_$QuestionSessionUnavailableImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? isNoTopics = null,
    Object? retryAfterSeconds = freezed,
  }) {
    return _then(_$QuestionSessionUnavailableImpl(
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

class _$QuestionSessionUnavailableImpl implements QuestionSessionUnavailable {
  const _$QuestionSessionUnavailableImpl(
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
    return 'QuestionSession.unavailable(message: $message, isNoTopics: $isNoTopics, retryAfterSeconds: $retryAfterSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionSessionUnavailableImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.isNoTopics, isNoTopics) ||
                other.isNoTopics == isNoTopics) &&
            (identical(other.retryAfterSeconds, retryAfterSeconds) ||
                other.retryAfterSeconds == retryAfterSeconds));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, isNoTopics, retryAfterSeconds);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionSessionUnavailableImplCopyWith<_$QuestionSessionUnavailableImpl>
      get copyWith => __$$QuestionSessionUnavailableImplCopyWithImpl<
          _$QuestionSessionUnavailableImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) {
    return unavailable(message, isNoTopics, retryAfterSeconds);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) {
    return unavailable?.call(message, isNoTopics, retryAfterSeconds);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
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
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) {
    return unavailable(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) {
    return unavailable?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (unavailable != null) {
      return unavailable(this);
    }
    return orElse();
  }
}

abstract class QuestionSessionUnavailable implements QuestionSession {
  const factory QuestionSessionUnavailable(
      {required final String message,
      required final bool isNoTopics,
      final int? retryAfterSeconds}) = _$QuestionSessionUnavailableImpl;

  String get message;
  bool get isNoTopics;
  int? get retryAfterSeconds;

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionSessionUnavailableImplCopyWith<_$QuestionSessionUnavailableImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$QuestionSessionErrorImplCopyWith<$Res> {
  factory _$$QuestionSessionErrorImplCopyWith(_$QuestionSessionErrorImpl value,
          $Res Function(_$QuestionSessionErrorImpl) then) =
      __$$QuestionSessionErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$QuestionSessionErrorImplCopyWithImpl<$Res>
    extends _$QuestionSessionCopyWithImpl<$Res, _$QuestionSessionErrorImpl>
    implements _$$QuestionSessionErrorImplCopyWith<$Res> {
  __$$QuestionSessionErrorImplCopyWithImpl(_$QuestionSessionErrorImpl _value,
      $Res Function(_$QuestionSessionErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$QuestionSessionErrorImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$QuestionSessionErrorImpl implements QuestionSessionError {
  const _$QuestionSessionErrorImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'QuestionSession.error(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionSessionErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionSessionErrorImplCopyWith<_$QuestionSessionErrorImpl>
      get copyWith =>
          __$$QuestionSessionErrorImplCopyWithImpl<_$QuestionSessionErrorImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
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
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class QuestionSessionError implements QuestionSession {
  const factory QuestionSessionError({required final String message}) =
      _$QuestionSessionErrorImpl;

  String get message;

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionSessionErrorImplCopyWith<_$QuestionSessionErrorImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$QuestionSessionCompletedImplCopyWith<$Res> {
  factory _$$QuestionSessionCompletedImplCopyWith(
          _$QuestionSessionCompletedImpl value,
          $Res Function(_$QuestionSessionCompletedImpl) then) =
      __$$QuestionSessionCompletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int correctCount, int totalCount});
}

/// @nodoc
class __$$QuestionSessionCompletedImplCopyWithImpl<$Res>
    extends _$QuestionSessionCopyWithImpl<$Res, _$QuestionSessionCompletedImpl>
    implements _$$QuestionSessionCompletedImplCopyWith<$Res> {
  __$$QuestionSessionCompletedImplCopyWithImpl(
      _$QuestionSessionCompletedImpl _value,
      $Res Function(_$QuestionSessionCompletedImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? correctCount = null,
    Object? totalCount = null,
  }) {
    return _then(_$QuestionSessionCompletedImpl(
      correctCount: null == correctCount
          ? _value.correctCount
          : correctCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$QuestionSessionCompletedImpl implements QuestionSessionCompleted {
  const _$QuestionSessionCompletedImpl(
      {required this.correctCount, required this.totalCount});

  @override
  final int correctCount;
  @override
  final int totalCount;

  @override
  String toString() {
    return 'QuestionSession.completed(correctCount: $correctCount, totalCount: $totalCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionSessionCompletedImpl &&
            (identical(other.correctCount, correctCount) ||
                other.correctCount == correctCount) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount));
  }

  @override
  int get hashCode => Object.hash(runtimeType, correctCount, totalCount);

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionSessionCompletedImplCopyWith<_$QuestionSessionCompletedImpl>
      get copyWith => __$$QuestionSessionCompletedImplCopyWithImpl<
          _$QuestionSessionCompletedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function() loading,
    required TResult Function(Question question, String? draftAnswer) ready,
    required TResult Function(Question question, String draftAnswer) submitting,
    required TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)
        feedback,
    required TResult Function(
            String message, bool isNoTopics, int? retryAfterSeconds)
        unavailable,
    required TResult Function(String message) error,
    required TResult Function(int correctCount, int totalCount) completed,
  }) {
    return completed(correctCount, totalCount);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function()? loading,
    TResult? Function(Question question, String? draftAnswer)? ready,
    TResult? Function(Question question, String draftAnswer)? submitting,
    TResult? Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult? Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult? Function(String message)? error,
    TResult? Function(int correctCount, int totalCount)? completed,
  }) {
    return completed?.call(correctCount, totalCount);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function()? loading,
    TResult Function(Question question, String? draftAnswer)? ready,
    TResult Function(Question question, String draftAnswer)? submitting,
    TResult Function(
            Question question, String submittedAnswer, AnswerFeedback feedback)?
        feedback,
    TResult Function(String message, bool isNoTopics, int? retryAfterSeconds)?
        unavailable,
    TResult Function(String message)? error,
    TResult Function(int correctCount, int totalCount)? completed,
    required TResult orElse(),
  }) {
    if (completed != null) {
      return completed(correctCount, totalCount);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(QuestionSessionIdle value) idle,
    required TResult Function(QuestionSessionLoading value) loading,
    required TResult Function(QuestionSessionReady value) ready,
    required TResult Function(QuestionSessionSubmitting value) submitting,
    required TResult Function(QuestionSessionFeedback value) feedback,
    required TResult Function(QuestionSessionUnavailable value) unavailable,
    required TResult Function(QuestionSessionError value) error,
    required TResult Function(QuestionSessionCompleted value) completed,
  }) {
    return completed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(QuestionSessionIdle value)? idle,
    TResult? Function(QuestionSessionLoading value)? loading,
    TResult? Function(QuestionSessionReady value)? ready,
    TResult? Function(QuestionSessionSubmitting value)? submitting,
    TResult? Function(QuestionSessionFeedback value)? feedback,
    TResult? Function(QuestionSessionUnavailable value)? unavailable,
    TResult? Function(QuestionSessionError value)? error,
    TResult? Function(QuestionSessionCompleted value)? completed,
  }) {
    return completed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(QuestionSessionIdle value)? idle,
    TResult Function(QuestionSessionLoading value)? loading,
    TResult Function(QuestionSessionReady value)? ready,
    TResult Function(QuestionSessionSubmitting value)? submitting,
    TResult Function(QuestionSessionFeedback value)? feedback,
    TResult Function(QuestionSessionUnavailable value)? unavailable,
    TResult Function(QuestionSessionError value)? error,
    TResult Function(QuestionSessionCompleted value)? completed,
    required TResult orElse(),
  }) {
    if (completed != null) {
      return completed(this);
    }
    return orElse();
  }
}

abstract class QuestionSessionCompleted implements QuestionSession {
  const factory QuestionSessionCompleted(
      {required final int correctCount,
      required final int totalCount}) = _$QuestionSessionCompletedImpl;

  int get correctCount;
  int get totalCount;

  /// Create a copy of QuestionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionSessionCompletedImplCopyWith<_$QuestionSessionCompletedImpl>
      get copyWith => throw _privateConstructorUsedError;
}
