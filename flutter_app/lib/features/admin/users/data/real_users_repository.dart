import 'package:dio/dio.dart';
import 'package:social_study_app/features/admin/users/data/demo_users_repository.dart'
    show UserEmailConflictException, UserNotFoundException;
import 'package:social_study_app/features/admin/users/data/users_repository.dart';
import 'package:social_study_app/shared/models/user.dart';

/// Dio-backed implementation hitting the implemented `/users` routes.
///
/// Role values are sent as their snake_case wire strings (`student`,
/// `workspace_admin`, …) — the same `@JsonValue` mapping [UserRole]
/// uses for parsing.
class RealUsersRepository implements UsersRepository {
  RealUsersRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  /// snake_case wire value for a [UserRole] — mirrors the backend enum.
  static const _roleWire = {
    UserRole.tenantAdmin: 'tenant_admin',
    UserRole.workspaceAdmin: 'workspace_admin',
    UserRole.student: 'student',
  };

  @override
  Future<List<User>> listWorkspaceUsers(String workspaceId) async {
    final response = await dio.get<List<dynamic>>(
      '$_apiPrefix/users/',
      queryParameters: {'workspace_id': workspaceId},
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(User.fromJson)
        .toList();
  }

  @override
  Future<User> createUser({
    required String workspaceId,
    required String email,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/members',
        data: {
          'email': email,
          'display_name': displayName,
          'role': _roleWire[role],
        },
      );
      return User.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw UserEmailConflictException(
          _detail(e.response?.data) ??
              'A user with that email already exists',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deactivateUser(String userId) async {
    try {
      await dio.delete<void>('$_apiPrefix/users/$userId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw UserNotFoundException(
          _detail(e.response?.data) ?? 'User not found',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> removeMember({
    required String workspaceId,
    required String userId,
  }) async {
    try {
      await dio.delete<void>(
        '$_apiPrefix/workspaces/$workspaceId/members/$userId',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw UserNotFoundException(
          _detail(e.response?.data) ?? 'Member not found',
        );
      }
      rethrow;
    }
  }

  @override
  Future<User> changeRole({
    required String workspaceId,
    required String userId,
    required UserRole role,
  }) async {
    try {
      final response = await dio.patch<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/members/$userId',
        data: {'role': _roleWire[role]},
      );
      return User.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw UserNotFoundException(
          _detail(e.response?.data) ?? 'User not found',
        );
      }
      rethrow;
    }
  }

  String? _detail(Object? body) {
    if (body is Map<String, dynamic> && body['detail'] is String) {
      return body['detail'] as String;
    }
    return null;
  }
}
