import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/router.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/notifications/presentation/notification_service.dart';
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

class _StudentAppState extends ConsumerState<_StudentApp> {
  /// Tracks the most recent auth state we acted on, so the
  /// authenticated → authenticated rebuild doesn't re-run init every
  /// frame. Null = no action taken yet.
  String? _lastAuthedUserId;
  bool _signedOutHandled = true;

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
            _initNotifications(router);
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
      title: 'Social Study',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
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
}

/// Tiny ``unawaited`` wrapper so we can fire async side effects from
/// the build/listen path without lint noise.
void unawaited(Future<void> future) {
  future.then((_) {}, onError: (_) {});
}
