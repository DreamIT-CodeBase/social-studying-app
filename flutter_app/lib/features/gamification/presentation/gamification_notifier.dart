import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/gamification/data/gamification_repository.dart';
import 'package:social_study_app/shared/models/gamification.dart';

part 'gamification_notifier.g.dart';

/// Async providers backing the Sprint 5.4 gamification UI.
///
/// One provider per backend endpoint. The family parameter carries
/// the workspace + user id (or just workspace, for the leaderboard).
///
/// **Refresh model.** No explicit refresh methods — callers use
/// ``ref.invalidate(provider(arg))`` from a pull-to-refresh handler.
/// This is the canonical Riverpod pattern post-2.0 and avoids the
/// brittle "stash the key on the notifier" idiom.

/// Composite key for the per-student endpoints. Record-typed so two
/// distinct (workspaceId, userId) pairs use distinct provider entries.
typedef GamificationKey = ({String workspaceId, String userId});

/// Full gamification profile — XP, level, streak, per-topic XP,
/// earned badges, daily activity.
@riverpod
Future<GamificationProfile> gamificationProfile(
  GamificationProfileRef ref,
  GamificationKey key,
) {
  return ref.read(gamificationRepositoryProvider).fetchProfile(
        workspaceId: key.workspaceId,
        userId: key.userId,
      );
}

/// Cheap streak-only fetch — used by the home page streak card so the
/// home tab doesn't pay for the full profile load on every visit.
@riverpod
Future<StreakSummary> streakSummary(
  StreakSummaryRef ref,
  GamificationKey key,
) {
  return ref.read(gamificationRepositoryProvider).fetchStreak(
        workspaceId: key.workspaceId,
        userId: key.userId,
      );
}

/// Earned + available badges in a single payload.
@riverpod
Future<BadgesSummary> badgesSummary(
  BadgesSummaryRef ref,
  GamificationKey key,
) {
  return ref.read(gamificationRepositoryProvider).fetchBadges(
        workspaceId: key.workspaceId,
        userId: key.userId,
      );
}

/// Workspace leaderboard.
@riverpod
Future<LeaderboardResponse> leaderboard(
  LeaderboardRef ref,
  String workspaceId,
) {
  return ref
      .read(gamificationRepositoryProvider)
      .fetchLeaderboard(workspaceId: workspaceId);
}
