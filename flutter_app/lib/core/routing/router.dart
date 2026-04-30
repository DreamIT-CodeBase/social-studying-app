import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/auth/presentation/login_screen.dart';
import 'package:social_study_app/features/home/presentation/admin_home_screen.dart';
import 'package:social_study_app/features/home/presentation/student_home_screen.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
class RouterNotifier extends _$RouterNotifier implements Listenable {
  VoidCallback? _listener;

  @override
  void build() {
    ref.listen(authNotifierProvider, (_, __) => _listener?.call());
  }

  @override
  void addListener(VoidCallback listener) => _listener = listener;

  @override
  void removeListener(VoidCallback listener) => _listener = null;

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = ref.read(authNotifierProvider);
    return authAsync.when(
      data: (authState) {
        final isOnLogin = state.matchedLocation == AppRoutes.login;
        return authState.when(
          unauthenticated: () => isOnLogin ? null : AppRoutes.login,
          authenticated: (_) {
            if (!isOnLogin) return null;
            return currentFlavor == AppFlavor.admin
                ? AppRoutes.adminDashboard
                : AppRoutes.studentHome;
          },
        );
      },
      loading: () => null,
      error: (_, __) => AppRoutes.login,
    );
  }
}

@Riverpod(keepAlive: true)
GoRouter router(RouterRef ref) {
  final notifier = ref.watch(routerNotifierProvider.notifier);
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (_, __) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (_, __) => const StudentHomeScreen(),
      ),
    ],
  );
}
