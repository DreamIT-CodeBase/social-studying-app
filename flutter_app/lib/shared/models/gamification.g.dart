// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EarnedBadgeImpl _$$EarnedBadgeImplFromJson(Map<String, dynamic> json) =>
    _$EarnedBadgeImpl(
      badgeId: json['badge_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      earnedAt: json['earned_at'] as String,
    );

Map<String, dynamic> _$$EarnedBadgeImplToJson(_$EarnedBadgeImpl instance) =>
    <String, dynamic>{
      'badge_id': instance.badgeId,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
      'earned_at': instance.earnedAt,
    };

_$AvailableBadgeImpl _$$AvailableBadgeImplFromJson(Map<String, dynamic> json) =>
    _$AvailableBadgeImpl(
      badgeId: json['badge_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
    );

Map<String, dynamic> _$$AvailableBadgeImplToJson(
        _$AvailableBadgeImpl instance) =>
    <String, dynamic>{
      'badge_id': instance.badgeId,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
    };

_$BadgeUnlockImpl _$$BadgeUnlockImplFromJson(Map<String, dynamic> json) =>
    _$BadgeUnlockImpl(
      badgeId: json['badge_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
    );

Map<String, dynamic> _$$BadgeUnlockImplToJson(_$BadgeUnlockImpl instance) =>
    <String, dynamic>{
      'badge_id': instance.badgeId,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
    };

_$BadgesSummaryImpl _$$BadgesSummaryImplFromJson(Map<String, dynamic> json) =>
    _$BadgesSummaryImpl(
      studentId: json['student_id'] as String,
      earned: (json['earned'] as List<dynamic>?)
              ?.map((e) => EarnedBadge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <EarnedBadge>[],
      available: (json['available'] as List<dynamic>?)
              ?.map((e) => AvailableBadge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AvailableBadge>[],
      earnedCount: (json['earned_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$BadgesSummaryImplToJson(_$BadgesSummaryImpl instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'earned': instance.earned,
      'available': instance.available,
      'earned_count': instance.earnedCount,
      'total_count': instance.totalCount,
    };

_$StreakSummaryImpl _$$StreakSummaryImplFromJson(Map<String, dynamic> json) =>
    _$StreakSummaryImpl(
      studentId: json['student_id'] as String,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      longestStreakDays: (json['longest_streak_days'] as num?)?.toInt() ?? 0,
      lastActiveDate: json['last_active_date'] as String?,
      activeToday: json['active_today'] as bool? ?? false,
    );

Map<String, dynamic> _$$StreakSummaryImplToJson(_$StreakSummaryImpl instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'streak_days': instance.streakDays,
      'longest_streak_days': instance.longestStreakDays,
      'last_active_date': instance.lastActiveDate,
      'active_today': instance.activeToday,
    };

_$GamificationProfileImpl _$$GamificationProfileImplFromJson(
        Map<String, dynamic> json) =>
    _$GamificationProfileImpl(
      studentId: json['student_id'] as String,
      workspaceId: json['workspace_id'] as String,
      xpTotal: (json['xp_total'] as num?)?.toInt() ?? 0,
      xpThisWeek: (json['xp_this_week'] as num?)?.toInt() ?? 0,
      xpByTopic: (json['xp_by_topic'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      level: (json['level'] as num?)?.toInt() ?? 1,
      xpIntoLevel: (json['xp_into_level'] as num?)?.toInt() ?? 0,
      xpForNextLevel: (json['xp_for_next_level'] as num?)?.toInt() ?? 100,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      longestStreakDays: (json['longest_streak_days'] as num?)?.toInt() ?? 0,
      lastActiveDate: json['last_active_date'] as String?,
      questionsAnswered: (json['questions_answered'] as num?)?.toInt() ?? 0,
      questionsCorrect: (json['questions_correct'] as num?)?.toInt() ?? 0,
      flashcardsReviewed: (json['flashcards_reviewed'] as num?)?.toInt() ?? 0,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((e) => EarnedBadge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <EarnedBadge>[],
      dailyActivity: (json['daily_activity'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
    );

Map<String, dynamic> _$$GamificationProfileImplToJson(
        _$GamificationProfileImpl instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'workspace_id': instance.workspaceId,
      'xp_total': instance.xpTotal,
      'xp_this_week': instance.xpThisWeek,
      'xp_by_topic': instance.xpByTopic,
      'level': instance.level,
      'xp_into_level': instance.xpIntoLevel,
      'xp_for_next_level': instance.xpForNextLevel,
      'streak_days': instance.streakDays,
      'longest_streak_days': instance.longestStreakDays,
      'last_active_date': instance.lastActiveDate,
      'questions_answered': instance.questionsAnswered,
      'questions_correct': instance.questionsCorrect,
      'flashcards_reviewed': instance.flashcardsReviewed,
      'badges': instance.badges,
      'daily_activity': instance.dailyActivity,
    };

_$LeaderboardEntryImpl _$$LeaderboardEntryImplFromJson(
        Map<String, dynamic> json) =>
    _$LeaderboardEntryImpl(
      studentId: json['student_id'] as String,
      displayName: json['display_name'] as String,
      level: (json['level'] as num?)?.toInt() ?? 1,
      xpTotal: (json['xp_total'] as num?)?.toInt() ?? 0,
      xpThisWeek: (json['xp_this_week'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$LeaderboardEntryImplToJson(
        _$LeaderboardEntryImpl instance) =>
    <String, dynamic>{
      'student_id': instance.studentId,
      'display_name': instance.displayName,
      'level': instance.level,
      'xp_total': instance.xpTotal,
      'xp_this_week': instance.xpThisWeek,
      'rank': instance.rank,
      'streak_days': instance.streakDays,
    };

_$LeaderboardResponseImpl _$$LeaderboardResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$LeaderboardResponseImpl(
      workspaceId: json['workspace_id'] as String,
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LeaderboardEntry>[],
      currentUserRank: (json['current_user_rank'] as num?)?.toInt(),
      visible: json['visible'] as bool? ?? true,
    );

Map<String, dynamic> _$$LeaderboardResponseImplToJson(
        _$LeaderboardResponseImpl instance) =>
    <String, dynamic>{
      'workspace_id': instance.workspaceId,
      'entries': instance.entries,
      'current_user_rank': instance.currentUserRank,
      'visible': instance.visible,
    };

_$SessionCompletionFeedbackImpl _$$SessionCompletionFeedbackImplFromJson(
        Map<String, dynamic> json) =>
    _$SessionCompletionFeedbackImpl(
      xpEarned: (json['xp_earned'] as num).toInt(),
      newLevel: (json['new_level'] as num).toInt(),
      leveledUp: json['leveled_up'] as bool,
      streakDays: (json['streak_days'] as num).toInt(),
      streakExtended: json['streak_extended'] as bool,
      badgesUnlocked: (json['badges_unlocked'] as List<dynamic>?)
              ?.map((e) => EarnedBadge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <EarnedBadge>[],
    );

Map<String, dynamic> _$$SessionCompletionFeedbackImplToJson(
        _$SessionCompletionFeedbackImpl instance) =>
    <String, dynamic>{
      'xp_earned': instance.xpEarned,
      'new_level': instance.newLevel,
      'leveled_up': instance.leveledUp,
      'streak_days': instance.streakDays,
      'streak_extended': instance.streakExtended,
      'badges_unlocked': instance.badgesUnlocked,
    };
