import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/presentation/login_screen.dart';
import 'package:social_study_app/shared/models/user.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _buildSubject({required AuthRepository repo}) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const LoginScreen(),
    ),
  );
}

void main() {
  late _MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = _MockAuthRepository();
    when(() => mockRepo.getStoredUser()).thenAnswer((_) async => null);
  });

  group('LoginScreen — unauthenticated', () {
    testWidgets('shows sign-in buttons', (tester) async {
      await tester.pumpWidget(_buildSubject(repo: mockRepo));
      await tester.pump(); // let FutureProvider resolve

      expect(find.text('Sign in / Sign up with Email'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Continue with Demo Account'), findsNothing);
    });

    testWidgets('shows app name and tagline', (tester) async {
      await tester.pumpWidget(_buildSubject(repo: mockRepo));
      await tester.pump();

      expect(find.text('Welcome to Social Studying'), findsOneWidget);
      expect(
        find.text('Sign in to continue learning.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'shows loading indicator while Microsoft sign-in is in progress',
        (tester) async {
      final completer = Completer<User>();
      when(() => mockRepo.signInWithMicrosoft())
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(_buildSubject(repo: mockRepo));
      await tester.pump();

      await tester.tap(find.text('Sign in / Sign up with Email'));
      await tester.pump(); // trigger loading state

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in / Sign up with Email'), findsNothing);

      completer.complete(_fakeUser); // clean up pending future
      await tester.pumpAndSettle();
    });

    testWidgets('shows loading indicator while Google sign-in is in progress',
        (tester) async {
      final completer = Completer<User>();
      when(() => mockRepo.signInWithGoogle())
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(_buildSubject(repo: mockRepo));
      await tester.pump();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump(); // trigger loading state

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);

      completer.complete(_fakeUser); // clean up pending future
      await tester.pumpAndSettle();
    });

    testWidgets('shows error view when Microsoft sign-in fails',
        (tester) async {
      when(() => mockRepo.signInWithMicrosoft())
          .thenThrow(Exception('Auth failed'));

      await tester.pumpWidget(_buildSubject(repo: mockRepo));
      await tester.pump();

      await tester.tap(find.text('Sign in / Sign up with Email'));
      await tester.pumpAndSettle();

      expect(find.text('Auth failed'), findsOneWidget);
      expect(find.text('Sign in / Sign up with Email'), findsOneWidget);
    });

    testWidgets('shows error view when Google sign-in fails', (tester) async {
      when(() => mockRepo.signInWithGoogle())
          .thenThrow(Exception('Auth failed'));

      await tester.pumpWidget(_buildSubject(repo: mockRepo));
      await tester.pump();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Auth failed'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });
  });

  group('LoginScreen — previously authenticated', () {
    testWidgets('shows loading while checking stored session', (tester) async {
      final completer = Completer<User?>();
      when(() => mockRepo.getStoredUser()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(_buildSubject(repo: mockRepo));
      await tester.pump(); // first frame — future not yet resolved

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(null); // clean up pending future
      await tester.pumpAndSettle();
    });
  });
}

final _fakeUser = User(
  id: 'usr_test_001',
  email: 'test@example.com',
  displayName: 'Test User',
  tenantId: 'ten_test_001',
  role: UserRole.tenantAdmin,
  createdAt: DateTime(2026),
  lastLogin: DateTime(2026),
);
