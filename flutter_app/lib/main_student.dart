import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/router.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/notifications/presentation/notification_service.dart';
import 'package:social_study_app/features/screen_time/data/screen_time_repository.dart';
import 'package:social_study_app/features/screen_time/providers/screen_time_providers.dart';
import 'package:social_study_app/features/screen_time/services/screen_time_service.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setAppFlavor(AppFlavor.student);
  await SessionPersistenceService.init();
  runApp(const ProviderScope(child: _StudentApp()));
}

class _StudentApp extends ConsumerStatefulWidget {
  const _StudentApp();

  @override
  ConsumerState<_StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends ConsumerState<_StudentApp>
    with WidgetsBindingObserver {
  /// Tracks the most recent auth state we acted on, so the
  /// authenticated → authenticated rebuild doesn't re-run init every
  /// frame. Null = no action taken yet.
  String? _lastAuthedUserId;
  bool _signedOutHandled = true;
  Future<void>? _permissionCheckInFlight;
  String? _permissionCheckUserId;

  // iOS: track whether we have already shown the setup screen this session.
  bool _iosSetupShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(
      authenticated: (authenticatedUser) => authenticatedUser,
      orElse: () => null,
    );
    if (user == null) return;
    _initNotifications(ref.read(routerProvider));
    unawaited(
      ref.read(screenTimeNotifierProvider.notifier).refreshWallet(),
    );
    // Re-apply shields on every foreground resume (iOS)
    if (Platform.isIOS) {
      unawaited(ScreenTimeService().reapplyShields());
    }
    unawaited(_verifyPermissionSetup(user.id, ref.read(routerProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Sprint 5.8 — drive the notification service off the auth state.
    // Listen (rather than watch) so the side effect runs once per
    // transition: register on authenticated, deregister on
    // unauthenticated.
    ref.listen(authNotifierProvider, (_, next) {
      next.whenOrNull(
        data: (state) => state.maybeWhen(
          authenticated: (user) {
            if (_lastAuthedUserId == user.id) return;
            _lastAuthedUserId = user.id;
            _signedOutHandled = false;
            _iosSetupShown = false; // Reset so new user sees the setup
            _initNotifications(router);
            unawaited(ref.read(screenTimeNotifierProvider.future));
            unawaited(_verifyPermissionSetup(user.id, router));
            // iOS: show permission setup if not yet authorized
            if (Platform.isIOS) {
              unawaited(_checkAndShowIOSPermissionSetup());
            }
          },
          unauthenticated: () {
            if (_signedOutHandled) return;
            _signedOutHandled = true;
            _lastAuthedUserId = null;
            unawaited(
              ref.read(notificationServiceProvider).deregister(),
            );
          },
          orElse: () {},
        ),
      );
    });

    return MaterialApp.router(
      title: 'Social Studying AI',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  // ── iOS Permission Setup ─────────────────────────────────────────────────

  Future<void> _checkAndShowIOSPermissionSetup() async {
    if (!Platform.isIOS) return;
    if (_iosSetupShown) return;
    _iosSetupShown = true;

    // Brief delay so the initial frame and navigation are ready
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final service = ScreenTimeService();

    // 1. Native Push Notification permission popup
    final notificationGranted = await service.isNotificationPermissionGranted();
    if (!notificationGranted) {
      await service.requestNotificationPermissionIOS();
    }

    // 2. Native Screen Time authorization popup (Face ID / Passcode prompt)
    final status = await service.getIOSAuthorizationStatus();
    if (status != 'approved') {
      await service.requestScreenTimeAuthorization();
    }

    // Internally re-apply shields based on admin policy
    unawaited(service.reapplyShields());
  }

  /// Fire-and-forget the notification subsystem init. Failures land
  /// in ``debugPrint`` inside the service — the app keeps running.
  void _initNotifications(router) {
    unawaited(
      ref.read(notificationServiceProvider).initialize(
        onTap: (RemoteMessage message) {
          final path = deepLinkFor(message.data);
          if (path != null) router.go(path);
        },
      ),
    );
  }

  Future<void> _verifyPermissionSetup(String userId, GoRouter router) async {
    final activeCheck = _permissionCheckInFlight;
    final activeUserId = _permissionCheckUserId;
    if (activeCheck != null) {
      await activeCheck;
      if (activeUserId == userId) return;
    }

    final check = _performPermissionSetupCheck(userId, router);
    _permissionCheckInFlight = check;
    _permissionCheckUserId = userId;
    try {
      await check;
    } finally {
      if (identical(_permissionCheckInFlight, check)) {
        _permissionCheckInFlight = null;
        _permissionCheckUserId = null;
      }
    }
  }

  Future<void> _performPermissionSetupCheck(
    String userId,
    GoRouter router,
  ) async {
    try {
      final service = ScreenTimeService();
      final status = await service.getPermissionStatus();
      await SessionPersistenceService.instance.setPermissionSetupComplete(
        userId,
        complete: true,
      );

      await ref.read(screenTimeRepositoryProvider).reportPermissionStatus(
            overlayPermission: status.overlay,
            usageAccessPermission: status.usageAccess,
            notificationAccess: status.notifications,
            accessibilityService: status.accessibility,
            batteryOptimizationExempt: status.batteryExempt,
            deviceAdministrator: false,
          );
    } catch (_) {
      // Device enforcement is local-first; cloud health sync retries on resume.
    }
  }
}

/// Tiny ``unawaited`` wrapper so we can fire async side effects from
/// the build/listen path without lint noise.
void unawaited<T>(Future<T> future) {
  future.then((_) {}, onError: (_) {});
}
