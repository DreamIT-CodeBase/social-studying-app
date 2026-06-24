// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'screen_time_wallet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ScreenTimeWallet _$ScreenTimeWalletFromJson(Map<String, dynamic> json) {
  return _ScreenTimeWallet.fromJson(json);
}

/// @nodoc
mixin _$ScreenTimeWallet {
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'workspace_id')
  String get workspaceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_earned_minutes')
  int get totalEarnedMinutes => throw _privateConstructorUsedError;
  @JsonKey(name: 'available_minutes')
  int get availableMinutes => throw _privateConstructorUsedError;
  @JsonKey(name: 'consumed_minutes')
  int get consumedMinutes => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_known_xp')
  int get lastKnownXp => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_sync_time')
  DateTime? get lastSyncTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'consumed_today')
  int get consumedToday => throw _privateConstructorUsedError;

  /// Serializes this ScreenTimeWallet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ScreenTimeWallet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScreenTimeWalletCopyWith<ScreenTimeWallet> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScreenTimeWalletCopyWith<$Res> {
  factory $ScreenTimeWalletCopyWith(
          ScreenTimeWallet value, $Res Function(ScreenTimeWallet) then) =
      _$ScreenTimeWalletCopyWithImpl<$Res, ScreenTimeWallet>;
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'workspace_id') String workspaceId,
      @JsonKey(name: 'total_earned_minutes') int totalEarnedMinutes,
      @JsonKey(name: 'available_minutes') int availableMinutes,
      @JsonKey(name: 'consumed_minutes') int consumedMinutes,
      @JsonKey(name: 'last_known_xp') int lastKnownXp,
      @JsonKey(name: 'last_sync_time') DateTime? lastSyncTime,
      @JsonKey(name: 'consumed_today') int consumedToday});
}

/// @nodoc
class _$ScreenTimeWalletCopyWithImpl<$Res, $Val extends ScreenTimeWallet>
    implements $ScreenTimeWalletCopyWith<$Res> {
  _$ScreenTimeWalletCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScreenTimeWallet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? workspaceId = null,
    Object? totalEarnedMinutes = null,
    Object? availableMinutes = null,
    Object? consumedMinutes = null,
    Object? lastKnownXp = null,
    Object? lastSyncTime = freezed,
    Object? consumedToday = null,
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
      totalEarnedMinutes: null == totalEarnedMinutes
          ? _value.totalEarnedMinutes
          : totalEarnedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      availableMinutes: null == availableMinutes
          ? _value.availableMinutes
          : availableMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      consumedMinutes: null == consumedMinutes
          ? _value.consumedMinutes
          : consumedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      lastKnownXp: null == lastKnownXp
          ? _value.lastKnownXp
          : lastKnownXp // ignore: cast_nullable_to_non_nullable
              as int,
      lastSyncTime: freezed == lastSyncTime
          ? _value.lastSyncTime
          : lastSyncTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      consumedToday: null == consumedToday
          ? _value.consumedToday
          : consumedToday // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ScreenTimeWalletImplCopyWith<$Res>
    implements $ScreenTimeWalletCopyWith<$Res> {
  factory _$$ScreenTimeWalletImplCopyWith(_$ScreenTimeWalletImpl value,
          $Res Function(_$ScreenTimeWalletImpl) then) =
      __$$ScreenTimeWalletImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'student_id') String studentId,
      @JsonKey(name: 'workspace_id') String workspaceId,
      @JsonKey(name: 'total_earned_minutes') int totalEarnedMinutes,
      @JsonKey(name: 'available_minutes') int availableMinutes,
      @JsonKey(name: 'consumed_minutes') int consumedMinutes,
      @JsonKey(name: 'last_known_xp') int lastKnownXp,
      @JsonKey(name: 'last_sync_time') DateTime? lastSyncTime,
      @JsonKey(name: 'consumed_today') int consumedToday});
}

