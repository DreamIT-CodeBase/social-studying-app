import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';
import 'package:social_study_app/features/screen_time/services/screen_time_service.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

void main() {
  group('ScreenTimeWallet Model', () {
    test('initial() returns a zeroed wallet', () {
      final wallet = ScreenTimeWallet.initial();
      expect(wallet.availableMinutes, 0);
      expect(wallet.consumedMinutes, 0);
      expect(wallet.totalEarnedMinutes, 0);
      expect(wallet.lastKnownXp, 0);
      expect(wallet.consumedToday, 0);
      expect(wallet.lastSyncTime?.millisecondsSinceEpoch, 0);
    });

    test('supports JSON serialization and deserialization', () {
      final original = ScreenTimeWallet(
        availableMinutes: 30,
        consumedMinutes: 10,
        totalEarnedMinutes: 40,
        lastKnownXp: 400,
        lastSyncTime: DateTime.fromMillisecondsSinceEpoch(123456789),
        consumedToday: 5,
      );

      final json = original.toJson();
      final reconstructed = ScreenTimeWallet.fromJson(json);

      expect(reconstructed, original);
    });
  });

  group('ScreenTimeService Storage & Conversion', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads default wallet when no values exist in storage', () async {
      final service = ScreenTimeService();
      final wallet = await service.loadWallet();

      expect(wallet.availableMinutes, 0);
      expect(wallet.consumedMinutes, 0);
      expect(wallet.totalEarnedMinutes, 0);
      expect(wallet.lastKnownXp, 0);
      expect(wallet.consumedToday, 0);
    });

    test('saves and loads wallet data correctly', () async {
      final service = ScreenTimeService();

      final wallet = ScreenTimeWallet(
        availableMinutes: 15,
        consumedMinutes: 20,
        totalEarnedMinutes: 35,
        lastKnownXp: 350,
        lastSyncTime: DateTime.now(),
        consumedToday: 10,
      );

      await service.saveWallet(wallet);
      final loaded = await service.loadWallet();

      expect(loaded.availableMinutes, wallet.availableMinutes);
      expect(loaded.consumedMinutes, wallet.consumedMinutes);
      expect(loaded.totalEarnedMinutes, wallet.totalEarnedMinutes);
      expect(loaded.lastKnownXp, wallet.lastKnownXp);
      expect(loaded.consumedToday, wallet.consumedToday);
      expect(
        loaded.lastSyncTime?.millisecondsSinceEpoch,
        wallet.lastSyncTime?.millisecondsSinceEpoch,
      );
    });

    test('handles default configurations correctly', () async {
      final service = ScreenTimeService();

      final ratio = await service.getXpToMinuteRatio();
      final enableBlocking = await service.getEnableBlocking();
      final blockedApps = await service.getBlockedPackages();

      expect(ratio, 10); // 100 XP = 10 Minutes -> 10 XP = 1 Minute default
      expect(enableBlocking, true);
      expect(blockedApps, contains('com.instagram.android'));
      expect(blockedApps, contains('com.google.android.youtube'));
      expect(blockedApps, contains('com.instagram.barcelona'));
      expect(blockedApps, contains('com.reddit.frontpage'));
      expect(blockedApps, contains('com.pinterest'));
    });

    test('updates configurations correctly', () async {
      final service = ScreenTimeService();

      await service.saveXpToMinuteRatio(20);
      await service.saveEnableBlocking(false);
      await service.saveBlockedPackages(['com.custom.app']);

      final ratio = await service.getXpToMinuteRatio();
      final enableBlocking = await service.getEnableBlocking();
      final blockedApps = await service.getBlockedPackages();

      expect(ratio, 20);
      expect(enableBlocking, false);
      expect(blockedApps, equals(['com.custom.app']));
    });

    test('handles distinct user-specific wallets correctly', () async {
      final service = ScreenTimeService();

      final walletA = ScreenTimeWallet(
        availableMinutes: 10,
        consumedMinutes: 5,
        totalEarnedMinutes: 15,
        lastKnownXp: 150,
        lastSyncTime: DateTime.fromMillisecondsSinceEpoch(100000),
        consumedToday: 2,
      );

      final walletB = ScreenTimeWallet(
        availableMinutes: 20,
        consumedMinutes: 10,
        totalEarnedMinutes: 30,
        lastKnownXp: 300,
        lastSyncTime: DateTime.fromMillisecondsSinceEpoch(200000),
        consumedToday: 4,
      );

      await service.saveWallet(walletA, 'user_A');
      await service.saveWallet(walletB, 'user_B');

      final loadedA = await service.loadWallet('user_A');
      final loadedB = await service.loadWallet('user_B');

      expect(loadedA.availableMinutes, 10);
      expect(loadedB.availableMinutes, 20);

      // Verify legacy load without user ID returns default/zeroed since they are different keys
      final loadedDefault = await service.loadWallet();
      expect(loadedDefault.availableMinutes, 0);
    });

    test('account changes hold enforcement until the new wallet is ready',
        () async {
      final service = ScreenTimeService();
      await service.setCurrentUserId('user_123');
      await service.setEnforcementReady(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('current_user_id'), 'user_123');
      expect(await service.isEnforcementReady(), isTrue);

      await service.setCurrentUserId('user_456');
      expect(prefs.getString('current_user_id'), 'user_456');
      expect(await service.isEnforcementReady(), isFalse);

      await service.setEnforcementReady(true);
      await service.setCurrentUserId(null);
      expect(prefs.containsKey('current_user_id'), isFalse);
      expect(await service.isEnforcementReady(), isFalse);
    });

    test('permission completion is stored separately for each student',
        () async {
      await SessionPersistenceService.init();
      final persistence = SessionPersistenceService.instance;

      expect(persistence.isPermissionSetupCompleteSync('student_a'), isFalse);
      await persistence.setPermissionSetupComplete(
        'student_a',
        complete: true,
      );

      expect(persistence.isPermissionSetupCompleteSync('student_a'), isTrue);
      expect(persistence.isPermissionSetupCompleteSync('student_b'), isFalse);
    });
  });

  group('DevicePermissionStatus', () {
    test('requires accessibility and usage access for blocking', () {
      const status = DevicePermissionStatus(
        usageAccess: true,
        overlay: false,
        notifications: false,
        accessibility: true,
        batteryExempt: false,
      );

      expect(status.requiredPermissionsGranted, isTrue);
      expect(status.allRecommendedPermissionsGranted, isFalse);
    });

    test('all recommended permissions include the overlay fallback', () {
      const status = DevicePermissionStatus(
        usageAccess: true,
        overlay: true,
        notifications: true,
        accessibility: true,
        batteryExempt: true,
      );

      expect(status.requiredPermissionsGranted, isTrue);
      expect(status.allRecommendedPermissionsGranted, isTrue);
    });

    test('supports iOS screen time permission status properties', () {
      const status = DevicePermissionStatus(
        usageAccess: true,
        overlay: true,
        notifications: true,
        accessibility: true,
        batteryExempt: true,
        iosScreenTimeAuthorized: true,
        iosHasSelectedApps: true,
      );

      expect(status.iosScreenTimeAuthorized, isTrue);
      expect(status.iosHasSelectedApps, isTrue);
    });
  });
}
