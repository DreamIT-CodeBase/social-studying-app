import 'package:dio/dio.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';

/// Backend-backed implementation. Talks to the Sprint 2.11 endpoints in
/// ``backend/app/api/taxonomy.py``.
///
/// Error mapping mirrors ``RealDocumentsRepository``: 404 turns into a
/// typed exception so the notifier can render an empty/not-found state
/// instead of looping forever on a workspace that no longer exists.
class RealTaxonomyRepository implements TaxonomyRepository {
  RealTaxonomyRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  @override
  Future<Taxonomy> get({required String workspaceId}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/taxonomy',
      );
      return Taxonomy.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<void> regenerate({required String workspaceId}) async {
    try {
      await dio.post<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/taxonomy/regenerate',
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  @override
  Future<Taxonomy> update({
    required String workspaceId,
    required int expectedVersion,
    required List<CanonicalTopic> topics,
  }) async {
    try {
      final response = await dio.put<Map<String, dynamic>>(
        '$_apiPrefix/workspaces/$workspaceId/taxonomy',
        data: {
          'taxonomy_version': expectedVersion,
          'topics': [for (final topic in topics) topic.toJson()],
        },
      );
      return Taxonomy.fromJson(response.data!);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Exception _translate(DioException e) {
    switch (e.response?.statusCode) {
      case 404:
        return const TaxonomyWorkspaceNotFoundException();
      case 409:
        return TaxonomyVersionConflictException(_detailFrom(e));
      case 422:
        return TaxonomyValidationException(_detailFrom(e));
      default:
        return e;
    }
  }

  /// Pull the FastAPI `detail` string out of an error response. Falls
  /// back to the generic Dio message if the shape isn't what we expect.
  static String _detailFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
    }
    return e.message ?? 'Request failed';
  }
}
