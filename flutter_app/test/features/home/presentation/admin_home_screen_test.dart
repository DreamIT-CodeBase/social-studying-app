import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/home/presentation/admin_home_screen.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockWorkspacesRepository extends Mock implements WorkspacesRepository {}

void main() {
  testWidgets(
      'AdminHomeScreen renders 4 navigation destinations without Notifications tab',
      (tester) async {
    final authRepo = _MockAuthRepository();
    final workspacesRepo = _MockWorkspacesRepository();
    final createdAt = DateTime(2026, 1, 1);

    final user = User(
      id: 'usr_admin',
      email: 'admin@example.com',
      displayName: 'Admin Jane',
      tenantId: 'ten_test',
      role: UserRole.workspaceAdmin,
      workspaceMemberships: [
        WorkspaceMembership(
          workspaceId: 'wsp_classroom',
          role: UserRole.workspaceAdmin,
          joinedAt: createdAt,
        ),
      ],
      createdAt: createdAt,
    );

    final workspace = Workspace(
      id: 'wsp_classroom',
      tenantId: 'ten_test',
      name: 'Science Classroom',
      settings: const WorkspaceSettings(),
      createdAt: createdAt,
    );

    when(authRepo.getStoredUser).thenAnswer((_) async => user);
    when(workspacesRepo.list).thenAnswer((_) async => [workspace]);

    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          workspacesRepositoryProvider.overrideWithValue(workspacesRepo),
        ],
        child: const MaterialApp(
          home: AdminHomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify 4 tabs exist in navigation bar
    expect(find.widgetWithText(NavigationDestination, 'Dashboard'),
        findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Documents'),
        findsOneWidget);
    expect(
        find.widgetWithText(NavigationDestination, 'Students'), findsOneWidget);
    expect(
        find.widgetWithText(NavigationDestination, 'Settings'), findsOneWidget);

    // Verify Notifications tab does NOT exist in navigation
    expect(find.widgetWithText(NavigationDestination, 'Notifications'),
        findsNothing);
  });
}
