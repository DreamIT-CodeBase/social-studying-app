import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/onboarding/presentation/app_tour_sheet.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionPersistenceService.init();
  });

  group('SessionPersistenceService App Tour', () {
    test('defaults to false for new user, and updates to true when marked',
        () async {
      expect(SessionPersistenceService.instance.hasSeenAppTourSync('user_123'),
          isFalse);

      await SessionPersistenceService.instance
          .setAppTourSeen('user_123', seen: true);
      expect(SessionPersistenceService.instance.hasSeenAppTourSync('user_123'),
          isTrue);

      // Other users remain false
      expect(
          SessionPersistenceService.instance.hasSeenAppTourSync('other_user'),
          isFalse);
    });
  });

  group('AppTourSheet Widget', () {
    testWidgets('renders step 1 with Workspace Switcher title and skip button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AppTourSheet(userId: 'test_user'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Workspace Switcher'), findsOneWidget);
      expect(find.text('1 of 7'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('tapping Skip marks tour as seen', (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppTourSheet(
              userId: 'test_user_skip',
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(
          SessionPersistenceService.instance
              .hasSeenAppTourSync('test_user_skip'),
          isFalse);

      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
          SessionPersistenceService.instance
              .hasSeenAppTourSync('test_user_skip'),
          isTrue);
      expect(completed, isTrue);
    });

    testWidgets('tapping Next advances through all 7 steps to Got It',
        (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppTourSheet(
              userId: 'test_user_flow',
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Step 1: Workspace Switcher
      expect(find.text('Workspace Switcher'), findsOneWidget);
      expect(find.text('1 of 7'), findsOneWidget);

      // Step 2: Manage Study Materials
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Manage Study Materials'), findsOneWidget);
      expect(find.text('2 of 7'), findsOneWidget);

      // Step 3: Question Formats
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Question Formats'), findsOneWidget);
      expect(find.text('3 of 7'), findsOneWidget);

      // Step 4: Weekly Progress & Mastery
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Weekly Progress & Mastery'), findsOneWidget);
      expect(find.text('4 of 7'), findsOneWidget);

      // Step 5: Recent Activity & Questions
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Recent Activity & Questions'), findsOneWidget);
      expect(find.text('5 of 7'), findsOneWidget);

      // Step 6: Study Sessions (lower nav Study tab)
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Study Sessions'), findsOneWidget);
      expect(find.text('6 of 7'), findsOneWidget);

      // Step 7: Active Recall Flashcards (lower nav Flashcards tab)
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Active Recall Flashcards'), findsOneWidget);
      expect(find.text('7 of 7'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);

      // Tap Got It -> completes and marks seen
      await tester.tap(find.text('Got It'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          SessionPersistenceService.instance
              .hasSeenAppTourSync('test_user_flow'),
          isTrue);
      expect(completed, isTrue);
    });
  });
}
