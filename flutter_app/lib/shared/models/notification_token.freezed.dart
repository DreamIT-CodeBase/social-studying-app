// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_token.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NotificationTokenRegistration _$NotificationTokenRegistrationFromJson(
    Map<String, dynamic> json) {
  return _NotificationTokenRegistration.fromJson(json);
}

/// @nodoc
mixin _$NotificationTokenRegistration {
  @JsonKey(name: 'installation_id')
  String get installationId => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;
  DevicePlatform get platform => throw _privateConstructorUsedError;

  /// Serializes this NotificationTokenRegistration to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationTokenRegistration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationTokenRegistrationCopyWith<NotificationTokenRegistration>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationTokenRegistrationCopyWith<$Res> {
  factory $NotificationTokenRegistrationCopyWith(
          NotificationTokenRegistration value,
          $Res Function(NotificationTokenRegistration) then) =
      _$NotificationTokenRegistrationCopyWithImpl<$Res,
          NotificationTokenRegistration>;
  @useResult
  $Res call(
      {@JsonKey(name: 'installation_id') String installationId,
      String token,
      DevicePlatform platform});
}

/// @nodoc
class _$NotificationTokenRegistrationCopyWithImpl<$Res,
        $Val extends NotificationTokenRegistration>
    implements $NotificationTokenRegistrationCopyWith<$Res> {
  _$NotificationTokenRegistrationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationTokenRegistration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? installationId = null,
    Object? token = null,
    Object? platform = null,
  }) {
    return _then(_value.copyWith(
      installationId: null == installationId
          ? _value.installationId
          : installationId // ignore: cast_nullable_to_non_nullable
              as String,
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as DevicePlatform,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NotificationTokenRegistrationImplCopyWith<$Res>
    implements $NotificationTokenRegistrationCopyWith<$Res> {
  factory _$$NotificationTokenRegistrationImplCopyWith(
          _$NotificationTokenRegistrationImpl value,
          $Res Function(_$NotificationTokenRegistrationImpl) then) =
      __$$NotificationTokenRegistrationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'installation_id') String installationId,
      String token,
      DevicePlatform platform});
}

/// @nodoc
class __$$NotificationTokenRegistrationImplCopyWithImpl<$Res>
    extends _$NotificationTokenRegistrationCopyWithImpl<$Res,
        _$NotificationTokenRegistrationImpl>
    implements _$$NotificationTokenRegistrationImplCopyWith<$Res> {
  __$$NotificationTokenRegistrationImplCopyWithImpl(
      _$NotificationTokenRegistrationImpl _value,
      $Res Function(_$NotificationTokenRegistrationImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationTokenRegistration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? installationId = null,
    Object? token = null,
    Object? platform = null,
  }) {
    return _then(_$NotificationTokenRegistrationImpl(
      installationId: null == installationId
          ? _value.installationId
          : installationId // ignore: cast_nullable_to_non_nullable
              as String,
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as DevicePlatform,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationTokenRegistrationImpl
    implements _NotificationTokenRegistration {
  const _$NotificationTokenRegistrationImpl(
      {@JsonKey(name: 'installation_id') required this.installationId,
      required this.token,
      required this.platform});

  factory _$NotificationTokenRegistrationImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$NotificationTokenRegistrationImplFromJson(json);

  @override
  @JsonKey(name: 'installation_id')
  final String installationId;
  @override
  final String token;
  @override
  final DevicePlatform platform;

  @override
  String toString() {
    return 'NotificationTokenRegistration(installationId: $installationId, token: $token, platform: $platform)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationTokenRegistrationImpl &&
            (identical(other.installationId, installationId) ||
                other.installationId == installationId) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.platform, platform) ||
                other.platform == platform));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, installationId, token, platform);

  /// Create a copy of NotificationTokenRegistration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationTokenRegistrationImplCopyWith<
          _$NotificationTokenRegistrationImpl>
      get copyWith => __$$NotificationTokenRegistrationImplCopyWithImpl<
          _$NotificationTokenRegistrationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationTokenRegistrationImplToJson(
      this,
    );
  }
}

abstract class _NotificationTokenRegistration
    implements NotificationTokenRegistration {
  const factory _NotificationTokenRegistration(
      {@JsonKey(name: 'installation_id') required final String installationId,
      required final String token,
      required final DevicePlatform
          platform}) = _$NotificationTokenRegistrationImpl;

  factory _NotificationTokenRegistration.fromJson(Map<String, dynamic> json) =
      _$NotificationTokenRegistrationImpl.fromJson;

  @override
  @JsonKey(name: 'installation_id')
  String get installationId;
  @override
  String get token;
  @override
  DevicePlatform get platform;

  /// Create a copy of NotificationTokenRegistration
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationTokenRegistrationImplCopyWith<
          _$NotificationTokenRegistrationImpl>
      get copyWith => throw _privateConstructorUsedError;
}

NotificationTokenResponse _$NotificationTokenResponseFromJson(
    Map<String, dynamic> json) {
  return _NotificationTokenResponse.fromJson(json);
}

/// @nodoc
mixin _$NotificationTokenResponse {
  @JsonKey(name: 'installation_id')
  String get installationId => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;
  DevicePlatform get platform => throw _privateConstructorUsedError;
  @JsonKey(name: 'registered_at')
  String get registeredAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_seen_at')
  String get lastSeenAt => throw _privateConstructorUsedError;

  /// Serializes this NotificationTokenResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationTokenResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationTokenResponseCopyWith<NotificationTokenResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationTokenResponseCopyWith<$Res> {
  factory $NotificationTokenResponseCopyWith(NotificationTokenResponse value,
          $Res Function(NotificationTokenResponse) then) =
      _$NotificationTokenResponseCopyWithImpl<$Res, NotificationTokenResponse>;
  @useResult
  $Res call(
      {@JsonKey(name: 'installation_id') String installationId,
      String token,
      DevicePlatform platform,
      @JsonKey(name: 'registered_at') String registeredAt,
      @JsonKey(name: 'last_seen_at') String lastSeenAt});
}

