import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/gamification/presentation/widgets/celebration_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pumps a minimal app with a button that fires [onPressed]. Lets each
/// test trigger the overlay from a real BuildContext so the navigator
/// has a route to push onto.
Future<void> _pumpTrigger(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onPressed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => onPressed(context),
              child: const Text('FIRE'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('showLevelUpBurst', () {
    testWidgets('shows the new level number', (tester) async {
      await _pumpTrigger(
        tester,
        onPressed: (context) => showLevelUpBurst(context, newLevel: 7),
      );

      await tester.tap(find.text('FIRE'));
      // Just enough to render the first frame of the overlay.
      await tester.pump();
      await tester.pump();

      expect(find.text('Level Up!'), findsOneWidget);
      expect(find.text('You reached Level 7'), findsOneWidget);

      // Let the auto-dismiss animation play out and pop the route.
      await tester.pumpAndSettle();
      expect(find.text('Level Up!'), findsNothing);
    });

    testWidgets('auto-dismisses when the animation completes',
        (tester) async {
      var resolved = false;
      await _pumpTrigger(
        tester,
        onPressed: (context) async {
          await showLevelUpBurst(context, newLevel: 2);
          resolved = true;
        },
      );

      await tester.tap(find.text('FIRE'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
    });
  });

  group('showBadgeUnlockSheet', () {
    testWidgets('shows badge name, description, and dismiss button',
        (tester) async {
      await _pumpTrigger(
        tester,
        onPressed: (context) => showBadgeUnlockSheet(
          context,
          badgeId: 'streak_7',
          name: 'Dedicated',
          description: 'Maintain a seven-day study streak.',
          icon: 'local_fire_department_rounded',
        ),
      );

      await tester.tap(find.text('FIRE'));
      await tester.pumpAndSettle();

      expect(find.text('BADGE UNLOCKED'), findsOneWidget);
      expect(find.text('Dedicated'), findsOneWidget);
      expect(
        find.text('Maintain a seven-day study streak.'),
        findsOneWidget,
      );
      expect(find.text('Nice!'), findsOneWidget);
    });

    testWidgets('Nice! button dismisses the sheet', (tester) async {
      var resolved = false;
      await _pumpTrigger(
        tester,
        onPressed: (context) async {
          await showBadgeUnlockSheet(
            context,
            badgeId: 'first_steps',
            name: 'First Steps',
            description: 'Answer your first question.',
            icon: 'spa_rounded',
          );
          resolved = true;
        },
      );

      await tester.tap(find.text('FIRE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nice!'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(find.text('First Steps'), findsNothing);
    });
  });
}
