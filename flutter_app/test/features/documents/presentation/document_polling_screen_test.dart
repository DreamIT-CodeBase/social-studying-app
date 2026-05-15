import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart'
    show DocumentNotFoundException;
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/features/documents/presentation/document_polling_notifier.dart';
import 'package:social_study_app/features/documents/presentation/document_polling_screen.dart';
import 'package:social_study_app/shared/models/document.dart';

class _MockRepo extends Mock implements DocumentsRepository {}

Document _doc({
  DocumentStatus status = DocumentStatus.ready,
  String filename = 'study.pdf',
  int chunkCount = 9,
  List<TopicTag> topicTags = const [TopicTag(name: 'Photosynthesis')],
  int? pageCount = 12,
  int? textCharCount = 18420,
  String? processingError,
}) =>
    Document(
      id: 'doc_test',
      workspaceId: 'wsp_test',
      filename: filename,
      docType: DocumentType.pdf,
      status: status,
      chunkCount: chunkCount,
      topicTags: topicTags,
      createdAt: '2026-05-15T00:00:00+00:00',
      pageCount: pageCount,
      textCharCount: textCharCount,
      languages: const ['en'],
      processingError: processingError,
    );

Widget _wrap({required _MockRepo repo}) => ProviderScope(
      overrides: [documentsRepositoryProvider.overrideWith((_) => repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const DocumentPollingScreen(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        ),
      ),
    );

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    // Long enough to keep the polling timer from firing during tests
    // (we only validate the first frame).
    DocumentPolling.debugInterval = const Duration(seconds: 30);
  });

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows loading indicator while initial fetch resolves',
      (tester) async {
    final completer = Completer<Document>();
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(_doc());
    await tester.pumpAndSettle();
  });

  testWidgets('ready doc shows success hero + filename in app bar',
      (tester) async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => _doc());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('study.pdf'), findsOneWidget);
    expect(find.text('Ready for questions'), findsOneWidget);
    expect(
      find.textContaining('9 indexed chunks across 1 topics'),
      findsOneWidget,
    );
    // Stage stepper present with the Ready row visible.
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('vectorizing doc shows in-progress hero + spinner',
      (tester) async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => _doc(status: DocumentStatus.vectorizing));

    await tester.pumpWidget(_wrap(repo: repo));
    // Cannot use pumpAndSettle here: the in-progress hero renders an
    // indeterminate CircularProgressIndicator which never settles. Two
    // pumps are enough: one to resolve the FutureProvider, one to build
    // with the resolved data.
    await tester.pump();
    await tester.pump();

    // 'Building search index' appears in both the hero and the active
    // row of the stage stepper — both are correct UX. findsWidgets just
    // asserts the label is on screen somewhere.
    expect(find.text('Building search index'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('failed doc surfaces processing_error in the hero',
      (tester) async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => _doc(
          status: DocumentStatus.failed,
          processingError: 'Document Intelligence rejected the file',
        ));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Processing failed'), findsOneWidget);
    expect(
      find.text('Document Intelligence rejected the file'),
      findsOneWidget,
    );
  });

  testWidgets('flagged doc shows the moderation hero', (tester) async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => _doc(status: DocumentStatus.flagged));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Flagged for review'), findsOneWidget);
  });

  testWidgets('renders metadata + topics cards when data is present',
      (tester) async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => _doc(
          topicTags: const [
            TopicTag(name: 'Photosynthesis'),
            TopicTag(name: 'Mitosis'),
          ],
        ));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Document details'), findsOneWidget);
    expect(find.text('Pages'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Topics found'), findsOneWidget);
    expect(find.text('Photosynthesis'), findsOneWidget);
    expect(find.text('Mitosis'), findsOneWidget);
  });

  testWidgets('initial DocumentNotFoundException renders the 404 view',
      (tester) async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => throw const DocumentNotFoundException());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('This document is no longer available.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });
}
