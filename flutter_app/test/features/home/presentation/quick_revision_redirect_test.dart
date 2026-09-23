import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/routing/router.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/features/home/presentation/student_home_screen.dart';
import 'package:social_study_app/shared/models/workspace.dart';

void main() {
  group('Quick Revision in Self Study Workspace', () {
    test(
        'isSelfLearningWorkspaceId accurately identifies self study workspaces',
        () {
      expect(isSelfLearningWorkspaceId('wsp_self_student123'), isTrue);
      expect(isSelfLearningWorkspaceId('wsp_group_class_4a'), isFalse);
    });

    test('studentHomeTabProvider index 1 corresponds to the Study tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default tab is 0 (Home)
      expect(container.read(studentHomeTabProvider), 0);

      // Switching to tab 1 switches to Study tab
      container.read(studentHomeTabProvider.notifier).state = 1;
      expect(container.read(studentHomeTabProvider), 1);
    });

    testWidgets(
        'GoRouter redirect for self study revision redirects to studentHome with tab=1',
        (tester) async {
      late BuildContext buildCtx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              buildCtx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final r = container.read(routerProvider);

      final route = r.configuration.routes.whereType<GoRoute>().firstWhere(
          (route) => route.path == AppRoutes.studentRevisionSession);

      final mockStateSelfStudy = GoRouterState(
        r.configuration,
        matchedLocation: '/student/revision/wsp_self_123',
        fullPath: AppRoutes.studentRevisionSession,
        pathParameters: const {'workspaceId': 'wsp_self_123'},
        uri: Uri.parse('/student/revision/wsp_self_123'),
        pageKey: const ValueKey('test1'),
      );

      final redirectResultSelfStudy = route.redirect?.call(
        buildCtx,
        mockStateSelfStudy,
      );

      expect(redirectResultSelfStudy, '${AppRoutes.studentHome}?tab=1');

      final mockStateGroup = GoRouterState(
        r.configuration,
        matchedLocation: '/student/revision/wsp_group_123',
        fullPath: AppRoutes.studentRevisionSession,
        pathParameters: const {'workspaceId': 'wsp_group_123'},
        uri: Uri.parse('/student/revision/wsp_group_123'),
        pageKey: const ValueKey('test2'),
      );

      final redirectResultGroup = route.redirect?.call(
        buildCtx,
        mockStateGroup,
      );

      expect(redirectResultGroup, isNull);
    });
  });
}