/// @nodoc
class _$NotificationTokenResponseCopyWithImpl<$Res,
        $Val extends NotificationTokenResponse>
    implements $NotificationTokenResponseCopyWith<$Res> {
  _$NotificationTokenResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationTokenResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? installationId = null,
    Object? token = null,
    Object? platform = null,
    Object? registeredAt = null,
    Object? lastSeenAt = null,
  }) {
    return _then(_value.copyWith(
      installationId: null == installationId
          ? _value.installationId
          : installationId // ignore: cast_nullable_to_non_nullable
              as String,
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as DevicePlatform,
      registeredAt: null == registeredAt
          ? _value.registeredAt
          : registeredAt // ignore: cast_nullable_to_non_nullable
              as String,
      lastSeenAt: null == lastSeenAt
          ? _value.lastSeenAt
          : lastSeenAt // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NotificationTokenResponseImplCopyWith<$Res>
    implements $NotificationTokenResponseCopyWith<$Res> {
  factory _$$NotificationTokenResponseImplCopyWith(
          _$NotificationTokenResponseImpl value,
          $Res Function(_$NotificationTokenResponseImpl) then) =
      __$$NotificationTokenResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'installation_id') String installationId,
      String token,
      DevicePlatform platform,
      @JsonKey(name: 'registered_at') String registeredAt,
      @JsonKey(name: 'last_seen_at') String lastSeenAt});
}

/// @nodoc
class __$$NotificationTokenResponseImplCopyWithImpl<$Res>
    extends _$NotificationTokenResponseCopyWithImpl<$Res,
        _$NotificationTokenResponseImpl>
    implements _$$NotificationTokenResponseImplCopyWith<$Res> {
  __$$NotificationTokenResponseImplCopyWithImpl(
      _$NotificationTokenResponseImpl _value,
      $Res Function(_$NotificationTokenResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationTokenResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? installationId = null,
    Object? token = null,
    Object? platform = null,
    Object? registeredAt = null,
    Object? lastSeenAt = null,
  }) {
    return _then(_$NotificationTokenResponseImpl(
      installationId: null == installationId
          ? _value.installationId
          : installationId // ignore: cast_nullable_to_non_nullable
              as String,
      token: null == token
          ? _value.token
          : token // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as DevicePlatform,
      registeredAt: null == registeredAt
          ? _value.registeredAt
          : registeredAt // ignore: cast_nullable_to_non_nullable
              as String,
      lastSeenAt: null == lastSeenAt
          ? _value.lastSeenAt
          : lastSeenAt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationTokenResponseImpl implements _NotificationTokenResponse {
  const _$NotificationTokenResponseImpl(
      {@JsonKey(name: 'installation_id') required this.installationId,
      required this.token,
      required this.platform,
      @JsonKey(name: 'registered_at') required this.registeredAt,
      @JsonKey(name: 'last_seen_at') required this.lastSeenAt});

  factory _$NotificationTokenResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationTokenResponseImplFromJson(json);

  @override
  @JsonKey(name: 'installation_id')
  final String installationId;
  @override
  final String token;
  @override
  final DevicePlatform platform;
  @override
  @JsonKey(name: 'registered_at')
  final String registeredAt;
  @override
  @JsonKey(name: 'last_seen_at')
  final String lastSeenAt;

  @override
  String toString() {
    return 'NotificationTokenResponse(installationId: $installationId, token: $token, platform: $platform, registeredAt: $registeredAt, lastSeenAt: $lastSeenAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationTokenResponseImpl &&
            (identical(other.installationId, installationId) ||
                other.installationId == installationId) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.registeredAt, registeredAt) ||
                other.registeredAt == registeredAt) &&
            (identical(other.lastSeenAt, lastSeenAt) ||
                other.lastSeenAt == lastSeenAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, installationId, token, platform, registeredAt, lastSeenAt);

  /// Create a copy of NotificationTokenResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationTokenResponseImplCopyWith<_$NotificationTokenResponseImpl>
      get copyWith => __$$NotificationTokenResponseImplCopyWithImpl<
          _$NotificationTokenResponseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationTokenResponseImplToJson(
      this,
    );
  }
}

abstract class _NotificationTokenResponse implements NotificationTokenResponse {
  const factory _NotificationTokenResponse(
      {@JsonKey(name: 'installation_id') required final String installationId,
      required final String token,
      required final DevicePlatform platform,
      @JsonKey(name: 'registered_at') required final String registeredAt,
      @JsonKey(name: 'last_seen_at')
      required final String lastSeenAt}) = _$NotificationTokenResponseImpl;

  factory _NotificationTokenResponse.fromJson(Map<String, dynamic> json) =
      _$NotificationTokenResponseImpl.fromJson;

  @override
  @JsonKey(name: 'installation_id')
  String get installationId;
  @override
  String get token;
  @override
  DevicePlatform get platform;
  @override
  @JsonKey(name: 'registered_at')
  String get registeredAt;
  @override
  @JsonKey(name: 'last_seen_at')
  String get lastSeenAt;

  /// Create a copy of NotificationTokenResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationTokenResponseImplCopyWith<_$NotificationTokenResponseImpl>
      get copyWith => throw _privateConstructorUsedError;
}
