// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

WorkspaceMembership _$WorkspaceMembershipFromJson(Map<String, dynamic> json) {
  return _WorkspaceMembership.fromJson(json);
}

/// @nodoc
mixin _$WorkspaceMembership {
  @JsonKey(name: 'workspace_id')
  String get workspaceId => throw _privateConstructorUsedError;
  UserRole get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'workspace_name')
  String? get workspaceName => throw _privateConstructorUsedError;
  @JsonKey(name: 'joined_at')
  DateTime? get joinedAt => throw _privateConstructorUsedError;

  /// Serializes this WorkspaceMembership to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WorkspaceMembership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkspaceMembershipCopyWith<WorkspaceMembership> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkspaceMembershipCopyWith<$Res> {
  factory $WorkspaceMembershipCopyWith(
          WorkspaceMembership value, $Res Function(WorkspaceMembership) then) =
      _$WorkspaceMembershipCopyWithImpl<$Res, WorkspaceMembership>;
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      UserRole role,
      @JsonKey(name: 'workspace_name') String? workspaceName,
      @JsonKey(name: 'joined_at') DateTime? joinedAt});
}

/// @nodoc
class _$WorkspaceMembershipCopyWithImpl<$Res, $Val extends WorkspaceMembership>
    implements $WorkspaceMembershipCopyWith<$Res> {
  _$WorkspaceMembershipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WorkspaceMembership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? role = null,
    Object? workspaceName = freezed,
    Object? joinedAt = freezed,
  }) {
    return _then(_value.copyWith(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as UserRole,
      workspaceName: freezed == workspaceName
          ? _value.workspaceName
          : workspaceName // ignore: cast_nullable_to_non_nullable
              as String?,
      joinedAt: freezed == joinedAt
          ? _value.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WorkspaceMembershipImplCopyWith<$Res>
    implements $WorkspaceMembershipCopyWith<$Res> {
  factory _$$WorkspaceMembershipImplCopyWith(_$WorkspaceMembershipImpl value,
          $Res Function(_$WorkspaceMembershipImpl) then) =
      __$$WorkspaceMembershipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'workspace_id') String workspaceId,
      UserRole role,
      @JsonKey(name: 'workspace_name') String? workspaceName,
      @JsonKey(name: 'joined_at') DateTime? joinedAt});
}

