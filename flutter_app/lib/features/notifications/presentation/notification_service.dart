import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show WidgetsBinding, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/services/sound_service.dart';
import 'package:social_study_app/features/notifications/data/notification_token_repository.dart';
import 'package:social_study_app/shared/models/notification_token.dart';

part 'notification_service.g.dart';

/// Sprint 5.8 — Flutter push notification client.
///
/// One service that owns the full FCM lifecycle:
///
/// 1. Lazy Firebase init (try/except so a dev build without
///    ``google-services.json`` doesn't crash on startup).
/// 2. Permission request (iOS modal, Android 13+ runtime perm).
/// 3. Token registration with the backend
///    (``POST /users/me/notification-tokens``).
/// 4. Foreground message handler → in-app banner.
/// 5. Tap-to-open handler → deep-links into the right screen via
///    GoRouter, branching on the payload's ``type`` data field
///    (mirrors the four notification types in
///    ``backend/app/models/notification.py``).
///
/// **Why a per-install UUID and not the FCM token itself.** The FCM
/// token rotates silently — using it as the row id on the backend
/// would dupe registrations on every rotation. The installation_id
/// is minted once per install (persisted in secure storage) and only
/// changes on a fresh install.
///
/// **Initialization is best-effort.** ``initialize`` swallows every
/// exception path — Firebase config missing, FCM permission denied,
/// backend unreachable — so a notification subsystem failure can
/// never block the app from booting. Errors are logged via
/// ``debugPrint`` and reported to the caller as a return-value boolean.
class NotificationService {
  NotificationService({
    required this.tokenRepository,
    required this.secureStorage,
    FirebaseMessaging? messaging,
  }) : _messaging = messaging;

  final NotificationTokenRepository tokenRepository;
  final FlutterSecureStorage secureStorage;
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _installationIdKey = 'notification_installation_id';

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  Future<void>? _registrationRetry;
  bool _localReady = false;
  bool _initialized = false;
  String? _lastLocalTitle;
  DateTime? _lastLocalAt;
  void Function(RemoteMessage message)? _onTap;

  /// Initialize Firebase, request permission, register the token.
  /// Returns true on full success, false on any failure path (the
  /// caller treats false as "notifications won't work this session").
  Future<bool> initialize({
    required void Function(RemoteMessage message) onTap,
  }) async {
    _onTap = onTap;
    if (_initialized) return true;
    try {
      await _initializeLocalNotifications(onTap);
    } catch (error) {
      debugPrint('NotificationService: Local notification init failed: $error');
    }
    try {
      await Firebase.initializeApp();
      _messaging ??= FirebaseMessaging.instance;
    } catch (error, stack) {
      debugPrint(
        'NotificationService: Firebase init skipped — likely '
        "missing google-services.json. App boots without push. "
        'error=$error',
      );
      debugPrintStack(stackTrace: stack);
      return false;
    }

    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      debugPrint('NotificationService: permission denied; skipping register');
      return false;
    }

    final recoveryInstallationId = await _installationId();
    final recoveryPlatform = _detectPlatform();
    if (recoveryPlatform == null) return false;

    // Install recovery before the APNs wait. The previous flow returned after
    // ten seconds and never heard Firebase's eventual token callback.
    _tokenRefreshSubscription ??=
        _messaging!.onTokenRefresh.listen((freshToken) async {
      await _registerRemoteToken(
        installationId: recoveryInstallationId,
        token: freshToken,
        platform: recoveryPlatform,
      );
    });

    // Firebase Messaging on Apple platforms cannot issue a usable FCM token
    // until APNs registration has completed. The APNs callback is asynchronous,
    // so give it a short bounded window instead of racing getToken() on launch.
    if (Platform.isIOS && !await _waitForApnsToken()) {
      debugPrint(
          'NotificationService: APNs token unavailable; skipping register');
      _startRegistrationRetry(
        installationId: recoveryInstallationId,
        platform: recoveryPlatform,
      );
      return false;
    }

    final token = await _safeGetToken();
    if (token == null) {
      debugPrint('NotificationService: no FCM token; skipping register');
      _startRegistrationRetry(
        installationId: recoveryInstallationId,
        platform: recoveryPlatform,
      );
      return false;
    }

