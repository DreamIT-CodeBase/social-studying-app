import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/documents/presentation/widgets/pipeline_stages.dart';
import 'package:social_study_app/features/documents/presentation/widgets/stage_stepper.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('renders one row per stage with the correct label',
      (tester) async {
    final rows = [
      const StageRow(stage: PipelineStage.uploaded, state: StageRowState.done),
      const StageRow(
          stage: PipelineStage.extracting, state: StageRowState.active),
      const StageRow(
          stage: PipelineStage.topics, state: StageRowState.upcoming),
    ];
    await tester.pumpWidget(_wrap(StageStepper(rows: rows)));

    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.text('Reading text'), findsOneWidget);
    expect(find.text('Identifying topics'), findsOneWidget);
  });

  testWidgets('done state renders a check icon', (tester) async {
    final rows = [
      const StageRow(stage: PipelineStage.uploaded, state: StageRowState.done),
    ];
    await tester.pumpWidget(_wrap(StageStepper(rows: rows)));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('active state renders a CircularProgressIndicator',
      (tester) async {
    final rows = [
      const StageRow(
          stage: PipelineStage.extracting, state: StageRowState.active),
    ];
    await tester.pumpWidget(_wrap(StageStepper(rows: rows)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state renders the error icon', (tester) async {
    final rows = [
      const StageRow(
          stage: PipelineStage.extracting, state: StageRowState.error),
    ];
    await tester.pumpWidget(_wrap(StageStepper(rows: rows)));
    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
  });
}
