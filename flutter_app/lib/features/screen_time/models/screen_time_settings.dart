// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'screen_time_settings.freezed.dart';
part 'screen_time_settings.g.dart';

@freezed
class ScreenTimeSettings with _$ScreenTimeSettings {
  const factory ScreenTimeSettings({
    @JsonKey(name: 'workspace_id') required String workspaceId,
    @JsonKey(name: 'enable_blocking') @Default(true) bool enableBlocking,
    @JsonKey(name: 'blocked_packages')
    @Default([])
    List<String> blockedPackages,
    @JsonKey(name: 'xp_to_minute_ratio') @Default(10) int xpToMinuteRatio,
    @JsonKey(name: 'updated_at') required String updatedAt,
  }) = _ScreenTimeSettings;

  factory ScreenTimeSettings.fromJson(Map<String, dynamic> json) =>
      _$ScreenTimeSettingsFromJson(json);
}
