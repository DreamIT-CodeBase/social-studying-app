import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/shared/models/progress.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Student progress view (Sprint 4.11).
///
/// Renders inside the Progress tab of the student home Scaffold, so it
/// carries no AppBar of its own. Surfaces three things from the
/// [StudentProgress] snapshot: the level + XP progress card, per-topic
/// mastery bars, and a recent-activity timeline.
///
/// Handles all four states (Boil the Lake): loading, error (with
/// retry), zero-state (a brand-new student — shows the Level 1 card
/// plus a single combined empty placeholder), and the populated view.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync =
        ref.watch(studentProgressNotifierProvider(workspaceId));

    return RefreshIndicator(
      onRefresh: () async {
        ref
            .read(studentProgressNotifierProvider(workspaceId).notifier)
            .refresh();
        await ref.read(studentProgressNotifierProvider(workspaceId).future);
      },
      child: progressAsync.when(
        data: (progress) => _ProgressBody(progress: progress),
        loading: () =>
            const LoadingIndicator(message: 'Loading your progress…'),
        error: (error, _) => ListView(
          // ListView keeps pull-to-refresh reachable on the error state.
          children: [
            SizedBox(
              height: context.screenHeight * 0.7,
              child: ErrorView(
                message: error.toString(),
                onRetry: () => ref
                    .read(
                      studentProgressNotifierProvider(workspaceId).notifier,
                    )
                    .refresh(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.progress});

  final StudentProgress progress;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _LevelCard(progress: progress),
        const SizedBox(height: Spacing.lg),
        _OverallMasteryCard(mastery: progress.overallMastery),
        const SizedBox(height: Spacing.xl),
        if (!progress.hasActivity)
          const _ZeroStatePlaceholder()
        else ...[
          const _SectionHeader(title: 'Topic mastery'),
          const SizedBox(height: Spacing.md),
          for (final topic in progress.topics) ...[
            _TopicMasteryCard(topic: topic),
            const SizedBox(height: Spacing.sm),
          ],
          const SizedBox(height: Spacing.lg),
          const _SectionHeader(title: 'Recent activity'),
          const SizedBox(height: Spacing.md),
          for (final entry in progress.recentActivity.take(20)) ...[
            _ActivityRow(entry: entry),
            const SizedBox(height: Spacing.sm),
          ],
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Level + XP
// ─────────────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.progress});

  final StudentProgress progress;

  @override
  Widget build(BuildContext context) {
    // `xpForNextLevel` is documented as always > 0, but clamp anyway so
    // a malformed payload can't crash the screen.
    final span = progress.xpForNextLevel <= 0 ? 1 : progress.xpForNextLevel;
    final fraction = (progress.xpIntoLevel / span).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
              const SizedBox(width: Spacing.sm),
              Text(
                'Level ${progress.level}',
                style: context.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${progress.totalXp} XP total',
                style: context.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withAlpha(230),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: Colors.white.withAlpha(77),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP '
            'to level ${progress.level + 1}',
            style: context.textTheme.bodySmall?.copyWith(
              color: Colors.white.withAlpha(230),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallMasteryCard extends StatelessWidget {
  const _OverallMasteryCard({required this.mastery});

  final double mastery;

  @override
  Widget build(BuildContext context) {
    final percent = (mastery.clamp(0.0, 1.0) * 100).round();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall mastery',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Average across every topic in this workspace.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              '$percent%',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Per-topic mastery
// ─────────────────────────────────────────────────────────────────────────

class _TopicMasteryCard extends StatelessWidget {
  const _TopicMasteryCard({required this.topic});

  final TopicMastery topic;

  @override
  Widget build(BuildContext context) {
    final mastery = topic.mastery.clamp(0.0, 1.0);
    final percent = (mastery * 100).round();
    final color = _masteryColor(mastery);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic.topicName,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: mastery,
                minHeight: 8,
                backgroundColor: context.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              _topicDetail(topic),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mastery is graded into three colored bands so the bar reads as a
  /// status at a glance: red until 30%, amber until 60%, green above.
  static Color _masteryColor(double mastery) {
    if (mastery < 0.3) return AppColors.error;
    if (mastery < 0.6) return AppColors.secondary;
    return AppColors.tertiary;
  }

  static String _topicDetail(TopicMastery topic) {
    final attempts =
        '${topic.attempts} ${topic.attempts == 1 ? 'attempt' : 'attempts'}';
    if (topic.attempts == 0) return attempts;
    final successPct = (topic.successRate.clamp(0.0, 1.0) * 100).round();
    return '$attempts • $successPct% correct';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Activity timeline
// ─────────────────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final isQuestion = entry.kind == ActivityKind.question;
    final (icon, accent) = isQuestion
        ? (Icons.quiz_rounded, AppColors.primary)
        : (Icons.style_rounded, AppColors.tertiary);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withAlpha(31),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.topic,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _StatusPill(entry: entry),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        _relativeTime(entry.occurredAt),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              '+${entry.xpEarned}',
              style: context.textTheme.labelLarge?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (entry) {
      ActivityEntry(kind: ActivityKind.flashcard) => (
          'Reviewed',
          AppColors.tertiary,
        ),
      ActivityEntry(isCorrect: true) => ('Correct', AppColors.tertiary),
      ActivityEntry(isCorrect: false) => ('Incorrect', AppColors.error),
      _ => ('Answered', context.colorScheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Compact relative timestamp. Falls back to the raw ISO string if it
/// can't be parsed.
String _relativeTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}';
}

// ─────────────────────────────────────────────────────────────────────────
// Empty state + section headers
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: context.textTheme.labelMedium?.copyWith(
        color: context.colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ZeroStatePlaceholder extends StatelessWidget {
  const _ZeroStatePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.xxl),
      child: EmptyStateView(
        icon: Icons.insights_rounded,
        title: 'No progress yet',
        subtitle:
            'Answer a question or rate a flashcard to start building your '
            'topic mastery profile.',
      ),
    );
  }
}
