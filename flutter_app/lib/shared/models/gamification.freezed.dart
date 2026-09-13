// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gamification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EarnedBadge _$EarnedBadgeFromJson(Map<String, dynamic> json) {
  return _EarnedBadge.fromJson(json);
}

/// @nodoc
mixin _$EarnedBadge {
  @JsonKey(name: 'badge_id')
  String get badgeId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;

  /// Material Icons name string (e.g. `"local_fire_department_rounded"`)
  /// — the UI maps it through [iconForName] in `presentation/widgets/
  /// badge_icon.dart` so we don't ship a giant codepoint table.
  String get icon => throw _privateConstructorUsedError;

  /// ISO 8601 UTC timestamp the badge was awarded.
  @JsonKey(name: 'earned_at')
  String get earnedAt => throw _privateConstructorUsedError;

  /// Serializes this EarnedBadge to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EarnedBadge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EarnedBadgeCopyWith<EarnedBadge> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EarnedBadgeCopyWith<$Res> {
  factory $EarnedBadgeCopyWith(
          EarnedBadge value, $Res Function(EarnedBadge) then) =
      _$EarnedBadgeCopyWithImpl<$Res, EarnedBadge>;
  @useResult
  $Res call(
      {@JsonKey(name: 'badge_id') String badgeId,
      String name,
      String description,
      String icon,
      @JsonKey(name: 'earned_at') String earnedAt});
}

/// @nodoc
class _$EarnedBadgeCopyWithImpl<$Res, $Val extends EarnedBadge>
    implements $EarnedBadgeCopyWith<$Res> {
  _$EarnedBadgeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EarnedBadge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? badgeId = null,
    Object? name = null,
    Object? description = null,
    Object? icon = null,
    Object? earnedAt = null,
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
      earnedAt: null == earnedAt
          ? _value.earnedAt
          : earnedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EarnedBadgeImplCopyWith<$Res>
    implements $EarnedBadgeCopyWith<$Res> {
  factory _$$EarnedBadgeImplCopyWith(
          _$EarnedBadgeImpl value, $Res Function(_$EarnedBadgeImpl) then) =
      __$$EarnedBadgeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'badge_id') String badgeId,
      String name,
      String description,
      String icon,
      @JsonKey(name: 'earned_at') String earnedAt});
}

/// @nodoc
class __$$EarnedBadgeImplCopyWithImpl<$Res>
    extends _$EarnedBadgeCopyWithImpl<$Res, _$EarnedBadgeImpl>
    implements _$$EarnedBadgeImplCopyWith<$Res> {
  __$$EarnedBadgeImplCopyWithImpl(
      _$EarnedBadgeImpl _value, $Res Function(_$EarnedBadgeImpl) _then)
      : super(_value, _then);

  /// Create a copy of EarnedBadge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? badgeId = null,
    Object? name = null,
    Object? description = null,
    Object? icon = null,
    Object? earnedAt = null,
  }) {
    return _then(_$EarnedBadgeImpl(
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
      earnedAt: null == earnedAt
          ? _value.earnedAt
          : earnedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EarnedBadgeImpl implements _EarnedBadge {
  const _$EarnedBadgeImpl(
      {@JsonKey(name: 'badge_id') required this.badgeId,
      required this.name,
      required this.description,
      required this.icon,
      @JsonKey(name: 'earned_at') required this.earnedAt});

  factory _$EarnedBadgeImpl.fromJson(Map<String, dynamic> json) =>
      _$$EarnedBadgeImplFromJson(json);

  @override
  @JsonKey(name: 'badge_id')
  final String badgeId;
  @override
  final String name;
  @override
  final String description;

  /// Material Icons name string (e.g. `"local_fire_department_rounded"`)
  /// — the UI maps it through [iconForName] in `presentation/widgets/
  /// badge_icon.dart` so we don't ship a giant codepoint table.
  @override
  final String icon;

  /// ISO 8601 UTC timestamp the badge was awarded.
  @override
  @JsonKey(name: 'earned_at')
  final String earnedAt;

  @override
  String toString() {
    return 'EarnedBadge(badgeId: $badgeId, name: $name, description: $description, icon: $icon, earnedAt: $earnedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EarnedBadgeImpl &&
            (identical(other.badgeId, badgeId) || other.badgeId == badgeId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.earnedAt, earnedAt) ||
                other.earnedAt == earnedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, badgeId, name, description, icon, earnedAt);

  /// Create a copy of EarnedBadge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EarnedBadgeImplCopyWith<_$EarnedBadgeImpl> get copyWith =>
      __$$EarnedBadgeImplCopyWithImpl<_$EarnedBadgeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EarnedBadgeImplToJson(
      this,
    );
  }
}

abstract class _EarnedBadge implements EarnedBadge {
  const factory _EarnedBadge(
          {@JsonKey(name: 'badge_id') required final String badgeId,
          required final String name,
          required final String description,
          required final String icon,
          @JsonKey(name: 'earned_at') required final String earnedAt}) =
      _$EarnedBadgeImpl;

  factory _EarnedBadge.fromJson(Map<String, dynamic> json) =
      _$EarnedBadgeImpl.fromJson;

  @override
  @JsonKey(name: 'badge_id')
  String get badgeId;
  @override
  String get name;
  @override
  String get description;

  /// Material Icons name string (e.g. `"local_fire_department_rounded"`)
  /// — the UI maps it through [iconForName] in `presentation/widgets/
  /// badge_icon.dart` so we don't ship a giant codepoint table.
  @override
  String get icon;

  /// ISO 8601 UTC timestamp the badge was awarded.
  @override
  @JsonKey(name: 'earned_at')
  String get earnedAt;

  /// Create a copy of EarnedBadge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EarnedBadgeImplCopyWith<_$EarnedBadgeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AvailableBadge _$AvailableBadgeFromJson(Map<String, dynamic> json) {
  return _AvailableBadge.fromJson(json);
}

/// @nodoc
mixin _$AvailableBadge {
  @JsonKey(name: 'badge_id')
  String get badgeId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;

  /// Serializes this AvailableBadge to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AvailableBadge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AvailableBadgeCopyWith<AvailableBadge> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AvailableBadgeCopyWith<$Res> {
  factory $AvailableBadgeCopyWith(
          AvailableBadge value, $Res Function(AvailableBadge) then) =
      _$AvailableBadgeCopyWithImpl<$Res, AvailableBadge>;
  @useResult
  $Res call(
      {@JsonKey(name: 'badge_id') String badgeId,
      String name,
      String description,
      String icon});
}

/// @nodoc
class _$AvailableBadgeCopyWithImpl<$Res, $Val extends AvailableBadge>
    implements $AvailableBadgeCopyWith<$Res> {
  _$AvailableBadgeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AvailableBadge
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
abstract class _$$AvailableBadgeImplCopyWith<$Res>
    implements $AvailableBadgeCopyWith<$Res> {
  factory _$$AvailableBadgeImplCopyWith(_$AvailableBadgeImpl value,
          $Res Function(_$AvailableBadgeImpl) then) =
      __$$AvailableBadgeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'badge_id') String badgeId,
      String name,
      String description,
      String icon});
}

