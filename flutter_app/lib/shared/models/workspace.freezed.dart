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
  /// How many questions a student is expected to answer per day.
  @JsonKey(name: 'questions_per_day')
  int get questionsPerDay => throw _privateConstructorUsedError;

  /// Which question formats the generator may produce. Values are the
  /// snake_case `QuestionType` wire strings (`mcq`, `short_answer`, …).
  @JsonKey(name: 'question_types')
  List<String> get questionTypes => throw _privateConstructorUsedError;

  /// When true, AI-generated content that passes safety is auto-served;
  /// when false it lands in the moderation queue for admin review.
  @JsonKey(name: 'auto_approve_content')
  bool get autoApproveContent => throw _privateConstructorUsedError;

  /// Whether the workspace leaderboard is visible to students.
  @JsonKey(name: 'leaderboard_visible')
  bool get leaderboardVisible => throw _privateConstructorUsedError;

  /// Whether difficulty calibration adapts to each student's mastery.
  @JsonKey(name: 'adaptive_difficulty')
  bool get adaptiveDifficulty => throw _privateConstructorUsedError;

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
      {@JsonKey(name: 'questions_per_day') int questionsPerDay,
      @JsonKey(name: 'question_types') List<String> questionTypes,
      @JsonKey(name: 'auto_approve_content') bool autoApproveContent,
      @JsonKey(name: 'leaderboard_visible') bool leaderboardVisible,
      @JsonKey(name: 'adaptive_difficulty') bool adaptiveDifficulty});
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
    Object? questionsPerDay = null,
    Object? questionTypes = null,
    Object? autoApproveContent = null,
    Object? leaderboardVisible = null,
    Object? adaptiveDifficulty = null,
  }) {
    return _then(_value.copyWith(
      questionsPerDay: null == questionsPerDay
          ? _value.questionsPerDay
          : questionsPerDay // ignore: cast_nullable_to_non_nullable
              as int,
      questionTypes: null == questionTypes
          ? _value.questionTypes
          : questionTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      autoApproveContent: null == autoApproveContent
          ? _value.autoApproveContent
          : autoApproveContent // ignore: cast_nullable_to_non_nullable
              as bool,
      leaderboardVisible: null == leaderboardVisible
          ? _value.leaderboardVisible
          : leaderboardVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      adaptiveDifficulty: null == adaptiveDifficulty
          ? _value.adaptiveDifficulty
          : adaptiveDifficulty // ignore: cast_nullable_to_non_nullable
              as bool,
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
      {@JsonKey(name: 'questions_per_day') int questionsPerDay,
      @JsonKey(name: 'question_types') List<String> questionTypes,
      @JsonKey(name: 'auto_approve_content') bool autoApproveContent,
      @JsonKey(name: 'leaderboard_visible') bool leaderboardVisible,
      @JsonKey(name: 'adaptive_difficulty') bool adaptiveDifficulty});
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
    Object? questionsPerDay = null,
    Object? questionTypes = null,
    Object? autoApproveContent = null,
    Object? leaderboardVisible = null,
    Object? adaptiveDifficulty = null,
  }) {
    return _then(_$WorkspaceSettingsImpl(
      questionsPerDay: null == questionsPerDay
          ? _value.questionsPerDay
          : questionsPerDay // ignore: cast_nullable_to_non_nullable
              as int,
      questionTypes: null == questionTypes
          ? _value._questionTypes
          : questionTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      autoApproveContent: null == autoApproveContent
          ? _value.autoApproveContent
          : autoApproveContent // ignore: cast_nullable_to_non_nullable
              as bool,
      leaderboardVisible: null == leaderboardVisible
          ? _value.leaderboardVisible
          : leaderboardVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      adaptiveDifficulty: null == adaptiveDifficulty
          ? _value.adaptiveDifficulty
          : adaptiveDifficulty // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkspaceSettingsImpl implements _WorkspaceSettings {
  const _$WorkspaceSettingsImpl(
      {@JsonKey(name: 'questions_per_day') this.questionsPerDay = 5,
      @JsonKey(name: 'question_types')
      final List<String> questionTypes = const <String>['mcq', 'short_answer'],
      @JsonKey(name: 'auto_approve_content') this.autoApproveContent = true,
      @JsonKey(name: 'leaderboard_visible') this.leaderboardVisible = true,
      @JsonKey(name: 'adaptive_difficulty') this.adaptiveDifficulty = true})
      : _questionTypes = questionTypes;

  factory _$WorkspaceSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkspaceSettingsImplFromJson(json);

  /// How many questions a student is expected to answer per day.
  @override
  @JsonKey(name: 'questions_per_day')
  final int questionsPerDay;

  /// Which question formats the generator may produce. Values are the
  /// snake_case `QuestionType` wire strings (`mcq`, `short_answer`, …).
  final List<String> _questionTypes;

  /// Which question formats the generator may produce. Values are the
  /// snake_case `QuestionType` wire strings (`mcq`, `short_answer`, …).
  @override
  @JsonKey(name: 'question_types')
  List<String> get questionTypes {
    if (_questionTypes is EqualUnmodifiableListView) return _questionTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_questionTypes);
  }

  /// When true, AI-generated content that passes safety is auto-served;
  /// when false it lands in the moderation queue for admin review.
  @override
  @JsonKey(name: 'auto_approve_content')
  final bool autoApproveContent;

  /// Whether the workspace leaderboard is visible to students.
  @override
  @JsonKey(name: 'leaderboard_visible')
  final bool leaderboardVisible;

  /// Whether difficulty calibration adapts to each student's mastery.
  @override
  @JsonKey(name: 'adaptive_difficulty')
  final bool adaptiveDifficulty;

  @override
  String toString() {
    return 'WorkspaceSettings(questionsPerDay: $questionsPerDay, questionTypes: $questionTypes, autoApproveContent: $autoApproveContent, leaderboardVisible: $leaderboardVisible, adaptiveDifficulty: $adaptiveDifficulty)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkspaceSettingsImpl &&
            (identical(other.questionsPerDay, questionsPerDay) ||
                other.questionsPerDay == questionsPerDay) &&
            const DeepCollectionEquality()
                .equals(other._questionTypes, _questionTypes) &&
            (identical(other.autoApproveContent, autoApproveContent) ||
                other.autoApproveContent == autoApproveContent) &&
            (identical(other.leaderboardVisible, leaderboardVisible) ||
                other.leaderboardVisible == leaderboardVisible) &&
            (identical(other.adaptiveDifficulty, adaptiveDifficulty) ||
                other.adaptiveDifficulty == adaptiveDifficulty));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      questionsPerDay,
      const DeepCollectionEquality().hash(_questionTypes),
      autoApproveContent,
      leaderboardVisible,
      adaptiveDifficulty);

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
      {@JsonKey(name: 'questions_per_day') final int questionsPerDay,
      @JsonKey(name: 'question_types') final List<String> questionTypes,
      @JsonKey(name: 'auto_approve_content') final bool autoApproveContent,
      @JsonKey(name: 'leaderboard_visible') final bool leaderboardVisible,
      @JsonKey(name: 'adaptive_difficulty')
      final bool adaptiveDifficulty}) = _$WorkspaceSettingsImpl;

  factory _WorkspaceSettings.fromJson(Map<String, dynamic> json) =
      _$WorkspaceSettingsImpl.fromJson;

  /// How many questions a student is expected to answer per day.
  @override
  @JsonKey(name: 'questions_per_day')
  int get questionsPerDay;

  /// Which question formats the generator may produce. Values are the
  /// snake_case `QuestionType` wire strings (`mcq`, `short_answer`, …).
  @override
  @JsonKey(name: 'question_types')
  List<String> get questionTypes;

  /// When true, AI-generated content that passes safety is auto-served;
  /// when false it lands in the moderation queue for admin review.
  @override
  @JsonKey(name: 'auto_approve_content')
  bool get autoApproveContent;

  /// Whether the workspace leaderboard is visible to students.
  @override
  @JsonKey(name: 'leaderboard_visible')
  bool get leaderboardVisible;

  /// Whether difficulty calibration adapts to each student's mastery.
  @override
  @JsonKey(name: 'adaptive_difficulty')
  bool get adaptiveDifficulty;

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
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;

  /// Number of workspace admins (teachers / parents).
  @JsonKey(name: 'admin_count')
  int get adminCount => throw _privateConstructorUsedError;

  /// Number of enrolled students.
  @JsonKey(name: 'student_count')
  int get studentCount => throw _privateConstructorUsedError;

  /// Number of uploaded study documents.
  @JsonKey(name: 'document_count')
  int get documentCount => throw _privateConstructorUsedError;
  WorkspaceSettings get settings => throw _privateConstructorUsedError;

  /// False once the workspace has been soft-deleted.
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

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
      @JsonKey(name: 'tenant_id') String tenantId,
      String name,
      String description,
      @JsonKey(name: 'admin_count') int adminCount,
      @JsonKey(name: 'student_count') int studentCount,
      @JsonKey(name: 'document_count') int documentCount,
      WorkspaceSettings settings,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'created_at') DateTime createdAt});

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
    Object? description = null,
    Object? adminCount = null,
    Object? studentCount = null,
    Object? documentCount = null,
    Object? settings = null,
    Object? isActive = null,
    Object? createdAt = null,
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
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      adminCount: null == adminCount
          ? _value.adminCount
          : adminCount // ignore: cast_nullable_to_non_nullable
              as int,
      studentCount: null == studentCount
          ? _value.studentCount
          : studentCount // ignore: cast_nullable_to_non_nullable
              as int,
      documentCount: null == documentCount
          ? _value.documentCount
          : documentCount // ignore: cast_nullable_to_non_nullable
              as int,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as WorkspaceSettings,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
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
      @JsonKey(name: 'tenant_id') String tenantId,
      String name,
      String description,
      @JsonKey(name: 'admin_count') int adminCount,
      @JsonKey(name: 'student_count') int studentCount,
      @JsonKey(name: 'document_count') int documentCount,
      WorkspaceSettings settings,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'created_at') DateTime createdAt});

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
    Object? description = null,
    Object? adminCount = null,
    Object? studentCount = null,
    Object? documentCount = null,
    Object? settings = null,
    Object? isActive = null,
    Object? createdAt = null,
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
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      adminCount: null == adminCount
          ? _value.adminCount
          : adminCount // ignore: cast_nullable_to_non_nullable
              as int,
      studentCount: null == studentCount
          ? _value.studentCount
          : studentCount // ignore: cast_nullable_to_non_nullable
              as int,
      documentCount: null == documentCount
          ? _value.documentCount
          : documentCount // ignore: cast_nullable_to_non_nullable
              as int,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as WorkspaceSettings,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkspaceImpl implements _Workspace {
  const _$WorkspaceImpl(
      {required this.id,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      required this.name,
      this.description = '',
      @JsonKey(name: 'admin_count') this.adminCount = 0,
      @JsonKey(name: 'student_count') this.studentCount = 0,
      @JsonKey(name: 'document_count') this.documentCount = 0,
      required this.settings,
      @JsonKey(name: 'is_active') this.isActive = true,
      @JsonKey(name: 'created_at') required this.createdAt});

  factory _$WorkspaceImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkspaceImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @override
  final String name;
  @override
  @JsonKey()
  final String description;

  /// Number of workspace admins (teachers / parents).
  @override
  @JsonKey(name: 'admin_count')
  final int adminCount;

  /// Number of enrolled students.
  @override
  @JsonKey(name: 'student_count')
  final int studentCount;

  /// Number of uploaded study documents.
  @override
  @JsonKey(name: 'document_count')
  final int documentCount;
  @override
  final WorkspaceSettings settings;

  /// False once the workspace has been soft-deleted.
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'Workspace(id: $id, tenantId: $tenantId, name: $name, description: $description, adminCount: $adminCount, studentCount: $studentCount, documentCount: $documentCount, settings: $settings, isActive: $isActive, createdAt: $createdAt)';
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
            (identical(other.adminCount, adminCount) ||
                other.adminCount == adminCount) &&
            (identical(other.studentCount, studentCount) ||
                other.studentCount == studentCount) &&
            (identical(other.documentCount, documentCount) ||
                other.documentCount == documentCount) &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, tenantId, name, description,
      adminCount, studentCount, documentCount, settings, isActive, createdAt);

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
          @JsonKey(name: 'tenant_id') required final String tenantId,
          required final String name,
          final String description,
          @JsonKey(name: 'admin_count') final int adminCount,
          @JsonKey(name: 'student_count') final int studentCount,
          @JsonKey(name: 'document_count') final int documentCount,
          required final WorkspaceSettings settings,
          @JsonKey(name: 'is_active') final bool isActive,
          @JsonKey(name: 'created_at') required final DateTime createdAt}) =
      _$WorkspaceImpl;

  factory _Workspace.fromJson(Map<String, dynamic> json) =
      _$WorkspaceImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'tenant_id')
  String get tenantId;
  @override
  String get name;
  @override
  String get description;

  /// Number of workspace admins (teachers / parents).
  @override
  @JsonKey(name: 'admin_count')
  int get adminCount;

  /// Number of enrolled students.
  @override
  @JsonKey(name: 'student_count')
  int get studentCount;

  /// Number of uploaded study documents.
  @override
  @JsonKey(name: 'document_count')
  int get documentCount;
  @override
  WorkspaceSettings get settings;

  /// False once the workspace has been soft-deleted.
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of Workspace
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkspaceImplCopyWith<_$WorkspaceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
