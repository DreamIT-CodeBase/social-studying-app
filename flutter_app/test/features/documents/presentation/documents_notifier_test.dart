import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/features/documents/presentation/documents_notifier.dart';
import 'package:social_study_app/shared/models/document.dart';

class _MockRepo extends Mock implements DocumentsRepository {}

Document _doc({String id = 'doc_a', String filename = 'study.pdf'}) => Document(
      id: id,
      workspaceId: 'wsp_test',
      filename: filename,
      docType: DocumentType.pdf,
      status: DocumentStatus.ready,
      createdAt: '2026-05-15T00:00:00+00:00',
    );

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = _MockRepo();
    container = ProviderContainer(
      overrides: [
        documentsRepositoryProvider.overrideWith((_) => repo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns the list from the repository', () async {
    when(() => repo.list(workspaceId: 'wsp_test')).thenAnswer(
      (_) async => [_doc(id: 'doc_a'), _doc(id: 'doc_b')],
    );

    final docs = await container.read(documentsListProvider('wsp_test').future);

    expect(docs.map((d) => d.id), ['doc_a', 'doc_b']);
    verify(() => repo.list(workspaceId: 'wsp_test')).called(1);
  });

  test('build returns empty list when no documents exist', () async {
    when(() => repo.list(workspaceId: 'wsp_test'))
        .thenAnswer((_) async => const []);

    final docs = await container.read(documentsListProvider('wsp_test').future);

    expect(docs, isEmpty);
  });

  test('refresh re-fetches the list', () async {
    var callCount = 0;
    when(() => repo.list(workspaceId: 'wsp_test')).thenAnswer((_) async {
      callCount++;
      return [_doc(id: 'doc_$callCount')];
    });

    // Initial fetch.
    final first =
        await container.read(documentsListProvider('wsp_test').future);
    expect(first.single.id, 'doc_1');

    // refresh() invalidates → build re-runs.
    container.read(documentsListProvider('wsp_test').notifier).refresh();
    final second =
        await container.read(documentsListProvider('wsp_test').future);
    expect(second.single.id, 'doc_2');

    verify(() => repo.list(workspaceId: 'wsp_test')).called(2);
  });

  test('deleteDocument deletes through repository and updates the list',
      () async {
    when(() => repo.list(workspaceId: 'wsp_test')).thenAnswer(
      (_) async => [_doc(id: 'doc_a'), _doc(id: 'doc_b')],
    );
    when(
      () => repo.delete(
        workspaceId: 'wsp_test',
        documentId: 'doc_a',
      ),
    ).thenAnswer((_) async {});

    await container.read(documentsListProvider('wsp_test').future);
    await container
        .read(documentsListProvider('wsp_test').notifier)
        .deleteDocument('doc_a');

    final remaining =
        container.read(documentsListProvider('wsp_test')).requireValue;
    expect(remaining.map((document) => document.id), ['doc_b']);
    verify(
      () => repo.delete(
        workspaceId: 'wsp_test',
        documentId: 'doc_a',
      ),
    ).called(1);
  });

  test('repository error propagates as AsyncError', () async {
    when(() => repo.list(workspaceId: 'wsp_test'))
        .thenThrow(Exception('backend is down'));

    expect(
      () => container.read(documentsListProvider('wsp_test').future),
      throwsA(isA<Exception>()),
    );
  });
}
