import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/core/theme/app_theme.dart';
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/features/documents/presentation/documents_list_screen.dart';
import 'package:social_study_app/shared/models/document.dart';

class _MockRepo extends Mock implements DocumentsRepository {}

Document _doc({
  String id = 'doc_1',
  String filename = 'study.pdf',
  DocumentStatus status = DocumentStatus.ready,
  int chunkCount = 5,
}) =>
    Document(
      id: id,
      workspaceId: 'wsp_test',
      filename: filename,
      docType: DocumentType.pdf,
      status: status,
      chunkCount: chunkCount,
      createdAt: '2026-05-15T00:00:00+00:00',
    );

Widget _wrap({required _MockRepo repo}) {
  return ProviderScope(
    overrides: [documentsRepositoryProvider.overrideWith((_) => repo)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: DocumentsListScreen(workspaceId: 'wsp_test'),
      ),
    ),
  );
}

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = _MockRepo();
  });

  testWidgets('shows loading then empty state when no docs exist', (tester) async {
    final completer = Completer<List<Document>>();
    when(() => repo.list(workspaceId: 'wsp_test'))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump(); // first frame

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('No documents yet'), findsOneWidget);
    expect(find.text('Upload Document'), findsOneWidget);
  });

  testWidgets('shows the docs list with status chips when docs exist',
      (tester) async {
    when(() => repo.list(workspaceId: 'wsp_test')).thenAnswer((_) async => [
          _doc(id: 'doc_a', filename: 'biology.pdf'),
          _doc(
            id: 'doc_b',
            filename: 'math.pdf',
            status: DocumentStatus.extracting,
          ),
        ]);

    await tester.pumpWidget(_wrap(repo: repo));
    // Cannot use pumpAndSettle here: the in-flight doc renders a
    // CircularProgressIndicator inside its StatusChip which never settles.
    // Two pumps are enough: one to resolve the FutureProvider, one to build.
    await tester.pump();
    await tester.pump();

    expect(find.text('biology.pdf'), findsOneWidget);
    expect(find.text('math.pdf'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Reading text'), findsOneWidget);
    // FAB present once list non-empty.
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('shows error view + retry on list failure', (tester) async {
    when(() => repo.list(workspaceId: 'wsp_test'))
        .thenThrow(Exception('Network down'));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('detail line summarises pages, chunks, and topics', (tester) async {
    when(() => repo.list(workspaceId: 'wsp_test')).thenAnswer(
      (_) async => [
        const Document(
          id: 'doc_a',
          workspaceId: 'wsp_test',
          filename: 'biology.pdf',
          docType: DocumentType.pdf,
          status: DocumentStatus.ready,
          pageCount: 12,
          chunkCount: 9,
          topicTags: [
            TopicTag(name: 'Photosynthesis'),
            TopicTag(name: 'Mitosis'),
          ],
          createdAt: '2026-05-15T00:00:00+00:00',
        ),
      ],
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('12 pages • 9 chunks • 2 topics'), findsOneWidget);
  });
}
