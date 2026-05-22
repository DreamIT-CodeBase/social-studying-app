import 'package:dio/dio.dart';
import 'package:social_study_app/features/progress/data/progress_repository.dart';
import 'package:social_study_app/shared/models/progress.dart';

/// Dio-backed implementation of [ProgressRepository].
///
/// **Contract note.** Hits `GET /workspaces/{ws}/users/{uid}/progress`,
/// a Sprint 5.9 endpoint not yet implemented. The translation below is
/// final; the call will start succeeding once 5.9 lands. Until then the
/// demo user (which everyone is, pre-launch) routes to the demo repo.
///
/// A 404 — student has no progress document yet — is translated to
/// [StudentProgress.empty] rather than thrown: a brand-new student
/// having no data is an expected state, not an error.
class RealProgressRepository implements ProgressRepository {
  RealProgressRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  @override
  Future<StudentProgress> fetch({
    required String workspaceId,
    required String userId,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/users/$userId/progress',
      );
      return StudentProgress.fromJson(response.data!);
    } on DioException catch (e) {
      // No progress document yet → zero state, not a failure.
      if (e.response?.statusCode == 404) {
        return StudentProgress.empty;
      }
      rethrow;
    }
  }
}
