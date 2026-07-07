import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/shared/models/gamification.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:social_study_app/features/mascot/models/mascot_state.dart';
import 'package:social_study_app/features/mascot/widgets/study_buddy.dart';

/// Workspace leaderboard (Sprint 5.4).
///
/// A standalone pushed screen that lists every student in the
/// workspace, sorted by XP descending. The caller's own row is
/// highlighted, and a "you are #N" banner above the list reinforces
/// their rank even when they scroll past their row.
///
/// Five states handled (Boil the Lake): loading, error with retry,
/// hidden (admin turned the leaderboard off for the workspace —
/// student-facing only), empty (no students in the workspace yet),
/// and populated.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({
    super.key,
    required this.workspaceId,
    required this.currentUserId,
  });

  final String workspaceId;

  /// The signed-in user's id — used to highlight their row in the
  /// list, distinct from the (separate) ``current_user_rank`` field
  /// the backend sends.
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(leaderboardProvider(workspaceId));
          await ref.read(leaderboardProvider(workspaceId).future);
        },
        child: leaderboardAsync.when(
          data: (response) => _LeaderboardBody(
            response: response,
            currentUserId: currentUserId,
          ),
          loading: () =>
              const LoadingIndicator(message: 'Loading leaderboard…'),
          error: (error, _) => ListView(
            children: [
              SizedBox(
                height: context.screenHeight * 0.7,
                child: ErrorView(
                  message: error.toString(),
                  onRetry: () =>
                      ref.invalidate(leaderboardProvider(workspaceId)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody({
    required this.response,
    required this.currentUserId,
  });

  final LeaderboardResponse response;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    if (!response.visible) {
      return ListView(
        children: [
          SizedBox(
            height: context.screenHeight * 0.7,
            child: const EmptyStateView(
              icon: Icons.visibility_off_rounded,
              title: 'Leaderboard hidden',
              subtitle:
                  'Your teacher has turned off the leaderboard for this '
                  'workspace.',
            ),
          ),
        ],
      );
    }
    if (response.entries.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: context.screenHeight * 0.7,
            child: const EmptyStateView(
              icon: Icons.group_outlined,
              title: 'No students yet',
              subtitle: 'Once students join and start studying, '
                  'they\'ll appear here ranked by XP.',
            ),
          ),
        ],
      );
    }
    final entries = response.entries;
    return ListView.builder(
      padding: const EdgeInsets.all(Spacing.lg),
      itemCount: entries.length + (response.currentUserRank != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (response.currentUserRank != null) {
          if (index == 0) {
            return Column(
              children: [
                _YourRankBanner(
                  rank: response.currentUserRank!,
                  total: entries.length,
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.1, end: 0, duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: Spacing.lg),
              ],
            );
          }
          final entryIndex = index - 1;
          final entry = entries[entryIndex];
          return Column(
            children: [
              _LeaderboardRow(
                entry: entry,
                isCurrentUser: entry.studentId == currentUserId,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (entryIndex * 40).ms)
                  .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad, delay: (entryIndex * 40).ms),
              const SizedBox(height: Spacing.sm),
            ],
          );
        } else {
          final entry = entries[index];
          return Column(
            children: [
              _LeaderboardRow(
                entry: entry,
                isCurrentUser: entry.studentId == currentUserId,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (index * 40).ms)
                  .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad, delay: (index * 40).ms),
              const SizedBox(height: Spacing.sm),
            ],
          );
        }
      },
    );
  }
}

class _YourRankBanner extends StatelessWidget {
  const _YourRankBanner({required this.rank, required this.total});

  final int rank;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are ranked #$rank',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'of $total studying in this workspace',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          const Icon(Icons.emoji_events_rounded, size: 48, color: Colors.white),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.isCurrentUser,
  });

  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    // Top-3 get medal styling; the rest a plain rank pill. Caller's row
    // gets a primary-tinted background regardless of rank.
    final (medalColor, medalIcon) = switch (entry.rank) {
      1 => (const Color(0xFFFFC93C), Icons.emoji_events_rounded),
      2 => (const Color(0xFFB0BEC5), Icons.emoji_events_rounded),
      3 => (const Color(0xFFCD7F32), Icons.emoji_events_rounded),
      _ => (null, null),
    };
    return Card(
      margin: EdgeInsets.zero,
      color: isCurrentUser
          ? context.colorScheme.primaryContainer
          : context.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            // Rank or medal.
            SizedBox(
              width: 40,
              child: medalIcon != null
                  ? Icon(medalIcon, color: medalColor, size: 28)
                  : Text(
                      '#${entry.rank}',
                      textAlign: TextAlign.center,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isCurrentUser
                            ? context.colorScheme.onPrimaryContainer
                            : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: Spacing.md),
            // Name + level.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isCurrentUser
                          ? context.colorScheme.onPrimaryContainer
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Level ${entry.level}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: isCurrentUser
                              ? context.colorScheme.onPrimaryContainer
                                  .withAlpha(204)
                              : context.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entry.streakDays > 0) ...[
                        const SizedBox(width: Spacing.sm),
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 12,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${entry.streakDays}d',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // XP.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.xpTotal} XP',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isCurrentUser
                        ? context.colorScheme.onPrimaryContainer
                        : AppColors.primary,
                  ),
                ),
                if (entry.xpThisWeek > 0)
                  Text(
                    '+${entry.xpThisWeek} this week',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: isCurrentUser
                          ? context.colorScheme.onPrimaryContainer
                              .withAlpha(204)
                          : context.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