/// @nodoc
class __$$AvailableBadgeImplCopyWithImpl<$Res>
    extends _$AvailableBadgeCopyWithImpl<$Res, _$AvailableBadgeImpl>
    implements _$$AvailableBadgeImplCopyWith<$Res> {
  __$$AvailableBadgeImplCopyWithImpl(
      _$AvailableBadgeImpl _value, $Res Function(_$AvailableBadgeImpl) _then)
      : super(_value, _then);

  /// Create a copy of AvailableBadge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? badgeId = null,
    Object? name = null,
    Object? description = null,
    Object? icon = null,
  }) {
    return _then(_$AvailableBadgeImpl(
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
class _$AvailableBadgeImpl implements _AvailableBadge {
  const _$AvailableBadgeImpl(
      {@JsonKey(name: 'badge_id') required this.badgeId,
      required this.name,
      required this.description,
      required this.icon});

  factory _$AvailableBadgeImpl.fromJson(Map<String, dynamic> json) =>
      _$$AvailableBadgeImplFromJson(json);

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
    return 'AvailableBadge(badgeId: $badgeId, name: $name, description: $description, icon: $icon)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AvailableBadgeImpl &&
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

  /// Create a copy of AvailableBadge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AvailableBadgeImplCopyWith<_$AvailableBadgeImpl> get copyWith =>
      __$$AvailableBadgeImplCopyWithImpl<_$AvailableBadgeImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AvailableBadgeImplToJson(
      this,
    );
  }
}

abstract class _AvailableBadge implements AvailableBadge {
  const factory _AvailableBadge(
      {@JsonKey(name: 'badge_id') required final String badgeId,
      required final String name,
      required final String description,
      required final String icon}) = _$AvailableBadgeImpl;

  factory _AvailableBadge.fromJson(Map<String, dynamic> json) =
      _$AvailableBadgeImpl.fromJson;

  @override
  @JsonKey(name: 'badge_id')
  String get badgeId;
  @override
  String get name;
  @override
  String get description;
  @override
  String get icon;

  /// Create a copy of AvailableBadge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AvailableBadgeImplCopyWith<_$AvailableBadgeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BadgeUnlock _$BadgeUnlockFromJson(Map<String, dynamic> json) {
  return _BadgeUnlock.fromJson(json);
}

/// @nodoc
mixin _$BadgeUnlock {
  @JsonKey(name: 'badge_id')
  String get badgeId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;

  /// Serializes this BadgeUnlock to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BadgeUnlockCopyWith<BadgeUnlock> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BadgeUnlockCopyWith<$Res> {
  factory $BadgeUnlockCopyWith(
          BadgeUnlock value, $Res Function(BadgeUnlock) then) =
      _$BadgeUnlockCopyWithImpl<$Res, BadgeUnlock>;
  @useResult
  $Res call(
      {@JsonKey(name: 'badge_id') String badgeId,
      String name,
      String description,
      String icon});
}

/// @nodoc
class _$BadgeUnlockCopyWithImpl<$Res, $Val extends BadgeUnlock>
    implements $BadgeUnlockCopyWith<$Res> {
  _$BadgeUnlockCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BadgeUnlock
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
abstract class _$$BadgeUnlockImplCopyWith<$Res>
    implements $BadgeUnlockCopyWith<$Res> {
  factory _$$BadgeUnlockImplCopyWith(
          _$BadgeUnlockImpl value, $Res Function(_$BadgeUnlockImpl) then) =
      __$$BadgeUnlockImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'badge_id') String badgeId,
      String name,
      String description,
      String icon});
}

/// @nodoc
class __$$BadgeUnlockImplCopyWithImpl<$Res>
    extends _$BadgeUnlockCopyWithImpl<$Res, _$BadgeUnlockImpl>
    implements _$$BadgeUnlockImplCopyWith<$Res> {
  __$$BadgeUnlockImplCopyWithImpl(
      _$BadgeUnlockImpl _value, $Res Function(_$BadgeUnlockImpl) _then)
      : super(_value, _then);

  /// Create a copy of BadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? badgeId = null,
    Object? name = null,
    Object? description = null,
    Object? icon = null,
  }) {
    return _then(_$BadgeUnlockImpl(
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
class _$BadgeUnlockImpl implements _BadgeUnlock {
  const _$BadgeUnlockImpl(
      {@JsonKey(name: 'badge_id') required this.badgeId,
      required this.name,
      required this.description,
      required this.icon});

  factory _$BadgeUnlockImpl.fromJson(Map<String, dynamic> json) =>
      _$$BadgeUnlockImplFromJson(json);

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
    return 'BadgeUnlock(badgeId: $badgeId, name: $name, description: $description, icon: $icon)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BadgeUnlockImpl &&
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

  /// Create a copy of BadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BadgeUnlockImplCopyWith<_$BadgeUnlockImpl> get copyWith =>
      __$$BadgeUnlockImplCopyWithImpl<_$BadgeUnlockImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BadgeUnlockImplToJson(
      this,
    );
  }
}

abstract class _BadgeUnlock implements BadgeUnlock {
  const factory _BadgeUnlock(
      {@JsonKey(name: 'badge_id') required final String badgeId,
      required final String name,
      required final String description,
      required final String icon}) = _$BadgeUnlockImpl;

  factory _BadgeUnlock.fromJson(Map<String, dynamic> json) =
      _$BadgeUnlockImpl.fromJson;

  @override
  @JsonKey(name: 'badge_id')
  String get badgeId;
  @override
  String get name;
  @override
  String get description;
  @override
  String get icon;

  /// Create a copy of BadgeUnlock
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BadgeUnlockImplCopyWith<_$BadgeUnlockImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BadgesSummary _$BadgesSummaryFromJson(Map<String, dynamic> json) {
  return _BadgesSummary.fromJson(json);
}

/// @nodoc
mixin _$BadgesSummary {
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  List<EarnedBadge> get earned => throw _privateConstructorUsedError;
  List<AvailableBadge> get available => throw _privateConstructorUsedError;
  @JsonKey(name: 'earned_count')
  int get earnedCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_count')
  int get totalCount => throw _privateConstructorUsedError;

  /// Serializes this BadgesSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BadgesSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BadgesSummaryCopyWith<BadgesSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BadgesSummaryCopyWith<$Res> {
  factory $BadgesSummaryCopyWith(
          BadgesSummary value, $Res Function(BadgesSummary) then) =
      _$BadgesSummaryCopyWithImpl<$Res, BadgesSummary>;
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      List<EarnedBadge> earned,
      List<AvailableBadge> available,
      @JsonKey(name: 'earned_count') int earnedCount,
      @JsonKey(name: 'total_count') int totalCount});
}

/// @nodoc
class _$BadgesSummaryCopyWithImpl<$Res, $Val extends BadgesSummary>
    implements $BadgesSummaryCopyWith<$Res> {
  _$BadgesSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BadgesSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? earned = null,
    Object? available = null,
    Object? earnedCount = null,
    Object? totalCount = null,
  }) {
    return _then(_value.copyWith(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      earned: null == earned
          ? _value.earned
          : earned // ignore: cast_nullable_to_non_nullable
              as List<EarnedBadge>,
      available: null == available
          ? _value.available
          : available // ignore: cast_nullable_to_non_nullable
              as List<AvailableBadge>,
      earnedCount: null == earnedCount
          ? _value.earnedCount
          : earnedCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BadgesSummaryImplCopyWith<$Res>
    implements $BadgesSummaryCopyWith<$Res> {
  factory _$$BadgesSummaryImplCopyWith(
          _$BadgesSummaryImpl value, $Res Function(_$BadgesSummaryImpl) then) =
      __$$BadgesSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      List<EarnedBadge> earned,
      List<AvailableBadge> available,
      @JsonKey(name: 'earned_count') int earnedCount,
      @JsonKey(name: 'total_count') int totalCount});
}

/// @nodoc
class __$$BadgesSummaryImplCopyWithImpl<$Res>
    extends _$BadgesSummaryCopyWithImpl<$Res, _$BadgesSummaryImpl>
    implements _$$BadgesSummaryImplCopyWith<$Res> {
  __$$BadgesSummaryImplCopyWithImpl(
      _$BadgesSummaryImpl _value, $Res Function(_$BadgesSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of BadgesSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? earned = null,
    Object? available = null,
    Object? earnedCount = null,
    Object? totalCount = null,
  }) {
    return _then(_$BadgesSummaryImpl(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      earned: null == earned
          ? _value._earned
          : earned // ignore: cast_nullable_to_non_nullable
              as List<EarnedBadge>,
      available: null == available
          ? _value._available
          : available // ignore: cast_nullable_to_non_nullable
              as List<AvailableBadge>,
      earnedCount: null == earnedCount
          ? _value.earnedCount
          : earnedCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BadgesSummaryImpl extends _BadgesSummary {
  const _$BadgesSummaryImpl(
      {@JsonKey(name: 'student_id') required this.studentId,
      final List<EarnedBadge> earned = const <EarnedBadge>[],
      final List<AvailableBadge> available = const <AvailableBadge>[],
      @JsonKey(name: 'earned_count') this.earnedCount = 0,
      @JsonKey(name: 'total_count') this.totalCount = 0})
      : _earned = earned,
        _available = available,
        super._();

  factory _$BadgesSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$BadgesSummaryImplFromJson(json);

  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  final List<EarnedBadge> _earned;
  @override
  @JsonKey()
  List<EarnedBadge> get earned {
    if (_earned is EqualUnmodifiableListView) return _earned;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_earned);
  }

  final List<AvailableBadge> _available;
  @override
  @JsonKey()
  List<AvailableBadge> get available {
    if (_available is EqualUnmodifiableListView) return _available;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_available);
  }

  @override
  @JsonKey(name: 'earned_count')
  final int earnedCount;
  @override
  @JsonKey(name: 'total_count')
  final int totalCount;

  @override
  String toString() {
    return 'BadgesSummary(studentId: $studentId, earned: $earned, available: $available, earnedCount: $earnedCount, totalCount: $totalCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BadgesSummaryImpl &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            const DeepCollectionEquality().equals(other._earned, _earned) &&
            const DeepCollectionEquality()
                .equals(other._available, _available) &&
            (identical(other.earnedCount, earnedCount) ||
                other.earnedCount == earnedCount) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      studentId,
      const DeepCollectionEquality().hash(_earned),
      const DeepCollectionEquality().hash(_available),
      earnedCount,
      totalCount);

  /// Create a copy of BadgesSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BadgesSummaryImplCopyWith<_$BadgesSummaryImpl> get copyWith =>
      __$$BadgesSummaryImplCopyWithImpl<_$BadgesSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BadgesSummaryImplToJson(
      this,
    );
  }
}

abstract class _BadgesSummary extends BadgesSummary {
  const factory _BadgesSummary(
          {@JsonKey(name: 'student_id') required final String studentId,
          final List<EarnedBadge> earned,
          final List<AvailableBadge> available,
          @JsonKey(name: 'earned_count') final int earnedCount,
          @JsonKey(name: 'total_count') final int totalCount}) =
      _$BadgesSummaryImpl;
  const _BadgesSummary._() : super._();

  factory _BadgesSummary.fromJson(Map<String, dynamic> json) =
      _$BadgesSummaryImpl.fromJson;

  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  List<EarnedBadge> get earned;
  @override
  List<AvailableBadge> get available;
  @override
  @JsonKey(name: 'earned_count')
  int get earnedCount;
  @override
  @JsonKey(name: 'total_count')
  int get totalCount;

  /// Create a copy of BadgesSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BadgesSummaryImplCopyWith<_$BadgesSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StreakSummary _$StreakSummaryFromJson(Map<String, dynamic> json) {
  return _StreakSummary.fromJson(json);
}

/// @nodoc
mixin _$StreakSummary {
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'streak_days')
  int get streakDays => throw _privateConstructorUsedError;
  @JsonKey(name: 'longest_streak_days')
  int get longestStreakDays => throw _privateConstructorUsedError;

  /// ISO date (YYYY-MM-DD) of the last day the student studied, or
  /// `null` if they've never studied.
  @JsonKey(name: 'last_active_date')
  String? get lastActiveDate => throw _privateConstructorUsedError;

  /// Convenience boolean — true iff the student already has activity
  /// today. Powers the "you've studied today!" flame styling.
  @JsonKey(name: 'active_today')
  bool get activeToday => throw _privateConstructorUsedError;

  /// Serializes this StreakSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StreakSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StreakSummaryCopyWith<StreakSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StreakSummaryCopyWith<$Res> {
  factory $StreakSummaryCopyWith(
          StreakSummary value, $Res Function(StreakSummary) then) =
      _$StreakSummaryCopyWithImpl<$Res, StreakSummary>;
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'streak_days') int streakDays,
      @JsonKey(name: 'longest_streak_days') int longestStreakDays,
      @JsonKey(name: 'last_active_date') String? lastActiveDate,
      @JsonKey(name: 'active_today') bool activeToday});
}

