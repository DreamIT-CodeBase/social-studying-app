import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/taxonomy/data/real_taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';

/// Tiny in-process Dio adapter — same pattern as
/// ``real_documents_repository_test.dart``. Avoids reaching for a
/// network mocking package.
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
  ) async =>
      handler(options);
}

ResponseBody _jsonRaw(String body, {int status = 200}) =>
    ResponseBody.fromString(
      body,
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );

Dio _dioWith(ResponseBody Function(RequestOptions options) handler) {
  return Dio()
    ..options.baseUrl = 'https://test.invalid'
    ..httpClientAdapter = _FakeAdapter(handler);
}

void main() {
  test('get parses topics + version', () async {
    final repo = RealTaxonomyRepository(
      dio: _dioWith(
        (_) => _jsonRaw('''
{
  "topics": [
    {
      "id": "tpc_a",
      "name": "Cells",
      "aliases": [],
      "description": "Basic units of life.",
      "complexity_level": 2.0,
      "parent_id": null,
      "source_document_ids": ["doc_1"]
    },
    {
      "id": "tpc_b",
      "name": "Photosynthesis",
      "aliases": ["Plant Energy"],
      "complexity_level": 3.0,
      "parent_id": "tpc_a",
      "source_document_ids": ["doc_1", "doc_2"]
    }
  ],
  "taxonomy_version": 7,
  "last_merged_at": "2026-05-15T00:00:00+00:00"
}
'''),
      ),
    );

    final taxonomy = await repo.get(workspaceId: 'wsp_test');
    expect(taxonomy.taxonomyVersion, 7);
    expect(taxonomy.topics, hasLength(2));
    expect(taxonomy.topics[1].parentId, 'tpc_a');
    expect(taxonomy.topics[1].aliases, ['Plant Energy']);
  });

  test('get on 404 throws TaxonomyWorkspaceNotFoundException', () async {
    final repo = RealTaxonomyRepository(
      dio: _dioWith(
        (_) =>
            _jsonRaw('{"detail":"Workspace wsp_test not found"}', status: 404),
      ),
    );

    expect(
      () => repo.get(workspaceId: 'wsp_test'),
      throwsA(isA<TaxonomyWorkspaceNotFoundException>()),
    );
  });

  test('regenerate hits POST /regenerate and returns void', () async {
    String? capturedPath;
    String? capturedMethod;
    final repo = RealTaxonomyRepository(
      dio: _dioWith((options) {
        capturedPath = options.path;
        capturedMethod = options.method;
        return _jsonRaw(
          '{"status":"accepted","workspace_id":"wsp_test","message":"ok"}',
          status: 202,
        );
      }),
    );

    await repo.regenerate(workspaceId: 'wsp_test');
    expect(capturedMethod, 'POST');
    expect(capturedPath, endsWith('/workspaces/wsp_test/taxonomy/regenerate'));
  });

  test('regenerate propagates non-404 DioException unchanged', () async {
    final repo = RealTaxonomyRepository(
      dio: _dioWith(
        (_) => _jsonRaw('{"detail":"boom"}', status: 500),
      ),
    );

    expect(
      () => repo.regenerate(workspaceId: 'wsp_test'),
      throwsA(isA<DioException>()),
    );
  });
}
