import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart';
import 'package:social_study_app/features/documents/data/real_documents_repository.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/document.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'documents_repository.g.dart';

/// Source-of-truth for document CRUD + polling, mirroring the auth
/// repository's interface-with-two-impls pattern.
///
/// The polling screen and list screen never reach for a Dio instance
/// directly — they go through this repository. In tests, a mock
/// implementation overrides the provider via `ProviderScope.overrides`.
abstract class DocumentsRepository {
  Future<List<Document>> list({required String workspaceId});

  Future<Document> get({
    required String workspaceId,
    required String documentId,
  });

  Future<Document> upload({
    required String workspaceId,
    required String filename,
    required String contentType,
    DocumentUpload? upload,
    Uint8List? bytes,
  });

  Future<Document> scrape({
    required String workspaceId,
    required String url,
  });

  Future<void> delete({
    required String workspaceId,
    required String documentId,
  });
}

/// A file source that can read a bounded range without loading the whole
/// document into memory.  Native pickers supply an [XFile]-backed reader;
/// the byte-array constructor remains useful for web and unit tests.
class DocumentUpload {
  DocumentUpload({
    required this.sizeBytes,
    required this.readRange,
  });

  factory DocumentUpload.fromBytes(Uint8List bytes) => DocumentUpload(
        sizeBytes: bytes.length,
        readRange: (start, end) async =>
            Uint8List.sublistView(bytes, start, end),
      );

  final int sizeBytes;
  final Future<Uint8List> Function(int start, int end) readRange;
}

/// Resolves the new streaming source or the legacy in-memory test source.
/// Exactly one form is required so callers cannot accidentally upload a
/// different byte sequence from the size they declared.
DocumentUpload resolveDocumentUpload({
  DocumentUpload? upload,
  Uint8List? bytes,
}) {
  if (upload != null && bytes == null) return upload;
  if (upload == null && bytes != null) return DocumentUpload.fromBytes(bytes);
  throw ArgumentError('Provide exactly one of upload or bytes.');
}

/// Provider selects between the demo (in-process state machine) and the
/// real (Dio → backend) implementation based on the authenticated user.
///
/// The demo user signs in via `_MockAuthRepository` (see
/// [authRepositoryProvider]) and gets the demo documents flow so the app
/// is fully exercisable without a live backend. Any other user is
/// assumed to be authenticated against the real API.
@Riverpod(keepAlive: true)
DocumentsRepository documentsRepository(DocumentsRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoDocumentsRepository();
  }
  return RealDocumentsRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