/// @nodoc
class _$StreakSummaryCopyWithImpl<$Res, $Val extends StreakSummary>
    implements $StreakSummaryCopyWith<$Res> {
  _$StreakSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StreakSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? streakDays = null,
    Object? longestStreakDays = null,
    Object? lastActiveDate = freezed,
    Object? activeToday = null,
  }) {
    return _then(_value.copyWith(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      streakDays: null == streakDays
          ? _value.streakDays
          : streakDays // ignore: cast_nullable_to_non_nullable
              as int,
      longestStreakDays: null == longestStreakDays
          ? _value.longestStreakDays
          : longestStreakDays // ignore: cast_nullable_to_non_nullable
              as int,
      lastActiveDate: freezed == lastActiveDate
          ? _value.lastActiveDate
          : lastActiveDate // ignore: cast_nullable_to_non_nullable
              as String?,
      activeToday: null == activeToday
          ? _value.activeToday
          : activeToday // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StreakSummaryImplCopyWith<$Res>
    implements $StreakSummaryCopyWith<$Res> {
  factory _$$StreakSummaryImplCopyWith(
          _$StreakSummaryImpl value, $Res Function(_$StreakSummaryImpl) then) =
      __$$StreakSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'streak_days') int streakDays,
      @JsonKey(name: 'longest_streak_days') int longestStreakDays,
      @JsonKey(name: 'last_active_date') String? lastActiveDate,
      @JsonKey(name: 'active_today') bool activeToday});
}

/// @nodoc
class __$$StreakSummaryImplCopyWithImpl<$Res>
    extends _$StreakSummaryCopyWithImpl<$Res, _$StreakSummaryImpl>
    implements _$$StreakSummaryImplCopyWith<$Res> {
  __$$StreakSummaryImplCopyWithImpl(
      _$StreakSummaryImpl _value, $Res Function(_$StreakSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of StreakSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? streakDays = null,
    Object? longestStreakDays = null,
    Object? lastActiveDate = freezed,
    Object? activeToday = null,
  }) {
    return _then(_$StreakSummaryImpl(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      streakDays: null == streakDays
          ? _value.streakDays
          : streakDays // ignore: cast_nullable_to_non_nullable
              as int,
      longestStreakDays: null == longestStreakDays
          ? _value.longestStreakDays
          : longestStreakDays // ignore: cast_nullable_to_non_nullable
              as int,
      lastActiveDate: freezed == lastActiveDate
          ? _value.lastActiveDate
          : lastActiveDate // ignore: cast_nullable_to_non_nullable
              as String?,
      activeToday: null == activeToday
          ? _value.activeToday
          : activeToday // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StreakSummaryImpl extends _StreakSummary {
  const _$StreakSummaryImpl(
      {@JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'streak_days') this.streakDays = 0,
      @JsonKey(name: 'longest_streak_days') this.longestStreakDays = 0,
      @JsonKey(name: 'last_active_date') this.lastActiveDate,
      @JsonKey(name: 'active_today') this.activeToday = false})
      : super._();

  factory _$StreakSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$StreakSummaryImplFromJson(json);

  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'streak_days')
  final int streakDays;
  @override
  @JsonKey(name: 'longest_streak_days')
  final int longestStreakDays;

  /// ISO date (YYYY-MM-DD) of the last day the student studied, or
  /// `null` if they've never studied.
  @override
  @JsonKey(name: 'last_active_date')
  final String? lastActiveDate;

  /// Convenience boolean — true iff the student already has activity
  /// today. Powers the "you've studied today!" flame styling.
  @override
  @JsonKey(name: 'active_today')
  final bool activeToday;

  @override
  String toString() {
    return 'StreakSummary(studentId: $studentId, streakDays: $streakDays, longestStreakDays: $longestStreakDays, lastActiveDate: $lastActiveDate, activeToday: $activeToday)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StreakSummaryImpl &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.streakDays, streakDays) ||
                other.streakDays == streakDays) &&
            (identical(other.longestStreakDays, longestStreakDays) ||
                other.longestStreakDays == longestStreakDays) &&
            (identical(other.lastActiveDate, lastActiveDate) ||
                other.lastActiveDate == lastActiveDate) &&
            (identical(other.activeToday, activeToday) ||
                other.activeToday == activeToday));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, studentId, streakDays,
      longestStreakDays, lastActiveDate, activeToday);

  /// Create a copy of StreakSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StreakSummaryImplCopyWith<_$StreakSummaryImpl> get copyWith =>
      __$$StreakSummaryImplCopyWithImpl<_$StreakSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StreakSummaryImplToJson(
      this,
    );
  }
}

abstract class _StreakSummary extends StreakSummary {
  const factory _StreakSummary(
          {@JsonKey(name: 'student_id') required final String studentId,
          @JsonKey(name: 'streak_days') final int streakDays,
          @JsonKey(name: 'longest_streak_days') final int longestStreakDays,
          @JsonKey(name: 'last_active_date') final String? lastActiveDate,
          @JsonKey(name: 'active_today') final bool activeToday}) =
      _$StreakSummaryImpl;
  const _StreakSummary._() : super._();

  factory _StreakSummary.fromJson(Map<String, dynamic> json) =
      _$StreakSummaryImpl.fromJson;

  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'streak_days')
  int get streakDays;
  @override
  @JsonKey(name: 'longest_streak_days')
  int get longestStreakDays;

  /// ISO date (YYYY-MM-DD) of the last day the student studied, or
  /// `null` if they've never studied.
  @override
  @JsonKey(name: 'last_active_date')
  String? get lastActiveDate;

  /// Convenience boolean — true iff the student already has activity
  /// today. Powers the "you've studied today!" flame styling.
  @override
  @JsonKey(name: 'active_today')
  bool get activeToday;

  /// Create a copy of StreakSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StreakSummaryImplCopyWith<_$StreakSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GamificationProfile _$GamificationProfileFromJson(Map<String, dynamic> json) {
  return _GamificationProfile.fromJson(json);
}