    // FCM tokens identify app installations and must never be printed.
    debugPrint('NotificationService: FCM token acquired');

    final installationId = await _installationId();
    final platform = _detectPlatform();
    if (platform == null) {
      debugPrint(
          'NotificationService: unsupported platform; skipping register');
      return false;
    }

    try {
      await tokenRepository.register(
        installationId: installationId,
        token: token,
        platform: platform,
      );
    } catch (error) {
      debugPrint('NotificationService: backend register failed — $error');
      return false;
    }

    // Foreground messages are rendered through the local plugin on both
    // platforms, avoiding iOS-version-specific presentation differences.
    await _messaging!.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    // Foreground messages. FCM doesn't render a system notification
    // when the app is in the foreground on Android — we use local notifications.
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        showCompletionNotification(
          title: notification.title ?? 'Social Studying',
          body: notification.body ?? '',
          payload: message.data,
        );
      }
    });

    // Background → tap path. ``getInitialMessage`` covers the
    // cold-start tap (app was terminated, tap launched it).
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(onTap);
    final initial = await _messaging!.getInitialMessage();
    if (initial != null) {
      // Deferred so the GoRouter is mounted by the time we navigate.
      WidgetsBinding.instance.addPostFrameCallback((_) => onTap(initial));
    }

    _initialized = true;
    return true;
  }

  Future<void> _initializeLocalNotifications(
    void Function(RemoteMessage message) onTap,
  ) async {
    if (_localReady) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (details) {
        final rawPayload = details.payload;
        if (rawPayload == null) return;
        try {
          onTap(RemoteMessage(
            data: jsonDecode(rawPayload) as Map<String, dynamic>,
          ));
        } catch (_) {}
      },
    );
    _localReady = true;
  }

  /// Immediately display completion feedback with sound while the app is open.
  /// The backend push covers background and terminated app states.
  Future<void> showCompletionNotification({
    required String title,
    required String body,
    Map<String, dynamic> payload = const {},
  }) async {
    // Local completion alerts do not depend on APNs/FCM registration. Ensure
    // the notification plugin is ready here so a slow or failed remote-token
    // registration cannot suppress the iPhone Notification Centre entry.
    if (!_localReady) {
      try {
        await _initializeLocalNotifications(_onTap ?? (_) {});
      } catch (error) {
        debugPrint(
          'NotificationService: local notification init failed: $error',
        );
        return;
      }
    }
    final now = DateTime.now();
    if (_lastLocalTitle == title &&
        _lastLocalAt != null &&
        now.difference(_lastLocalAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastLocalTitle = title;
    _lastLocalAt = now;
    await _localNotifications.show(
      id: now.millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'social_study_channel',
          'Social Study Notifications',
          channelDescription: 'Study and flashcard completion notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
        ),
      ),
      payload: jsonEncode(payload),
    );
    SoundService.instance.playNotification();
  }

  /// Clean up subscriptions. Tests use this; production tears down on
  /// app exit, where the OS reclaims the streams anyway.
  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _tokenRefreshSubscription = null;
  }

  /// Delete the token from the backend on explicit sign-out so the
  /// previous user's account doesn't keep receiving pushes from this
  /// installation.
  Future<void> deregister() async {
    try {
      final installationId = await secureStorage.read(key: _installationIdKey);
      if (installationId == null) return;
      await tokenRepository.delete(installationId: installationId);
    } catch (error) {
      debugPrint('NotificationService: deregister failed — $error');
    }
  }

  // ── Internals ────────────────────────────────────────────────────

  Future<bool> _requestPermission() async {
    try {
      final settings = await _messaging!.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (error) {
      debugPrint('NotificationService: permission request failed — $error');
      return false;
    }
  }

  Future<String?> _safeGetToken() async {
    try {
      return await _messaging!.getToken();
    } catch (error) {
      debugPrint('NotificationService: getToken failed — $error');
      return null;
    }
  }

  Future<bool> _registerRemoteToken({
    required String installationId,
    required String token,
    required DevicePlatform platform,
  }) async {
    try {
      await tokenRepository.register(
        installationId: installationId,
        token: token,
        platform: platform,
      );
      debugPrint('NotificationService: backend device registration complete');
      return true;
    } catch (error) {
      debugPrint('NotificationService: backend registration failed: $error');
      return false;
    }
  }

  void _startRegistrationRetry({
    required String installationId,
    required DevicePlatform platform,
  }) {
    if (_registrationRetry != null) return;
    _registrationRetry = () async {
      // Continue for five minutes. App-resume also invokes initialize again,
      // while Firebase token refresh remains subscribed for the app lifetime.
      for (var attempt = 0; attempt < 60; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 5));
        if (Platform.isIOS && !await _waitForApnsToken(maxAttempts: 2)) {
          continue;
        }
        final token = await _safeGetToken();
        if (token != null &&
            await _registerRemoteToken(
              installationId: installationId,
              token: token,
              platform: platform,
            )) {
          break;
        }
      }
      _registrationRetry = null;
    }();
  }

  Future<bool> _waitForApnsToken({int maxAttempts = 20}) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        if (await _messaging!.getAPNSToken() != null) return true;
      } catch (error) {
        debugPrint('NotificationService: APNs token check failed — $error');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Read the per-install UUID from secure storage, minting one on
  /// first call. Stable across app restarts; rotates on fresh
  /// install (because the secure storage is wiped).
  Future<String> _installationId() async {
    final existing = await secureStorage.read(key: _installationIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = _mintUuid();
    await secureStorage.write(key: _installationIdKey, value: fresh);
    return fresh;
  }

  /// Minimal UUID v4. Doesn't pull a dep — the backend treats this as
  /// an opaque token, so RFC compliance isn't load-bearing.
  String _mintUuid() {
    final bytes = List<int>.generate(
      16,
      (_) => DateTime.now().microsecondsSinceEpoch & 0xff,
    );
    // Real entropy from a fresh Stopwatch — good enough for an
    // identifier the backend doesn't validate, and avoids pulling in
    // dart:math.Random just for this.
    final sw = Stopwatch()..start();
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = (bytes[i] ^ sw.elapsedMicroseconds) & 0xff;
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-'
        '${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }

  DevicePlatform? _detectPlatform() {
    try {
      if (Platform.isAndroid) return DevicePlatform.android;
      if (Platform.isIOS) return DevicePlatform.ios;
    } on UnsupportedError {
      // ``Platform`` is unavailable on web/desktop; v1 ships mobile
      // only, so a missing platform = unsupported and we drop the
      // registration cleanly.
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tap routing
// ─────────────────────────────────────────────────────────────────────────

/// Maps a notification payload to a deep-link path. Centralised so the
/// tap handler in the app's startup wiring and the cold-start handler
/// inside [NotificationService] use the same routing rules.
///
/// Returns null if the payload doesn't have a known type — the caller
/// should ignore it (the app stays on whatever screen the user was
/// on).
///
/// Mirrors the four ``NotificationType`` values in
/// ``backend/app/models/notification.py``:
/// - ``study_reminder`` / ``streak_warning`` / ``unanswered_reprompt``
///   → student home study tab (caller has to push the route — we
///   return a marker path)
/// - ``milestone`` → badges screen
String? deepLinkFor(Map<String, dynamic> data) {
  final type = data['type'];
  final workspaceId = data['workspace_id'];
  if (type == null || workspaceId == null) return null;
  switch (type) {
    case 'milestone':
      // Caller needs the user id too. Embedded inline so the deep-link
      // is self-contained — the badges route is per-(workspace, user).
      final userId = data['user_id'];
      if (userId == null) return null;
      return '/student/badges/$workspaceId/$userId';
    case 'study_reminder':
    case 'streak_warning':
    case 'unanswered_reprompt':
      // The student home is the right landing — the Study tab is
      // index 1 inside the home Scaffold and re-entering the route
      // re-selects it. Sprint 6 polish: a query param to pre-select
      // the tab.
      return '/student/home';
    default:
      return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────

/// Singleton ``NotificationService`` keyed off the auth-driven token
/// repository. Held for the app lifetime so the FCM subscriptions
/// outlive any one screen.
@Riverpod(keepAlive: true)
NotificationService notificationService(NotificationServiceRef ref) {
  return NotificationService(
    tokenRepository: ref.read(notificationTokenRepositoryProvider),
    secureStorage: const FlutterSecureStorage(),
  );
}
