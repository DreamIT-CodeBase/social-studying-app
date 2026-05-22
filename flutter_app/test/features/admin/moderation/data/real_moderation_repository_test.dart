import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/admin/moderation/data/demo_moderation_repository.dart';
import 'package:social_study_app/features/admin/moderation/data/real_moderation_repository.dart';
import 'package:social_study_app/shared/models/moderation.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;
  Uint8List? lastRequestBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      lastRequestBody = Uint8List.fromList(bytes);
    }
    return handler(options);
  }
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
      body,
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );

Dio _dio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> _itemJson({
  String id = 'mod_1',
  String verdict = 'pending',
}) =>
    {
      'id': id,
      'content_kind': 'question',
      'topic': 'Genetics',
      'excerpt': 'A flagged question excerpt',
      'reason': 'Violence',
      'severity': 2,
      'flagged_at': '2026-05-22T08:00:00Z',
      'verdict': verdict,
    };

void main() {
  group('RealModerationRepository.listFlagged', () {
    test('GETs the moderation/flagged path and parses items', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode([_itemJson()])),
      );
      final repo = RealModerationRepository(dio: _dio(adapter));
      final flagged = await repo.listFlagged('wsp_a');

      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_a/moderation/flagged',
      );
      expect(flagged.single.contentKind, FlaggedContentKind.question);
      expect(flagged.single.severity, 2);
    });
  });

  group('RealModerationRepository.resolve', () {
    test('PUTs to the resolve sub-resource with the approved flag',
        () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode(_itemJson(verdict: 'approved'))),
      );
      final repo = RealModerationRepository(dio: _dio(adapter));
      final resolved = await repo.resolve(
        workspaceId: 'wsp_a',
        itemId: 'mod_1',
        approved: true,
      );

      expect(adapter.lastRequest!.method, 'PUT');
      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_a/moderation/mod_1/resolve',
      );
      final sent = jsonDecode(utf8.decode(adapter.lastRequestBody!))
          as Map<String, dynamic>;
      expect(sent['approved'], true);
      expect(resolved.verdict, ModerationVerdict.approved);
    });

    test('404 → FlaggedItemNotFoundException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'gone'}), status: 404),
      );
      final repo = RealModerationRepository(dio: _dio(adapter));
      expect(
        () => repo.resolve(
          workspaceId: 'wsp_a',
          itemId: 'mod_ghost',
          approved: true,
        ),
        throwsA(isA<FlaggedItemNotFoundException>()),
      );
    });
  });

  group('RealModerationRepository.listLog', () {
    test('GETs the moderation/log path', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode([_itemJson(verdict: 'rejected')])),
      );
      final repo = RealModerationRepository(dio: _dio(adapter));
      final log = await repo.listLog('wsp_a');

      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_a/moderation/log',
      );
      expect(log.single.verdict, ModerationVerdict.rejected);
    });
  });
}
