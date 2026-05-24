import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/admin/moderation/presentation/moderation_screen.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspace_settings_screen.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_screen.dart';
import 'package:social_study_app/features/auth/presentation/login_screen.dart';
import 'package:social_study_app/features/documents/presentation/document_polling_screen.dart';
import 'package:social_study_app/features/gamification/presentation/badges_screen.dart';
import 'package:social_study_app/features/gamification/presentation/leaderboard_screen.dart';
import 'package:social_study_app/features/revision/presentation/revision_screen.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_editor_screen.dart';
import 'package:social_study_app/features/home/presentation/admin_home_screen.dart';
import 'package:social_study_app/features/home/presentation/student_home_screen.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_viewer_screen.dart';

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
        path: AppRoutes.adminDocumentPolling,
        builder: (_, state) => DocumentPollingScreen(
          workspaceId: state.pathParameters['workspaceId']!,
          documentId: state.pathParameters['documentId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.adminTaxonomyViewer,
        builder: (_, state) => TaxonomyViewerScreen(
          workspaceId: state.pathParameters['workspaceId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.adminTaxonomyEditor,
        builder: (_, state) => TaxonomyEditorScreen(
          workspaceId: state.pathParameters['workspaceId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.adminWorkspaces,
        builder: (_, __) => const WorkspacesScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminWorkspaceSettingsEditor,
        builder: (_, state) => WorkspaceSettingsScreen(
          workspaceId: state.pathParameters['workspaceId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.adminModerationDashboard,
        builder: (_, state) => ModerationScreen(
          workspaceId: state.pathParameters['workspaceId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (_, __) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentRevisionSession,
        builder: (_, state) => RevisionScreen(
          workspaceId: state.pathParameters['workspaceId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.studentBadges,
        builder: (_, state) => BadgesScreen(
          workspaceId: state.pathParameters['workspaceId']!,
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.studentLeaderboard,
        builder: (_, state) {
          // The caller's identity drives row highlighting. Reading
          // ``authNotifierProvider`` off ``ref`` (closed over from the
          // outer ``router`` builder) keeps the screen signature
          // declarative without coupling it to the auth feature.
          final auth = ref.read(authNotifierProvider).valueOrNull;
          final userId = auth?.maybeWhen(
                authenticated: (user) => user.id,
                orElse: () => '',
              ) ??
              '';
          return LeaderboardScreen(
            workspaceId: state.pathParameters['workspaceId']!,
            currentUserId: userId,
          );
        },
      ),
    ],
  );
}
