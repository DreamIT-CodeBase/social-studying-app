import 'package:social_study_app/features/screen_time/data/screen_time_repository.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_settings.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';
import 'package:social_study_app/features/screen_time/models/student_device_status.dart';

class DemoScreenTimeRepository implements ScreenTimeRepository {
  DemoScreenTimeRepository();

  ScreenTimeSettings _settings = ScreenTimeSettings(
    workspaceId: 'wsp_demo',
    enableBlocking: true,
    blockedPackages: [
      'com.instagram.android',
      'com.zhiliaoapp.musically',
      'com.google.android.youtube',
      'com.facebook.katana',
      'com.twitter.android',
      'com.snapchat.android',
    ],
    xpToMinuteRatio: 10,
    updatedAt: DateTime.now().toIso8601String(),
  );

  ScreenTimeWallet _wallet = ScreenTimeWallet(
    studentId: 'usr_demo_001',
    workspaceId: 'wsp_demo',
    totalEarnedMinutes: 48,
    availableMinutes: 15,
    consumedMinutes: 33,
    consumedToday: 5,
    lastKnownXp: 480,
    lastSyncTime: DateTime.now().subtract(const Duration(hours: 1)),
  );

  @override
  Future<ScreenTimeSettings> fetchSettings(
      {required String workspaceId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _settings;
  }

  @override
  Future<ScreenTimeSettings> updateSettings({
    required String workspaceId,
    bool? enableBlocking,
    List<String>? blockedPackages,
    int? xpToMinuteRatio,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _settings = _settings.copyWith(
      enableBlocking: enableBlocking ?? _settings.enableBlocking,
      blockedPackages: blockedPackages ?? _settings.blockedPackages,
      xpToMinuteRatio: xpToMinuteRatio ?? _settings.xpToMinuteRatio,
      updatedAt: DateTime.now().toIso8601String(),
    );
    return _settings;
  }

  @override
  Future<ScreenTimeWallet> fetchWallet({required String workspaceId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _wallet;
  }

  @override
  Future<ScreenTimeWallet> consumeMinutes({
    required String workspaceId,
    required int minutes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final newAvailable = (_wallet.availableMinutes - minutes).clamp(0, 999999);
    _wallet = _wallet.copyWith(
      availableMinutes: newAvailable,
      consumedMinutes: _wallet.consumedMinutes + minutes,
      consumedToday: _wallet.consumedToday + minutes,
      lastSyncTime: DateTime.now(),
    );
    return _wallet;
  }

  @override
  Future<ScreenTimeWallet> syncXp({required String workspaceId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _wallet;
  }

  @override
  Future<List<StudentDeviceStatus>> fetchDeviceStatuses({
    required String workspaceId,
  }) async {
    return [
      StudentDeviceStatus(
        studentId: _wallet.studentId,
        displayName: 'Demo Student',
        usageAccessPermission: true,
        overlayPermission: true,
        notificationAccess: true,
        accessibilityService: true,
        batteryOptimizationExempt: true,
        lastReportedAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> reportPermissionStatus({
    required bool overlayPermission,
    required bool usageAccessPermission,
    required bool notificationAccess,
    required bool accessibilityService,
    required bool batteryOptimizationExempt,
    required bool deviceAdministrator,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
