import 'package:dio/dio.dart';
import 'package:social_study_app/features/gamification/data/gamification_repository.dart';
import 'package:social_study_app/shared/models/gamification.dart';

/// Dio-backed implementation of [GamificationRepository].
///
/// Maps directly onto the Sprint 5.2 endpoints under
/// `/api/v1/workspaces/{workspaceId}/...`. Errors propagate as
/// [DioException]s — callers map them to their own state (the
/// notifiers treat any failure as a load error; pull-to-refresh
/// retries).
class RealGamificationRepository implements GamificationRepository {
  RealGamificationRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  @override
  Future<GamificationProfile> fetchProfile({
    required String workspaceId,
    required String userId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/users/$userId/gamification',
    );
    return GamificationProfile.fromJson(response.data!);
  }

  @override
  Future<StreakSummary> fetchStreak({
    required String workspaceId,
    required String userId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/users/$userId/streak',
    );
    return StreakSummary.fromJson(response.data!);
  }

  @override
  Future<BadgesSummary> fetchBadges({
    required String workspaceId,
    required String userId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/users/$userId/badges',
    );
    return BadgesSummary.fromJson(response.data!);
  }

  @override
  Future<LeaderboardResponse> fetchLeaderboard({
    required String workspaceId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/leaderboard',
    );
    return LeaderboardResponse.fromJson(response.data!);
  }

  @override
  Future<SessionCompletionFeedback> completeSession({
    required String workspaceId,
    required String userId,
    required String sessionType,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/users/$userId/gamification/complete-session',
      data: {'session_type': sessionType},
    );
    return SessionCompletionFeedback.fromJson(response.data!);
  }
}
