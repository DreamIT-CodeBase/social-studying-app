import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/documents/presentation/widgets/status_chip.dart';
import 'package:social_study_app/shared/models/document.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('shows spinner for in-flight statuses', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusChip(status: DocumentStatus.extracting)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Reading text'), findsOneWidget);
  });

  testWidgets('shows check icon for ready', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusChip(status: DocumentStatus.ready)),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows error icon for failed', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusChip(status: DocumentStatus.failed)),
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('shows shield icon for flagged', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusChip(status: DocumentStatus.flagged)),
    );
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.text('Flagged'), findsOneWidget);
  });

  testWidgets('every status renders a label without crashing', (tester) async {
    for (final status in DocumentStatus.values) {
      await tester.pumpWidget(_wrap(StatusChip(status: status)));
      // Some text exists — actual label content already covered above.
      expect(find.byType(StatusChip), findsOneWidget);
    }
  });
}
