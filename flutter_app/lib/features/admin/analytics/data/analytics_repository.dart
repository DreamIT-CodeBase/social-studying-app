import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/analytics.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'analytics_repository.g.dart';

/// Source-of-truth for admin analytics — backs the Sprint 5.11
/// workspace dashboard and the tenant roll-up.
///
/// Hits the Sprint 5.9 backend endpoints:
/// - ``GET /workspaces/{ws}/analytics``
/// - ``GET /tenants/{tid}/analytics``
abstract class AnalyticsRepository {
  Future<WorkspaceAnalytics> fetchWorkspace({required String workspaceId});

  Future<TenantAnalytics> fetchTenant({required String tenantId});
}

/// Dio-backed implementation.
class RealAnalyticsRepository implements AnalyticsRepository {
  RealAnalyticsRepository({required this.dio});

  final Dio dio;

  static const _apiPrefix = '/api/v1';

  @override
  Future<WorkspaceAnalytics> fetchWorkspace({
    required String workspaceId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_apiPrefix/workspaces/$workspaceId/analytics',
    );
    return WorkspaceAnalytics.fromJson(response.data!);
  }

  @override
  Future<TenantAnalytics> fetchTenant({required String tenantId}) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_apiPrefix/tenants/$tenantId/analytics',
    );
    return TenantAnalytics.fromJson(response.data!);
  }
}

/// Demo implementation serving a plausible mid-journey workspace + a
/// two-workspace tenant. Lets the dashboard render without a live
/// backend.
class DemoAnalyticsRepository implements AnalyticsRepository {
  const DemoAnalyticsRepository();

  static const _latency = Duration(milliseconds: 220);

  @override
  Future<WorkspaceAnalytics> fetchWorkspace({
    required String workspaceId,
  }) async {
    await Future<void>.delayed(_latency);
    return _workspace(workspaceId: workspaceId);
  }

  @override
  Future<TenantAnalytics> fetchTenant({required String tenantId}) async {
    await Future<void>.delayed(_latency);
    return TenantAnalytics(
      tenantId: tenantId,
      totalWorkspaces: 2,
      totalStudents: 18,
      activeStudents7d: 11,
      workspaces: const [
        TenantWorkspaceSummary(
          workspaceId: 'wsp_demo',
          name: 'Grade 7 Science',
          totalStudents: 12,
          activeStudents7d: 8,
          avgMastery: 0.56,
          totalQuestionsAnswered: 320,
          totalFlashcardsReviewed: 145,
        ),
        TenantWorkspaceSummary(
          workspaceId: 'wsp_demo_b',
          name: 'Grade 8 Biology',
          totalStudents: 6,
          activeStudents7d: 3,
          avgMastery: 0.42,
          totalQuestionsAnswered: 92,
          totalFlashcardsReviewed: 38,
        ),
      ],
    );
  }

  WorkspaceAnalytics _workspace({required String workspaceId}) =>
      WorkspaceAnalytics(
        workspaceId: workspaceId,
        totalStudents: 12,
        activeStudents7d: 8,
        avgOverallMastery: 0.56,
        avgQuestionsPerStudent: 26.7,
        avgCorrectRate: 0.68,
        topicDistribution: const [
          TopicStats(
            topic: 'Cell Biology',
            attempts: 89,
            avgMastery: 0.62,
            correctRate: 0.71,
          ),
          TopicStats(
            topic: 'Cellular Respiration',
            attempts: 54,
            avgMastery: 0.48,
            correctRate: 0.59,
          ),
          TopicStats(
            topic: 'Genetics',
            attempts: 41,
            avgMastery: 0.38,
            correctRate: 0.51,
          ),
          TopicStats(
            topic: 'Photosynthesis',
            attempts: 136,
            avgMastery: 0.72,
            correctRate: 0.79,
          ),
        ],
        difficultyDistribution: const {
          'beginner': DifficultyStats(attempts: 0, correct: 0),
          'intermediate': DifficultyStats(attempts: 0, correct: 0),
          'advanced': DifficultyStats(attempts: 0, correct: 0),
        },
        engagementHeatmap: _heatmap14Days(),
      );

  /// 14-day heatmap ending today (UTC). Two clear weekly cycles —
  /// quiet weekends, ramps mid-week. Lets the demo screen show what a
  /// real workspace shape looks like without sterile randomness.
  static List<HeatmapCell> _heatmap14Days() {
    final today = DateTime.now().toUtc();
    const pattern = <int>[2, 5, 8, 10, 6, 1, 0, 3, 7, 11, 14, 9, 4, 1];
    return [
      for (var i = 0; i < 14; i++)
        HeatmapCell(
          date: today
              .subtract(Duration(days: 13 - i))
              .toIso8601String()
              .substring(0, 10),
          events: pattern[i],
        ),
    ];
  }
}

/// Provider selects between demo and real impl based on the
/// authenticated user — same heuristic as every other feature.
@Riverpod(keepAlive: true)
AnalyticsRepository analyticsRepository(AnalyticsRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;
  if (isDemo) {
    return const DemoAnalyticsRepository();
  }
  return RealAnalyticsRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
