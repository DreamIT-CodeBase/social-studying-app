import 'package:dio/dio.dart';
import 'package:social_study_app/features/admin/moderation/data/demo_moderation_repository.dart'
    show FlaggedItemNotFoundException;
import 'package:social_study_app/features/admin/moderation/data/moderation_repository.dart';
import 'package:social_study_app/shared/models/moderation.dart';

/// Dio-backed implementation of [ModerationRepository].
///
/// **Contract note.** Hits the plan §5.8 moderation routes, which are a
/// Sprint 6 surface not yet implemented. The translation here is final;
/// the calls start succeeding once the backend lands. Until then the
/// demo user routes to [DemoModerationRepository].
class RealModerationRepository implements ModerationRepository {
  RealModerationRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  @override
  Future<List<FlaggedItem>> listFlagged(String workspaceId) async {
    final response = await dio.get<List<dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/moderation/flagged',
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(FlaggedItem.fromJson)
        .toList();
  }

  @override
  Future<FlaggedItem> resolve({
    required String workspaceId,
    required String itemId,
    required bool approved,
  }) async {
    try {
      final response = await dio.put<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/moderation/$itemId/resolve',
        data: {'approved': approved},
      );
      return FlaggedItem.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw FlaggedItemNotFoundException(
          _detail(e.response?.data) ?? 'Flagged item not found',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<FlaggedItem>> listLog(String workspaceId) async {
    final response = await dio.get<List<dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/moderation/log',
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(FlaggedItem.fromJson)
        .toList();
  }

  String? _detail(Object? body) {
    if (body is Map<String, dynamic> && body['detail'] is String) {
      return body['detail'] as String;
    }
    return null;
  }
}
