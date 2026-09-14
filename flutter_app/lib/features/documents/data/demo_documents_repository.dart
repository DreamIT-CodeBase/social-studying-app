import 'dart:async';
import 'dart:typed_data';

import 'package:social_study_app/features/documents/data/documents_repository.dart';
import 'package:social_study_app/shared/models/document.dart';

/// In-process demo repository — simulates the Sprint 2.x backend state
/// machine on a Timer so the polling screen is fully exercisable
/// without standing up Cosmos / Service Bus / OpenAI / AI Search.
///
/// Why a real state machine and not just a fake "spinner that ends"
/// ----------------------------------------------------------------
/// The backend pipeline has eight visible stages, each with side
/// effects (page count, topic tags, chunk count). The demo has to
/// produce the same shape of progressive updates so the polling UI
/// renders identically to a real backend run. A simpler "set status
/// to ready after 5 seconds" mock would mask UI bugs that only show
/// up when intermediate fields land asynchronously.
///
/// Singleton-per-instance state
/// ----------------------------
/// One `DemoDocumentsRepository` instance is built per process by the
/// Riverpod provider (keepAlive, single auth flip during a session).
/// All state — the `_byWorkspace` map and all running Timers — lives
/// on the instance so a Timer can keep updating a doc after the
/// polling screen rebuilds.
class DemoDocumentsRepository implements DocumentsRepository {
  DemoDocumentsRepository({
    Duration stageDuration = const Duration(milliseconds: 1500),
  }) : _stageDuration = stageDuration;

  /// Per-stage delay. Shortened in tests via the constructor argument.
  final Duration _stageDuration;

  /// `workspaceId → documentId → Document`. Updated in place by
  /// `_advanceStage`; readers always observe the latest snapshot.
  final Map<String, Map<String, Document>> _byWorkspace = {};

  /// Active timers keyed by `documentId`. Held so we can cancel on
  /// permanent deletion and so we never leak timers across re-uploads of the
  /// same doc id (which can't happen in practice but defends against
  /// bugs in tests).
  final Map<String, Timer> _activeTimers = {};

