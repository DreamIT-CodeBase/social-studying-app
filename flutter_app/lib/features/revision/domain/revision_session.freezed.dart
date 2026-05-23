// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'revision_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RevisionProgress {
  int get position => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;

  /// Create a copy of RevisionProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RevisionProgressCopyWith<RevisionProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RevisionProgressCopyWith<$Res> {
  factory $RevisionProgressCopyWith(
          RevisionProgress value, $Res Function(RevisionProgress) then) =
      _$RevisionProgressCopyWithImpl<$Res, RevisionProgress>;
  @useResult
  $Res call({int position, int total});
}

/// @nodoc
class _$RevisionProgressCopyWithImpl<$Res, $Val extends RevisionProgress>
    implements $RevisionProgressCopyWith<$Res> {
  _$RevisionProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RevisionProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? position = null,
    Object? total = null,
  }) {
    return _then(_value.copyWith(
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RevisionProgressImplCopyWith<$Res>
    implements $RevisionProgressCopyWith<$Res> {
  factory _$$RevisionProgressImplCopyWith(_$RevisionProgressImpl value,
          $Res Function(_$RevisionProgressImpl) then) =
      __$$RevisionProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int position, int total});
}

/// @nodoc
class __$$RevisionProgressImplCopyWithImpl<$Res>
    extends _$RevisionProgressCopyWithImpl<$Res, _$RevisionProgressImpl>
    implements _$$RevisionProgressImplCopyWith<$Res> {
  __$$RevisionProgressImplCopyWithImpl(_$RevisionProgressImpl _value,
      $Res Function(_$RevisionProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? position = null,
    Object? total = null,
  }) {
    return _then(_$RevisionProgressImpl(
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$RevisionProgressImpl implements _RevisionProgress {
  const _$RevisionProgressImpl({required this.position, required this.total});

  @override
  final int position;
  @override
  final int total;

  @override
  String toString() {
    return 'RevisionProgress(position: $position, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionProgressImpl &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.total, total) || other.total == total));
  }

  @override
  int get hashCode => Object.hash(runtimeType, position, total);

  /// Create a copy of RevisionProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionProgressImplCopyWith<_$RevisionProgressImpl> get copyWith =>
      __$$RevisionProgressImplCopyWithImpl<_$RevisionProgressImpl>(
          this, _$identity);
}

abstract class _RevisionProgress implements RevisionProgress {
  const factory _RevisionProgress(
      {required final int position,
      required final int total}) = _$RevisionProgressImpl;

  @override
  int get position;
  @override
  int get total;

  /// Create a copy of RevisionProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionProgressImplCopyWith<_$RevisionProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RevisionSummary {
  int get total => throw _privateConstructorUsedError;
  int get questionsAnswered => throw _privateConstructorUsedError;
  int get questionsCorrect => throw _privateConstructorUsedError;
  int get flashcardsReviewed => throw _privateConstructorUsedError;

  /// Create a copy of RevisionSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RevisionSummaryCopyWith<RevisionSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RevisionSummaryCopyWith<$Res> {
  factory $RevisionSummaryCopyWith(
          RevisionSummary value, $Res Function(RevisionSummary) then) =
      _$RevisionSummaryCopyWithImpl<$Res, RevisionSummary>;
  @useResult
  $Res call(
      {int total,
      int questionsAnswered,
      int questionsCorrect,
      int flashcardsReviewed});
}

/// @nodoc
class _$RevisionSummaryCopyWithImpl<$Res, $Val extends RevisionSummary>
    implements $RevisionSummaryCopyWith<$Res> {
  _$RevisionSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RevisionSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? total = null,
    Object? questionsAnswered = null,
    Object? questionsCorrect = null,
    Object? flashcardsReviewed = null,
  }) {
    return _then(_value.copyWith(
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      questionsAnswered: null == questionsAnswered
          ? _value.questionsAnswered
          : questionsAnswered // ignore: cast_nullable_to_non_nullable
              as int,
      questionsCorrect: null == questionsCorrect
          ? _value.questionsCorrect
          : questionsCorrect // ignore: cast_nullable_to_non_nullable
              as int,
      flashcardsReviewed: null == flashcardsReviewed
          ? _value.flashcardsReviewed
          : flashcardsReviewed // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RevisionSummaryImplCopyWith<$Res>
    implements $RevisionSummaryCopyWith<$Res> {
  factory _$$RevisionSummaryImplCopyWith(_$RevisionSummaryImpl value,
          $Res Function(_$RevisionSummaryImpl) then) =
      __$$RevisionSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int total,
      int questionsAnswered,
      int questionsCorrect,
      int flashcardsReviewed});
}

/// @nodoc
class __$$RevisionSummaryImplCopyWithImpl<$Res>
    extends _$RevisionSummaryCopyWithImpl<$Res, _$RevisionSummaryImpl>
    implements _$$RevisionSummaryImplCopyWith<$Res> {
  __$$RevisionSummaryImplCopyWithImpl(
      _$RevisionSummaryImpl _value, $Res Function(_$RevisionSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? total = null,
    Object? questionsAnswered = null,
    Object? questionsCorrect = null,
    Object? flashcardsReviewed = null,
  }) {
    return _then(_$RevisionSummaryImpl(
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      questionsAnswered: null == questionsAnswered
          ? _value.questionsAnswered
          : questionsAnswered // ignore: cast_nullable_to_non_nullable
              as int,
      questionsCorrect: null == questionsCorrect
          ? _value.questionsCorrect
          : questionsCorrect // ignore: cast_nullable_to_non_nullable
              as int,
      flashcardsReviewed: null == flashcardsReviewed
          ? _value.flashcardsReviewed
          : flashcardsReviewed // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$RevisionSummaryImpl implements _RevisionSummary {
  const _$RevisionSummaryImpl(
      {required this.total,
      required this.questionsAnswered,
      required this.questionsCorrect,
      required this.flashcardsReviewed});

  @override
  final int total;
  @override
  final int questionsAnswered;
  @override
  final int questionsCorrect;
  @override
  final int flashcardsReviewed;

  @override
  String toString() {
    return 'RevisionSummary(total: $total, questionsAnswered: $questionsAnswered, questionsCorrect: $questionsCorrect, flashcardsReviewed: $flashcardsReviewed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSummaryImpl &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.questionsAnswered, questionsAnswered) ||
                other.questionsAnswered == questionsAnswered) &&
            (identical(other.questionsCorrect, questionsCorrect) ||
                other.questionsCorrect == questionsCorrect) &&
            (identical(other.flashcardsReviewed, flashcardsReviewed) ||
                other.flashcardsReviewed == flashcardsReviewed));
  }

  @override
  int get hashCode => Object.hash(runtimeType, total, questionsAnswered,
      questionsCorrect, flashcardsReviewed);

  /// Create a copy of RevisionSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSummaryImplCopyWith<_$RevisionSummaryImpl> get copyWith =>
      __$$RevisionSummaryImplCopyWithImpl<_$RevisionSummaryImpl>(
          this, _$identity);
}

abstract class _RevisionSummary implements RevisionSummary {
  const factory _RevisionSummary(
      {required final int total,
      required final int questionsAnswered,
      required final int questionsCorrect,
      required final int flashcardsReviewed}) = _$RevisionSummaryImpl;

  @override
  int get total;
  @override
  int get questionsAnswered;
  @override
  int get questionsCorrect;
  @override
  int get flashcardsReviewed;

  /// Create a copy of RevisionSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSummaryImplCopyWith<_$RevisionSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RevisionSession {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RevisionSessionCopyWith<$Res> {
  factory $RevisionSessionCopyWith(
          RevisionSession value, $Res Function(RevisionSession) then) =
      _$RevisionSessionCopyWithImpl<$Res, RevisionSession>;
}

/// @nodoc
class _$RevisionSessionCopyWithImpl<$Res, $Val extends RevisionSession>
    implements $RevisionSessionCopyWith<$Res> {
  _$RevisionSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$RevisionSessionIdleImplCopyWith<$Res> {
  factory _$$RevisionSessionIdleImplCopyWith(_$RevisionSessionIdleImpl value,
          $Res Function(_$RevisionSessionIdleImpl) then) =
      __$$RevisionSessionIdleImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RevisionSessionIdleImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res, _$RevisionSessionIdleImpl>
    implements _$$RevisionSessionIdleImplCopyWith<$Res> {
  __$$RevisionSessionIdleImplCopyWithImpl(_$RevisionSessionIdleImpl _value,
      $Res Function(_$RevisionSessionIdleImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$RevisionSessionIdleImpl implements RevisionSessionIdle {
  const _$RevisionSessionIdleImpl();

  @override
  String toString() {
    return 'RevisionSession.idle()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionIdleImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return idle();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return idle?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
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
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return idle(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return idle?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionIdle implements RevisionSession {
  const factory RevisionSessionIdle() = _$RevisionSessionIdleImpl;
}

/// @nodoc
abstract class _$$RevisionSessionLoadingImplCopyWith<$Res> {
  factory _$$RevisionSessionLoadingImplCopyWith(
          _$RevisionSessionLoadingImpl value,
          $Res Function(_$RevisionSessionLoadingImpl) then) =
      __$$RevisionSessionLoadingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({RevisionProgress progress});

  $RevisionProgressCopyWith<$Res> get progress;
}

/// @nodoc
class __$$RevisionSessionLoadingImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res, _$RevisionSessionLoadingImpl>
    implements _$$RevisionSessionLoadingImplCopyWith<$Res> {
  __$$RevisionSessionLoadingImplCopyWithImpl(
      _$RevisionSessionLoadingImpl _value,
      $Res Function(_$RevisionSessionLoadingImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
  }) {
    return _then(_$RevisionSessionLoadingImpl(
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as RevisionProgress,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionProgressCopyWith<$Res> get progress {
    return $RevisionProgressCopyWith<$Res>(_value.progress, (value) {
      return _then(_value.copyWith(progress: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionLoadingImpl implements RevisionSessionLoading {
  const _$RevisionSessionLoadingImpl({required this.progress});

  @override
  final RevisionProgress progress;

  @override
  String toString() {
    return 'RevisionSession.loading(progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionLoadingImpl &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, progress);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionLoadingImplCopyWith<_$RevisionSessionLoadingImpl>
      get copyWith => __$$RevisionSessionLoadingImplCopyWithImpl<
          _$RevisionSessionLoadingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return loading(progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return loading?.call(progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return loading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return loading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (loading != null) {
      return loading(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionLoading implements RevisionSession {
  const factory RevisionSessionLoading(
          {required final RevisionProgress progress}) =
      _$RevisionSessionLoadingImpl;

  RevisionProgress get progress;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionLoadingImplCopyWith<_$RevisionSessionLoadingImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionQuestionImplCopyWith<$Res> {
  factory _$$RevisionSessionQuestionImplCopyWith(
          _$RevisionSessionQuestionImpl value,
          $Res Function(_$RevisionSessionQuestionImpl) then) =
      __$$RevisionSessionQuestionImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {Question question, String? draftAnswer, RevisionProgress progress});

  $QuestionCopyWith<$Res> get question;
  $RevisionProgressCopyWith<$Res> get progress;
}

/// @nodoc
class __$$RevisionSessionQuestionImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res, _$RevisionSessionQuestionImpl>
    implements _$$RevisionSessionQuestionImplCopyWith<$Res> {
  __$$RevisionSessionQuestionImplCopyWithImpl(
      _$RevisionSessionQuestionImpl _value,
      $Res Function(_$RevisionSessionQuestionImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? draftAnswer = freezed,
    Object? progress = null,
  }) {
    return _then(_$RevisionSessionQuestionImpl(
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as Question,
      draftAnswer: freezed == draftAnswer
          ? _value.draftAnswer
          : draftAnswer // ignore: cast_nullable_to_non_nullable
              as String?,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as RevisionProgress,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuestionCopyWith<$Res> get question {
    return $QuestionCopyWith<$Res>(_value.question, (value) {
      return _then(_value.copyWith(question: value));
    });
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionProgressCopyWith<$Res> get progress {
    return $RevisionProgressCopyWith<$Res>(_value.progress, (value) {
      return _then(_value.copyWith(progress: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionQuestionImpl implements RevisionSessionQuestion {
  const _$RevisionSessionQuestionImpl(
      {required this.question, this.draftAnswer, required this.progress});

  @override
  final Question question;
  @override
  final String? draftAnswer;
  @override
  final RevisionProgress progress;

  @override
  String toString() {
    return 'RevisionSession.question(question: $question, draftAnswer: $draftAnswer, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionQuestionImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.draftAnswer, draftAnswer) ||
                other.draftAnswer == draftAnswer) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, question, draftAnswer, progress);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionQuestionImplCopyWith<_$RevisionSessionQuestionImpl>
      get copyWith => __$$RevisionSessionQuestionImplCopyWithImpl<
          _$RevisionSessionQuestionImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return question(this.question, draftAnswer, progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return question?.call(this.question, draftAnswer, progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (question != null) {
      return question(this.question, draftAnswer, progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return question(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return question?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (question != null) {
      return question(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionQuestion implements RevisionSession {
  const factory RevisionSessionQuestion(
          {required final Question question,
          final String? draftAnswer,
          required final RevisionProgress progress}) =
      _$RevisionSessionQuestionImpl;

  Question get question;
  String? get draftAnswer;
  RevisionProgress get progress;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionQuestionImplCopyWith<_$RevisionSessionQuestionImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionQuestionSubmittingImplCopyWith<$Res> {
  factory _$$RevisionSessionQuestionSubmittingImplCopyWith(
          _$RevisionSessionQuestionSubmittingImpl value,
          $Res Function(_$RevisionSessionQuestionSubmittingImpl) then) =
      __$$RevisionSessionQuestionSubmittingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Question question, String draftAnswer, RevisionProgress progress});

  $QuestionCopyWith<$Res> get question;
  $RevisionProgressCopyWith<$Res> get progress;
}

/// @nodoc
class __$$RevisionSessionQuestionSubmittingImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res,
        _$RevisionSessionQuestionSubmittingImpl>
    implements _$$RevisionSessionQuestionSubmittingImplCopyWith<$Res> {
  __$$RevisionSessionQuestionSubmittingImplCopyWithImpl(
      _$RevisionSessionQuestionSubmittingImpl _value,
      $Res Function(_$RevisionSessionQuestionSubmittingImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? draftAnswer = null,
    Object? progress = null,
  }) {
    return _then(_$RevisionSessionQuestionSubmittingImpl(
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as Question,
      draftAnswer: null == draftAnswer
          ? _value.draftAnswer
          : draftAnswer // ignore: cast_nullable_to_non_nullable
              as String,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as RevisionProgress,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuestionCopyWith<$Res> get question {
    return $QuestionCopyWith<$Res>(_value.question, (value) {
      return _then(_value.copyWith(question: value));
    });
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionProgressCopyWith<$Res> get progress {
    return $RevisionProgressCopyWith<$Res>(_value.progress, (value) {
      return _then(_value.copyWith(progress: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionQuestionSubmittingImpl
    implements RevisionSessionQuestionSubmitting {
  const _$RevisionSessionQuestionSubmittingImpl(
      {required this.question,
      required this.draftAnswer,
      required this.progress});

  @override
  final Question question;
  @override
  final String draftAnswer;
  @override
  final RevisionProgress progress;

  @override
  String toString() {
    return 'RevisionSession.questionSubmitting(question: $question, draftAnswer: $draftAnswer, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionQuestionSubmittingImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.draftAnswer, draftAnswer) ||
                other.draftAnswer == draftAnswer) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, question, draftAnswer, progress);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionQuestionSubmittingImplCopyWith<
          _$RevisionSessionQuestionSubmittingImpl>
      get copyWith => __$$RevisionSessionQuestionSubmittingImplCopyWithImpl<
          _$RevisionSessionQuestionSubmittingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return questionSubmitting(this.question, draftAnswer, progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return questionSubmitting?.call(this.question, draftAnswer, progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (questionSubmitting != null) {
      return questionSubmitting(this.question, draftAnswer, progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return questionSubmitting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return questionSubmitting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (questionSubmitting != null) {
      return questionSubmitting(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionQuestionSubmitting implements RevisionSession {
  const factory RevisionSessionQuestionSubmitting(
          {required final Question question,
          required final String draftAnswer,
          required final RevisionProgress progress}) =
      _$RevisionSessionQuestionSubmittingImpl;

  Question get question;
  String get draftAnswer;
  RevisionProgress get progress;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionQuestionSubmittingImplCopyWith<
          _$RevisionSessionQuestionSubmittingImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionQuestionGradedImplCopyWith<$Res> {
  factory _$$RevisionSessionQuestionGradedImplCopyWith(
          _$RevisionSessionQuestionGradedImpl value,
          $Res Function(_$RevisionSessionQuestionGradedImpl) then) =
      __$$RevisionSessionQuestionGradedImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {Question question,
      String submittedAnswer,
      AnswerFeedback feedback,
      RevisionProgress progress});

  $QuestionCopyWith<$Res> get question;
  $AnswerFeedbackCopyWith<$Res> get feedback;
  $RevisionProgressCopyWith<$Res> get progress;
}

/// @nodoc
class __$$RevisionSessionQuestionGradedImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res,
        _$RevisionSessionQuestionGradedImpl>
    implements _$$RevisionSessionQuestionGradedImplCopyWith<$Res> {
  __$$RevisionSessionQuestionGradedImplCopyWithImpl(
      _$RevisionSessionQuestionGradedImpl _value,
      $Res Function(_$RevisionSessionQuestionGradedImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? question = null,
    Object? submittedAnswer = null,
    Object? feedback = null,
    Object? progress = null,
  }) {
    return _then(_$RevisionSessionQuestionGradedImpl(
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
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as RevisionProgress,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuestionCopyWith<$Res> get question {
    return $QuestionCopyWith<$Res>(_value.question, (value) {
      return _then(_value.copyWith(question: value));
    });
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AnswerFeedbackCopyWith<$Res> get feedback {
    return $AnswerFeedbackCopyWith<$Res>(_value.feedback, (value) {
      return _then(_value.copyWith(feedback: value));
    });
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionProgressCopyWith<$Res> get progress {
    return $RevisionProgressCopyWith<$Res>(_value.progress, (value) {
      return _then(_value.copyWith(progress: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionQuestionGradedImpl
    implements RevisionSessionQuestionGraded {
  const _$RevisionSessionQuestionGradedImpl(
      {required this.question,
      required this.submittedAnswer,
      required this.feedback,
      required this.progress});

  @override
  final Question question;
  @override
  final String submittedAnswer;
  @override
  final AnswerFeedback feedback;
  @override
  final RevisionProgress progress;

  @override
  String toString() {
    return 'RevisionSession.questionGraded(question: $question, submittedAnswer: $submittedAnswer, feedback: $feedback, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionQuestionGradedImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.submittedAnswer, submittedAnswer) ||
                other.submittedAnswer == submittedAnswer) &&
            (identical(other.feedback, feedback) ||
                other.feedback == feedback) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, question, submittedAnswer, feedback, progress);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionQuestionGradedImplCopyWith<
          _$RevisionSessionQuestionGradedImpl>
      get copyWith => __$$RevisionSessionQuestionGradedImplCopyWithImpl<
          _$RevisionSessionQuestionGradedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return questionGraded(this.question, submittedAnswer, feedback, progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return questionGraded?.call(
        this.question, submittedAnswer, feedback, progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (questionGraded != null) {
      return questionGraded(this.question, submittedAnswer, feedback, progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return questionGraded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return questionGraded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (questionGraded != null) {
      return questionGraded(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionQuestionGraded implements RevisionSession {
  const factory RevisionSessionQuestionGraded(
          {required final Question question,
          required final String submittedAnswer,
          required final AnswerFeedback feedback,
          required final RevisionProgress progress}) =
      _$RevisionSessionQuestionGradedImpl;

  Question get question;
  String get submittedAnswer;
  AnswerFeedback get feedback;
  RevisionProgress get progress;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionQuestionGradedImplCopyWith<
          _$RevisionSessionQuestionGradedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionFlashcardFrontImplCopyWith<$Res> {
  factory _$$RevisionSessionFlashcardFrontImplCopyWith(
          _$RevisionSessionFlashcardFrontImpl value,
          $Res Function(_$RevisionSessionFlashcardFrontImpl) then) =
      __$$RevisionSessionFlashcardFrontImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Flashcard card, RevisionProgress progress});

  $FlashcardCopyWith<$Res> get card;
  $RevisionProgressCopyWith<$Res> get progress;
}

/// @nodoc
class __$$RevisionSessionFlashcardFrontImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res,
        _$RevisionSessionFlashcardFrontImpl>
    implements _$$RevisionSessionFlashcardFrontImplCopyWith<$Res> {
  __$$RevisionSessionFlashcardFrontImplCopyWithImpl(
      _$RevisionSessionFlashcardFrontImpl _value,
      $Res Function(_$RevisionSessionFlashcardFrontImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? card = null,
    Object? progress = null,
  }) {
    return _then(_$RevisionSessionFlashcardFrontImpl(
      card: null == card
          ? _value.card
          : card // ignore: cast_nullable_to_non_nullable
              as Flashcard,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as RevisionProgress,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardCopyWith<$Res> get card {
    return $FlashcardCopyWith<$Res>(_value.card, (value) {
      return _then(_value.copyWith(card: value));
    });
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionProgressCopyWith<$Res> get progress {
    return $RevisionProgressCopyWith<$Res>(_value.progress, (value) {
      return _then(_value.copyWith(progress: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionFlashcardFrontImpl
    implements RevisionSessionFlashcardFront {
  const _$RevisionSessionFlashcardFrontImpl(
      {required this.card, required this.progress});

  @override
  final Flashcard card;
  @override
  final RevisionProgress progress;

  @override
  String toString() {
    return 'RevisionSession.flashcardFront(card: $card, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionFlashcardFrontImpl &&
            (identical(other.card, card) || other.card == card) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, card, progress);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionFlashcardFrontImplCopyWith<
          _$RevisionSessionFlashcardFrontImpl>
      get copyWith => __$$RevisionSessionFlashcardFrontImplCopyWithImpl<
          _$RevisionSessionFlashcardFrontImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return flashcardFront(card, progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return flashcardFront?.call(card, progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (flashcardFront != null) {
      return flashcardFront(card, progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return flashcardFront(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return flashcardFront?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (flashcardFront != null) {
      return flashcardFront(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionFlashcardFront implements RevisionSession {
  const factory RevisionSessionFlashcardFront(
          {required final Flashcard card,
          required final RevisionProgress progress}) =
      _$RevisionSessionFlashcardFrontImpl;

  Flashcard get card;
  RevisionProgress get progress;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionFlashcardFrontImplCopyWith<
          _$RevisionSessionFlashcardFrontImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionFlashcardBackImplCopyWith<$Res> {
  factory _$$RevisionSessionFlashcardBackImplCopyWith(
          _$RevisionSessionFlashcardBackImpl value,
          $Res Function(_$RevisionSessionFlashcardBackImpl) then) =
      __$$RevisionSessionFlashcardBackImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Flashcard card, RevisionProgress progress});

  $FlashcardCopyWith<$Res> get card;
  $RevisionProgressCopyWith<$Res> get progress;
}

/// @nodoc
class __$$RevisionSessionFlashcardBackImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res,
        _$RevisionSessionFlashcardBackImpl>
    implements _$$RevisionSessionFlashcardBackImplCopyWith<$Res> {
  __$$RevisionSessionFlashcardBackImplCopyWithImpl(
      _$RevisionSessionFlashcardBackImpl _value,
      $Res Function(_$RevisionSessionFlashcardBackImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? card = null,
    Object? progress = null,
  }) {
    return _then(_$RevisionSessionFlashcardBackImpl(
      card: null == card
          ? _value.card
          : card // ignore: cast_nullable_to_non_nullable
              as Flashcard,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as RevisionProgress,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardCopyWith<$Res> get card {
    return $FlashcardCopyWith<$Res>(_value.card, (value) {
      return _then(_value.copyWith(card: value));
    });
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionProgressCopyWith<$Res> get progress {
    return $RevisionProgressCopyWith<$Res>(_value.progress, (value) {
      return _then(_value.copyWith(progress: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionFlashcardBackImpl
    implements RevisionSessionFlashcardBack {
  const _$RevisionSessionFlashcardBackImpl(
      {required this.card, required this.progress});

  @override
  final Flashcard card;
  @override
  final RevisionProgress progress;

  @override
  String toString() {
    return 'RevisionSession.flashcardBack(card: $card, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionFlashcardBackImpl &&
            (identical(other.card, card) || other.card == card) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, card, progress);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionFlashcardBackImplCopyWith<
          _$RevisionSessionFlashcardBackImpl>
      get copyWith => __$$RevisionSessionFlashcardBackImplCopyWithImpl<
          _$RevisionSessionFlashcardBackImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return flashcardBack(card, progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return flashcardBack?.call(card, progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (flashcardBack != null) {
      return flashcardBack(card, progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return flashcardBack(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return flashcardBack?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (flashcardBack != null) {
      return flashcardBack(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionFlashcardBack implements RevisionSession {
  const factory RevisionSessionFlashcardBack(
          {required final Flashcard card,
          required final RevisionProgress progress}) =
      _$RevisionSessionFlashcardBackImpl;

  Flashcard get card;
  RevisionProgress get progress;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionFlashcardBackImplCopyWith<
          _$RevisionSessionFlashcardBackImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionFlashcardRatingImplCopyWith<$Res> {
  factory _$$RevisionSessionFlashcardRatingImplCopyWith(
          _$RevisionSessionFlashcardRatingImpl value,
          $Res Function(_$RevisionSessionFlashcardRatingImpl) then) =
      __$$RevisionSessionFlashcardRatingImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {Flashcard card, FlashcardRating rating, RevisionProgress progress});

  $FlashcardCopyWith<$Res> get card;
  $RevisionProgressCopyWith<$Res> get progress;
}

/// @nodoc
class __$$RevisionSessionFlashcardRatingImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res,
        _$RevisionSessionFlashcardRatingImpl>
    implements _$$RevisionSessionFlashcardRatingImplCopyWith<$Res> {
  __$$RevisionSessionFlashcardRatingImplCopyWithImpl(
      _$RevisionSessionFlashcardRatingImpl _value,
      $Res Function(_$RevisionSessionFlashcardRatingImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? card = null,
    Object? rating = null,
    Object? progress = null,
  }) {
    return _then(_$RevisionSessionFlashcardRatingImpl(
      card: null == card
          ? _value.card
          : card // ignore: cast_nullable_to_non_nullable
              as Flashcard,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as RevisionProgress,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardCopyWith<$Res> get card {
    return $FlashcardCopyWith<$Res>(_value.card, (value) {
      return _then(_value.copyWith(card: value));
    });
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionProgressCopyWith<$Res> get progress {
    return $RevisionProgressCopyWith<$Res>(_value.progress, (value) {
      return _then(_value.copyWith(progress: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionFlashcardRatingImpl
    implements RevisionSessionFlashcardRating {
  const _$RevisionSessionFlashcardRatingImpl(
      {required this.card, required this.rating, required this.progress});

  @override
  final Flashcard card;
  @override
  final FlashcardRating rating;
  @override
  final RevisionProgress progress;

  @override
  String toString() {
    return 'RevisionSession.flashcardRating(card: $card, rating: $rating, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionFlashcardRatingImpl &&
            (identical(other.card, card) || other.card == card) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, card, rating, progress);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionFlashcardRatingImplCopyWith<
          _$RevisionSessionFlashcardRatingImpl>
      get copyWith => __$$RevisionSessionFlashcardRatingImplCopyWithImpl<
          _$RevisionSessionFlashcardRatingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return flashcardRating(card, rating, progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return flashcardRating?.call(card, rating, progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (flashcardRating != null) {
      return flashcardRating(card, rating, progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return flashcardRating(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return flashcardRating?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (flashcardRating != null) {
      return flashcardRating(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionFlashcardRating implements RevisionSession {
  const factory RevisionSessionFlashcardRating(
          {required final Flashcard card,
          required final FlashcardRating rating,
          required final RevisionProgress progress}) =
      _$RevisionSessionFlashcardRatingImpl;

  Flashcard get card;
  FlashcardRating get rating;
  RevisionProgress get progress;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionFlashcardRatingImplCopyWith<
          _$RevisionSessionFlashcardRatingImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionFlashcardRatedImplCopyWith<$Res> {
  factory _$$RevisionSessionFlashcardRatedImplCopyWith(
          _$RevisionSessionFlashcardRatedImpl value,
          $Res Function(_$RevisionSessionFlashcardRatedImpl) then) =
      __$$RevisionSessionFlashcardRatedImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {Flashcard card, FlashcardRating rating, RevisionProgress progress});

  $FlashcardCopyWith<$Res> get card;
  $RevisionProgressCopyWith<$Res> get progress;
}

/// @nodoc
class __$$RevisionSessionFlashcardRatedImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res,
        _$RevisionSessionFlashcardRatedImpl>
    implements _$$RevisionSessionFlashcardRatedImplCopyWith<$Res> {
  __$$RevisionSessionFlashcardRatedImplCopyWithImpl(
      _$RevisionSessionFlashcardRatedImpl _value,
      $Res Function(_$RevisionSessionFlashcardRatedImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? card = null,
    Object? rating = null,
    Object? progress = null,
  }) {
    return _then(_$RevisionSessionFlashcardRatedImpl(
      card: null == card
          ? _value.card
          : card // ignore: cast_nullable_to_non_nullable
              as Flashcard,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as FlashcardRating,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as RevisionProgress,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlashcardCopyWith<$Res> get card {
    return $FlashcardCopyWith<$Res>(_value.card, (value) {
      return _then(_value.copyWith(card: value));
    });
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionProgressCopyWith<$Res> get progress {
    return $RevisionProgressCopyWith<$Res>(_value.progress, (value) {
      return _then(_value.copyWith(progress: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionFlashcardRatedImpl
    implements RevisionSessionFlashcardRated {
  const _$RevisionSessionFlashcardRatedImpl(
      {required this.card, required this.rating, required this.progress});

  @override
  final Flashcard card;
  @override
  final FlashcardRating rating;
  @override
  final RevisionProgress progress;

  @override
  String toString() {
    return 'RevisionSession.flashcardRated(card: $card, rating: $rating, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionFlashcardRatedImpl &&
            (identical(other.card, card) || other.card == card) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, card, rating, progress);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionFlashcardRatedImplCopyWith<
          _$RevisionSessionFlashcardRatedImpl>
      get copyWith => __$$RevisionSessionFlashcardRatedImplCopyWithImpl<
          _$RevisionSessionFlashcardRatedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return flashcardRated(card, rating, progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return flashcardRated?.call(card, rating, progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (flashcardRated != null) {
      return flashcardRated(card, rating, progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return flashcardRated(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return flashcardRated?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (flashcardRated != null) {
      return flashcardRated(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionFlashcardRated implements RevisionSession {
  const factory RevisionSessionFlashcardRated(
          {required final Flashcard card,
          required final FlashcardRating rating,
          required final RevisionProgress progress}) =
      _$RevisionSessionFlashcardRatedImpl;

  Flashcard get card;
  FlashcardRating get rating;
  RevisionProgress get progress;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionFlashcardRatedImplCopyWith<
          _$RevisionSessionFlashcardRatedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionCompleteImplCopyWith<$Res> {
  factory _$$RevisionSessionCompleteImplCopyWith(
          _$RevisionSessionCompleteImpl value,
          $Res Function(_$RevisionSessionCompleteImpl) then) =
      __$$RevisionSessionCompleteImplCopyWithImpl<$Res>;
  @useResult
  $Res call({RevisionSummary summary});

  $RevisionSummaryCopyWith<$Res> get summary;
}

/// @nodoc
class __$$RevisionSessionCompleteImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res, _$RevisionSessionCompleteImpl>
    implements _$$RevisionSessionCompleteImplCopyWith<$Res> {
  __$$RevisionSessionCompleteImplCopyWithImpl(
      _$RevisionSessionCompleteImpl _value,
      $Res Function(_$RevisionSessionCompleteImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? summary = null,
  }) {
    return _then(_$RevisionSessionCompleteImpl(
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as RevisionSummary,
    ));
  }

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RevisionSummaryCopyWith<$Res> get summary {
    return $RevisionSummaryCopyWith<$Res>(_value.summary, (value) {
      return _then(_value.copyWith(summary: value));
    });
  }
}

/// @nodoc

class _$RevisionSessionCompleteImpl implements RevisionSessionComplete {
  const _$RevisionSessionCompleteImpl({required this.summary});

  @override
  final RevisionSummary summary;

  @override
  String toString() {
    return 'RevisionSession.complete(summary: $summary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionCompleteImpl &&
            (identical(other.summary, summary) || other.summary == summary));
  }

  @override
  int get hashCode => Object.hash(runtimeType, summary);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionCompleteImplCopyWith<_$RevisionSessionCompleteImpl>
      get copyWith => __$$RevisionSessionCompleteImplCopyWithImpl<
          _$RevisionSessionCompleteImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return complete(summary);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return complete?.call(summary);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (complete != null) {
      return complete(summary);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return complete(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return complete?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (complete != null) {
      return complete(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionComplete implements RevisionSession {
  const factory RevisionSessionComplete(
      {required final RevisionSummary summary}) = _$RevisionSessionCompleteImpl;

  RevisionSummary get summary;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionCompleteImplCopyWith<_$RevisionSessionCompleteImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionUnavailableImplCopyWith<$Res> {
  factory _$$RevisionSessionUnavailableImplCopyWith(
          _$RevisionSessionUnavailableImpl value,
          $Res Function(_$RevisionSessionUnavailableImpl) then) =
      __$$RevisionSessionUnavailableImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message, bool isNoTopics});
}

/// @nodoc
class __$$RevisionSessionUnavailableImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res,
        _$RevisionSessionUnavailableImpl>
    implements _$$RevisionSessionUnavailableImplCopyWith<$Res> {
  __$$RevisionSessionUnavailableImplCopyWithImpl(
      _$RevisionSessionUnavailableImpl _value,
      $Res Function(_$RevisionSessionUnavailableImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? isNoTopics = null,
  }) {
    return _then(_$RevisionSessionUnavailableImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      isNoTopics: null == isNoTopics
          ? _value.isNoTopics
          : isNoTopics // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$RevisionSessionUnavailableImpl implements RevisionSessionUnavailable {
  const _$RevisionSessionUnavailableImpl(
      {required this.message, required this.isNoTopics});

  @override
  final String message;
  @override
  final bool isNoTopics;

  @override
  String toString() {
    return 'RevisionSession.unavailable(message: $message, isNoTopics: $isNoTopics)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionUnavailableImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.isNoTopics, isNoTopics) ||
                other.isNoTopics == isNoTopics));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message, isNoTopics);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionUnavailableImplCopyWith<_$RevisionSessionUnavailableImpl>
      get copyWith => __$$RevisionSessionUnavailableImplCopyWithImpl<
          _$RevisionSessionUnavailableImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return unavailable(message, isNoTopics);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return unavailable?.call(message, isNoTopics);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (unavailable != null) {
      return unavailable(message, isNoTopics);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return unavailable(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return unavailable?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (unavailable != null) {
      return unavailable(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionUnavailable implements RevisionSession {
  const factory RevisionSessionUnavailable(
      {required final String message,
      required final bool isNoTopics}) = _$RevisionSessionUnavailableImpl;

  String get message;
  bool get isNoTopics;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionUnavailableImplCopyWith<_$RevisionSessionUnavailableImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RevisionSessionErrorImplCopyWith<$Res> {
  factory _$$RevisionSessionErrorImplCopyWith(_$RevisionSessionErrorImpl value,
          $Res Function(_$RevisionSessionErrorImpl) then) =
      __$$RevisionSessionErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$RevisionSessionErrorImplCopyWithImpl<$Res>
    extends _$RevisionSessionCopyWithImpl<$Res, _$RevisionSessionErrorImpl>
    implements _$$RevisionSessionErrorImplCopyWith<$Res> {
  __$$RevisionSessionErrorImplCopyWithImpl(_$RevisionSessionErrorImpl _value,
      $Res Function(_$RevisionSessionErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$RevisionSessionErrorImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$RevisionSessionErrorImpl implements RevisionSessionError {
  const _$RevisionSessionErrorImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'RevisionSession.error(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RevisionSessionErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RevisionSessionErrorImplCopyWith<_$RevisionSessionErrorImpl>
      get copyWith =>
          __$$RevisionSessionErrorImplCopyWithImpl<_$RevisionSessionErrorImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(RevisionProgress progress) loading,
    required TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)
        question,
    required TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)
        questionSubmitting,
    required TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)
        questionGraded,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardFront,
    required TResult Function(Flashcard card, RevisionProgress progress)
        flashcardBack,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRating,
    required TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)
        flashcardRated,
    required TResult Function(RevisionSummary summary) complete,
    required TResult Function(String message, bool isNoTopics) unavailable,
    required TResult Function(String message) error,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(RevisionProgress progress)? loading,
    TResult? Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult? Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult? Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult? Function(Flashcard card, RevisionProgress progress)?
        flashcardFront,
    TResult? Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult? Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult? Function(RevisionSummary summary)? complete,
    TResult? Function(String message, bool isNoTopics)? unavailable,
    TResult? Function(String message)? error,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(RevisionProgress progress)? loading,
    TResult Function(
            Question question, String? draftAnswer, RevisionProgress progress)?
        question,
    TResult Function(
            Question question, String draftAnswer, RevisionProgress progress)?
        questionSubmitting,
    TResult Function(Question question, String submittedAnswer,
            AnswerFeedback feedback, RevisionProgress progress)?
        questionGraded,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardFront,
    TResult Function(Flashcard card, RevisionProgress progress)? flashcardBack,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRating,
    TResult Function(
            Flashcard card, FlashcardRating rating, RevisionProgress progress)?
        flashcardRated,
    TResult Function(RevisionSummary summary)? complete,
    TResult Function(String message, bool isNoTopics)? unavailable,
    TResult Function(String message)? error,
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
    required TResult Function(RevisionSessionIdle value) idle,
    required TResult Function(RevisionSessionLoading value) loading,
    required TResult Function(RevisionSessionQuestion value) question,
    required TResult Function(RevisionSessionQuestionSubmitting value)
        questionSubmitting,
    required TResult Function(RevisionSessionQuestionGraded value)
        questionGraded,
    required TResult Function(RevisionSessionFlashcardFront value)
        flashcardFront,
    required TResult Function(RevisionSessionFlashcardBack value) flashcardBack,
    required TResult Function(RevisionSessionFlashcardRating value)
        flashcardRating,
    required TResult Function(RevisionSessionFlashcardRated value)
        flashcardRated,
    required TResult Function(RevisionSessionComplete value) complete,
    required TResult Function(RevisionSessionUnavailable value) unavailable,
    required TResult Function(RevisionSessionError value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RevisionSessionIdle value)? idle,
    TResult? Function(RevisionSessionLoading value)? loading,
    TResult? Function(RevisionSessionQuestion value)? question,
    TResult? Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult? Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult? Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult? Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult? Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult? Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult? Function(RevisionSessionComplete value)? complete,
    TResult? Function(RevisionSessionUnavailable value)? unavailable,
    TResult? Function(RevisionSessionError value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RevisionSessionIdle value)? idle,
    TResult Function(RevisionSessionLoading value)? loading,
    TResult Function(RevisionSessionQuestion value)? question,
    TResult Function(RevisionSessionQuestionSubmitting value)?
        questionSubmitting,
    TResult Function(RevisionSessionQuestionGraded value)? questionGraded,
    TResult Function(RevisionSessionFlashcardFront value)? flashcardFront,
    TResult Function(RevisionSessionFlashcardBack value)? flashcardBack,
    TResult Function(RevisionSessionFlashcardRating value)? flashcardRating,
    TResult Function(RevisionSessionFlashcardRated value)? flashcardRated,
    TResult Function(RevisionSessionComplete value)? complete,
    TResult Function(RevisionSessionUnavailable value)? unavailable,
    TResult Function(RevisionSessionError value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class RevisionSessionError implements RevisionSession {
  const factory RevisionSessionError({required final String message}) =
      _$RevisionSessionErrorImpl;

  String get message;

  /// Create a copy of RevisionSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RevisionSessionErrorImplCopyWith<_$RevisionSessionErrorImpl>
      get copyWith => throw _privateConstructorUsedError;
}
