import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/features/profile/presentation/profile_screen.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/admin/moderation/presentation/moderation_screen.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspace_settings_screen.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_screen.dart';
import 'package:social_study_app/features/admin/analytics/presentation/workspace_analytics_screen.dart';
import 'package:social_study_app/features/admin/students/presentation/student_progress_detail_screen.dart';
import 'package:social_study_app/features/auth/presentation/login_screen.dart';
import 'package:social_study_app/features/auth/presentation/legal_document_screen.dart';
import 'package:social_study_app/features/documents/presentation/document_polling_screen.dart';
import 'package:social_study_app/features/documents/presentation/documents_list_screen.dart';
import 'package:social_study_app/features/gamification/presentation/badges_screen.dart';
import 'package:social_study_app/features/gamification/presentation/leaderboard_screen.dart';
import 'package:social_study_app/features/revision/presentation/revision_screen.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_editor_screen.dart';
import 'package:social_study_app/features/home/presentation/admin_home_screen.dart';
import 'package:social_study_app/features/home/presentation/student_home_screen.dart';
import 'package:social_study_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:social_study_app/features/onboarding/presentation/permission_onboarding_screen.dart';
import 'package:social_study_app/features/onboarding/presentation/theme_selection_screen.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_viewer_screen.dart';
import 'package:social_study_app/features/screen_time/screens/screen_time_settings_screen.dart';
import 'package:social_study_app/features/study_sessions/domain/adaptive_session_models.dart';
import 'package:social_study_app/features/study_sessions/presentation/adaptive_session_screen.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

part 'router.g.dart';

@riverpod
class PendingInviteCode extends _$PendingInviteCode {
  @override
  String? build() => null;

  void set(String code) => state = code;
  void clear() => state = null;
}

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
    final code = state.uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      ref.read(pendingInviteCodeProvider.notifier).set(code);
    }

    final authAsync = ref.read(authNotifierProvider);
    return authAsync.when(
      data: (authState) {
        final isOnLogin = state.matchedLocation == AppRoutes.login;
        final isOnAdminOnboarding =
            state.matchedLocation == AppRoutes.adminOnboarding;
        // Legal pages are publicly accessible — no auth required.
        final isOnLegal = state.matchedLocation == AppRoutes.terms ||
            state.matchedLocation == AppRoutes.privacy;
        return authState.when(
          unauthenticated: () =>
              (isOnLogin || isOnLegal) ? null : AppRoutes.login,
          authenticated: (user) {
            if (currentFlavor == AppFlavor.student) {
              if (isOnLogin) {
                return AppRoutes.studentHome;
              }
              return null;
            }

            // Sprint 6.9 — admin with zero workspaces lands on the
            // onboarding wizard, not the dashboard. The wizard
            // creates the first workspace, and the redirect stops
            // firing the moment ``workspaceMemberships`` is non-empty.
            // The student flavor doesn't get this — students join a
            // workspace via invite code, not creation.
            final adminWorkspaces = user.workspaceMemberships.where((m) =>
                !isSelfLearningWorkspaceId(m.workspaceId) &&
                (m.role == UserRole.tenantAdmin ||
                    m.role == UserRole.workspaceAdmin ||
                    user.role == UserRole.tenantAdmin));
            final needsOnboarding =
                currentFlavor == AppFlavor.admin && adminWorkspaces.isEmpty;

            if (needsOnboarding) {
              return isOnAdminOnboarding ? null : AppRoutes.adminOnboarding;
            }
            // If the admin has workspaces but somehow lands on
            // /onboarding (e.g. browser back button after first
            // creation), bounce them to the dashboard.
            if (isOnAdminOnboarding) {
              return AppRoutes.adminDashboard;
            }
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
        path: '/join',
        redirect: (_, __) => currentFlavor == AppFlavor.admin
            ? AppRoutes.adminDashboard
            : AppRoutes.studentHome,
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      // ── Legal screens — accessible from the login footer ─────────────
      GoRoute(
        path: AppRoutes.terms,
        builder: (_, __) => const TermsAndConditionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (_, __) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AppRoutes.themeSelection,
        builder: (_, __) => const ThemeSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (_, __) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminOnboarding,
        builder: (_, __) => const OnboardingScreen(),
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
        path: AppRoutes.studentOnboarding,
        builder: (_, __) => const PermissionOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentScreenTimeSettings,
        builder: (_, __) => const ScreenTimeSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentAdaptiveSession,
        builder: (_, state) => AdaptiveSessionScreen(
          workspaceId: state.pathParameters['workspaceId']!,
          mode: adaptiveSessionModeFromWire(
            state.uri.queryParameters['mode'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.studentRevisionSession,
        builder: (_, state) {
          final autoStart = state.uri.queryParameters['autoStart'] == 'true';
          return RevisionScreen(
            workspaceId: state.pathParameters['workspaceId']!,
            autoStart: autoStart,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.studentDocuments,
        builder: (_, state) => DocumentsListScreen(
          workspaceId: state.pathParameters['workspaceId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.studentDocumentPolling,
        builder: (_, state) => DocumentPollingScreen(
          workspaceId: state.pathParameters['workspaceId']!,
          documentId: state.pathParameters['documentId']!,
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
        path: AppRoutes.adminStudentProgress,
        builder: (_, state) => StudentProgressDetailScreen(
          workspaceId: state.pathParameters['workspaceId']!,
          studentId: state.pathParameters['userId']!,
          // Display name rides as a ``?name=`` query param so the
          // AppBar can render it without a users lookup. The roster
          // already has the name in hand and just URL-encodes it.
          studentName: state.uri.queryParameters['name'] ?? 'Student progress',
        ),
      ),
      GoRoute(
        path: AppRoutes.adminWorkspaceAnalytics,
        builder: (_, state) => WorkspaceAnalyticsScreen(
          workspaceId: state.pathParameters['workspaceId']!,
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
