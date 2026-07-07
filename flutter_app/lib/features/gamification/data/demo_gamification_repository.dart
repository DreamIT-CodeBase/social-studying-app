import 'dart:async';

import 'package:social_study_app/features/gamification/data/gamification_repository.dart';
import 'package:social_study_app/shared/models/gamification.dart';

/// Offline, deterministic gamification data for the demo user.
///
/// Provides a plausible mid-journey profile (Level 3, 480 XP, 4-day
/// streak, 5 earned badges) so the gamification screens render with
/// real content without a live backend — and so widget tests can
/// drive the populated state through the repository seam.
class DemoGamificationRepository implements GamificationRepository {
  DemoGamificationRepository();

  static const _latency = Duration(milliseconds: 200);

  @override
  Future<GamificationProfile> fetchProfile({
    required String workspaceId,
    required String userId,
  }) async {
    await Future<void>.delayed(_latency);
    return _profile.copyWith(
      studentId: userId,
      workspaceId: workspaceId,
    );
  }

  @override
  Future<StreakSummary> fetchStreak({
    required String workspaceId,
    required String userId,
  }) async {
    await Future<void>.delayed(_latency);
    return StreakSummary(
      studentId: userId,
      streakDays: _profile.streakDays,
      longestStreakDays: _profile.longestStreakDays,
      lastActiveDate: _profile.lastActiveDate,
      activeToday: true,
    );
  }

  @override
  Future<BadgesSummary> fetchBadges({
    required String workspaceId,
    required String userId,
  }) async {
    await Future<void>.delayed(_latency);
    return BadgesSummary(
      studentId: userId,
      earned: _profile.badges,
      available: _availableBadges,
      earnedCount: _profile.badges.length,
      totalCount: _profile.badges.length + _availableBadges.length,
    );
  }

  @override
  Future<LeaderboardResponse> fetchLeaderboard({
    required String workspaceId,
  }) async {
    await Future<void>.delayed(_latency);
    return LeaderboardResponse(
      workspaceId: workspaceId,
      entries: _leaderboard,
      currentUserRank: 2,
      visible: true,
    );
  }

  @override
  Future<SessionCompletionFeedback> completeSession({
    required String workspaceId,
    required String userId,
    required String sessionType,
  }) async {
    await Future<void>.delayed(_latency);
    int xp = sessionType == "study" ? 8 : 5;
    return SessionCompletionFeedback(
      xpEarned: xp,
      newLevel: 3,
      leveledUp: false,
      streakDays: 4,
      streakExtended: false,
      badgesUnlocked: const [],
    );
  }

  // ── Fixture data ──────────────────────────────────────────────────

  static const GamificationProfile _profile = GamificationProfile(
    studentId: 'usr_demo_001',
    workspaceId: 'wsp_demo',
    xpTotal: 480,
    xpThisWeek: 120,
    xpByTopic: {
      'Photosynthesis': 220,
      'Cell Biology': 145,
      'Cellular Respiration': 70,
      'Genetics': 45,
    },
    level: 3,
    xpIntoLevel: 80,
    xpForNextLevel: 200,
    streakDays: 4,
    longestStreakDays: 11,
    lastActiveDate: '2026-05-23',
    questionsAnswered: 33,
    questionsCorrect: 24,
    flashcardsReviewed: 17,
    badges: [
      EarnedBadge(
        badgeId: 'first_steps',
        name: 'First Steps',
        description: 'Answer your first question.',
        icon: 'spa_rounded',
        earnedAt: '2026-05-15T10:00:00Z',
      ),
      EarnedBadge(
        badgeId: 'first_flashcard',
        name: 'Flip Side',
        description: 'Review your first flashcard.',
        icon: 'style_rounded',
        earnedAt: '2026-05-15T11:00:00Z',
      ),
      EarnedBadge(
        badgeId: 'streak_3',
        name: 'Warming Up',
        description: 'Study three days in a row.',
        icon: 'whatshot_rounded',
        earnedAt: '2026-05-18T19:00:00Z',
      ),
      EarnedBadge(
        badgeId: 'sharp_5',
        name: 'Sharp',
        description: 'Answer five questions correctly.',
        icon: 'adjust_rounded',
        earnedAt: '2026-05-17T15:00:00Z',
      ),
      EarnedBadge(
        badgeId: 'xp_100',
        name: 'Rising Star',
        description: 'Earn 100 XP.',
        icon: 'star_rounded',
        earnedAt: '2026-05-16T20:00:00Z',
      ),
    ],
    dailyActivity: {
      '2026-05-17': 4,
      '2026-05-18': 6,
      '2026-05-19': 0,
      '2026-05-20': 3,
      '2026-05-21': 8,
      '2026-05-22': 5,
      '2026-05-23': 7,
    },
  );