/// @nodoc
class __$$WorkspaceMembershipImplCopyWithImpl<$Res>
    extends _$WorkspaceMembershipCopyWithImpl<$Res, _$WorkspaceMembershipImpl>
    implements _$$WorkspaceMembershipImplCopyWith<$Res> {
  __$$WorkspaceMembershipImplCopyWithImpl(_$WorkspaceMembershipImpl _value,
      $Res Function(_$WorkspaceMembershipImpl) _then)
      : super(_value, _then);

  /// Create a copy of WorkspaceMembership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? workspaceId = null,
    Object? role = null,
    Object? workspaceName = freezed,
    Object? joinedAt = freezed,
  }) {
    return _then(_$WorkspaceMembershipImpl(
      workspaceId: null == workspaceId
          ? _value.workspaceId
          : workspaceId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as UserRole,
      workspaceName: freezed == workspaceName
          ? _value.workspaceName
          : workspaceName // ignore: cast_nullable_to_non_nullable
              as String?,
      joinedAt: freezed == joinedAt
          ? _value.joinedAt
          : joinedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkspaceMembershipImpl implements _WorkspaceMembership {
  const _$WorkspaceMembershipImpl(
      {@JsonKey(name: 'workspace_id') required this.workspaceId,
      required this.role,
      @JsonKey(name: 'workspace_name') this.workspaceName,
      @JsonKey(name: 'joined_at') this.joinedAt});

  factory _$WorkspaceMembershipImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkspaceMembershipImplFromJson(json);

  @override
  @JsonKey(name: 'workspace_id')
  final String workspaceId;
  @override
  final UserRole role;
  @override
  @JsonKey(name: 'workspace_name')
  final String? workspaceName;
  @override
  @JsonKey(name: 'joined_at')
  final DateTime? joinedAt;

  @override
  String toString() {
    return 'WorkspaceMembership(workspaceId: $workspaceId, role: $role, workspaceName: $workspaceName, joinedAt: $joinedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkspaceMembershipImpl &&
            (identical(other.workspaceId, workspaceId) ||
                other.workspaceId == workspaceId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.workspaceName, workspaceName) ||
                other.workspaceName == workspaceName) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, workspaceId, role, workspaceName, joinedAt);

  /// Create a copy of WorkspaceMembership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkspaceMembershipImplCopyWith<_$WorkspaceMembershipImpl> get copyWith =>
      __$$WorkspaceMembershipImplCopyWithImpl<_$WorkspaceMembershipImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkspaceMembershipImplToJson(
      this,
    );
  }
}

abstract class _WorkspaceMembership implements WorkspaceMembership {
  const factory _WorkspaceMembership(
          {@JsonKey(name: 'workspace_id') required final String workspaceId,
          required final UserRole role,
          @JsonKey(name: 'workspace_name') final String? workspaceName,
          @JsonKey(name: 'joined_at') final DateTime? joinedAt}) =
      _$WorkspaceMembershipImpl;

  factory _WorkspaceMembership.fromJson(Map<String, dynamic> json) =
      _$WorkspaceMembershipImpl.fromJson;

  @override
  @JsonKey(name: 'workspace_id')
  String get workspaceId;
  @override
  UserRole get role;
  @override
  @JsonKey(name: 'workspace_name')
  String? get workspaceName;
  @override
  @JsonKey(name: 'joined_at')
  DateTime? get joinedAt;

  /// Create a copy of WorkspaceMembership
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkspaceMembershipImplCopyWith<_$WorkspaceMembershipImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

User _$UserFromJson(Map<String, dynamic> json) {
  return _User.fromJson(json);
}

/// @nodoc
mixin _$User {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_name')
  String get displayName => throw _privateConstructorUsedError;
  @JsonKey(name: 'tenant_id')
  String get tenantId => throw _privateConstructorUsedError;
  UserRole get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'workspace_memberships')
  List<WorkspaceMembership> get workspaceMemberships =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'avatar_url')
  String? get avatarUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'grade_level')
  int? get gradeLevel => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_login_at')
  DateTime? get lastLogin => throw _privateConstructorUsedError;

  /// False once the account has been soft-deleted (`is_active` on the
  /// backend).
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call(
      {String id,
      String email,
      @JsonKey(name: 'display_name') String displayName,
      @JsonKey(name: 'tenant_id') String tenantId,
      UserRole role,
      @JsonKey(name: 'workspace_memberships')
      List<WorkspaceMembership> workspaceMemberships,
      @JsonKey(name: 'avatar_url') String? avatarUrl,
      @JsonKey(name: 'grade_level') int? gradeLevel,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'last_login_at') DateTime? lastLogin,
      @JsonKey(name: 'is_active') bool isActive});
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? displayName = null,
    Object? tenantId = null,
    Object? role = null,
    Object? workspaceMemberships = null,
    Object? avatarUrl = freezed,
    Object? gradeLevel = freezed,
    Object? createdAt = null,
    Object? lastLogin = freezed,
    Object? isActive = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as UserRole,
      workspaceMemberships: null == workspaceMemberships
          ? _value.workspaceMemberships
          : workspaceMemberships // ignore: cast_nullable_to_non_nullable
              as List<WorkspaceMembership>,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      gradeLevel: freezed == gradeLevel
          ? _value.gradeLevel
          : gradeLevel // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastLogin: freezed == lastLogin
          ? _value.lastLogin
          : lastLogin // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
          _$UserImpl value, $Res Function(_$UserImpl) then) =
      __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String email,
      @JsonKey(name: 'display_name') String displayName,
      @JsonKey(name: 'tenant_id') String tenantId,
      UserRole role,
      @JsonKey(name: 'workspace_memberships')
      List<WorkspaceMembership> workspaceMemberships,
      @JsonKey(name: 'avatar_url') String? avatarUrl,
      @JsonKey(name: 'grade_level') int? gradeLevel,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'last_login_at') DateTime? lastLogin,
      @JsonKey(name: 'is_active') bool isActive});
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
      : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? displayName = null,
    Object? tenantId = null,
    Object? role = null,
    Object? workspaceMemberships = null,
    Object? avatarUrl = freezed,
    Object? gradeLevel = freezed,
    Object? createdAt = null,
    Object? lastLogin = freezed,
    Object? isActive = null,
  }) {
    return _then(_$UserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as UserRole,
      workspaceMemberships: null == workspaceMemberships
          ? _value._workspaceMemberships
          : workspaceMemberships // ignore: cast_nullable_to_non_nullable
              as List<WorkspaceMembership>,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      gradeLevel: freezed == gradeLevel
          ? _value.gradeLevel
          : gradeLevel // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastLogin: freezed == lastLogin
          ? _value.lastLogin
          : lastLogin // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserImpl implements _User {
  const _$UserImpl(
      {required this.id,
      required this.email,
      @JsonKey(name: 'display_name') required this.displayName,
      @JsonKey(name: 'tenant_id') required this.tenantId,
      required this.role,
      @JsonKey(name: 'workspace_memberships')
      final List<WorkspaceMembership> workspaceMemberships =
          const <WorkspaceMembership>[],
      @JsonKey(name: 'avatar_url') this.avatarUrl,
      @JsonKey(name: 'grade_level') this.gradeLevel,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'last_login_at') this.lastLogin,
      @JsonKey(name: 'is_active') this.isActive = true})
      : _workspaceMemberships = workspaceMemberships;

  factory _$UserImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserImplFromJson(json);

  @override
  final String id;
  @override
  final String email;
  @override
  @JsonKey(name: 'display_name')
  final String displayName;
  @override
  @JsonKey(name: 'tenant_id')
  final String tenantId;
  @override
  final UserRole role;
  final List<WorkspaceMembership> _workspaceMemberships;
  @override
  @JsonKey(name: 'workspace_memberships')
  List<WorkspaceMembership> get workspaceMemberships {
    if (_workspaceMemberships is EqualUnmodifiableListView)
      return _workspaceMemberships;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_workspaceMemberships);
  }

  @override
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @override
  @JsonKey(name: 'grade_level')
  final int? gradeLevel;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'last_login_at')
  final DateTime? lastLogin;

  /// False once the account has been soft-deleted (`is_active` on the
  /// backend).
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName, tenantId: $tenantId, role: $role, workspaceMemberships: $workspaceMemberships, avatarUrl: $avatarUrl, gradeLevel: $gradeLevel, createdAt: $createdAt, lastLogin: $lastLogin, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.role, role) || other.role == role) &&
            const DeepCollectionEquality()
                .equals(other._workspaceMemberships, _workspaceMemberships) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.gradeLevel, gradeLevel) ||
                other.gradeLevel == gradeLevel) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastLogin, lastLogin) ||
                other.lastLogin == lastLogin) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      email,
      displayName,
      tenantId,
      role,
      const DeepCollectionEquality().hash(_workspaceMemberships),
      avatarUrl,
      gradeLevel,
      createdAt,
      lastLogin,
      isActive);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserImplToJson(
      this,
    );
  }
}