/// @nodoc
mixin _$GamificationProfile {
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'workspace_id')
  String get workspaceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_total')
  int get xpTotal => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_this_week')
  int get xpThisWeek => throw _privateConstructorUsedError;

  /// Per-topic XP — key is topic display name.
  @JsonKey(name: 'xp_by_topic')
  Map<String, int> get xpByTopic => throw _privateConstructorUsedError;
  int get level => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_into_level')
  int get xpIntoLevel => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_for_next_level')
  int get xpForNextLevel => throw _privateConstructorUsedError;
  @JsonKey(name: 'streak_days')
  int get streakDays => throw _privateConstructorUsedError;
  @JsonKey(name: 'longest_streak_days')
  int get longestStreakDays => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_active_date')
  String? get lastActiveDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'questions_answered')
  int get questionsAnswered => throw _privateConstructorUsedError;
  @JsonKey(name: 'questions_correct')
  int get questionsCorrect => throw _privateConstructorUsedError;
  @JsonKey(name: 'flashcards_reviewed')
  int get flashcardsReviewed => throw _privateConstructorUsedError;
  @JsonKey(name: 'study_sessions_completed')
  int get studySessionsCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'revision_sessions_completed')
  int get revisionSessionsCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'flashcard_sessions_completed')
  int get flashcardSessionsCompleted => throw _privateConstructorUsedError;
  List<EarnedBadge> get badges => throw _privateConstructorUsedError;

  /// Last 30 days of activity counts — `{"2026-05-23": 12, ...}`.
  @JsonKey(name: 'daily_activity')
  Map<String, int> get dailyActivity => throw _privateConstructorUsedError;

  /// Last 30 days of net XP by UTC calendar date.
  @JsonKey(name: 'daily_xp')
  Map<String, int> get dailyXp => throw _privateConstructorUsedError;

  /// Serializes this GamificationProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GamificationProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GamificationProfileCopyWith<GamificationProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GamificationProfileCopyWith<$Res> {
  factory $GamificationProfileCopyWith(
          GamificationProfile value, $Res Function(GamificationProfile) then) =
      _$GamificationProfileCopyWithImpl<$Res, GamificationProfile>;
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'workspace_id') String workspaceId,
      @JsonKey(name: 'xp_total') int xpTotal,
      @JsonKey(name: 'xp_this_week') int xpThisWeek,
      @JsonKey(name: 'xp_by_topic') Map<String, int> xpByTopic,
      int level,
      @JsonKey(name: 'xp_into_level') int xpIntoLevel,
      @JsonKey(name: 'xp_for_next_level') int xpForNextLevel,
      @JsonKey(name: 'streak_days') int streakDays,
      @JsonKey(name: 'longest_streak_days') int longestStreakDays,
      @JsonKey(name: 'last_active_date') String? lastActiveDate,
      @JsonKey(name: 'questions_answered') int questionsAnswered,
      @JsonKey(name: 'questions_correct') int questionsCorrect,
      @JsonKey(name: 'flashcards_reviewed') int flashcardsReviewed,
      @JsonKey(name: 'study_sessions_completed') int studySessionsCompleted,
      @JsonKey(name: 'revision_sessions_completed')
      int revisionSessionsCompleted,
      @JsonKey(name: 'flashcard_sessions_completed')
      int flashcardSessionsCompleted,
      List<EarnedBadge> badges,
      @JsonKey(name: 'daily_activity') Map<String, int> dailyActivity,
      @JsonKey(name: 'daily_xp') Map<String, int> dailyXp});
}

/// @nodoc
class _$GamificationProfileCopyWithImpl<$Res, $Val extends GamificationProfile>
    implements $GamificationProfileCopyWith<$Res> {
  _$GamificationProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GamificationProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? workspaceId = null,
    Object? xpTotal = null,
    Object? xpThisWeek = null,
    Object? xpByTopic = null,
    Object? level = null,
    Object? xpIntoLevel = null,
    Object? xpForNextLevel = null,
    Object? streakDays = null,
    Object? longestStreakDays = null,
    Object? lastActiveDate = freezed,
    Object? questionsAnswered = null,
    Object? questionsCorrect = null,
    Object? flashcardsReviewed = null,
    Object? studySessionsCompleted = null,
    Object? revisionSessionsCompleted = null,
    Object? flashcardSessionsCompleted = null,
    Object? badges = null,
    Object? dailyActivity = null,
    Object? dailyXp = null,
  }) {
    return _then(_value.copyWith(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      xpTotal: null == xpTotal
          ? _value.xpTotal
          : xpTotal // ignore: cast_nullable_to_non_nullable
              as int,
      xpThisWeek: null == xpThisWeek
          ? _value.xpThisWeek
          : xpThisWeek // ignore: cast_nullable_to_non_nullable
              as int,
      xpByTopic: null == xpByTopic
          ? _value.xpByTopic
          : xpByTopic // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      xpIntoLevel: null == xpIntoLevel
          ? _value.xpIntoLevel
          : xpIntoLevel // ignore: cast_nullable_to_non_nullable
              as int,
      xpForNextLevel: null == xpForNextLevel
          ? _value.xpForNextLevel
          : xpForNextLevel // ignore: cast_nullable_to_non_nullable
              as int,
      streakDays: null == streakDays
          ? _value.streakDays
          : streakDays // ignore: cast_nullable_to_non_nullable
              as int,
      longestStreakDays: null == longestStreakDays
          ? _value.longestStreakDays
          : longestStreakDays // ignore: cast_nullable_to_non_nullable
              as int,
      lastActiveDate: freezed == lastActiveDate
          ? _value.lastActiveDate
          : lastActiveDate // ignore: cast_nullable_to_non_nullable
              as String?,
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
      studySessionsCompleted: null == studySessionsCompleted
          ? _value.studySessionsCompleted
          : studySessionsCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      revisionSessionsCompleted: null == revisionSessionsCompleted
          ? _value.revisionSessionsCompleted
          : revisionSessionsCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      flashcardSessionsCompleted: null == flashcardSessionsCompleted
          ? _value.flashcardSessionsCompleted
          : flashcardSessionsCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      badges: null == badges
          ? _value.badges
          : badges // ignore: cast_nullable_to_non_nullable
              as List<EarnedBadge>,
      dailyActivity: null == dailyActivity
          ? _value.dailyActivity
          : dailyActivity // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      dailyXp: null == dailyXp
          ? _value.dailyXp
          : dailyXp // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GamificationProfileImplCopyWith<$Res>
    implements $GamificationProfileCopyWith<$Res> {
  factory _$$GamificationProfileImplCopyWith(_$GamificationProfileImpl value,
          $Res Function(_$GamificationProfileImpl) then) =
      __$$GamificationProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'workspace_id') String workspaceId,
      @JsonKey(name: 'xp_total') int xpTotal,
      @JsonKey(name: 'xp_this_week') int xpThisWeek,
      @JsonKey(name: 'xp_by_topic') Map<String, int> xpByTopic,
      int level,
      @JsonKey(name: 'xp_into_level') int xpIntoLevel,
      @JsonKey(name: 'xp_for_next_level') int xpForNextLevel,
      @JsonKey(name: 'streak_days') int streakDays,
      @JsonKey(name: 'longest_streak_days') int longestStreakDays,
      @JsonKey(name: 'last_active_date') String? lastActiveDate,
      @JsonKey(name: 'questions_answered') int questionsAnswered,
      @JsonKey(name: 'questions_correct') int questionsCorrect,
      @JsonKey(name: 'flashcards_reviewed') int flashcardsReviewed,
      @JsonKey(name: 'study_sessions_completed') int studySessionsCompleted,
      @JsonKey(name: 'revision_sessions_completed')
      int revisionSessionsCompleted,
      @JsonKey(name: 'flashcard_sessions_completed')
      int flashcardSessionsCompleted,
      List<EarnedBadge> badges,
      @JsonKey(name: 'daily_activity') Map<String, int> dailyActivity,
      @JsonKey(name: 'daily_xp') Map<String, int> dailyXp});
}

