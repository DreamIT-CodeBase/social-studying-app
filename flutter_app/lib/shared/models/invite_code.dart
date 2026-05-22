// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_code.freezed.dart';
part 'invite_code.g.dart';

/// The result of `POST /workspaces/{ws}/invite-codes`.
///
/// Mirrors the backend's response dict `{code, expires_at, max_uses}`
/// from `app.api.workspaces.generate_invite_code`. The admin shares
/// [code] with students, who redeem it via `POST /users/join`.
@freezed
class GeneratedInviteCode with _$GeneratedInviteCode {
  const GeneratedInviteCode._();

  const factory GeneratedInviteCode({
    /// The 8-character uppercase code students type to join.
    required String code,

    /// When the code stops working. `null` means it never expires.
    @JsonKey(name: 'expires_at') DateTime? expiresAt,

    /// How many students may redeem the code. `0` means unlimited.
    @JsonKey(name: 'max_uses') @Default(0) int maxUses,
  }) = _GeneratedInviteCode;

  factory GeneratedInviteCode.fromJson(Map<String, dynamic> json) =>
      _$GeneratedInviteCodeFromJson(json);

  /// Human-readable usage limit for display on the invite-code card.
  String get usageLabel => maxUses == 0 ? 'Unlimited uses' : '$maxUses uses';
}
