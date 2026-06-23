import 'package:dio/dio.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart'
    show WorkspaceNameConflictException, WorkspaceNotFoundException;
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/shared/models/invite_code.dart';
import 'package:social_study_app/shared/models/workspace.dart';

/// Dio-backed implementation hitting the implemented workspace routes.
///
/// Error translation maps HTTP statuses to the typed exceptions defined
/// alongside the demo implementation, so the UI can branch on a
/// duplicate-name conflict vs. a missing workspace.
class RealWorkspacesRepository implements WorkspacesRepository {
  RealWorkspacesRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  @override
  Future<List<Workspace>> list() async {
    final response = await dio.get<List<dynamic>>('$_apiPrefix/workspaces/');
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Workspace.fromJson)
        .toList();
  }

  @override
  Future<Workspace> create({
    required String name,
    String? description,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/',
        data: {
          'name': name,
          if (description != null) 'description': description,
        },
      );
      return Workspace.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw WorkspaceNameConflictException(
          _detail(e.response?.data) ??
              'A workspace with that name already exists',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Workspace> update({
    required String workspaceId,
    String? name,
    String? description,
    WorkspaceSettings? settings,
  }) async {
    try {
      final response = await dio.patch<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId',
        // Send only the fields being changed — the backend's
        // WorkspaceUpdate treats omitted keys as "leave unchanged".
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (settings != null) 'settings': settings.toJson(),
        },
      );
      return Workspace.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw WorkspaceNotFoundException(
          _detail(e.response?.data) ?? 'Workspace not found',
        );
      }
      if (e.response?.statusCode == 409) {
        throw WorkspaceNameConflictException(
          _detail(e.response?.data) ??
              'A workspace with that name already exists',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String workspaceId) async {
    try {
      await dio.delete<void>('$_apiPrefix/workspaces/$workspaceId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw WorkspaceNotFoundException(
          _detail(e.response?.data) ?? 'Workspace not found',
        );
      }
      rethrow;
    }
  }

  @override
  Future<GeneratedInviteCode> generateInviteCode(String workspaceId) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/invite-codes',
      );
      return GeneratedInviteCode.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw WorkspaceNotFoundException(
          _detail(e.response?.data) ?? 'Workspace not found',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Workspace> createCollaborative({required String name, String? description}) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/collaborative',
        data: {
          'name': name,
          if (description != null) 'description': description,
        },
      );
      return Workspace.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw WorkspaceNameConflictException(
          _detail(e.response?.data) ?? 'A workspace with that name already exists',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Workspace> joinCollaborative({String? joinCode, String? inviteToken}) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/join/join',
        data: {
          if (joinCode != null) 'join_code': joinCode,
          if (inviteToken != null) 'invite_token': inviteToken,
        },
      );
      return Workspace.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw WorkspaceNotFoundException(
          _detail(e.response?.data) ?? 'Workspace or invitation not found',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> leaveCollaborative(String workspaceId) async {
    try {
      await dio.post<void>('$_apiPrefix/workspaces/$workspaceId/leave');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw WorkspaceNotFoundException(
          _detail(e.response?.data) ?? 'Workspace not found',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listMembers(String workspaceId) async {
    final response = await dio.get<List<dynamic>>('$_apiPrefix/workspaces/$workspaceId/members');
    return (response.data ?? const []).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> listActivity(String workspaceId) async {
    final response = await dio.get<List<dynamic>>('$_apiPrefix/workspaces/$workspaceId/activity');
    return (response.data ?? const []).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages(String workspaceId) async {
    final response = await dio.get<List<dynamic>>('$_apiPrefix/workspaces/$workspaceId/messages');
    return (response.data ?? const []).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> postMessage(String workspaceId, {required String content, List<String>? attachments}) async {
    await dio.post<void>(
      '$_apiPrefix/workspaces/$workspaceId/messages',
      data: {
        'content': content,
        'attachments': attachments ?? const [],
      },
    );
  }

  @override
  Future<void> changeMemberRole(String workspaceId, {required String userId, required String role}) async {
    await dio.post<void>(
      '$_apiPrefix/workspaces/$workspaceId/role',
      data: {
        'user_id': userId,
        'role': role,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> inviteToCollaborative(String workspaceId, {String? email, String? username, required String role}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/invite',
      data: {
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        'role': role,
      },
    );
    return response.data!;
  }

  String? _detail(Object? body) {
    if (body is Map<String, dynamic> && body['detail'] is String) {
      return body['detail'] as String;
    }
    return null;
  }
}