  @override
  Future<List<Document>> list({required String workspaceId}) async {
    await _simulateNetwork();
    _seedIfEmpty(workspaceId);
    final docs = _byWorkspace[workspaceId]?.values.toList() ?? <Document>[];
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  void _seedIfEmpty(String workspaceId) {
    if (_byWorkspace[workspaceId]?.isNotEmpty ?? false) return;
    final map = _byWorkspace.putIfAbsent(workspaceId, () => {});
    final doc1 = Document(
      id: 'doc_algebra_ready',
      workspaceId: workspaceId,
      filename: 'Algebra_1_200_Equations_and_Answers.pdf',
      docType: DocumentType.pdf,
      status: DocumentStatus.ready,
      pageCount: 15,
      textCharCount: 24500,
      chunkCount: 25,
      createdAt: DateTime.now()
          .subtract(const Duration(hours: 2))
          .toUtc()
          .toIso8601String(),
      topicTags: const [
        TopicTag(
          name: 'Linear Equations',
          description:
              'Solving one-variable and two-variable linear equations.',
          complexityLevel: 2,
          pageRefs: [1, 2, 3],
        ),
        TopicTag(
          name: 'Quadratic Equations',
          description: 'Factoring, quadratic formula, and graphing parabolas.',
          complexityLevel: 3,
          pageRefs: [4, 5, 6],
        ),
        TopicTag(
          name: 'Systems of Equations',
          description: 'Substitution, elimination, and graphical solutions.',
          complexityLevel: 3,
          pageRefs: [7, 8, 9],
        ),
      ],
    );
    final doc2 = Document(
      id: 'doc_algebra_flagged',
      workspaceId: workspaceId,
      filename: 'Algebra_1_Formulas_Review.pdf',
      docType: DocumentType.pdf,
      status: DocumentStatus.flagged,
      moderationFlagged: true,
      pageCount: 5,
      textCharCount: 6200,
      chunkCount: 6,
      processingError:
          'Safety Review Required: Flagged for self-study approval.',
      createdAt: DateTime.now()
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    );
    map[doc1.id] = doc1;
    map[doc2.id] = doc2;
  }

  @override
  Future<Document> get({
    required String workspaceId,
    required String documentId,
  }) async {
    await _simulateNetwork();
    _seedIfEmpty(workspaceId);
    final doc = _byWorkspace[workspaceId]?[documentId];
    if (doc == null) {
      throw const DocumentNotFoundException();
    }
    return doc;
  }

  @override
  Future<Document> upload({
    required String workspaceId,
    required String filename,
    required String contentType,
    DocumentUpload? upload,
    Uint8List? bytes,
  }) async {
    await _simulateNetwork();
    final file = resolveDocumentUpload(upload: upload, bytes: bytes);
    if (file.sizeBytes == 0) {
      throw const EmptyUploadException();
    }
    final docType = _docTypeFor(contentType, filename);
    if (docType == null) {
      throw UnsupportedFileTypeException(contentType);
    }

    final id = 'doc_${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final initial = Document(
      id: id,
      workspaceId: workspaceId,
      filename: filename,
      docType: docType,
      status: DocumentStatus.pending,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    _byWorkspace.putIfAbsent(workspaceId, () => {})[id] = initial;
    _scheduleNext(workspaceId: workspaceId, documentId: id);
    return initial;
  }

  @override
  Future<Document> scrape({
    required String workspaceId,
    required String url,
  }) async {
    await _simulateNetwork();
    if (url.isEmpty) {
      throw Exception('URL cannot be empty');
    }
    final id = 'doc_${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? 'website';
    final filename = 'scraped_$host.txt';

    final initial = Document(
      id: id,
      workspaceId: workspaceId,
      filename: filename,
      docType: DocumentType.text,
      status: DocumentStatus.pending,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    _byWorkspace.putIfAbsent(workspaceId, () => {})[id] = initial;
    _scheduleNext(workspaceId: workspaceId, documentId: id);
    return initial;
  }

  @override
  Future<void> delete({
    required String workspaceId,
    required String documentId,
  }) async {
    await _simulateNetwork();
    _activeTimers.remove(documentId)?.cancel();
    _byWorkspace[workspaceId]?.remove(documentId);
  }

  @override
  Future<Document> approve({
    required String workspaceId,
    required String documentId,
  }) async {
    await _simulateNetwork();
    final doc = await get(workspaceId: workspaceId, documentId: documentId);
    final updated = doc.copyWith(
      status: DocumentStatus.textExtracted,
      moderationFlagged: false,
      processingError: null,
    );
    _byWorkspace[workspaceId]?[documentId] = updated;
    _scheduleNext(workspaceId: workspaceId, documentId: documentId);
    return updated;
  }

  // ── State machine ──────────────────────────────────────────────────────────

  /// Schedule the next stage transition. Cancellation is implicit — we
  /// only ever schedule one timer per document at a time, so reassigning
  /// the slot wins.
  void _scheduleNext({
    required String workspaceId,
    required String documentId,
  }) {
    _activeTimers[documentId]?.cancel();
    _activeTimers[documentId] = Timer(_stageDuration, () {
      _advanceStage(workspaceId: workspaceId, documentId: documentId);
    });
  }

  /// Apply one stage transition + fire the next timer (or terminate).
  void _advanceStage({
    required String workspaceId,
    required String documentId,
  }) {
    final current = _byWorkspace[workspaceId]?[documentId];
    if (current == null) return; // deleted between scheduling and firing
    final next = _nextSnapshot(current);
    _byWorkspace[workspaceId]![documentId] = next;
    if (!next.status.isTerminal) {
      _scheduleNext(workspaceId: workspaceId, documentId: documentId);
    } else {
      _activeTimers.remove(documentId);
    }
  }

  /// Compute the next snapshot from the current one. Each transition
  /// mutates ONLY the fields a real worker would touch at that point in
  /// the pipeline — so the UI sees the same progressive disclosure it
  /// would in production.
  Document _nextSnapshot(Document current) {
    return switch (current.status) {
      DocumentStatus.pending =>
        current.copyWith(status: DocumentStatus.extracting),
      DocumentStatus.extracting => current.copyWith(
          status: DocumentStatus.textExtracted,
          pageCount: 12,
          textCharCount: 18420,
          languages: const ['en'],
        ),
      DocumentStatus.textExtracted =>
        current.copyWith(status: DocumentStatus.extractingTopics),
      DocumentStatus.extractingTopics => current.copyWith(
          status: DocumentStatus.topicsExtracted,
          topicTags: _extractTopicTagsFor(current.filename),
        ),
      DocumentStatus.topicsExtracted =>
        current.copyWith(status: DocumentStatus.chunking),
      DocumentStatus.chunking =>
        current.copyWith(status: DocumentStatus.chunked, chunkCount: 9),
      DocumentStatus.chunked =>
        current.copyWith(status: DocumentStatus.vectorizing),
      DocumentStatus.vectorizing =>
        current.copyWith(status: DocumentStatus.ready),
      // Terminal — caller should not advance these. Return unchanged so
      // we don't accidentally unroll a terminal state.
      DocumentStatus.ready ||
      DocumentStatus.flagged ||
      DocumentStatus.failed =>
        current,
    };
  }

  List<TopicTag> _extractTopicTagsFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('math') ||
        lower.contains('algebra') ||
        lower.contains('equation') ||
        lower.contains('calc') ||
        lower.contains('geom')) {
      return const [
        TopicTag(
          name: 'Linear Equations',
          description:
              'Solving one-variable and two-variable linear equations.',
          complexityLevel: 2,
          pageRefs: [1, 2, 3],
        ),
        TopicTag(
          name: 'Quadratic Equations',
          description: 'Factoring, quadratic formula, and graphing parabolas.',
          complexityLevel: 3,
          pageRefs: [4, 5, 6],
        ),
        TopicTag(
          name: 'Systems of Equations',
          description: 'Substitution, elimination, and graphical solutions.',
          complexityLevel: 3,
          pageRefs: [7, 8, 9],
        ),
      ];
    }
    if (lower.contains('hist') ||
        lower.contains('war') ||
        lower.contains('civ')) {
      return const [
        TopicTag(
          name: 'Ancient Civilizations',
          description: 'Early river valley societies and governance.',
          complexityLevel: 2,
          pageRefs: [1, 2],
        ),
        TopicTag(
          name: 'World War II',
          description: 'Global conflict, causes, and consequences.',
          complexityLevel: 3,
          pageRefs: [3, 4, 5],
        ),
      ];
    }
    return const [
      TopicTag(
        name: 'Linear Equations',
        description: 'Core linear relationships and mathematical principles.',
        complexityLevel: 2,
        pageRefs: [1, 2],
      ),
      TopicTag(
        name: 'Practical Applications',
        description: 'Real-world problem solving and case studies.',
        complexityLevel: 3,
        pageRefs: [3, 4],
      ),
    ];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Tiny sleep so consumers never observe synchronous returns — keeps the
  /// loading-state code paths exercised even in demo mode.
  Future<void> _simulateNetwork() => Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

  /// Resolve a `DocumentType` from MIME + filename, mirroring
  /// `_ALLOWED_MIME_TO_TYPE` on the backend.
  DocumentType? _docTypeFor(String contentType, String filename) {
    switch (contentType) {
      case 'application/pdf':
        return DocumentType.pdf;
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return DocumentType.docx;
      case 'image/jpeg':
      case 'image/png':
      case 'image/webp':
        return DocumentType.image;
      case 'text/plain':
        return DocumentType.text;
    }
    // Fall back to extension sniffing — file_picker on some platforms
    // returns an empty content type.
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'pdf' => DocumentType.pdf,
      'docx' => DocumentType.docx,
      'jpg' || 'jpeg' || 'png' || 'webp' => DocumentType.image,
      'txt' => DocumentType.text,
      _ => null,
    };
  }
}

/// Thrown by `DocumentsRepository.get` when the doc id is not known to
/// the backend (or the demo store). Surfaces back through the polling
/// notifier as an `AsyncError`.
class DocumentNotFoundException implements Exception {
  const DocumentNotFoundException();
  @override
  String toString() => 'Document not found';
}

class EmptyUploadException implements Exception {
  const EmptyUploadException();
  @override
  String toString() => 'Uploaded file is empty';
}

class UploadTooLargeException implements Exception {
  const UploadTooLargeException([
    this.message =
        'This document is larger than the supported processing limit.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class UnsupportedFileTypeException implements Exception {
  const UnsupportedFileTypeException(this.contentType);
  final String contentType;
  @override
  String toString() => 'Unsupported file type: $contentType';
}
