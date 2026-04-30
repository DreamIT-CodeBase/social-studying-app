// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

WorkspaceSettings _$WorkspaceSettingsFromJson(Map<String, dynamic> json) {
  return _WorkspaceSettings.fromJson(json);
}

/// @nodoc
mixin _$WorkspaceSettings {
  int get dailyQuestionGoal => throw _privateConstructorUsedError;
  bool get gamificationEnabled => throw _privateConstructorUsedError;
  bool get leaderboardVisible => throw _privateConstructorUsedError;
  double get moderationThreshold => throw _privateConstructorUsedError;

  /// Serializes this WorkspaceSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkspaceSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkspaceSettingsCopyWith<WorkspaceSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkspaceSettingsCopyWith<$Res> {
  factory $WorkspaceSettingsCopyWith(
          WorkspaceSettings value, $Res Function(WorkspaceSettings) then) =
      _$WorkspaceSettingsCopyWithImpl<$Res, WorkspaceSettings>;
  @useResult
  $Res call(
      {int dailyQuestionGoal,
      bool gamificationEnabled,
      bool leaderboardVisible,
      double moderationThreshold});
}

/// @nodoc
class _$WorkspaceSettingsCopyWithImpl<$Res, $Val extends WorkspaceSettings>
    implements $WorkspaceSettingsCopyWith<$Res> {
  _$WorkspaceSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkspaceSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dailyQuestionGoal = null,
    Object? gamificationEnabled = null,
    Object? leaderboardVisible = null,
    Object? moderationThreshold = null,
  }) {
    return _then(_value.copyWith(
      dailyQuestionGoal: null == dailyQuestionGoal
          ? _value.dailyQuestionGoal
          : dailyQuestionGoal // ignore: cast_nullable_to_non_nullable
              as int,
      gamificationEnabled: null == gamificationEnabled
          ? _value.gamificationEnabled
          : gamificationEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      leaderboardVisible: null == leaderboardVisible
          ? _value.leaderboardVisible
          : leaderboardVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      moderationThreshold: null == moderationThreshold
          ? _value.moderationThreshold
          : moderationThreshold // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WorkspaceSettingsImplCopyWith<$Res>
    implements $WorkspaceSettingsCopyWith<$Res> {
  factory _$$WorkspaceSettingsImplCopyWith(_$WorkspaceSettingsImpl value,
          $Res Function(_$WorkspaceSettingsImpl) then) =
      __$$WorkspaceSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int dailyQuestionGoal,
      bool gamificationEnabled,
      bool leaderboardVisible,
      double moderationThreshold});
}

/// @nodoc
class __$$WorkspaceSettingsImplCopyWithImpl<$Res>
    extends _$WorkspaceSettingsCopyWithImpl<$Res, _$WorkspaceSettingsImpl>
    implements _$$WorkspaceSettingsImplCopyWith<$Res> {
  __$$WorkspaceSettingsImplCopyWithImpl(_$WorkspaceSettingsImpl _value,
      $Res Function(_$WorkspaceSettingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of WorkspaceSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dailyQuestionGoal = null,
    Object? gamificationEnabled = null,
    Object? leaderboardVisible = null,
    Object? moderationThreshold = null,
  }) {
    return _then(_$WorkspaceSettingsImpl(
      dailyQuestionGoal: null == dailyQuestionGoal
          ? _value.dailyQuestionGoal
          : dailyQuestionGoal // ignore: cast_nullable_to_non_nullable
              as int,
      gamificationEnabled: null == gamificationEnabled
          ? _value.gamificationEnabled
          : gamificationEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      leaderboardVisible: null == leaderboardVisible
          ? _value.leaderboardVisible
          : leaderboardVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      moderationThreshold: null == moderationThreshold
          ? _value.moderationThreshold
          : moderationThreshold // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkspaceSettingsImpl implements _WorkspaceSettings {
  const _$WorkspaceSettingsImpl(
      {this.dailyQuestionGoal = 5,
      this.gamificationEnabled = true,
      this.leaderboardVisible = true,
      this.moderationThreshold = 0.7});

  factory _$WorkspaceSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkspaceSettingsImplFromJson(json);

  @override
  @JsonKey()
  final int dailyQuestionGoal;
  @override
  @JsonKey()
  final bool gamificationEnabled;
  @override
  @JsonKey()
  final bool leaderboardVisible;
  @override
  @JsonKey()
  final double moderationThreshold;

  @override
  String toString() {
    return 'WorkspaceSettings(dailyQuestionGoal: $dailyQuestionGoal, gamificationEnabled: $gamificationEnabled, leaderboardVisible: $leaderboardVisible, moderationThreshold: $moderationThreshold)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkspaceSettingsImpl &&
            (identical(other.dailyQuestionGoal, dailyQuestionGoal) ||
                other.dailyQuestionGoal == dailyQuestionGoal) &&
            (identical(other.gamificationEnabled, gamificationEnabled) ||
                other.gamificationEnabled == gamificationEnabled) &&
            (identical(other.leaderboardVisible, leaderboardVisible) ||
                other.leaderboardVisible == leaderboardVisible) &&
            (identical(other.moderationThreshold, moderationThreshold) ||
                other.moderationThreshold == moderationThreshold));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, dailyQuestionGoal,
      gamificationEnabled, leaderboardVisible, moderationThreshold);

  /// Create a copy of WorkspaceSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkspaceSettingsImplCopyWith<_$WorkspaceSettingsImpl> get copyWith =>
      __$$WorkspaceSettingsImplCopyWithImpl<_$WorkspaceSettingsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkspaceSettingsImplToJson(
      this,
    );
  }
}

abstract class _WorkspaceSettings implements WorkspaceSettings {
  const factory _WorkspaceSettings(
      {final int dailyQuestionGoal,
      final bool gamificationEnabled,
      final bool leaderboardVisible,
      final double moderationThreshold}) = _$WorkspaceSettingsImpl;

  factory _WorkspaceSettings.fromJson(Map<String, dynamic> json) =
      _$WorkspaceSettingsImpl.fromJson;

  @override
  int get dailyQuestionGoal;
  @override
  bool get gamificationEnabled;
  @override
  bool get leaderboardVisible;
  @override
  double get moderationThreshold;

  /// Create a copy of WorkspaceSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkspaceSettingsImplCopyWith<_$WorkspaceSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Workspace _$WorkspaceFromJson(Map<String, dynamic> json) {
  return _Workspace.fromJson(json);
}

/// @nodoc
mixin _$Workspace {
  String get id => throw _privateConstructorUsedError;
  String get tenantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  WorkspaceSettings get settings => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  bool get isDeleted => throw _privateConstructorUsedError;

  /// Serializes this Workspace to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Workspace
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkspaceCopyWith<Workspace> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkspaceCopyWith<$Res> {
  factory $WorkspaceCopyWith(Workspace value, $Res Function(Workspace) then) =
      _$WorkspaceCopyWithImpl<$Res, Workspace>;
  @useResult
  $Res call(
      {String id,
      String tenantId,
      String name,
      String? description,
      WorkspaceSettings settings,
      DateTime createdAt,
      bool isDeleted});

  $WorkspaceSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class _$WorkspaceCopyWithImpl<$Res, $Val extends Workspace>
    implements $WorkspaceCopyWith<$Res> {
  _$WorkspaceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Workspace
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? name = null,
    Object? description = freezed,
    Object? settings = null,
    Object? createdAt = null,
    Object? isDeleted = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as WorkspaceSettings,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isDeleted: null == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of Workspace
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WorkspaceSettingsCopyWith<$Res> get settings {
    return $WorkspaceSettingsCopyWith<$Res>(_value.settings, (value) {
      return _then(_value.copyWith(settings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$WorkspaceImplCopyWith<$Res>
    implements $WorkspaceCopyWith<$Res> {
  factory _$$WorkspaceImplCopyWith(
          _$WorkspaceImpl value, $Res Function(_$WorkspaceImpl) then) =
      __$$WorkspaceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String tenantId,
      String name,
      String? description,
      WorkspaceSettings settings,
      DateTime createdAt,
      bool isDeleted});

  @override
  $WorkspaceSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class __$$WorkspaceImplCopyWithImpl<$Res>
    extends _$WorkspaceCopyWithImpl<$Res, _$WorkspaceImpl>
    implements _$$WorkspaceImplCopyWith<$Res> {
  __$$WorkspaceImplCopyWithImpl(
      _$WorkspaceImpl _value, $Res Function(_$WorkspaceImpl) _then)
      : super(_value, _then);

  /// Create a copy of Workspace
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? name = null,
    Object? description = freezed,
    Object? settings = null,
    Object? createdAt = null,
    Object? isDeleted = null,
  }) {
    return _then(_$WorkspaceImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as WorkspaceSettings,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isDeleted: null == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkspaceImpl implements _Workspace {
  const _$WorkspaceImpl(
      {required this.id,
      required this.tenantId,
      required this.name,
      this.description,
      required this.settings,
      required this.createdAt,
      this.isDeleted = false});

  factory _$WorkspaceImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkspaceImplFromJson(json);

  @override
  final String id;
  @override
  final String tenantId;
  @override
  final String name;
  @override
  final String? description;
  @override
  final WorkspaceSettings settings;
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final bool isDeleted;

  @override
  String toString() {
    return 'Workspace(id: $id, tenantId: $tenantId, name: $name, description: $description, settings: $settings, createdAt: $createdAt, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkspaceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, tenantId, name, description,
      settings, createdAt, isDeleted);

  /// Create a copy of Workspace
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkspaceImplCopyWith<_$WorkspaceImpl> get copyWith =>
      __$$WorkspaceImplCopyWithImpl<_$WorkspaceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkspaceImplToJson(
      this,
    );
  }
}

abstract class _Workspace implements Workspace {
  const factory _Workspace(
      {required final String id,
      required final String tenantId,
      required final String name,
      final String? description,
      required final WorkspaceSettings settings,
      required final DateTime createdAt,
      final bool isDeleted}) = _$WorkspaceImpl;

  factory _Workspace.fromJson(Map<String, dynamic> json) =
      _$WorkspaceImpl.fromJson;

  @override
  String get id;
  @override
  String get tenantId;
  @override
  String get name;
  @override
  String? get description;
  @override
  WorkspaceSettings get settings;
  @override
  DateTime get createdAt;
  @override
  bool get isDeleted;

  /// Create a copy of Workspace
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkspaceImplCopyWith<_$WorkspaceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
