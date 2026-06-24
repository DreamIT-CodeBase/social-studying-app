// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'screen_time_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ScreenTimeSettings _$ScreenTimeSettingsFromJson(Map<String, dynamic> json) {
  return _ScreenTimeSettings.fromJson(json);
}

/// @nodoc
mixin _$ScreenTimeSettings {
  @JsonKey(name: 'workspace_id')
  String get workspaceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'enable_blocking')
  bool get enableBlocking => throw _privateConstructorUsedError;
  @JsonKey(name: 'blocked_packages')
  List<String> get blockedPackages => throw _privateConstructorUsedError;
  @JsonKey(name: 'xp_to_minute_ratio')
  int get xpToMinuteRatio => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  String get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ScreenTimeSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ScreenTimeSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScreenTimeSettingsCopyWith<ScreenTimeSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScreenTimeSettingsCopyWith<$Res> {
  factory $ScreenTimeSettingsCopyWith(
          ScreenTimeSettings value, $Res Function(ScreenTimeSettings) then) =
      _$ScreenTimeSettingsCopyWithImpl<$Res, ScreenTimeSettings>;
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      @JsonKey(name: 'enable_blocking') bool enableBlocking,
      @JsonKey(name: 'blocked_packages') List<String> blockedPackages,
      @JsonKey(name: 'xp_to_minute_ratio') int xpToMinuteRatio,
      @JsonKey(name: 'updated_at') String updatedAt});
}

/// @nodoc
class _$ScreenTimeSettingsCopyWithImpl<$Res, $Val extends ScreenTimeSettings>
    implements $ScreenTimeSettingsCopyWith<$Res> {
  _$ScreenTimeSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScreenTimeSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? enableBlocking = null,
    Object? blockedPackages = null,
    Object? xpToMinuteRatio = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      enableBlocking: null == enableBlocking
          ? _value.enableBlocking
          : enableBlocking // ignore: cast_nullable_to_non_nullable
              as bool,
      blockedPackages: null == blockedPackages
          ? _value.blockedPackages
          : blockedPackages // ignore: cast_nullable_to_non_nullable
              as List<String>,
      xpToMinuteRatio: null == xpToMinuteRatio
          ? _value.xpToMinuteRatio
          : xpToMinuteRatio // ignore: cast_nullable_to_non_nullable
              as int,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ScreenTimeSettingsImplCopyWith<$Res>
    implements $ScreenTimeSettingsCopyWith<$Res> {
  factory _$$ScreenTimeSettingsImplCopyWith(_$ScreenTimeSettingsImpl value,
          $Res Function(_$ScreenTimeSettingsImpl) then) =
      __$$ScreenTimeSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      @JsonKey(name: 'enable_blocking') bool enableBlocking,
      @JsonKey(name: 'blocked_packages') List<String> blockedPackages,
      @JsonKey(name: 'xp_to_minute_ratio') int xpToMinuteRatio,
      @JsonKey(name: 'updated_at') String updatedAt});
}

