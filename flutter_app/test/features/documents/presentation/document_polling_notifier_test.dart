import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart'
    show DocumentNotFoundException;
import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/features/documents/presentation/document_polling_notifier.dart';
import 'package:social_study_app/shared/models/document.dart';

class _MockRepo extends Mock implements DocumentsRepository {}

Document _doc({DocumentStatus status = DocumentStatus.pending}) => Document(
      id: 'doc_test',
      workspaceId: 'wsp_test',
      filename: 'study.pdf',
      docType: DocumentType.pdf,
      status: status,
      createdAt: '2026-05-15T00:00:00+00:00',
    );

void main() {
  late _MockRepo repo;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    // Tiny interval so the test isn't sleeping for seconds.
    DocumentPolling.debugInterval = const Duration(milliseconds: 5);
    repo = _MockRepo();
    container = ProviderContainer(
      overrides: [
        documentsRepositoryProvider.overrideWith((_) => repo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    DocumentPolling.debugInterval = kDocumentPollInterval;
  });

  test('first build returns the initial fetch', () async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => _doc(status: DocumentStatus.extracting));

    final initial = await container.read(
      documentPollingProvider(
        workspaceId: 'wsp_test',
        documentId: 'doc_test',
      ).future,
    );
    expect(initial.status, DocumentStatus.extracting);
  });

  test(
    'continues polling while status is non-terminal, stops on ready',
    () async {
      // First call returns extracting, second returns vectorizing, third
      // returns ready. After ready, no further calls should happen.
      var callCount = 0;
      final stages = [
        DocumentStatus.extracting,
        DocumentStatus.vectorizing,
        DocumentStatus.ready,
      ];
      when(() => repo.get(
            workspaceId: 'wsp_test',
            documentId: 'doc_test',
          )).thenAnswer((_) async {
        final i = callCount.clamp(0, stages.length - 1);
        callCount++;
        return _doc(status: stages[i]);
      });

      // Subscribe so the provider stays alive while we wait.
      container.listen(
        documentPollingProvider(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        ),
        (_, __) {},
      );

      await container.read(
        documentPollingProvider(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        ).future,
      );

      // Wait long enough for two more polls (5ms each) plus a buffer.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final state = container.read(
        documentPollingProvider(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        ),
      );
      expect(state.value?.status, DocumentStatus.ready);

      // After ready, no further repo calls should happen even with
      // additional waits.
      final countAfterReady = callCount;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(callCount, countAfterReady);
    },
  );

  test('stops polling immediately when initial fetch returns ready', () async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => _doc(status: DocumentStatus.ready));

    container.listen(
      documentPollingProvider(
        workspaceId: 'wsp_test',
        documentId: 'doc_test',
      ),
      (_, __) {},
    );
    await container.read(
      documentPollingProvider(
        workspaceId: 'wsp_test',
        documentId: 'doc_test',
      ).future,
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    verify(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).called(1);
  });

  test(
    'DocumentNotFoundException mid-poll surfaces as AsyncError + stops polling',
    () async {
      var callCount = 0;
      when(() => repo.get(
            workspaceId: 'wsp_test',
            documentId: 'doc_test',
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return _doc(status: DocumentStatus.extracting);
        throw const DocumentNotFoundException();
      });

      container.listen(
        documentPollingProvider(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        ),
        (_, __) {},
      );
      await container.read(
        documentPollingProvider(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        ).future,
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      final state = container.read(
        documentPollingProvider(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        ),
      );
      expect(state.hasError, true);
      expect(state.error, isA<DocumentNotFoundException>());

      // No further polls after the 404 surfaces.
      final countAfterError = callCount;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(callCount, countAfterError);
    },
  );

  test('cancels the timer on dispose', () async {
    when(() => repo.get(
          workspaceId: 'wsp_test',
          documentId: 'doc_test',
        )).thenAnswer((_) async => _doc(status: DocumentStatus.extracting));

    final sub = container.listen(
      documentPollingProvider(
        workspaceId: 'wsp_test',
        documentId: 'doc_test',
      ),
      (_, __) {},
    );
    await container.read(
      documentPollingProvider(
        workspaceId: 'wsp_test',
        documentId: 'doc_test',
      ).future,
    );

    // The initial fetch must have run exactly once. ``verify`` marks
    // those calls as consumed — what mocktail considers "verified".
    verify(() => repo.get(
          workspaceId: any(named: 'workspaceId'),
          documentId: any(named: 'documentId'),
        )).called(1);

    sub.close();
    // Force-trigger the provider's dispose path. Auto-dispose normally
    // runs on the next microtask after the last subscription closes,
    // but Riverpod gives a tiny grace period for re-listen that races
    // with the 5ms test timer. invalidate() bypasses the grace and runs
    // ref.onDispose → _cancelTimer immediately, isolating this test from
    // the auto-dispose scheduling implementation detail.
    container.invalidate(
      documentPollingProvider(
        workspaceId: 'wsp_test',
        documentId: 'doc_test',
      ),
    );
    // Wait longer than any plausible scheduled poll would take. If
    // dispose failed to cancel the timer, a stray poll fires here and
    // verifyNever below catches the new (unverified) call.
    await Future<void>.delayed(const Duration(milliseconds: 30));

    verifyNever(() => repo.get(
          workspaceId: any(named: 'workspaceId'),
          documentId: any(named: 'documentId'),
        ));
  });
}