/// @nodoc
class __$$GamificationProfileImplCopyWithImpl<$Res>
    extends _$GamificationProfileCopyWithImpl<$Res, _$GamificationProfileImpl>
    implements _$$GamificationProfileImplCopyWith<$Res> {
  __$$GamificationProfileImplCopyWithImpl(_$GamificationProfileImpl _value,
      $Res Function(_$GamificationProfileImpl) _then)
      : super(_value, _then);

  /// Create a copy of GamificationProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? workspaceId = null,
    Object? xpTotal = null,
    Object? xpThisWeek = null,
    Object? xpByTopic = null,
    Object? level = null,
    Object? xpIntoLevel = null,
    Object? xpForNextLevel = null,
    Object? streakDays = null,
    Object? longestStreakDays = null,
    Object? lastActiveDate = freezed,
    Object? questionsAnswered = null,
    Object? questionsCorrect = null,
    Object? flashcardsReviewed = null,
    Object? studySessionsCompleted = null,
    Object? revisionSessionsCompleted = null,
    Object? flashcardSessionsCompleted = null,
    Object? badges = null,
    Object? dailyActivity = null,
    Object? dailyXp = null,
  }) {
    return _then(_$GamificationProfileImpl(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      xpTotal: null == xpTotal
          ? _value.xpTotal
          : xpTotal // ignore: cast_nullable_to_non_nullable
              as int,
      xpThisWeek: null == xpThisWeek
          ? _value.xpThisWeek
          : xpThisWeek // ignore: cast_nullable_to_non_nullable
              as int,
      xpByTopic: null == xpByTopic
          ? _value._xpByTopic
          : xpByTopic // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      xpIntoLevel: null == xpIntoLevel
          ? _value.xpIntoLevel
          : xpIntoLevel // ignore: cast_nullable_to_non_nullable
              as int,
      xpForNextLevel: null == xpForNextLevel
          ? _value.xpForNextLevel
          : xpForNextLevel // ignore: cast_nullable_to_non_nullable
              as int,
      streakDays: null == streakDays
          ? _value.streakDays
          : streakDays // ignore: cast_nullable_to_non_nullable
              as int,
      longestStreakDays: null == longestStreakDays
          ? _value.longestStreakDays
          : longestStreakDays // ignore: cast_nullable_to_non_nullable
              as int,
      lastActiveDate: freezed == lastActiveDate
          ? _value.lastActiveDate
          : lastActiveDate // ignore: cast_nullable_to_non_nullable
              as String?,
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
      studySessionsCompleted: null == studySessionsCompleted
          ? _value.studySessionsCompleted
          : studySessionsCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      revisionSessionsCompleted: null == revisionSessionsCompleted
          ? _value.revisionSessionsCompleted
          : revisionSessionsCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      flashcardSessionsCompleted: null == flashcardSessionsCompleted
          ? _value.flashcardSessionsCompleted
          : flashcardSessionsCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      badges: null == badges
          ? _value._badges
          : badges // ignore: cast_nullable_to_non_nullable
              as List<EarnedBadge>,
      dailyActivity: null == dailyActivity
          ? _value._dailyActivity
          : dailyActivity // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      dailyXp: null == dailyXp
          ? _value._dailyXp
          : dailyXp // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GamificationProfileImpl extends _GamificationProfile {
  const _$GamificationProfileImpl(
      {@JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'workspace_id') required this.workspaceId,
      @JsonKey(name: 'xp_total') this.xpTotal = 0,
      @JsonKey(name: 'xp_this_week') this.xpThisWeek = 0,
      @JsonKey(name: 'xp_by_topic')
      final Map<String, int> xpByTopic = const <String, int>{},
      this.level = 1,
      @JsonKey(name: 'xp_into_level') this.xpIntoLevel = 0,
      @JsonKey(name: 'xp_for_next_level') this.xpForNextLevel = 100,
      @JsonKey(name: 'streak_days') this.streakDays = 0,
      @JsonKey(name: 'longest_streak_days') this.longestStreakDays = 0,
      @JsonKey(name: 'last_active_date') this.lastActiveDate,
      @JsonKey(name: 'questions_answered') this.questionsAnswered = 0,
      @JsonKey(name: 'questions_correct') this.questionsCorrect = 0,
      @JsonKey(name: 'flashcards_reviewed') this.flashcardsReviewed = 0,
      @JsonKey(name: 'study_sessions_completed')
      this.studySessionsCompleted = 0,
      @JsonKey(name: 'revision_sessions_completed')
      this.revisionSessionsCompleted = 0,
      @JsonKey(name: 'flashcard_sessions_completed')
      this.flashcardSessionsCompleted = 0,
      final List<EarnedBadge> badges = const <EarnedBadge>[],
      @JsonKey(name: 'daily_activity')
      final Map<String, int> dailyActivity = const <String, int>{},
      @JsonKey(name: 'daily_xp')
      final Map<String, int> dailyXp = const <String, int>{}})
      : _xpByTopic = xpByTopic,
        _badges = badges,
        _dailyActivity = dailyActivity,
        _dailyXp = dailyXp,
        super._();

  factory _$GamificationProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$GamificationProfileImplFromJson(json);

  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'workspace_id')
  final String workspaceId;
  @override
  @JsonKey(name: 'xp_total')
  final int xpTotal;
  @override
  @JsonKey(name: 'xp_this_week')
  final int xpThisWeek;

  /// Per-topic XP — key is topic display name.
  final Map<String, int> _xpByTopic;

  /// Per-topic XP — key is topic display name.
  @override
  @JsonKey(name: 'xp_by_topic')
  Map<String, int> get xpByTopic {
    if (_xpByTopic is EqualUnmodifiableMapView) return _xpByTopic;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_xpByTopic);
  }

  @override
  @JsonKey()
  final int level;
  @override
  @JsonKey(name: 'xp_into_level')
  final int xpIntoLevel;
  @override
  @JsonKey(name: 'xp_for_next_level')
  final int xpForNextLevel;
  @override
  @JsonKey(name: 'streak_days')
  final int streakDays;
  @override
  @JsonKey(name: 'longest_streak_days')
  final int longestStreakDays;
  @override
  @JsonKey(name: 'last_active_date')
  final String? lastActiveDate;
  @override
  @JsonKey(name: 'questions_answered')
  final int questionsAnswered;
  @override
  @JsonKey(name: 'questions_correct')
  final int questionsCorrect;
  @override
  @JsonKey(name: 'flashcards_reviewed')
  final int flashcardsReviewed;
  @override
  @JsonKey(name: 'study_sessions_completed')
  final int studySessionsCompleted;
  @override
  @JsonKey(name: 'revision_sessions_completed')
  final int revisionSessionsCompleted;
  @override
  @JsonKey(name: 'flashcard_sessions_completed')
  final int flashcardSessionsCompleted;
  final List<EarnedBadge> _badges;
  @override
  @JsonKey()
  List<EarnedBadge> get badges {
    if (_badges is EqualUnmodifiableListView) return _badges;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_badges);
  }

  /// Last 30 days of activity counts — `{"2026-05-23": 12, ...}`.
  final Map<String, int> _dailyActivity;

  /// Last 30 days of activity counts — `{"2026-05-23": 12, ...}`.
  @override
  @JsonKey(name: 'daily_activity')
  Map<String, int> get dailyActivity {
    if (_dailyActivity is EqualUnmodifiableMapView) return _dailyActivity;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dailyActivity);
  }

  /// Last 30 days of net XP by UTC calendar date.
  final Map<String, int> _dailyXp;

  /// Last 30 days of net XP by UTC calendar date.
  @override
  @JsonKey(name: 'daily_xp')
  Map<String, int> get dailyXp {
    if (_dailyXp is EqualUnmodifiableMapView) return _dailyXp;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dailyXp);
  }

  @override
  String toString() {
    return 'GamificationProfile(studentId: $studentId, workspaceId: $workspaceId, xpTotal: $xpTotal, xpThisWeek: $xpThisWeek, xpByTopic: $xpByTopic, level: $level, xpIntoLevel: $xpIntoLevel, xpForNextLevel: $xpForNextLevel, streakDays: $streakDays, longestStreakDays: $longestStreakDays, lastActiveDate: $lastActiveDate, questionsAnswered: $questionsAnswered, questionsCorrect: $questionsCorrect, flashcardsReviewed: $flashcardsReviewed, studySessionsCompleted: $studySessionsCompleted, revisionSessionsCompleted: $revisionSessionsCompleted, flashcardSessionsCompleted: $flashcardSessionsCompleted, badges: $badges, dailyActivity: $dailyActivity, dailyXp: $dailyXp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GamificationProfileImpl &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.workspaceId, workspaceId) ||
                other.workspaceId == workspaceId) &&
            (identical(other.xpTotal, xpTotal) || other.xpTotal == xpTotal) &&
            (identical(other.xpThisWeek, xpThisWeek) ||
                other.xpThisWeek == xpThisWeek) &&
            const DeepCollectionEquality()
                .equals(other._xpByTopic, _xpByTopic) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.xpIntoLevel, xpIntoLevel) ||
                other.xpIntoLevel == xpIntoLevel) &&
            (identical(other.xpForNextLevel, xpForNextLevel) ||
                other.xpForNextLevel == xpForNextLevel) &&
            (identical(other.streakDays, streakDays) ||
                other.streakDays == streakDays) &&
            (identical(other.longestStreakDays, longestStreakDays) ||
                other.longestStreakDays == longestStreakDays) &&
            (identical(other.lastActiveDate, lastActiveDate) ||
                other.lastActiveDate == lastActiveDate) &&
            (identical(other.questionsAnswered, questionsAnswered) ||
                other.questionsAnswered == questionsAnswered) &&
            (identical(other.questionsCorrect, questionsCorrect) ||
                other.questionsCorrect == questionsCorrect) &&
            (identical(other.flashcardsReviewed, flashcardsReviewed) ||
                other.flashcardsReviewed == flashcardsReviewed) &&
            (identical(other.studySessionsCompleted, studySessionsCompleted) ||
                other.studySessionsCompleted == studySessionsCompleted) &&
            (identical(other.revisionSessionsCompleted,
                    revisionSessionsCompleted) ||
                other.revisionSessionsCompleted == revisionSessionsCompleted) &&
            (identical(other.flashcardSessionsCompleted,
                    flashcardSessionsCompleted) ||
                other.flashcardSessionsCompleted ==
                    flashcardSessionsCompleted) &&
            const DeepCollectionEquality().equals(other._badges, _badges) &&
            const DeepCollectionEquality()
                .equals(other._dailyActivity, _dailyActivity) &&
            const DeepCollectionEquality().equals(other._dailyXp, _dailyXp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        studentId,
        workspaceId,
        xpTotal,
        xpThisWeek,
        const DeepCollectionEquality().hash(_xpByTopic),
        level,
        xpIntoLevel,
        xpForNextLevel,
        streakDays,
        longestStreakDays,
        lastActiveDate,
        questionsAnswered,
        questionsCorrect,
        flashcardsReviewed,
        studySessionsCompleted,
        revisionSessionsCompleted,
        flashcardSessionsCompleted,
        const DeepCollectionEquality().hash(_badges),
        const DeepCollectionEquality().hash(_dailyActivity),
        const DeepCollectionEquality().hash(_dailyXp)
      ]);

  /// Create a copy of GamificationProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GamificationProfileImplCopyWith<_$GamificationProfileImpl> get copyWith =>
      __$$GamificationProfileImplCopyWithImpl<_$GamificationProfileImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GamificationProfileImplToJson(
      this,
    );
  }
}