/// @nodoc
class __$$ScreenTimeSettingsImplCopyWithImpl<$Res>
    extends _$ScreenTimeSettingsCopyWithImpl<$Res, _$ScreenTimeSettingsImpl>
    implements _$$ScreenTimeSettingsImplCopyWith<$Res> {
  __$$ScreenTimeSettingsImplCopyWithImpl(_$ScreenTimeSettingsImpl _value,
      $Res Function(_$ScreenTimeSettingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of ScreenTimeSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? enableBlocking = null,
    Object? blockedPackages = null,
    Object? xpToMinuteRatio = null,
    Object? updatedAt = null,
  }) {
    return _then(_$ScreenTimeSettingsImpl(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      enableBlocking: null == enableBlocking
          ? _value.enableBlocking
          : enableBlocking // ignore: cast_nullable_to_non_nullable
              as bool,
      blockedPackages: null == blockedPackages
          ? _value._blockedPackages
          : blockedPackages // ignore: cast_nullable_to_non_nullable
              as List<String>,
      xpToMinuteRatio: null == xpToMinuteRatio
          ? _value.xpToMinuteRatio
          : xpToMinuteRatio // ignore: cast_nullable_to_non_nullable
              as int,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ScreenTimeSettingsImpl implements _ScreenTimeSettings {
  const _$ScreenTimeSettingsImpl(
      {@JsonKey(name: 'workspace_id') required this.workspaceId,
      @JsonKey(name: 'enable_blocking') this.enableBlocking = true,
      @JsonKey(name: 'blocked_packages')
      final List<String> blockedPackages = const [],
      @JsonKey(name: 'xp_to_minute_ratio') this.xpToMinuteRatio = 10,
      @JsonKey(name: 'updated_at') required this.updatedAt})
      : _blockedPackages = blockedPackages;

  factory _$ScreenTimeSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScreenTimeSettingsImplFromJson(json);

  @override
  @JsonKey(name: 'workspace_id')
  final String workspaceId;
  @override
  @JsonKey(name: 'enable_blocking')
  final bool enableBlocking;
  final List<String> _blockedPackages;
  @override
  @JsonKey(name: 'blocked_packages')
  List<String> get blockedPackages {
    if (_blockedPackages is EqualUnmodifiableListView) return _blockedPackages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blockedPackages);
  }

  @override
  @JsonKey(name: 'xp_to_minute_ratio')
  final int xpToMinuteRatio;
  @override
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  @override
  String toString() {
    return 'ScreenTimeSettings(workspaceId: $workspaceId, enableBlocking: $enableBlocking, blockedPackages: $blockedPackages, xpToMinuteRatio: $xpToMinuteRatio, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScreenTimeSettingsImpl &&
            (identical(other.workspaceId, workspaceId) ||
                other.workspaceId == workspaceId) &&
            (identical(other.enableBlocking, enableBlocking) ||
                other.enableBlocking == enableBlocking) &&
            const DeepCollectionEquality()
                .equals(other._blockedPackages, _blockedPackages) &&
            (identical(other.xpToMinuteRatio, xpToMinuteRatio) ||
                other.xpToMinuteRatio == xpToMinuteRatio) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      workspaceId,
      enableBlocking,
      const DeepCollectionEquality().hash(_blockedPackages),
      xpToMinuteRatio,
      updatedAt);

  /// Create a copy of ScreenTimeSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScreenTimeSettingsImplCopyWith<_$ScreenTimeSettingsImpl> get copyWith =>
      __$$ScreenTimeSettingsImplCopyWithImpl<_$ScreenTimeSettingsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScreenTimeSettingsImplToJson(
      this,
    );
  }
}

abstract class _ScreenTimeSettings implements ScreenTimeSettings {
  const factory _ScreenTimeSettings(
          {@JsonKey(name: 'workspace_id') required final String workspaceId,
          @JsonKey(name: 'enable_blocking') final bool enableBlocking,
          @JsonKey(name: 'blocked_packages') final List<String> blockedPackages,
          @JsonKey(name: 'xp_to_minute_ratio') final int xpToMinuteRatio,
          @JsonKey(name: 'updated_at') required final String updatedAt}) =
      _$ScreenTimeSettingsImpl;

  factory _ScreenTimeSettings.fromJson(Map<String, dynamic> json) =
      _$ScreenTimeSettingsImpl.fromJson;

  @override
  @JsonKey(name: 'workspace_id')
  String get workspaceId;
  @override
  @JsonKey(name: 'enable_blocking')
  bool get enableBlocking;
  @override
  @JsonKey(name: 'blocked_packages')
  List<String> get blockedPackages;
  @override
  @JsonKey(name: 'xp_to_minute_ratio')
  int get xpToMinuteRatio;
  @override
  @JsonKey(name: 'updated_at')
  String get updatedAt;

  /// Create a copy of ScreenTimeSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScreenTimeSettingsImplCopyWith<_$ScreenTimeSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
