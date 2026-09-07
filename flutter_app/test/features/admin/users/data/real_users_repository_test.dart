import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/admin/users/data/demo_users_repository.dart';
import 'package:social_study_app/features/admin/users/data/real_users_repository.dart';
import 'package:social_study_app/shared/models/user.dart';

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

Map<String, dynamic> _userJson({
  String id = 'usr_1',
  String role = 'student',
}) =>
    {
      'id': id,
      'tenant_id': 'ten_1',
      'email': 'a@b.com',
      'display_name': 'A B',
      'role': role,
      'is_active': true,
      'created_at': '2026-04-01T00:00:00Z',
    };

void main() {
  group('RealUsersRepository.listWorkspaceUsers', () {
    test('GETs /users/ with the workspace_id query param', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode([_userJson()])),
      );
      final repo = RealUsersRepository(dio: _dio(adapter));
      final users = await repo.listWorkspaceUsers('wsp_a');

      expect(adapter.lastRequest!.path, '/api/v1/users/');
      expect(adapter.lastRequest!.queryParameters['workspace_id'], 'wsp_a');
      expect(users.single.role, UserRole.student);
      // UserResponse omits memberships → tolerant model defaults to [].
      expect(users.single.workspaceMemberships, isEmpty);
    });
  });

  group('RealUsersRepository.createUser', () {
    test('POSTs email/display_name/role with snake_case role value', () async {
      final adapter = _FakeAdapter(
        (opts) =>
            _json(jsonEncode(_userJson(role: 'workspace_admin')), status: 201),
      );
      final repo = RealUsersRepository(dio: _dio(adapter));
      await repo.createUser(
        workspaceId: 'wsp_1',
        email: 'a@b.com',
        displayName: 'A B',
        role: UserRole.workspaceAdmin,
      );

      final sent = jsonDecode(utf8.decode(adapter.lastRequestBody!))
          as Map<String, dynamic>;
      expect(sent['email'], 'a@b.com');
      expect(sent['display_name'], 'A B');
      expect(sent['role'], 'workspace_admin');
    });

    test('409 → UserEmailConflictException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'taken'}), status: 409),
      );
      final repo = RealUsersRepository(dio: _dio(adapter));
      expect(
        () => repo.createUser(
          workspaceId: 'wsp_1',
          email: 'a@b.com',
          displayName: 'A B',
          role: UserRole.student,
        ),
        throwsA(isA<UserEmailConflictException>()),
      );
    });
  });

  group('RealUsersRepository.deactivateUser', () {
    test('DELETEs the user path', () async {
      final adapter = _FakeAdapter((opts) => _json('', status: 204));
      final repo = RealUsersRepository(dio: _dio(adapter));
      await repo.deactivateUser('usr_1');
      expect(adapter.lastRequest!.method, 'DELETE');
      expect(adapter.lastRequest!.path, '/api/v1/users/usr_1');
    });

    test('404 → UserNotFoundException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'gone'}), status: 404),
      );
      final repo = RealUsersRepository(dio: _dio(adapter));
      expect(
        () => repo.deactivateUser('usr_ghost'),
        throwsA(isA<UserNotFoundException>()),
      );
    });
  });

  group('RealUsersRepository.changeRole', () {
    test('PATCHes the user with the snake_case role', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode(_userJson(role: 'workspace_admin'))),
      );
      final repo = RealUsersRepository(dio: _dio(adapter));
      await repo.changeRole(
        workspaceId: 'wsp_1',
        userId: 'usr_1',
        role: UserRole.workspaceAdmin,
      );

      expect(adapter.lastRequest!.method, 'PATCH');
      expect(
          adapter.lastRequest!.path, '/api/v1/workspaces/wsp_1/members/usr_1');
      final sent = jsonDecode(utf8.decode(adapter.lastRequestBody!))
          as Map<String, dynamic>;
      expect(sent['role'], 'workspace_admin');
    });

    test('404 → UserNotFoundException', () async {
      final adapter = _FakeAdapter(
        (opts) => _json(jsonEncode({'detail': 'gone'}), status: 404),
      );
      final repo = RealUsersRepository(dio: _dio(adapter));
      expect(
        () => repo.changeRole(
            workspaceId: 'wsp_1', userId: 'usr_ghost', role: UserRole.student),
        throwsA(isA<UserNotFoundException>()),
      );
    });
  });
}