abstract class _GamificationProfile extends GamificationProfile {
  const factory _GamificationProfile(
          {@JsonKey(name: 'student_id') required final String studentId,
          @JsonKey(name: 'workspace_id') required final String workspaceId,
          @JsonKey(name: 'xp_total') final int xpTotal,
          @JsonKey(name: 'xp_this_week') final int xpThisWeek,
          @JsonKey(name: 'xp_by_topic') final Map<String, int> xpByTopic,
          final int level,
          @JsonKey(name: 'xp_into_level') final int xpIntoLevel,
          @JsonKey(name: 'xp_for_next_level') final int xpForNextLevel,
          @JsonKey(name: 'streak_days') final int streakDays,
          @JsonKey(name: 'longest_streak_days') final int longestStreakDays,
          @JsonKey(name: 'last_active_date') final String? lastActiveDate,
          @JsonKey(name: 'questions_answered') final int questionsAnswered,
          @JsonKey(name: 'questions_correct') final int questionsCorrect,
          @JsonKey(name: 'flashcards_reviewed') final int flashcardsReviewed,
          @JsonKey(name: 'study_sessions_completed')
          final int studySessionsCompleted,
          @JsonKey(name: 'revision_sessions_completed')
          final int revisionSessionsCompleted,
          @JsonKey(name: 'flashcard_sessions_completed')
          final int flashcardSessionsCompleted,
          final List<EarnedBadge> badges,
          @JsonKey(name: 'daily_activity') final Map<String, int> dailyActivity,
          @JsonKey(name: 'daily_xp') final Map<String, int> dailyXp}) =
      _$GamificationProfileImpl;
  const _GamificationProfile._() : super._();

  factory _GamificationProfile.fromJson(Map<String, dynamic> json) =
      _$GamificationProfileImpl.fromJson;

  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'workspace_id')
  String get workspaceId;
  @override
  @JsonKey(name: 'xp_total')
  int get xpTotal;
  @override
  @JsonKey(name: 'xp_this_week')
  int get xpThisWeek;

  /// Per-topic XP — key is topic display name.
  @override
  @JsonKey(name: 'xp_by_topic')
  Map<String, int> get xpByTopic;
  @override
  int get level;
  @override
  @JsonKey(name: 'xp_into_level')
  int get xpIntoLevel;
  @override
  @JsonKey(name: 'xp_for_next_level')
  int get xpForNextLevel;
  @override
  @JsonKey(name: 'streak_days')
  int get streakDays;
  @override
  @JsonKey(name: 'longest_streak_days')
  int get longestStreakDays;
  @override
  @JsonKey(name: 'last_active_date')
  String? get lastActiveDate;
  @override
  @JsonKey(name: 'questions_answered')
  int get questionsAnswered;
  @override
  @JsonKey(name: 'questions_correct')
  int get questionsCorrect;
  @override
  @JsonKey(name: 'flashcards_reviewed')
  int get flashcardsReviewed;
  @override
  @JsonKey(name: 'study_sessions_completed')
  int get studySessionsCompleted;
  @override
  @JsonKey(name: 'revision_sessions_completed')
  int get revisionSessionsCompleted;
  @override
  @JsonKey(name: 'flashcard_sessions_completed')
  int get flashcardSessionsCompleted;
  @override
  List<EarnedBadge> get badges;

  /// Last 30 days of activity counts — `{"2026-05-23": 12, ...}`.
  @override
  @JsonKey(name: 'daily_activity')
  Map<String, int> get dailyActivity;

  /// Last 30 days of net XP by UTC calendar date.
  @override
  @JsonKey(name: 'daily_xp')
  Map<String, int> get dailyXp;

  /// Create a copy of GamificationProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GamificationProfileImplCopyWith<_$GamificationProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LeaderboardEntry _$LeaderboardEntryFromJson(Map<String, dynamic> json) {
  return _LeaderboardEntry.fromJson(json);
}

/// @nodoc
mixin _$LeaderboardEntry {
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_name')
  String get displayName => throw _privateConstructorUsedError;
  int get level => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_total')
  int get xpTotal => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_this_week')
  int get xpThisWeek => throw _privateConstructorUsedError;
  int get rank => throw _privateConstructorUsedError;
  @JsonKey(name: 'streak_days')
  int get streakDays => throw _privateConstructorUsedError;

  /// Serializes this LeaderboardEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LeaderboardEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LeaderboardEntryCopyWith<LeaderboardEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LeaderboardEntryCopyWith<$Res> {
  factory $LeaderboardEntryCopyWith(
          LeaderboardEntry value, $Res Function(LeaderboardEntry) then) =
      _$LeaderboardEntryCopyWithImpl<$Res, LeaderboardEntry>;
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'display_name') String displayName,
      int level,
      @JsonKey(name: 'xp_total') int xpTotal,
      @JsonKey(name: 'xp_this_week') int xpThisWeek,
      int rank,
      @JsonKey(name: 'streak_days') int streakDays});
}

/// @nodoc
class _$LeaderboardEntryCopyWithImpl<$Res, $Val extends LeaderboardEntry>
    implements $LeaderboardEntryCopyWith<$Res> {
  _$LeaderboardEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LeaderboardEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? displayName = null,
    Object? level = null,
    Object? xpTotal = null,
    Object? xpThisWeek = null,
    Object? rank = null,
    Object? streakDays = null,
  }) {
    return _then(_value.copyWith(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      xpTotal: null == xpTotal
          ? _value.xpTotal
          : xpTotal // ignore: cast_nullable_to_non_nullable
              as int,
      xpThisWeek: null == xpThisWeek
          ? _value.xpThisWeek
          : xpThisWeek // ignore: cast_nullable_to_non_nullable
              as int,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
      streakDays: null == streakDays
          ? _value.streakDays
          : streakDays // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LeaderboardEntryImplCopyWith<$Res>
    implements $LeaderboardEntryCopyWith<$Res> {
  factory _$$LeaderboardEntryImplCopyWith(_$LeaderboardEntryImpl value,
          $Res Function(_$LeaderboardEntryImpl) then) =
      __$$LeaderboardEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'display_name') String displayName,
      int level,
      @JsonKey(name: 'xp_total') int xpTotal,
      @JsonKey(name: 'xp_this_week') int xpThisWeek,
      int rank,
      @JsonKey(name: 'streak_days') int streakDays});
}

