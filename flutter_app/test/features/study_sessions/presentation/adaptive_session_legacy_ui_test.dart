import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/study_sessions/presentation/adaptive_session_legacy_ui.dart';

void main() {
  testWidgets('shows the reverse timer immediately to the right of XP',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegacySessionHeader(
            current: 1,
            total: 7,
            remainingSeconds: 15 * 60,
            sessionXp: 0,
            lastXpDelta: null,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('15:00'), findsOneWidget);
    expect(
      tester.getCenter(find.text('15:00')).dx,
      greaterThan(tester.getCenter(find.text('0 XP').first).dx),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegacySessionHeader(
            current: 1,
            total: 7,
            remainingSeconds: 14 * 60 + 59,
            sessionXp: 0,
            lastXpDelta: null,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('14:59'), findsOneWidget);
  });
}