  static const List<AvailableBadge> _availableBadges = [
    AvailableBadge(
      badgeId: 'streak_7',
      name: 'Dedicated',
      description: 'Maintain a seven-day study streak.',
      icon: 'local_fire_department_rounded',
    ),
    AvailableBadge(
      badgeId: 'streak_30',
      name: 'Committed',
      description: 'Maintain a thirty-day study streak.',
      icon: 'emoji_events_rounded',
    ),
    AvailableBadge(
      badgeId: 'scholar_25',
      name: 'Scholar',
      description: 'Answer 25 questions.',
      icon: 'menu_book_rounded',
    ),
    AvailableBadge(
      badgeId: 'scholar_100',
      name: 'Honor Student',
      description: 'Answer 100 questions.',
      icon: 'school_rounded',
    ),
    AvailableBadge(
      badgeId: 'sharp_50',
      name: 'Sharpshooter',
      description: 'Answer fifty questions correctly.',
      icon: 'gps_fixed_rounded',
    ),
    AvailableBadge(
      badgeId: 'perfectionist',
      name: 'Perfectionist',
      description: 'Maintain 90% accuracy over 50+ questions.',
      icon: 'workspace_premium_rounded',
    ),
    AvailableBadge(
      badgeId: 'xp_1000',
      name: 'XP Powerhouse',
      description: 'Earn 1,000 XP.',
      icon: 'bolt_rounded',
    ),
    AvailableBadge(
      badgeId: 'flashcard_fan',
      name: 'Flashcard Fan',
      description: 'Review 50 flashcards.',
      icon: 'filter_drama_rounded',
    ),
    AvailableBadge(
      badgeId: 'level_5',
      name: 'Apprentice',
      description: 'Reach level 5.',
      icon: 'emoji_events_outlined',
    ),
  ];

  static const List<LeaderboardEntry> _leaderboard = [
    LeaderboardEntry(
      studentId: 'usr_demo_alex',
      displayName: 'Alex Chen',
      level: 4,
      xpTotal: 920,
      xpThisWeek: 240,
      rank: 1,
      streakDays: 12,
    ),
    LeaderboardEntry(
      studentId: 'usr_demo_001',
      displayName: 'You',
      level: 3,
      xpTotal: 480,
      xpThisWeek: 120,
      rank: 2,
      streakDays: 4,
    ),
    LeaderboardEntry(
      studentId: 'usr_demo_priya',
      displayName: 'Priya Sharma',
      level: 3,
      xpTotal: 425,
      xpThisWeek: 95,
      rank: 3,
      streakDays: 7,
    ),
    LeaderboardEntry(
      studentId: 'usr_demo_jordan',
      displayName: 'Jordan Lee',
      level: 2,
      xpTotal: 310,
      xpThisWeek: 65,
      rank: 4,
      streakDays: 2,
    ),
    LeaderboardEntry(
      studentId: 'usr_demo_sam',
      displayName: 'Sam Patel',
      level: 2,
      xpTotal: 175,
      xpThisWeek: 30,
      rank: 5,
      streakDays: 1,
    ),
    LeaderboardEntry(
      studentId: 'usr_demo_riley',
      displayName: 'Riley Kim',
      level: 1,
      xpTotal: 60,
      xpThisWeek: 20,
      rank: 6,
      streakDays: 0,
    ),
  ];
}

/// Variant returning a brand-new student's zero-state. Not wired into
/// the provider — exists for widget tests that drive the empty branches.
class EmptyDemoGamificationRepository implements GamificationRepository {
  const EmptyDemoGamificationRepository();

  @override
  Future<GamificationProfile> fetchProfile({
    required String workspaceId,
    required String userId,
  }) async =>
      GamificationProfile.empty.copyWith(
        studentId: userId,
        workspaceId: workspaceId,
      );

  @override
  Future<StreakSummary> fetchStreak({
    required String workspaceId,
    required String userId,
  }) async =>
      StreakSummary.empty.copyWith(studentId: userId);

  @override
  Future<BadgesSummary> fetchBadges({
    required String workspaceId,
    required String userId,
  }) async =>
      BadgesSummary.empty.copyWith(studentId: userId);

  @override
  Future<LeaderboardResponse> fetchLeaderboard({
    required String workspaceId,
  }) async =>
      const LeaderboardResponse(workspaceId: '');

  @override
  Future<SessionCompletionFeedback> completeSession({
    required String workspaceId,
    required String userId,
    required String sessionType,
  }) async {
    int xp = sessionType == "study" ? 8 : 5;
    return SessionCompletionFeedback(
      xpEarned: xp,
      newLevel: 1,
      leveledUp: false,
      streakDays: 1,
      streakExtended: true,
      badgesUnlocked: const [],
    );
  }
}