/// @nodoc
class __$$LeaderboardEntryImplCopyWithImpl<$Res>
    extends _$LeaderboardEntryCopyWithImpl<$Res, _$LeaderboardEntryImpl>
    implements _$$LeaderboardEntryImplCopyWith<$Res> {
  __$$LeaderboardEntryImplCopyWithImpl(_$LeaderboardEntryImpl _value,
      $Res Function(_$LeaderboardEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of LeaderboardEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? displayName = null,
    Object? level = null,
    Object? xpTotal = null,
    Object? xpThisWeek = null,
    Object? rank = null,
    Object? streakDays = null,
  }) {
    return _then(_$LeaderboardEntryImpl(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      level: null == level
          ? _value.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
      xpTotal: null == xpTotal
          ? _value.xpTotal
          : xpTotal // ignore: cast_nullable_to_non_nullable
              as int,
      xpThisWeek: null == xpThisWeek
          ? _value.xpThisWeek
          : xpThisWeek // ignore: cast_nullable_to_non_nullable
              as int,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
      streakDays: null == streakDays
          ? _value.streakDays
          : streakDays // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LeaderboardEntryImpl implements _LeaderboardEntry {
  const _$LeaderboardEntryImpl(
      {@JsonKey(name: 'student_id') required this.studentId,
      @JsonKey(name: 'display_name') required this.displayName,
      this.level = 1,
      @JsonKey(name: 'xp_total') this.xpTotal = 0,
      @JsonKey(name: 'xp_this_week') this.xpThisWeek = 0,
      this.rank = 0,
      @JsonKey(name: 'streak_days') this.streakDays = 0});

  factory _$LeaderboardEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$LeaderboardEntryImplFromJson(json);

  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'display_name')
  final String displayName;
  @override
  @JsonKey()
  final int level;
  @override
  @JsonKey(name: 'xp_total')
  final int xpTotal;
  @override
  @JsonKey(name: 'xp_this_week')
  final int xpThisWeek;
  @override
  @JsonKey()
  final int rank;
  @override
  @JsonKey(name: 'streak_days')
  final int streakDays;

  @override
  String toString() {
    return 'LeaderboardEntry(studentId: $studentId, displayName: $displayName, level: $level, xpTotal: $xpTotal, xpThisWeek: $xpThisWeek, rank: $rank, streakDays: $streakDays)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LeaderboardEntryImpl &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.xpTotal, xpTotal) || other.xpTotal == xpTotal) &&
            (identical(other.xpThisWeek, xpThisWeek) ||
                other.xpThisWeek == xpThisWeek) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.streakDays, streakDays) ||
                other.streakDays == streakDays));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, studentId, displayName, level,
      xpTotal, xpThisWeek, rank, streakDays);

  /// Create a copy of LeaderboardEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LeaderboardEntryImplCopyWith<_$LeaderboardEntryImpl> get copyWith =>
      __$$LeaderboardEntryImplCopyWithImpl<_$LeaderboardEntryImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LeaderboardEntryImplToJson(
      this,
    );
  }
}

abstract class _LeaderboardEntry implements LeaderboardEntry {
  const factory _LeaderboardEntry(
          {@JsonKey(name: 'student_id') required final String studentId,
          @JsonKey(name: 'display_name') required final String displayName,
          final int level,
          @JsonKey(name: 'xp_total') final int xpTotal,
          @JsonKey(name: 'xp_this_week') final int xpThisWeek,
          final int rank,
          @JsonKey(name: 'streak_days') final int streakDays}) =
      _$LeaderboardEntryImpl;

  factory _LeaderboardEntry.fromJson(Map<String, dynamic> json) =
      _$LeaderboardEntryImpl.fromJson;

  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'display_name')
  String get displayName;
  @override
  int get level;
  @override
  @JsonKey(name: 'xp_total')
  int get xpTotal;
  @override
  @JsonKey(name: 'xp_this_week')
  int get xpThisWeek;
  @override
  int get rank;
  @override
  @JsonKey(name: 'streak_days')
  int get streakDays;

  /// Create a copy of LeaderboardEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LeaderboardEntryImplCopyWith<_$LeaderboardEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LeaderboardResponse _$LeaderboardResponseFromJson(Map<String, dynamic> json) {
  return _LeaderboardResponse.fromJson(json);
}

/// @nodoc
mixin _$LeaderboardResponse {
  @JsonKey(name: 'workspace_id')
  String get workspaceId => throw _privateConstructorUsedError;
  List<LeaderboardEntry> get entries => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_user_rank')
  int? get currentUserRank => throw _privateConstructorUsedError;

  /// False ⇒ the workspace setting hides the leaderboard from the
  /// calling student. `entries` is empty in that case. Admins
  /// always see `visible: true`.
  bool get visible => throw _privateConstructorUsedError;

  /// Serializes this LeaderboardResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LeaderboardResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LeaderboardResponseCopyWith<LeaderboardResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LeaderboardResponseCopyWith<$Res> {
  factory $LeaderboardResponseCopyWith(
          LeaderboardResponse value, $Res Function(LeaderboardResponse) then) =
      _$LeaderboardResponseCopyWithImpl<$Res, LeaderboardResponse>;
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      List<LeaderboardEntry> entries,
      @JsonKey(name: 'current_user_rank') int? currentUserRank,
      bool visible});
}

