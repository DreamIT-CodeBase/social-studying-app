import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/router.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/notifications/presentation/notification_service.dart';

void main() {
  setAppFlavor(AppFlavor.admin);
  runApp(const ProviderScope(child: _AdminApp()));
}

class _AdminApp extends ConsumerStatefulWidget {
  const _AdminApp();

  @override
  ConsumerState<_AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<_AdminApp> {
  String? _lastAuthedUserId;
  bool _signedOutHandled = true;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

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
      title: 'Social Study — Admin',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

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

void unawaited(Future<void> future) {
  future.then((_) {}, onError: (_) {});
}
