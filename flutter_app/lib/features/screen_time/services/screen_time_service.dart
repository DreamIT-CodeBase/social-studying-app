import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';

class ScreenTimeService {
  ScreenTimeService({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channel = MethodChannel('com.socialstudyapp.app/screen_time');

  static const String _keyAvailableMinutes = 'available_minutes';
  static const String _keyConsumedMinutes = 'consumed_minutes';
  static const String _keyTotalEarnedMinutes = 'total_earned_minutes';
  static const String _keyLastKnownXp = 'last_known_xp';
  static const String _keyLastSyncTime = 'last_sync_time';
  static const String _keyConsumedToday = 'consumed_today';
  static const String _keyWeekStartDate = 'week_start_date';
  static const String _keyXpToMinuteRatio = 'xp_to_minute_ratio';
  static const String _keyEnableBlocking = 'enable_blocking';
  static const String _keyBlockedPackages = 'blocked_packages_json';
  static const String _keyEnforcementReady = 'enforcement_ready';

  static const String _keyEnableSocialQuestions = 'enable_social_questions';
  static const String _keyRecurringQuestionsInterval =
      'recurring_questions_interval_minutes';
  static const String _keyQuestionsPerPrompt = 'questions_per_prompt';
  static const String _keySocialQuestionsSubject = 'social_questions_subject';

  static const String _keyCurrentUserId = 'current_user_id';

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs;
    return SharedPreferences.getInstance();
  }

  Future<void> setCurrentUserId(String? userId) async {
    final prefs = await _getPrefs();
    if (userId != null) {
      if (prefs.getString(_keyCurrentUserId) != userId) {
        await prefs.setBool(_keyEnforcementReady, false);
      }
      await prefs.setString(_keyCurrentUserId, userId);
    } else {
      await prefs.remove(_keyCurrentUserId);
      await prefs.setBool(_keyEnforcementReady, false);
    }
  }

  Future<void> setEnforcementReady(bool ready) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyEnforcementReady, ready);
  }

  Future<bool> isEnforcementReady() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyEnforcementReady) ?? false;
  }

  Future<ScreenTimeWallet> loadWallet([String? userId]) async {
    final suffix = userId != null ? '_$userId' : '';
    final prefs = await _getPrefs();
    try {
      await prefs.reload();
    } catch (_) {
      // In some test/mock environments or platforms, reload might throw or be unsupported.
      // We catch and swallow to maintain stability.
    }
    await _resetExpiredWeeklyBalance(prefs, suffix);
    int availableMinutes = prefs.getInt('$_keyAvailableMinutes$suffix') ?? 0;
    int consumedMinutes = prefs.getInt('$_keyConsumedMinutes$suffix') ?? 0;
    final totalEarnedMinutes =
        prefs.getInt('$_keyTotalEarnedMinutes$suffix') ?? 0;
    final lastKnownXp = prefs.getInt('$_keyLastKnownXp$suffix') ?? 0;
    final lastSyncMs = prefs.getInt('$_keyLastSyncTime$suffix') ?? 0;
    int consumedToday = prefs.getInt('$_keyConsumedToday$suffix') ?? 0;

    if (Platform.isIOS) {
      // Read native-side available minutes (may have been set to 0 by extension)
      final nativeMinutes = await getIOSAvailableMinutes();
      if (nativeMinutes != null && nativeMinutes < availableMinutes) {
        final consumedDelta = availableMinutes - nativeMinutes;
        availableMinutes = nativeMinutes;
        consumedMinutes += consumedDelta;
        consumedToday += consumedDelta;
        await prefs.setInt('$_keyAvailableMinutes$suffix', availableMinutes);
        await prefs.setInt('$_keyConsumedMinutes$suffix', consumedMinutes);
        await prefs.setInt('$_keyConsumedToday$suffix', consumedToday);
      }

      // Check if shields are active (time fully exhausted by extension)
      final shieldsActive = await areIOSShieldsActive();
      if (shieldsActive && availableMinutes > 0) {
        // Extension says time is up but our local wallet disagrees —
        // trust the extension since it has the real usage data.
        consumedToday += availableMinutes;
        consumedMinutes += availableMinutes;
        availableMinutes = 0;
        await prefs.setInt('$_keyAvailableMinutes$suffix', 0);
        await prefs.setInt('$_keyConsumedMinutes$suffix', consumedMinutes);
        await prefs.setInt('$_keyConsumedToday$suffix', consumedToday);
        unawaited(sendTimeExhaustedNotification());
      }

      // Write consumed_today back to native for display consistency
      await setIOSConsumedToday(consumedToday);
    }

    return ScreenTimeWallet(
      studentId: userId ?? '',
      availableMinutes: availableMinutes,
      consumedMinutes: consumedMinutes,
      totalEarnedMinutes: totalEarnedMinutes,
      lastKnownXp: lastKnownXp,
      lastSyncTime: DateTime.fromMillisecondsSinceEpoch(lastSyncMs),
      consumedToday: consumedToday,
    );
  }

  Future<void> saveWallet(ScreenTimeWallet wallet, [String? userId]) async {
    final suffix = userId != null ? '_$userId' : '';
    final prefs = await _getPrefs();
    await _resetExpiredWeeklyBalance(prefs, suffix);
    await prefs.setInt('$_keyAvailableMinutes$suffix', wallet.availableMinutes);
    await prefs.setInt('$_keyConsumedMinutes$suffix', wallet.consumedMinutes);
    await prefs.setInt(
        '$_keyTotalEarnedMinutes$suffix', wallet.totalEarnedMinutes);
    await prefs.setInt('$_keyLastKnownXp$suffix', wallet.lastKnownXp);
    await prefs.setInt('$_keyLastSyncTime$suffix',
        wallet.lastSyncTime?.millisecondsSinceEpoch ?? 0);
    await prefs.setInt('$_keyConsumedToday$suffix', wallet.consumedToday);
    await prefs.setString('$_keyWeekStartDate$suffix', _currentWeekStart());

    if (Platform.isIOS) {
      final enableBlocking = prefs.getBool(_keyEnableBlocking) ?? true;
      await syncScreenTimeBalance(
        availableMinutes: wallet.availableMinutes,
        enableBlocking: enableBlocking,
      );
    }
  }

  /// Expires locally cached social time on Monday even while the device is
  /// offline. The backend performs the authoritative matching reset; this
  /// protects Android's native accessibility service between synchronizations.
  Future<void> _resetExpiredWeeklyBalance(
    SharedPreferences prefs,
    String suffix,
  ) async {
    final key = '$_keyWeekStartDate$suffix';
    final currentWeek = _currentWeekStart();
    final savedWeek = prefs.getString(key);
    if (savedWeek == null) {
      await prefs.setString(key, currentWeek);
      return;
    }
    if (savedWeek == currentWeek) return;

    await prefs.setInt('$_keyAvailableMinutes$suffix', 0);
    await prefs.setInt('$_keyTotalEarnedMinutes$suffix', 0);
    await prefs.setInt('$_keyConsumedToday$suffix', 0);
    await prefs.setString(key, currentWeek);
  }

  String _currentWeekStart() {
    final today = DateTime.now().toUtc();
    final monday =
        today.subtract(Duration(days: today.weekday - DateTime.monday));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  Future<int> getXpToMinuteRatio() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyXpToMinuteRatio) ??
        10; // default 100 XP = 10 Minutes -> 10 XP = 1 Minute
  }

  Future<void> saveXpToMinuteRatio(int ratio) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyXpToMinuteRatio, ratio);
  }

  Future<bool> getEnableBlocking() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyEnableBlocking) ?? true;
  }

  Future<void> saveEnableBlocking(bool enable) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyEnableBlocking, enable);
    if (Platform.isIOS) {
      final wallet = await loadWallet(prefs.getString(_keyCurrentUserId));
      await syncScreenTimeBalance(
        availableMinutes: wallet.availableMinutes,
        enableBlocking: enable,
      );
    }
  }

  Future<List<String>> getBlockedPackages() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_keyBlockedPackages);
    if (jsonStr == null) {
      // Default list of apps to block (India & US popular social media and video apps)
      return [
        'com.instagram.android',
        'com.instagram.barcelona',
        'com.zhiliaoapp.musically',
        'com.ss.android.ugc.trill',
        'com.google.android.youtube',
        'com.google.android.apps.youtube.music',
        'com.facebook.katana',
        'com.facebook.orca',
        'com.twitter.android',
        'com.x.android',
        'com.snapchat.android',
        'com.reddit.frontpage',
        'com.pinterest',
        'tv.twitch.android.app',
        'com.discord',
        'org.telegram.messenger',
        'com.linkedin.android',
        'com.netflix.mediaclient',
        'com.amazon.avod.thirdpartyclient',
        'com.hotstar.mobile',
        'com.jio.media.ondemand',
        'in.mohalla.sharechat',
        'com.next.innovation.takatak',
        'com.eterno',
        'video.like',
        'com.kwai.video',
      ];
    }
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBlockedPackages(List<String> packages) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyBlockedPackages, jsonEncode(packages));
  }

  Future<bool> getEnableSocialQuestions() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyEnableSocialQuestions) ?? true;
  }

  Future<void> saveEnableSocialQuestions(bool enable) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyEnableSocialQuestions, enable);
  }

  Future<int> getRecurringQuestionsInterval() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyRecurringQuestionsInterval) ??
        15; // default: 15 minutes
  }

  Future<void> saveRecurringQuestionsInterval(int minutes) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyRecurringQuestionsInterval, minutes);
  }

  Future<int> getQuestionsPerPrompt() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyQuestionsPerPrompt) ?? 1; // default: 1 question
  }

  Future<void> saveQuestionsPerPrompt(int count) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyQuestionsPerPrompt, count);
  }

  Future<String?> getSocialQuestionsSubject() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keySocialQuestionsSubject);
  }

  Future<void> saveSocialQuestionsSubject(String? subject) async {
    final prefs = await _getPrefs();
    if (subject == null || subject.isEmpty) {
      await prefs.remove(_keySocialQuestionsSubject);
    } else {
      await prefs.setString(_keySocialQuestionsSubject, subject);
    }
  }

  Future<void> showNotification(int minutesEarned) async {
    const androidDetails = AndroidNotificationDetails(
      'screen_time_channel',
      'Screen Time Alerts',
      channelDescription: 'Notifications for screen time updates',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    // Fallback: in case notifications plugin isn't fully initialized
    try {
      await _localNotifications.show(
        id: 888,
        title: 'Earn Digital Freedom!',
        body:
            'Great job! You earned $minutesEarned more minutes of screen time.',
        notificationDetails: notificationDetails,
      );
    } catch (_) {
      // Swallowed: best effort local notification
    }
  }

  // MARK: - iOS Screen Time Methods

  Future<bool> isScreenTimeAuthorized() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isScreenTimeAuthorized') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Returns 'approved', 'denied', or 'notDetermined'.
  Future<String> getIOSAuthorizationStatus() async {
    if (!Platform.isIOS) return 'approved';
    try {
      return await _channel.invokeMethod<String>('getAuthorizationStatus') ??
          'notDetermined';
    } catch (_) {
      return 'notDetermined';
    }
  }

  /// Request Screen Time authorization. Returns true when the device owner
  /// approves the system Face ID or Touch ID prompt.
  Future<({bool approved, String? errorMessage})>
      requestScreenTimeAuthorization() async {
    if (!Platform.isIOS) return (approved: false, errorMessage: null);
    try {
      final result =
          await _channel.invokeMethod<bool>('requestScreenTimeAuthorization');
      return (approved: result ?? false, errorMessage: null);
    } on PlatformException catch (e) {
      return (approved: false, errorMessage: e.message);
    } catch (_) {
      return (approved: false, errorMessage: null);
    }
  }

  Future<bool> presentFamilyActivityPicker() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('presentFamilyActivityPicker') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasSelectedBlockedApps() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('hasSelectedBlockedApps') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncScreenTimeBalance({
    required int availableMinutes,
    required bool enableBlocking,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('syncScreenTimeBalance', {
        'availableMinutes': availableMinutes,
        'enableBlocking': enableBlocking,
      });
    } catch (_) {}
  }

  /// Force re-apply shields from cached state. Call after foreground resume.
  Future<void> reapplyShields() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('reapplyShields');
    } catch (_) {}
  }

  /// Fetches the remaining available minutes cached on iOS by ScreenTimeManager.
  Future<int?> getIOSAvailableMinutes() async {
    if (!Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<int>('getAvailableMinutes');
    } catch (_) {
      return null;
    }
  }

  /// Fetches the consumed-today value from iOS native ScreenTimeManager.
  Future<int> getIOSConsumedToday() async {
    if (!Platform.isIOS) return 0;
    try {
      return await _channel.invokeMethod<int>('getConsumedToday') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Writes consumed-today back to iOS native for display consistency.
  Future<void> setIOSConsumedToday(int minutes) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('setConsumedToday', {
        'minutes': minutes,
      });
    } catch (_) {}
  }

  /// Returns true if iOS shields are currently active (blocking apps).
  Future<bool> areIOSShieldsActive() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('areShieldsActive') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers a local notification on iOS informing the user that social time is exhausted.
  Future<void> sendTimeExhaustedNotification() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('sendTimeExhaustedNotification');
    } catch (_) {
      // Swallowed: best-effort notification
    }
  }

  // MARK: - Notifications (cross-platform)

  /// Returns whether notification permission has been granted on iOS.
  Future<bool> isNotificationPermissionGranted() async {
    final status = await getPermissionStatus();
    return status.notifications;
  }

  /// Request notification permission on iOS (Android uses the system dialog).
  Future<bool> requestNotificationPermissionIOS() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel
              .invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  // MARK: - Android Accessibility Methods

  Future<bool> isAccessibilityServiceEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<DevicePermissionStatus> getPermissionStatus() async {
    if (Platform.isIOS) {
      try {
        final map = await _channel
            .invokeMapMethod<String, dynamic>('getIOSPermissionStatus');
        final screenTimeAuth = map?['screenTimeAuthorized'] as bool? ?? false;
        final hasSelectedApps = map?['hasSelectedApps'] as bool? ?? false;
        final notifications = map?['notifications'] as bool? ?? false;
        return DevicePermissionStatus(
          usageAccess: true,
          overlay: true,
          notifications: notifications,
          accessibility: true,
          batteryExempt: true,
          iosScreenTimeAuthorized: screenTimeAuth,
          iosHasSelectedApps: hasSelectedApps,
        );
      } catch (_) {
        return const DevicePermissionStatus(
          usageAccess: true,
          overlay: true,
          notifications: false,
          accessibility: true,
          batteryExempt: true,
          iosScreenTimeAuthorized: false,
          iosHasSelectedApps: false,
        );
      }
    }

    if (!Platform.isAndroid) return DevicePermissionStatus.notRequired();

    Future<bool> check(String method) async {
      try {
        return await _channel.invokeMethod<bool>(method) ?? false;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    }

    return DevicePermissionStatus(
      usageAccess: await check('isUsageAccessGranted'),
      overlay: await check('isOverlayGranted'),
      notifications: await check('isNotificationGranted'),
      accessibility: await check('isAccessibilityEnabled'),
      batteryExempt: await check('isBatteryOptimizationExempt'),
    );
  }

  Future<void> openUsageAccessSettings() =>
      _invokeSettingsMethod('openUsageAccessSettings');

  Future<void> openOverlaySettings() =>
      _invokeSettingsMethod('openOverlaySettings');

  Future<void> requestNotificationPermission() =>
      _invokeSettingsMethod('requestNotificationPermission');

  Future<void> openNotificationSettings() =>
      _invokeSettingsMethod('openNotificationSettings');

  Future<void> openBatteryOptimizationSettings() =>
      _invokeSettingsMethod('openBatteryOptimizationSettings');

  Future<void> _invokeSettingsMethod(String method) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>(method);
  }

  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } catch (_) {}
  }
}

class DevicePermissionStatus {
  const DevicePermissionStatus({
    required this.usageAccess,
    required this.overlay,
    required this.notifications,
    required this.accessibility,
    required this.batteryExempt,
    this.iosScreenTimeAuthorized = true,
    this.iosHasSelectedApps = true,
  });

  factory DevicePermissionStatus.notRequired() => const DevicePermissionStatus(
        usageAccess: true,
        overlay: true,
        notifications: true,
        accessibility: true,
        batteryExempt: true,
        iosScreenTimeAuthorized: true,
        iosHasSelectedApps: true,
      );

  final bool usageAccess;
  final bool overlay;
  final bool notifications;
  final bool accessibility;
  final bool batteryExempt;
  final bool iosScreenTimeAuthorized;
  final bool iosHasSelectedApps;

  bool get requiredPermissionsGranted {
    if (Platform.isIOS) {
      return iosScreenTimeAuthorized;
    }
    return usageAccess && accessibility;
  }

  bool get allRecommendedPermissionsGranted {
    if (Platform.isIOS) {
      return requiredPermissionsGranted && notifications;
    }
    return requiredPermissionsGranted &&
        overlay &&
        notifications &&
        batteryExempt;
  }
}
