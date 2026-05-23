import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/admin/moderation/data/demo_moderation_repository.dart';
import 'package:social_study_app/features/admin/moderation/data/moderation_repository.dart';
import 'package:social_study_app/features/admin/moderation/presentation/moderation_screen.dart';
import 'package:social_study_app/shared/models/moderation.dart';

class _MockRepo extends Mock implements ModerationRepository {}

const _wsId = 'wsp_test';

FlaggedItem _item({
  String id = 'mod_1',
  FlaggedContentKind kind = FlaggedContentKind.question,
  String topic = 'Cellular Respiration',
  String excerpt = 'Which process releases energy in the cell?',
  String reason = 'Violence',
  int severity = 2,
  ModerationVerdict verdict = ModerationVerdict.pending,
}) =>
    FlaggedItem(
      id: id,
      contentKind: kind,
      topic: topic,
      excerpt: excerpt,
      reason: reason,
      severity: severity,
      flaggedAt: '2026-05-22T08:00:00Z',
      verdict: verdict,
    );

Widget _wrap(_MockRepo repo) => ProviderScope(
      overrides: [
        moderationRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ModerationScreen(workspaceId: _wsId),
      ),
    );

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    // The Audit Log tab builds alongside the Queue tab — keep its
    // fetch stubbed in every test unless a test overrides it.
    when(() => repo.listLog(any())).thenAnswer((_) async => <FlaggedItem>[]);
  });

  testWidgets('queue shows a loading indicator while the fetch resolves',
      (tester) async {
    final completer = Completer<List<FlaggedItem>>();
    when(() => repo.listFlagged(any())).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();

    expect(find.text('Loading review queue…'), findsOneWidget);

    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('queue error state shows ErrorView with a retry action',
      (tester) async {
    when(() => repo.listFlagged(any())).thenThrow(Exception('queue down'));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('empty queue shows the all-clear empty state', (tester) async {
    when(() => repo.listFlagged(any()))
        .thenAnswer((_) async => <FlaggedItem>[]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to review'), findsOneWidget);
  });

  testWidgets('populated queue renders the flagged item details',
      (tester) async {
    when(() => repo.listFlagged(any())).thenAnswer((_) async => [_item()]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Cellular Respiration'), findsOneWidget);
    expect(
        find.text('Which process releases energy in the cell?'),
        findsOneWidget);
    expect(find.textContaining('Violence'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
  });

  testWidgets('approving an item calls resolve and clears it from the queue',
      (tester) async {
    var calls = 0;
    when(() => repo.listFlagged(any())).thenAnswer((_) async {
      calls++;
      return calls == 1 ? [_item()] : <FlaggedItem>[];
    });
    when(() => repo.resolve(
          workspaceId: any(named: 'workspaceId'),
          itemId: any(named: 'itemId'),
          approved: any(named: 'approved'),
        )).thenAnswer(
      (_) async => _item(verdict: ModerationVerdict.approved),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    verify(() => repo.resolve(
          workspaceId: _wsId,
          itemId: 'mod_1',
          approved: true,
        )).called(1);
    expect(find.text('Content approved'), findsOneWidget);
    expect(find.text('Nothing to review'), findsOneWidget);
  });

  testWidgets('rejecting an item calls resolve with approved false',
      (tester) async {
    var calls = 0;
    when(() => repo.listFlagged(any())).thenAnswer((_) async {
      calls++;
      return calls == 1 ? [_item()] : <FlaggedItem>[];
    });
    when(() => repo.resolve(
          workspaceId: any(named: 'workspaceId'),
          itemId: any(named: 'itemId'),
          approved: any(named: 'approved'),
        )).thenAnswer(
      (_) async => _item(verdict: ModerationVerdict.rejected),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();

    verify(() => repo.resolve(
          workspaceId: _wsId,
          itemId: 'mod_1',
          approved: false,
        )).called(1);
    expect(find.text('Content rejected'), findsOneWidget);
  });

  testWidgets('an already-resolved item surfaces a friendly message',
      (tester) async {
    when(() => repo.listFlagged(any())).thenAnswer((_) async => [_item()]);
    when(() => repo.resolve(
          workspaceId: any(named: 'workspaceId'),
          itemId: any(named: 'itemId'),
          approved: any(named: 'approved'),
        )).thenThrow(const FlaggedItemNotFoundException());

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(find.text('That item was already resolved'), findsOneWidget);
  });

  testWidgets('audit log tab shows resolved items with a verdict chip',
      (tester) async {
    when(() => repo.listFlagged(any()))
        .thenAnswer((_) async => <FlaggedItem>[]);
    when(() => repo.listLog(any())).thenAnswer(
      (_) async => [
        _item(id: 'mod_9', topic: 'Genetics', verdict: ModerationVerdict.approved),
      ],
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audit Log'));
    await tester.pumpAndSettle();

    expect(find.text('Genetics'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('empty audit log shows its own empty state', (tester) async {
    when(() => repo.listFlagged(any()))
        .thenAnswer((_) async => <FlaggedItem>[]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audit Log'));
    await tester.pumpAndSettle();

    expect(find.text('No resolved items'), findsOneWidget);
  });

  testWidgets('the demo repository drives the dashboard end to end',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moderationRepositoryProvider
              .overrideWithValue(DemoModerationRepository()),
        ],
        child: const MaterialApp(
          home: ModerationScreen(workspaceId: 'wsp_demo_001'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The demo seed has two pending items in the queue.
    expect(find.text('Cellular Respiration'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsNWidgets(2));
  });
}