abstract class _User implements User {
  const factory _User(
      {required final String id,
      required final String email,
      @JsonKey(name: 'display_name') required final String displayName,
      @JsonKey(name: 'tenant_id') required final String tenantId,
      required final UserRole role,
      @JsonKey(name: 'workspace_memberships')
      final List<WorkspaceMembership> workspaceMemberships,
      @JsonKey(name: 'avatar_url') final String? avatarUrl,
      @JsonKey(name: 'grade_level') final int? gradeLevel,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'last_login_at') final DateTime? lastLogin,
      @JsonKey(name: 'is_active') final bool isActive}) = _$UserImpl;

  factory _User.fromJson(Map<String, dynamic> json) = _$UserImpl.fromJson;

  @override
  String get id;
  @override
  String get email;
  @override
  @JsonKey(name: 'display_name')
  String get displayName;
  @override
  @JsonKey(name: 'tenant_id')
  String get tenantId;
  @override
  UserRole get role;
  @override
  @JsonKey(name: 'workspace_memberships')
  List<WorkspaceMembership> get workspaceMemberships;
  @override
  @JsonKey(name: 'avatar_url')
  String? get avatarUrl;
  @override
  @JsonKey(name: 'grade_level')
  int? get gradeLevel;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'last_login_at')
  DateTime? get lastLogin;

  /// False once the account has been soft-deleted (`is_active` on the
  /// backend).
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
