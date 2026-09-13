import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/study_sessions/domain/adaptive_session_models.dart';
import 'package:social_study_app/features/study_sessions/presentation/adaptive_session_legacy_ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  required AdaptiveSessionMode mode,
  required bool canUpload,
  VoidCallback? onUpload,
  VoidCallback? onClose,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionExhaustedView(
            mode: mode,
            canUpload: canUpload,
            onUpload: onUpload ?? () {},
            onClose: onClose ?? () {},
          ),
        ),
      ),
    );

void main() {
  group('SessionExhaustedView', () {
    testWidgets('prompts a self-study learner to upload more material',
        (tester) async {
      await _pump(tester, mode: AdaptiveSessionMode.study, canUpload: true);

      expect(find.text('All caught up!'), findsOneWidget);
      expect(find.text('Upload more study material'), findsOneWidget);
      expect(find.textContaining('every question'), findsOneWidget);
      // It is a call-to-action, not a failure — no retry affordance.
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('uses flashcard wording in flashcard mode', (tester) async {
      await _pump(tester, mode: AdaptiveSessionMode.flashcard, canUpload: true);

      expect(find.textContaining('every flashcard'), findsOneWidget);
      expect(find.textContaining('every question'), findsNothing);
    });

    testWidgets('hides the upload action when the learner cannot add material',
        (tester) async {
      await _pump(tester, mode: AdaptiveSessionMode.study, canUpload: false);

      expect(find.text('Upload more study material'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('All caught up!'), findsOneWidget);
    });

    testWidgets('invokes the upload callback when tapped', (tester) async {
      var uploads = 0;
      await _pump(
        tester,
        mode: AdaptiveSessionMode.study,
        canUpload: true,
        onUpload: () => uploads++,
      );

      await tester.tap(find.text('Upload more study material'));
      await tester.pump();

      expect(uploads, 1);
    });

    testWidgets('invokes the close callback when dismissed', (tester) async {
      var closes = 0;
      await _pump(
        tester,
        mode: AdaptiveSessionMode.study,
        canUpload: true,
        onClose: () => closes++,
      );

      await tester.tap(find.text('Not now'));
      await tester.pump();

      expect(closes, 1);
    });
  });
}
