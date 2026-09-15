import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/data/real_workspaces_repository.dart';

/// In-process Dio adapter — same pattern as the other repository tests.
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

Map<String, dynamic> _workspaceJson({
  String id = 'wsp_1',
  String name = 'Biology 101',
}) =>
    {
      'id': id,
      'tenant_id': 'ten_1',
      'name': name,
      'description': 'A course',
      'admin_count': 1,
      'student_count': 4,
      'document_count': 2,
      'settings': {
        'questions_per_day': 5,
        'question_types': ['mcq', 'short_answer'],
        'auto_approve_content': true,
        'leaderboard_visible': true,
        'adaptive_difficulty': true,
      },
      'is_active': true,
      'created_at': '2026-04-01T00:00:00Z',
    };

void main() {
  group('RealWorkspacesRepository.list', () {
    test('GETs /api/v1/workspaces/ and parses snake_case payload', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode([_workspaceJson()])),
      );
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      final list = await repo.list();

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/api/v1/workspaces/');
      expect(list, hasLength(1));
      expect(list.single.name, 'Biology 101');
      expect(list.single.tenantId, 'ten_1');
      expect(list.single.studentCount, 4);
      expect(list.single.settings.questionsPerDay, 5);
    });
  });

  group('RealWorkspacesRepository.create', () {
    test('POSTs name + description and parses the response', () async {
      final adapter = _FakeAdapter(
        (opts) =>
            _json(jsonEncode(_workspaceJson(name: 'Chemistry')), status: 201),
      );
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      final created =
          await repo.create(name: 'Chemistry', description: 'A course');

      expect(adapter.lastRequest!.path, '/api/v1/workspaces/');
      final sent = jsonDecode(utf8.decode(adapter.lastRequestBody!))
          as Map<String, dynamic>;
      expect(sent['name'], 'Chemistry');
      expect(sent['description'], 'A course');
      expect(created.name, 'Chemistry');
    });

    test('409 → WorkspaceNameConflictException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'already exists'}), status: 409),
      );
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      expect(
        () => repo.create(name: 'Demo Classroom'),
        throwsA(isA<WorkspaceNameConflictException>()),
      );
    });
  });

  group('RealWorkspacesRepository.update', () {
    test('PATCHes only the provided fields', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode(_workspaceJson(name: 'Renamed'))),
      );
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      await repo.update(workspaceId: 'wsp_1', name: 'Renamed');

      expect(adapter.lastRequest!.method, 'PATCH');
      expect(adapter.lastRequest!.path, '/api/v1/workspaces/wsp_1');
      final sent = jsonDecode(utf8.decode(adapter.lastRequestBody!))
          as Map<String, dynamic>;
      expect(sent.keys, ['name']);
    });

    test('404 → WorkspaceNotFoundException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'gone'}), status: 404),
      );
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      expect(
        () => repo.update(workspaceId: 'wsp_ghost', name: 'X'),
        throwsA(isA<WorkspaceNotFoundException>()),
      );
    });
  });

  group('RealWorkspacesRepository.delete', () {
    test('DELETEs the workspace path', () async {
      final adapter = _FakeAdapter((opts) => _json('', status: 204));
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      await repo.delete('wsp_1');
      expect(adapter.lastRequest!.method, 'DELETE');
      expect(adapter.lastRequest!.path, '/api/v1/workspaces/wsp_1');
    });

    test('404 → WorkspaceNotFoundException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'gone'}), status: 404),
      );
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      expect(
        () => repo.delete('wsp_ghost'),
        throwsA(isA<WorkspaceNotFoundException>()),
      );
    });
  });

  group('RealWorkspacesRepository.generateInviteCode', () {
    test('POSTs to the invite-codes sub-resource and parses the code',
        () async {
      final adapter = _FakeAdapter(
        (opts) => _json(
          jsonEncode({
            'code': 'ABCD1234',
            'expires_at': '2026-06-01T00:00:00Z',
            'max_uses': 30,
          }),
          status: 201,
        ),
      );
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      final invite = await repo.generateInviteCode('wsp_1');

      expect(
        adapter.lastRequest!.path,
        '/api/v1/workspaces/wsp_1/invite-codes',
      );
      expect(invite.code, 'ABCD1234');
      expect(invite.maxUses, 30);
    });

    test('404 → WorkspaceNotFoundException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'gone'}), status: 404),
      );
      final repo = RealWorkspacesRepository(dio: _dio(adapter));
      expect(
        () => repo.generateInviteCode('wsp_ghost'),
        throwsA(isA<WorkspaceNotFoundException>()),
      );
    });
  });
}