/// @nodoc
class __$$ScreenTimeWalletImplCopyWithImpl<$Res>
    extends _$ScreenTimeWalletCopyWithImpl<$Res, _$ScreenTimeWalletImpl>
    implements _$$ScreenTimeWalletImplCopyWith<$Res> {
  __$$ScreenTimeWalletImplCopyWithImpl(_$ScreenTimeWalletImpl _value,
      $Res Function(_$ScreenTimeWalletImpl) _then)
      : super(_value, _then);

  /// Create a copy of ScreenTimeWallet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? studentId = null,
    Object? workspaceId = null,
    Object? totalEarnedMinutes = null,
    Object? availableMinutes = null,
    Object? consumedMinutes = null,
    Object? lastKnownXp = null,
    Object? lastSyncTime = freezed,
    Object? consumedToday = null,
  }) {
    return _then(_$ScreenTimeWalletImpl(
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      totalEarnedMinutes: null == totalEarnedMinutes
          ? _value.totalEarnedMinutes
          : totalEarnedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      availableMinutes: null == availableMinutes
          ? _value.availableMinutes
          : availableMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      consumedMinutes: null == consumedMinutes
          ? _value.consumedMinutes
          : consumedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      lastKnownXp: null == lastKnownXp
          ? _value.lastKnownXp
          : lastKnownXp // ignore: cast_nullable_to_non_nullable
              as int,
      lastSyncTime: freezed == lastSyncTime
          ? _value.lastSyncTime
          : lastSyncTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      consumedToday: null == consumedToday
          ? _value.consumedToday
          : consumedToday // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ScreenTimeWalletImpl implements _ScreenTimeWallet {
  const _$ScreenTimeWalletImpl(
      {@JsonKey(name: 'student_id') this.studentId = '',
      @JsonKey(name: 'workspace_id') this.workspaceId = '',
      @JsonKey(name: 'total_earned_minutes') this.totalEarnedMinutes = 0,
      @JsonKey(name: 'available_minutes') this.availableMinutes = 0,
      @JsonKey(name: 'consumed_minutes') this.consumedMinutes = 0,
      @JsonKey(name: 'last_known_xp') this.lastKnownXp = 0,
      @JsonKey(name: 'last_sync_time') this.lastSyncTime,
      @JsonKey(name: 'consumed_today') this.consumedToday = 0});

  factory _$ScreenTimeWalletImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScreenTimeWalletImplFromJson(json);

  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  @JsonKey(name: 'workspace_id')
  final String workspaceId;
  @override
  @JsonKey(name: 'total_earned_minutes')
  final int totalEarnedMinutes;
  @override
  @JsonKey(name: 'available_minutes')
  final int availableMinutes;
  @override
  @JsonKey(name: 'consumed_minutes')
  final int consumedMinutes;
  @override
  @JsonKey(name: 'last_known_xp')
  final int lastKnownXp;
  @override
  @JsonKey(name: 'last_sync_time')
  final DateTime? lastSyncTime;
  @override
  @JsonKey(name: 'consumed_today')
  final int consumedToday;

  @override
  String toString() {
    return 'ScreenTimeWallet(studentId: $studentId, workspaceId: $workspaceId, totalEarnedMinutes: $totalEarnedMinutes, availableMinutes: $availableMinutes, consumedMinutes: $consumedMinutes, lastKnownXp: $lastKnownXp, lastSyncTime: $lastSyncTime, consumedToday: $consumedToday)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScreenTimeWalletImpl &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.workspaceId, workspaceId) ||
                other.workspaceId == workspaceId) &&
            (identical(other.totalEarnedMinutes, totalEarnedMinutes) ||
                other.totalEarnedMinutes == totalEarnedMinutes) &&
            (identical(other.availableMinutes, availableMinutes) ||
                other.availableMinutes == availableMinutes) &&
            (identical(other.consumedMinutes, consumedMinutes) ||
                other.consumedMinutes == consumedMinutes) &&
            (identical(other.lastKnownXp, lastKnownXp) ||
                other.lastKnownXp == lastKnownXp) &&
            (identical(other.lastSyncTime, lastSyncTime) ||
                other.lastSyncTime == lastSyncTime) &&
            (identical(other.consumedToday, consumedToday) ||
                other.consumedToday == consumedToday));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      studentId,
      workspaceId,
      totalEarnedMinutes,
      availableMinutes,
      consumedMinutes,
      lastKnownXp,
      lastSyncTime,
      consumedToday);

  /// Create a copy of ScreenTimeWallet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScreenTimeWalletImplCopyWith<_$ScreenTimeWalletImpl> get copyWith =>
      __$$ScreenTimeWalletImplCopyWithImpl<_$ScreenTimeWalletImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScreenTimeWalletImplToJson(
      this,
    );
  }
}

abstract class _ScreenTimeWallet implements ScreenTimeWallet {
  const factory _ScreenTimeWallet(
          {@JsonKey(name: 'student_id') final String studentId,
          @JsonKey(name: 'workspace_id') final String workspaceId,
          @JsonKey(name: 'total_earned_minutes') final int totalEarnedMinutes,
          @JsonKey(name: 'available_minutes') final int availableMinutes,
          @JsonKey(name: 'consumed_minutes') final int consumedMinutes,
          @JsonKey(name: 'last_known_xp') final int lastKnownXp,
          @JsonKey(name: 'last_sync_time') final DateTime? lastSyncTime,
          @JsonKey(name: 'consumed_today') final int consumedToday}) =
      _$ScreenTimeWalletImpl;

  factory _ScreenTimeWallet.fromJson(Map<String, dynamic> json) =
      _$ScreenTimeWalletImpl.fromJson;

  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  @JsonKey(name: 'workspace_id')
  String get workspaceId;
  @override
  @JsonKey(name: 'total_earned_minutes')
  int get totalEarnedMinutes;
  @override
  @JsonKey(name: 'available_minutes')
  int get availableMinutes;
  @override
  @JsonKey(name: 'consumed_minutes')
  int get consumedMinutes;
  @override
  @JsonKey(name: 'last_known_xp')
  int get lastKnownXp;
  @override
  @JsonKey(name: 'last_sync_time')
  DateTime? get lastSyncTime;
  @override
  @JsonKey(name: 'consumed_today')
  int get consumedToday;

  /// Create a copy of ScreenTimeWallet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScreenTimeWalletImplCopyWith<_$ScreenTimeWalletImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
