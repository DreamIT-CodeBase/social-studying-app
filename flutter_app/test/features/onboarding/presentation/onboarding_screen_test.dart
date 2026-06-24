import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/shared/services/dio_client.dart';
import 'package:dio/dio.dart';

class _MockWorkspacesRepo extends Mock implements WorkspacesRepository {}

class _FakeWorkspaceSettings extends Fake implements WorkspaceSettings {}

/// Stub auth repo so ``AuthNotifier.refresh`` doesn't hit unmocked
/// secure storage (which hangs the test). The wizard calls refresh
/// after a successful create — see Sprint 6 /review fix.
class _StubAuthRepo implements AuthRepository {
  const _StubAuthRepo();

  @override
  Future<User> signInWithMicrosoft() async => _user;

  @override
  Future<void> signOut() async {}

  @override
  Future<User?> getStoredUser() async => _user;

  @override
  Future<void> updateStoredUser(User user) async {}

  @override
  Future<User> redeemInviteCode(String code) async => _user;

  static final _user = User(
    id: 'usr_test',
    email: 'test@example.com',
    displayName: 'Test Admin',
    tenantId: 'ten_test',
    role: UserRole.tenantAdmin,
    workspaceMemberships: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}


class _MockDioClient extends Mock implements DioClient {}
class _MockDio extends Mock implements Dio {}

/// Builds a minimal app that renders the onboarding screen at ``/``
/// and the post-onboarding dashboard stub at ``/admin/dashboard``.
/// The wizard calls ``context.go(AppRoutes.adminDashboard)`` on
/// success — the stub at that route lets us assert the navigation
/// without booting the whole admin home tree.
Widget _wrap({required WorkspacesRepository repo}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Dashboard stub')),
        ),
      ),
    ],
  );
  
  final mockDioClient = _MockDioClient();
  final mockDio = _MockDio();
  when(() => mockDioClient.dio).thenReturn(mockDio);
  when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'), options: any(named: 'options'), cancelToken: any(named: 'cancelToken'), onReceiveProgress: any(named: 'onReceiveProgress')))
      .thenThrow(DioException(requestOptions: RequestOptions(path: '/users/me')));

  return ProviderScope(
    overrides: [
      workspacesRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(const _StubAuthRepo()),
      dioClientProvider.overrideWithValue(mockDioClient),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}


void main() {
  setUpAll(() {
    registerFallbackValue(_FakeWorkspaceSettings());
  });

  late _MockWorkspacesRepo repo;

  setUp(() {
    repo = _MockWorkspacesRepo();
  });

  testWidgets('first screen offers parent and teacher role choices',
      (tester) async {
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text("I'm a Parent"), findsOneWidget);
    expect(find.text("I'm a Teacher"), findsOneWidget);
  });

  testWidgets('parent choice seeds the family workspace default',
      (tester) async {
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a Parent"));
    await tester.pumpAndSettle();

    expect(find.text('Name your workspace'), findsOneWidget);
    // The default seeds visible in the text fields.
    expect(find.text('Family Study'), findsOneWidget);
    expect(find.text('Daily learning at home.'), findsOneWidget);
  });

  testWidgets('teacher choice seeds the classroom workspace default',
      (tester) async {
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a Teacher"));
    await tester.pumpAndSettle();

    expect(find.text('My Class'), findsOneWidget);
    expect(find.text('Classroom learning space.'), findsOneWidget);
  });

  testWidgets('back button returns from step 2 to step 1', (tester) async {
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a Parent"));
    await tester.pumpAndSettle();
    expect(find.text('Name your workspace'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Welcome!'), findsOneWidget);
  });

  testWidgets('create button calls the repo and navigates to dashboard',
      (tester) async {
    when(
      () => repo.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async => Workspace(
          id: 'wsp_a',
          tenantId: 'ten_a',
          name: 'Family Study',
          description: 'Daily learning at home.',
          settings: const WorkspaceSettings(),
          createdAt: DateTime(2026, 5, 27),
          studentCount: 0,
          documentCount: 0,
          adminCount: 1,
        ));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm a Parent"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard stub'), findsOneWidget);
    verify(
      () => repo.create(
        name: 'Family Study',
        description: 'Daily learning at home.',
      ),
    ).called(1);
  });

  testWidgets('empty workspace name shows an inline error', (tester) async {
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm a Parent"));
    await tester.pumpAndSettle();

    // Clear the default name.
    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('Create workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace name is required'), findsOneWidget);
    // The repository wasn't called.
    verifyNever(
      () => repo.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    );
  });

  testWidgets('name conflict from backend surfaces as inline error',
      (tester) async {
    when(
      () => repo.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    ).thenThrow(
      const WorkspaceNameConflictException('A workspace with that name already exists'),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm a Teacher"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create workspace'));
    await tester.pumpAndSettle();

    // Error message lands as the field's errorText.
    expect(
      find.text('A workspace with that name already exists'),
      findsOneWidget,
    );
  });
}
