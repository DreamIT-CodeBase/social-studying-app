import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart';
import 'package:social_study_app/shared/models/document.dart';

void main() {
  // Use a tiny stage interval so the state machine walks all stages
  // within a sensible test time-budget.
  late DemoDocumentsRepository repo;

  setUp(() {
    repo =
        DemoDocumentsRepository(stageDuration: const Duration(milliseconds: 5));
  });

  group('upload', () {
    test('returns a pending Document and stores it', () async {
      final doc = await repo.upload(
        workspaceId: 'wsp_x',
        filename: 'study.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        contentType: 'application/pdf',
      );

      expect(doc.status, DocumentStatus.pending);
      expect(doc.filename, 'study.pdf');
      expect(doc.docType, DocumentType.pdf);
      expect(doc.id, startsWith('doc_'));

      final fetched = await repo.get(
        workspaceId: 'wsp_x',
        documentId: doc.id,
      );
      expect(fetched.id, doc.id);
    });

    test('rejects empty files', () async {
      expect(
        () => repo.upload(
          workspaceId: 'wsp_x',
          filename: 'empty.pdf',
          bytes: Uint8List(0),
          contentType: 'application/pdf',
        ),
        throwsA(isA<EmptyUploadException>()),
      );
    });

    test('rejects unsupported MIME and unknown extension', () async {
      expect(
        () => repo.upload(
          workspaceId: 'wsp_x',
          filename: 'evil.exe',
          bytes: Uint8List.fromList([0x4D, 0x5A]),
          contentType: 'application/x-msdownload',
        ),
        throwsA(isA<UnsupportedFileTypeException>()),
      );
    });

    test('falls back to extension when content type is empty', () async {
      final doc = await repo.upload(
        workspaceId: 'wsp_x',
        filename: 'notes.txt',
        bytes: Uint8List.fromList([0x68, 0x69]),
        contentType: '',
      );
      expect(doc.docType, DocumentType.text);
    });
  });

  group('state machine', () {
    test('walks pending → ready and stops there', () async {
      final doc = await repo.upload(
        workspaceId: 'wsp_x',
        filename: 'study.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        contentType: 'application/pdf',
      );

      // Each stage is 5ms; the pipeline has 8 transitions to reach
      // ready. Wait generously to give Future cooperative scheduling
      // some headroom on slow CI machines.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final final_ = await repo.get(
        workspaceId: 'wsp_x',
        documentId: doc.id,
      );
      expect(final_.status, DocumentStatus.ready);
      expect(final_.chunkCount, greaterThan(0));
      expect(final_.topicTags, isNotEmpty);
      expect(final_.pageCount, isNotNull);
      expect(final_.textCharCount, isNotNull);
      expect(final_.languages, isNotEmpty);
    });

    test('intermediate snapshot exposes side effects in order', () async {
      final doc = await repo.upload(
        workspaceId: 'wsp_x',
        filename: 'study.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        contentType: 'application/pdf',
      );

      // After ~25ms we should be past the text_extracted transition
      // (5ms pending→extracting + 5ms extracting→text_extracted = 10ms,
      // so by 25ms we should be well into topic extraction).
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final snap = await repo.get(
        workspaceId: 'wsp_x',
        documentId: doc.id,
      );
      // Page count appears at text_extracted regardless of where we
      // are after — proves the side effects accumulate.
      expect(snap.pageCount, isNotNull);
      expect(snap.textCharCount, isNotNull);
    });
  });

  group('list / delete', () {
    test('list returns docs sorted newest first', () async {
      final first = await repo.upload(
        workspaceId: 'wsp_x',
        filename: 'a.pdf',
        bytes: Uint8List.fromList([0x25]),
        contentType: 'application/pdf',
      );
      // Tiny gap to ensure distinct createdAt timestamps.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await repo.upload(
        workspaceId: 'wsp_x',
        filename: 'b.pdf',
        bytes: Uint8List.fromList([0x25]),
        contentType: 'application/pdf',
      );
      final list = await repo.list(workspaceId: 'wsp_x');
      expect(list.first.id, second.id);
      expect(list.last.id, first.id);
    });

    test('delete removes the doc and cancels its timer', () async {
      final doc = await repo.upload(
        workspaceId: 'wsp_x',
        filename: 'study.pdf',
        bytes: Uint8List.fromList([0x25]),
        contentType: 'application/pdf',
      );
      await repo.delete(workspaceId: 'wsp_x', documentId: doc.id);
      expect(
        () => repo.get(workspaceId: 'wsp_x', documentId: doc.id),
        throwsA(isA<DocumentNotFoundException>()),
      );
      // No way to assert "timer cancelled" except that the call doesn't
      // throw; the deleted doc isn't reinserted by an in-flight stage.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        () => repo.get(workspaceId: 'wsp_x', documentId: doc.id),
        throwsA(isA<DocumentNotFoundException>()),
      );
    });

    test('get on missing doc throws DocumentNotFoundException', () async {
      expect(
        () => repo.get(workspaceId: 'wsp_x', documentId: 'doc_missing'),
        throwsA(isA<DocumentNotFoundException>()),
      );
    });
  });
}
