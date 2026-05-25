// JsonKey on constructor params (Freezed pattern) trips the analyzer's
// invalid_annotation_target lint falsely. The model works at runtime —
// JsonSerializable picks up the keys correctly.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_token.freezed.dart';
part 'notification_token.g.dart';

/// Wire shapes for the Sprint 5.7 notification-token endpoints.
///
/// Field names mirror ``backend/app/api/notifications.py``. Keep in
/// sync with the Pydantic models there — when a field is renamed
/// on the backend, this file is the source of truth on the Flutter
/// side.

/// The Flutter app supports two platforms today. ``ios`` ships in the
/// iOS submission sprint; Android is the MVP target.
enum DevicePlatform {
  @JsonValue('android')
  android,
  @JsonValue('ios')
  ios,
}

/// Request body for ``POST /users/me/notification-tokens``.
@freezed
class NotificationTokenRegistration with _$NotificationTokenRegistration {
  const factory NotificationTokenRegistration({
    @JsonKey(name: 'installation_id') required String installationId,
    required String token,
    required DevicePlatform platform,
  }) = _NotificationTokenRegistration;

  factory NotificationTokenRegistration.fromJson(Map<String, dynamic> json) =>
      _$NotificationTokenRegistrationFromJson(json);
}

/// Response body — the backend echoes back the persisted row so the
/// Flutter side can verify the heartbeat actually landed.
@freezed
class NotificationTokenResponse with _$NotificationTokenResponse {
  const factory NotificationTokenResponse({
    @JsonKey(name: 'installation_id') required String installationId,
    required String token,
    required DevicePlatform platform,
    @JsonKey(name: 'registered_at') required String registeredAt,
    @JsonKey(name: 'last_seen_at') required String lastSeenAt,
  }) = _NotificationTokenResponse;

  factory NotificationTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$NotificationTokenResponseFromJson(json);
}
