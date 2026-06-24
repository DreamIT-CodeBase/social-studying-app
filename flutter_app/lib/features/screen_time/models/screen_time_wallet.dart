// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'screen_time_wallet.freezed.dart';
part 'screen_time_wallet.g.dart';

@freezed
class ScreenTimeWallet with _$ScreenTimeWallet {
  const factory ScreenTimeWallet({
    @JsonKey(name: 'student_id') @Default('') String studentId,
    @JsonKey(name: 'workspace_id') @Default('') String workspaceId,
    @JsonKey(name: 'total_earned_minutes') @Default(0) int totalEarnedMinutes,
    @JsonKey(name: 'available_minutes') @Default(0) int availableMinutes,
    @JsonKey(name: 'consumed_minutes') @Default(0) int consumedMinutes,
    @JsonKey(name: 'last_known_xp') @Default(0) int lastKnownXp,
    @JsonKey(name: 'last_sync_time') DateTime? lastSyncTime,
    @JsonKey(name: 'consumed_today') @Default(0) int consumedToday,
  }) = _ScreenTimeWallet;

  factory ScreenTimeWallet.fromJson(Map<String, dynamic> json) =>
      _$ScreenTimeWalletFromJson(json);

  static ScreenTimeWallet initial() => ScreenTimeWallet(
        studentId: '',
        workspaceId: '',
        totalEarnedMinutes: 0,
        availableMinutes: 0,
        consumedMinutes: 0,
        lastKnownXp: 0,
        lastSyncTime: DateTime.fromMillisecondsSinceEpoch(0),
        consumedToday: 0,
      );
}
