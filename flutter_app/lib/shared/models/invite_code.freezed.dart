// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invite_code.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

GeneratedInviteCode _$GeneratedInviteCodeFromJson(Map<String, dynamic> json) {
  return _GeneratedInviteCode.fromJson(json);
}

/// @nodoc
mixin _$GeneratedInviteCode {
  /// The 8-character uppercase code students type to join.
  String get code => throw _privateConstructorUsedError;

  /// When the code stops working. `null` means it never expires.
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt => throw _privateConstructorUsedError;

  /// How many students may redeem the code. `0` means unlimited.
  @JsonKey(name: 'max_uses')
  int get maxUses => throw _privateConstructorUsedError;

  /// Serializes this GeneratedInviteCode to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GeneratedInviteCode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GeneratedInviteCodeCopyWith<GeneratedInviteCode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GeneratedInviteCodeCopyWith<$Res> {
  factory $GeneratedInviteCodeCopyWith(
          GeneratedInviteCode value, $Res Function(GeneratedInviteCode) then) =
      _$GeneratedInviteCodeCopyWithImpl<$Res, GeneratedInviteCode>;
  @useResult
  $Res call(
      {String code,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'max_uses') int maxUses});
}

/// @nodoc
class _$GeneratedInviteCodeCopyWithImpl<$Res, $Val extends GeneratedInviteCode>
    implements $GeneratedInviteCodeCopyWith<$Res> {
  _$GeneratedInviteCodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GeneratedInviteCode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? expiresAt = freezed,
    Object? maxUses = null,
  }) {
    return _then(_value.copyWith(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      maxUses: null == maxUses
          ? _value.maxUses
          : maxUses // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GeneratedInviteCodeImplCopyWith<$Res>
    implements $GeneratedInviteCodeCopyWith<$Res> {
  factory _$$GeneratedInviteCodeImplCopyWith(_$GeneratedInviteCodeImpl value,
          $Res Function(_$GeneratedInviteCodeImpl) then) =
      __$$GeneratedInviteCodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String code,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      @JsonKey(name: 'max_uses') int maxUses});
}

/// @nodoc
class __$$GeneratedInviteCodeImplCopyWithImpl<$Res>
    extends _$GeneratedInviteCodeCopyWithImpl<$Res, _$GeneratedInviteCodeImpl>
    implements _$$GeneratedInviteCodeImplCopyWith<$Res> {
  __$$GeneratedInviteCodeImplCopyWithImpl(_$GeneratedInviteCodeImpl _value,
      $Res Function(_$GeneratedInviteCodeImpl) _then)
      : super(_value, _then);

  /// Create a copy of GeneratedInviteCode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? expiresAt = freezed,
    Object? maxUses = null,
  }) {
    return _then(_$GeneratedInviteCodeImpl(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      maxUses: null == maxUses
          ? _value.maxUses
          : maxUses // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GeneratedInviteCodeImpl extends _GeneratedInviteCode {
  const _$GeneratedInviteCodeImpl(
      {required this.code,
      @JsonKey(name: 'expires_at') this.expiresAt,
      @JsonKey(name: 'max_uses') this.maxUses = 0})
      : super._();

  factory _$GeneratedInviteCodeImpl.fromJson(Map<String, dynamic> json) =>
      _$$GeneratedInviteCodeImplFromJson(json);

  /// The 8-character uppercase code students type to join.
  @override
  final String code;

  /// When the code stops working. `null` means it never expires.
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  /// How many students may redeem the code. `0` means unlimited.
  @override
  @JsonKey(name: 'max_uses')
  final int maxUses;

  @override
  String toString() {
    return 'GeneratedInviteCode(code: $code, expiresAt: $expiresAt, maxUses: $maxUses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GeneratedInviteCodeImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.maxUses, maxUses) || other.maxUses == maxUses));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, code, expiresAt, maxUses);

  /// Create a copy of GeneratedInviteCode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GeneratedInviteCodeImplCopyWith<_$GeneratedInviteCodeImpl> get copyWith =>
      __$$GeneratedInviteCodeImplCopyWithImpl<_$GeneratedInviteCodeImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GeneratedInviteCodeImplToJson(
      this,
    );
  }
}

abstract class _GeneratedInviteCode extends GeneratedInviteCode {
  const factory _GeneratedInviteCode(
          {required final String code,
          @JsonKey(name: 'expires_at') final DateTime? expiresAt,
          @JsonKey(name: 'max_uses') final int maxUses}) =
      _$GeneratedInviteCodeImpl;
  const _GeneratedInviteCode._() : super._();

  factory _GeneratedInviteCode.fromJson(Map<String, dynamic> json) =
      _$GeneratedInviteCodeImpl.fromJson;

  /// The 8-character uppercase code students type to join.
  @override
  String get code;

  /// When the code stops working. `null` means it never expires.
  @override
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;

  /// How many students may redeem the code. `0` means unlimited.
  @override
  @JsonKey(name: 'max_uses')
  int get maxUses;

  /// Create a copy of GeneratedInviteCode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GeneratedInviteCodeImplCopyWith<_$GeneratedInviteCodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
