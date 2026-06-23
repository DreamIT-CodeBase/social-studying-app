import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';

class ScreenTimeService {
  ScreenTimeService({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = MethodChannel('com.socialstudyapp.app/screen_time');

  static const String _keyAvailableMinutes = 'available_minutes';
  static const String _keyConsumedMinutes = 'consumed_minutes';
  static const String _keyTotalEarnedMinutes = 'total_earned_minutes';
  static const String _keyLastKnownXp = 'last_known_xp';
  static const String _keyLastSyncTime = 'last_sync_time';
  static const String _keyConsumedToday = 'consumed_today';
  static const String _keyXpToMinuteRatio = 'xp_to_minute_ratio';
  static const String _keyEnableBlocking = 'enable_blocking';
  static const String _keyBlockedPackages = 'blocked_packages_json';

  static const String _keyCurrentUserId = 'current_user_id';

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs;
    return SharedPreferences.getInstance();
  }

  Future<void> setCurrentUserId(String? userId) async {
    final prefs = await _getPrefs();
    if (userId != null) {
      await prefs.setString(_keyCurrentUserId, userId);
    } else {
      await prefs.remove(_keyCurrentUserId);
    }
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
    final availableMinutes = prefs.getInt('$_keyAvailableMinutes$suffix') ?? 0;
    final consumedMinutes = prefs.getInt('$_keyConsumedMinutes$suffix') ?? 0;
    final totalEarnedMinutes = prefs.getInt('$_keyTotalEarnedMinutes$suffix') ?? 0;
    final lastKnownXp = prefs.getInt('$_keyLastKnownXp$suffix') ?? 0;
    final lastSyncMs = prefs.getInt('$_keyLastSyncTime$suffix') ?? 0;
    final consumedToday = prefs.getInt('$_keyConsumedToday$suffix') ?? 0;

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
    await prefs.setInt('$_keyAvailableMinutes$suffix', wallet.availableMinutes);
    await prefs.setInt('$_keyConsumedMinutes$suffix', wallet.consumedMinutes);
    await prefs.setInt('$_keyTotalEarnedMinutes$suffix', wallet.totalEarnedMinutes);
    await prefs.setInt('$_keyLastKnownXp$suffix', wallet.lastKnownXp);
    await prefs.setInt('$_keyLastSyncTime$suffix', wallet.lastSyncTime?.millisecondsSinceEpoch ?? 0);
    await prefs.setInt('$_keyConsumedToday$suffix', wallet.consumedToday);
  }

  Future<int> getXpToMinuteRatio() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyXpToMinuteRatio) ?? 10; // default 100 XP = 10 Minutes -> 10 XP = 1 Minute
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
  }

  Future<List<String>> getBlockedPackages() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_keyBlockedPackages);
    if (jsonStr == null) {
      // Default list of apps to block
      return [
        'com.instagram.android',
        'com.zhiliaoapp.musically',
        'com.google.android.youtube',
        'com.facebook.katana',
        'com.twitter.android',
        'com.snapchat.android',
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
        body: 'Great job! You earned $minutesEarned more minutes of screen time.',
        notificationDetails: notificationDetails,
      );

    } catch (_) {
      // Swallowed: best effort local notification
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } catch (_) {}
  }
}