/// @nodoc
class _$LeaderboardResponseCopyWithImpl<$Res, $Val extends LeaderboardResponse>
    implements $LeaderboardResponseCopyWith<$Res> {
  _$LeaderboardResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LeaderboardResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? entries = null,
    Object? currentUserRank = freezed,
    Object? visible = null,
  }) {
    return _then(_value.copyWith(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      entries: null == entries
          ? _value.entries
          : entries // ignore: cast_nullable_to_non_nullable
              as List<LeaderboardEntry>,
      currentUserRank: freezed == currentUserRank
          ? _value.currentUserRank
          : currentUserRank // ignore: cast_nullable_to_non_nullable
              as int?,
      visible: null == visible
          ? _value.visible
          : visible // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LeaderboardResponseImplCopyWith<$Res>
    implements $LeaderboardResponseCopyWith<$Res> {
  factory _$$LeaderboardResponseImplCopyWith(_$LeaderboardResponseImpl value,
          $Res Function(_$LeaderboardResponseImpl) then) =
      __$$LeaderboardResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      List<LeaderboardEntry> entries,
      @JsonKey(name: 'current_user_rank') int? currentUserRank,
      bool visible});
}

/// @nodoc
class __$$LeaderboardResponseImplCopyWithImpl<$Res>
    extends _$LeaderboardResponseCopyWithImpl<$Res, _$LeaderboardResponseImpl>
    implements _$$LeaderboardResponseImplCopyWith<$Res> {
  __$$LeaderboardResponseImplCopyWithImpl(_$LeaderboardResponseImpl _value,
      $Res Function(_$LeaderboardResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of LeaderboardResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? entries = null,
    Object? currentUserRank = freezed,
    Object? visible = null,
  }) {
    return _then(_$LeaderboardResponseImpl(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      entries: null == entries
          ? _value._entries
          : entries // ignore: cast_nullable_to_non_nullable
              as List<LeaderboardEntry>,
      currentUserRank: freezed == currentUserRank
          ? _value.currentUserRank
          : currentUserRank // ignore: cast_nullable_to_non_nullable
              as int?,
      visible: null == visible
          ? _value.visible
          : visible // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LeaderboardResponseImpl extends _LeaderboardResponse {
  const _$LeaderboardResponseImpl(
      {@JsonKey(name: 'workspace_id') required this.workspaceId,
      final List<LeaderboardEntry> entries = const <LeaderboardEntry>[],
      @JsonKey(name: 'current_user_rank') this.currentUserRank,
      this.visible = true})
      : _entries = entries,
        super._();

  factory _$LeaderboardResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$LeaderboardResponseImplFromJson(json);

  @override
  @JsonKey(name: 'workspace_id')
  final String workspaceId;
  final List<LeaderboardEntry> _entries;
  @override
  @JsonKey()
  List<LeaderboardEntry> get entries {
    if (_entries is EqualUnmodifiableListView) return _entries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entries);
  }

  @override
  @JsonKey(name: 'current_user_rank')
  final int? currentUserRank;

  /// False ⇒ the workspace setting hides the leaderboard from the
  /// calling student. `entries` is empty in that case. Admins
  /// always see `visible: true`.
  @override
  @JsonKey()
  final bool visible;

  @override
  String toString() {
    return 'LeaderboardResponse(workspaceId: $workspaceId, entries: $entries, currentUserRank: $currentUserRank, visible: $visible)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LeaderboardResponseImpl &&
            (identical(other.workspaceId, workspaceId) ||
                other.workspaceId == workspaceId) &&
            const DeepCollectionEquality().equals(other._entries, _entries) &&
            (identical(other.currentUserRank, currentUserRank) ||
                other.currentUserRank == currentUserRank) &&
            (identical(other.visible, visible) || other.visible == visible));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, workspaceId,
      const DeepCollectionEquality().hash(_entries), currentUserRank, visible);

  /// Create a copy of LeaderboardResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LeaderboardResponseImplCopyWith<_$LeaderboardResponseImpl> get copyWith =>
      __$$LeaderboardResponseImplCopyWithImpl<_$LeaderboardResponseImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LeaderboardResponseImplToJson(
      this,
    );
  }
}

abstract class _LeaderboardResponse extends LeaderboardResponse {
  const factory _LeaderboardResponse(
      {@JsonKey(name: 'workspace_id') required final String workspaceId,
      final List<LeaderboardEntry> entries,
      @JsonKey(name: 'current_user_rank') final int? currentUserRank,
      final bool visible}) = _$LeaderboardResponseImpl;
  const _LeaderboardResponse._() : super._();

  factory _LeaderboardResponse.fromJson(Map<String, dynamic> json) =
      _$LeaderboardResponseImpl.fromJson;

  @override
  @JsonKey(name: 'workspace_id')
  String get workspaceId;
  @override
  List<LeaderboardEntry> get entries;
  @override
  @JsonKey(name: 'current_user_rank')
  int? get currentUserRank;

  /// False ⇒ the workspace setting hides the leaderboard from the
  /// calling student. `entries` is empty in that case. Admins
  /// always see `visible: true`.
  @override
  bool get visible;

  /// Create a copy of LeaderboardResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LeaderboardResponseImplCopyWith<_$LeaderboardResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SessionCompletionFeedback _$SessionCompletionFeedbackFromJson(
    Map<String, dynamic> json) {
  return _SessionCompletionFeedback.fromJson(json);
}

/// @nodoc
mixin _$SessionCompletionFeedback {
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
  List<EarnedBadge> get badgesUnlocked => throw _privateConstructorUsedError;

  /// Serializes this SessionCompletionFeedback to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionCompletionFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionCompletionFeedbackCopyWith<SessionCompletionFeedback> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionCompletionFeedbackCopyWith<$Res> {
  factory $SessionCompletionFeedbackCopyWith(SessionCompletionFeedback value,
          $Res Function(SessionCompletionFeedback) then) =
      _$SessionCompletionFeedbackCopyWithImpl<$Res, SessionCompletionFeedback>;
  @useResult
  $Res call(
      {@JsonKey(name: 'xp_earned') int xpEarned,
      @JsonKey(name: 'new_level') int newLevel,
      @JsonKey(name: 'leveled_up') bool leveledUp,
      @JsonKey(name: 'streak_days') int streakDays,
      @JsonKey(name: 'streak_extended') bool streakExtended,
      @JsonKey(name: 'badges_unlocked') List<EarnedBadge> badgesUnlocked});
}

/// @nodoc
class _$SessionCompletionFeedbackCopyWithImpl<$Res,
        $Val extends SessionCompletionFeedback>
    implements $SessionCompletionFeedbackCopyWith<$Res> {
  _$SessionCompletionFeedbackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionCompletionFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? xpEarned = null,
    Object? newLevel = null,
    Object? leveledUp = null,
    Object? streakDays = null,
    Object? streakExtended = null,
    Object? badgesUnlocked = null,
  }) {
    return _then(_value.copyWith(
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
              as List<EarnedBadge>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SessionCompletionFeedbackImplCopyWith<$Res>
    implements $SessionCompletionFeedbackCopyWith<$Res> {
  factory _$$SessionCompletionFeedbackImplCopyWith(
          _$SessionCompletionFeedbackImpl value,
          $Res Function(_$SessionCompletionFeedbackImpl) then) =
      __$$SessionCompletionFeedbackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'xp_earned') int xpEarned,
      @JsonKey(name: 'new_level') int newLevel,
      @JsonKey(name: 'leveled_up') bool leveledUp,
      @JsonKey(name: 'streak_days') int streakDays,
      @JsonKey(name: 'streak_extended') bool streakExtended,
      @JsonKey(name: 'badges_unlocked') List<EarnedBadge> badgesUnlocked});
}

/// @nodoc
class __$$SessionCompletionFeedbackImplCopyWithImpl<$Res>
    extends _$SessionCompletionFeedbackCopyWithImpl<$Res,
        _$SessionCompletionFeedbackImpl>
    implements _$$SessionCompletionFeedbackImplCopyWith<$Res> {
  __$$SessionCompletionFeedbackImplCopyWithImpl(
      _$SessionCompletionFeedbackImpl _value,
      $Res Function(_$SessionCompletionFeedbackImpl) _then)
      : super(_value, _then);

  /// Create a copy of SessionCompletionFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? xpEarned = null,
    Object? newLevel = null,
    Object? leveledUp = null,
    Object? streakDays = null,
    Object? streakExtended = null,
    Object? badgesUnlocked = null,
  }) {
    return _then(_$SessionCompletionFeedbackImpl(
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
              as List<EarnedBadge>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionCompletionFeedbackImpl implements _SessionCompletionFeedback {
  const _$SessionCompletionFeedbackImpl(
      {@JsonKey(name: 'xp_earned') required this.xpEarned,
      @JsonKey(name: 'new_level') required this.newLevel,
      @JsonKey(name: 'leveled_up') required this.leveledUp,
      @JsonKey(name: 'streak_days') required this.streakDays,
      @JsonKey(name: 'streak_extended') required this.streakExtended,
      @JsonKey(name: 'badges_unlocked')
      final List<EarnedBadge> badgesUnlocked = const <EarnedBadge>[]})
      : _badgesUnlocked = badgesUnlocked;

  factory _$SessionCompletionFeedbackImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionCompletionFeedbackImplFromJson(json);

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
  final List<EarnedBadge> _badgesUnlocked;
  @override
  @JsonKey(name: 'badges_unlocked')
  List<EarnedBadge> get badgesUnlocked {
    if (_badgesUnlocked is EqualUnmodifiableListView) return _badgesUnlocked;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_badgesUnlocked);
  }

  @override
  String toString() {
    return 'SessionCompletionFeedback(xpEarned: $xpEarned, newLevel: $newLevel, leveledUp: $leveledUp, streakDays: $streakDays, streakExtended: $streakExtended, badgesUnlocked: $badgesUnlocked)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionCompletionFeedbackImpl &&
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
      xpEarned,
      newLevel,
      leveledUp,
      streakDays,
      streakExtended,
      const DeepCollectionEquality().hash(_badgesUnlocked));

  /// Create a copy of SessionCompletionFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionCompletionFeedbackImplCopyWith<_$SessionCompletionFeedbackImpl>
      get copyWith => __$$SessionCompletionFeedbackImplCopyWithImpl<
          _$SessionCompletionFeedbackImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionCompletionFeedbackImplToJson(
      this,
    );
  }
}

abstract class _SessionCompletionFeedback implements SessionCompletionFeedback {
  const factory _SessionCompletionFeedback(
          {@JsonKey(name: 'xp_earned') required final int xpEarned,
          @JsonKey(name: 'new_level') required final int newLevel,
          @JsonKey(name: 'leveled_up') required final bool leveledUp,
          @JsonKey(name: 'streak_days') required final int streakDays,
          @JsonKey(name: 'streak_extended') required final bool streakExtended,
          @JsonKey(name: 'badges_unlocked')
          final List<EarnedBadge> badgesUnlocked}) =
      _$SessionCompletionFeedbackImpl;

  factory _SessionCompletionFeedback.fromJson(Map<String, dynamic> json) =
      _$SessionCompletionFeedbackImpl.fromJson;

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
  List<EarnedBadge> get badgesUnlocked;

  /// Create a copy of SessionCompletionFeedback
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionCompletionFeedbackImplCopyWith<_$SessionCompletionFeedbackImpl>
      get copyWith => throw _privateConstructorUsedError;
}
