import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/gamification/data/demo_gamification_repository.dart';
import 'package:social_study_app/features/gamification/data/real_gamification_repository.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/gamification.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'gamification_repository.g.dart';

/// Source-of-truth for gamification data — profile (XP + level +
/// streak + per-topic XP), badges (earned + available), the streak
/// summary, and the workspace leaderboard.
///
/// Backs the Sprint 5.4 student gamification UI:
/// - `BadgesScreen` — earned + locked tiles
/// - `LeaderboardScreen` — ranked roster
/// - `StreakCard` / level UI on the home + progress views
///
/// Hits the Sprint 5.2 endpoints under
/// `/api/v1/workspaces/{ws}/users/{uid}/...`. [DemoGamificationRepository]
/// serves plausible fake data when the demo user is signed in so the
/// screens work fully offline.
abstract class GamificationRepository {
  /// Fetch the full gamification profile for one student.
  Future<GamificationProfile> fetchProfile({
    required String workspaceId,
    required String userId,
  });

  /// Cheap streak-only fetch — used by the home page card so we don't
  /// have to load the full profile just to render a flame.
  Future<StreakSummary> fetchStreak({
    required String workspaceId,
    required String userId,
  });

  /// Earned + available badges.
  Future<BadgesSummary> fetchBadges({
    required String workspaceId,
    required String userId,
  });

  /// Ranked roster. Honours the workspace's `leaderboard_visible`
  /// setting for students — admins always see it.
  Future<LeaderboardResponse> fetchLeaderboard({
    required String workspaceId,
  });
}

/// Selects between the demo (in-process) and real (Dio → backend)
/// implementation based on the authenticated user. Same heuristic as
/// every other repository in the app.
@Riverpod(keepAlive: true)
GamificationRepository gamificationRepository(GamificationRepositoryRef ref) {
  final auth = ref.watch(authNotifierProvider);
  final isDemo = auth.valueOrNull?.maybeWhen(
        authenticated: (user) => _isDemoUser(user),
        orElse: () => false,
      ) ??
      false;

  if (isDemo) {
    return DemoGamificationRepository();
  }
  return RealGamificationRepository(dio: ref.read(dioClientProvider).dio);
}

// `!useRealBackend` so a `--dart-define=USE_REAL_BACKEND=true` build treats
// nobody as a demo user and routes every call to the Real* impl over Dio.
bool _isDemoUser(User user) =>
    !Environment.useRealBackend &&
    (user.id == 'usr_demo_001' || user.email == 'demo@socialstudyapp.com');
