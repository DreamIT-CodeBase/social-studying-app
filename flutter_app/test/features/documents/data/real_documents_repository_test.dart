import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart';
import 'package:social_study_app/features/documents/data/real_documents_repository.dart';
import 'package:social_study_app/shared/models/document.dart';

/// Tiny in-process Dio adapter that returns canned responses based on
/// (method, path) pairs. Avoids reaching for a network mocking package.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

ResponseBody _json(Map<String, dynamic> body, {int status = 200}) {
  if (body.containsKey('document_id')) {
    return _jsonRaw(jsonEncode(body), status: status);
  }
  final json = '{"id":"${body['id'] ?? ''}",'
      '"workspace_id":"${body['workspace_id'] ?? ''}",'
      '"filename":"${body['filename'] ?? ''}",'
      '"doc_type":"${body['doc_type'] ?? 'pdf'}",'
      '"status":"${body['status'] ?? 'pending'}",'
      '"chunk_count":${body['chunk_count'] ?? 0},'
      '"topic_tags":[],'
      '"moderation_flagged":false,'
      '"created_at":"2026-05-15T00:00:00+00:00"}';
  return ResponseBody.fromString(
    json,
    status,
    headers: {
      'content-type': ['application/json'],
    },
  );
}

ResponseBody _jsonRaw(String body, {int status = 200}) =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );

Dio _dioWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('list', () {
    test('GETs the workspace docs URL and parses the array', () async {
      final adapter = _FakeAdapter(
        (options) {
          expect(options.method, 'GET');
          expect(
            options.uri.path,
            '/api/v1/workspaces/wsp_test/documents',
          );
          return _jsonRaw(
            '[{"id":"doc_a","workspace_id":"wsp_test","filename":"a.pdf",'
            '"doc_type":"pdf","status":"ready","chunk_count":3,'
            '"topic_tags":[],"moderation_flagged":false,'
            '"created_at":"2026-05-15T00:00:00+00:00"}]',
          );
        },
      );
      final repo = RealDocumentsRepository(dio: _dioWith(adapter));
      final docs = await repo.list(workspaceId: 'wsp_test');
      expect(docs.length, 1);
      expect(docs.first.id, 'doc_a');
      expect(docs.first.status, DocumentStatus.ready);
    });
  });

  group('get', () {
    test('GETs the single doc URL and parses it', () async {
      final adapter = _FakeAdapter(
        (options) {
          expect(
            options.uri.path,
            '/api/v1/workspaces/wsp_test/documents/doc_a',
          );
          return _json({
            'id': 'doc_a',
            'workspace_id': 'wsp_test',
            'filename': 'a.pdf',
            'status': 'vectorizing',
            'chunk_count': 5,
          });
        },
      );
      final repo = RealDocumentsRepository(dio: _dioWith(adapter));
      final doc = await repo.get(
        workspaceId: 'wsp_test',
        documentId: 'doc_a',
      );
      expect(doc.id, 'doc_a');
      expect(doc.status, DocumentStatus.vectorizing);
    });

    test('404 maps to DocumentNotFoundException', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonRaw('{"detail":"missing"}', status: 404),
      );
      final repo = RealDocumentsRepository(dio: _dioWith(adapter));
      expect(
        () => repo.get(workspaceId: 'wsp_test', documentId: 'doc_x'),
        throwsA(isA<DocumentNotFoundException>()),
      );
    });
  });

  group('upload', () {
    test('POSTs direct upload and parses returned doc', () async {
      int step = 0;
      final adapter = _FakeAdapter(
        (options) {
          step++;
          if (step == 1) {
            expect(options.method, 'POST');
            expect(options.path, contains('/documents/uploads'));
            return _json({
              'document_id': 'doc_new',
              'upload_token': 'token123',
              'upload_url': 'https://storage.azure.com/blob?sig=xyz',
              'block_size_bytes': 4194304,
            }, status: 201);
          } else if (step == 2) {
            // Stage blocks (PUT to upload_url)
            return ResponseBody.fromString('', 201);
          } else if (step == 3) {
            // Commit block list (PUT to upload_url with comp=blocklist)
            return ResponseBody.fromString('', 201);
          } else {
            // Complete upload
            expect(options.path, contains('/complete'));
            return _json({
              'id': 'doc_new',
              'workspace_id': 'wsp_test',
              'filename': 'study.pdf',
              'status': 'pending',
            }, status: 201);
          }
        },
      );
      final repo = RealDocumentsRepository(
        dio: _dioWith(adapter),
        blobDio: _dioWith(adapter),
      );
      final doc = await repo.upload(
        workspaceId: 'wsp_test',
        filename: 'study.pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        contentType: 'application/pdf',
      );
      expect(doc.id, 'doc_new');
      expect(doc.status, DocumentStatus.pending);
    });

    test('rejects empty payload before hitting the network', () async {
      final adapter = _FakeAdapter(
        (_) => throw StateError('should not be called'),
      );
      final repo = RealDocumentsRepository(dio: _dioWith(adapter));
      expect(
        () => repo.upload(
          workspaceId: 'wsp_test',
          filename: 'empty.pdf',
          bytes: Uint8List(0),
          contentType: 'application/pdf',
        ),
        throwsA(isA<EmptyUploadException>()),
      );
    });

    test('422 with "Unsupported file type" detail maps to typed exception',
        () async {
      final adapter = _FakeAdapter(
        (_) => _jsonRaw(
          '{"detail":"Unsupported file type \'evil/exe\'."}',
          status: 422,
        ),
      );
      final repo = RealDocumentsRepository(dio: _dioWith(adapter));
      expect(
        () => repo.upload(
          workspaceId: 'wsp_test',
          filename: 'evil.exe',
          bytes: Uint8List.fromList([0x4D]),
          contentType: 'application/x-msdownload',
        ),
        throwsA(isA<UnsupportedFileTypeException>()),
      );
    });

    test('422 with "empty" detail maps to EmptyUploadException', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonRaw('{"detail":"Uploaded file is empty."}', status: 422),
      );
      final repo = RealDocumentsRepository(dio: _dioWith(adapter));
      expect(
        () => repo.upload(
          workspaceId: 'wsp_test',
          filename: 'a.pdf',
          // Non-empty so the local guard doesn't catch it; we want to
          // verify the server-side message mapping.
          bytes: Uint8List.fromList([0x25]),
          contentType: 'application/pdf',
        ),
        throwsA(isA<EmptyUploadException>()),
      );
    });
  });

  group('delete', () {
    test('DELETEs the single doc URL and returns void', () async {
      final adapter = _FakeAdapter((options) {
        expect(options.method, 'DELETE');
        expect(
          options.uri.path,
          '/api/v1/workspaces/wsp_test/documents/doc_a',
        );
        return ResponseBody.fromString('', 204);
      });
      final repo = RealDocumentsRepository(dio: _dioWith(adapter));
      await repo.delete(workspaceId: 'wsp_test', documentId: 'doc_a');
    });
  });
}
