import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/progress/data/progress_repository.dart';
import 'package:social_study_app/shared/models/progress.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

part 'student_progress_detail_screen.g.dart';

/// Per-student progress detail for admins (Sprint 5.10).
///
/// Pushed from the workspace roster (``users_screen.dart``) when an
/// admin taps a student row. Reuses the existing
/// ``ProgressRepository`` — the wire shape is identical to the
/// student's own progress view, but this screen routes through an
/// admin-scoped notifier that takes ``(workspaceId, userId)`` as the
/// family key so we never tangle with the student-self notifier that
/// reads its id off the auth state.
///
/// Renders the student's name in the AppBar, the same level + mastery
/// content as the student progress screen (4.11), plus a "weak areas"
/// callout pulled from the lowest-mastery topics so the admin can see
/// at a glance where to intervene.
class StudentProgressDetailScreen extends ConsumerWidget {
  const StudentProgressDetailScreen({
    super.key,
    required this.workspaceId,
    required this.studentId,
    required this.studentName,
  });

  final String workspaceId;
  final String studentId;

  /// Caller-supplied display name — saves a round-trip to the users
  /// endpoint just to render an AppBar title.
  final String studentName;

  AdminStudentProgressKey get _key =>
      (workspaceId: workspaceId, userId: studentId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(adminStudentProgressProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              studentName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Student progress',
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminStudentProgressProvider(_key));
          await ref.read(adminStudentProgressProvider(_key).future);
        },
        child: progressAsync.when(
          data: (progress) => _ProgressBody(
            progress: progress,
            studentName: studentName,
          ),
          loading: () =>
              const LoadingIndicator(message: 'Loading student progress…'),
          error: (error, _) => ListView(
            children: [
              SizedBox(
                height: context.screenHeight * 0.7,
                child: ErrorView(
                  message: error.toString(),
                  onRetry: () =>
                      ref.invalidate(adminStudentProgressProvider(_key)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.progress, required this.studentName});

  final StudentProgress progress;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    final span = progress.xpForNextLevel <= 0 ? 1 : progress.xpForNextLevel;
    final levelFraction = (progress.xpIntoLevel / span).clamp(0.0, 1.0);
    final weakAreas = _weakestTopics(progress.topics);

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _LevelCard(
          progress: progress,
          fraction: levelFraction,
        ),
        const SizedBox(height: Spacing.lg),
        _SummaryRow(progress: progress),
        const SizedBox(height: Spacing.xl),
        if (!progress.hasActivity)
          _ZeroState(studentName: studentName)
        else ...[
          if (weakAreas.isNotEmpty) ...[
            const _SectionHeader(title: 'Weak areas'),
            const SizedBox(height: Spacing.md),
            _WeakAreasCard(weakAreas: weakAreas),
            const SizedBox(height: Spacing.lg),
          ],
          const _SectionHeader(title: 'Topic mastery'),
          const SizedBox(height: Spacing.md),
          for (final topic in progress.topics) ...[
            _TopicMasteryCard(topic: topic),
            const SizedBox(height: Spacing.sm),
          ],
          const SizedBox(height: Spacing.lg),
          const _SectionHeader(title: 'Recent activity'),
          const SizedBox(height: Spacing.md),
          for (final entry in progress.recentActivity) ...[
            _ActivityRow(entry: entry),
            const SizedBox(height: Spacing.sm),
          ],
        ],
      ],
    );
  }

  /// Topics with mastery < 0.5 and at least one attempt — the admin's
  /// signal that the student is struggling there. Sorted ascending so
  /// the most painful topic shows up first.
  static List<TopicMastery> _weakestTopics(List<TopicMastery> topics) {
    return [
      for (final t in topics)
        if (t.mastery < 0.5 && t.attempts > 0) t,
    ]..sort((a, b) => a.mastery.compareTo(b.mastery));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Cards
// ─────────────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.progress, required this.fraction});

  final StudentProgress progress;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF6366F1)],
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
              const Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: 28,
              ),
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

/// Three-stat summary tile: overall mastery, topics studied, attempts.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.progress});

  final StudentProgress progress;

  @override
  Widget build(BuildContext context) {
    final overallPct = (progress.overallMastery.clamp(0.0, 1.0) * 100).round();
    final totalAttempts = progress.topics.fold<int>(
      0,
      (sum, t) => sum + t.attempts,
    );
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.insights_rounded,
            color: AppColors.primary,
            label: 'Overall',
            value: '$overallPct%',
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.menu_book_rounded,
            color: AppColors.secondary,
            label: 'Topics',
            value: '${progress.topics.length}',
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _StatTile(
            icon: Icons.quiz_rounded,
            color: AppColors.tertiary,
            label: 'Attempts',
            value: '$totalAttempts',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: Spacing.xs),
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakAreasCard extends StatelessWidget {
  const _WeakAreasCard({required this.weakAreas});

  final List<TopicMastery> weakAreas;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.error.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Below 50% mastery',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            for (final topic in weakAreas)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        topic.topicName,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${(topic.mastery * 100).round()}%',
                      style: context.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopicMasteryCard extends StatelessWidget {
  const _TopicMasteryCard({required this.topic});

  final TopicMastery topic;

  @override
  Widget build(BuildContext context) {
    final mastery = topic.mastery.clamp(0.0, 1.0);
    final percent = (mastery * 100).round();
    final color = _bandColor(mastery);
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
              _detail(topic),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _bandColor(double mastery) {
    if (mastery < 0.3) return AppColors.error;
    if (mastery < 0.6) return AppColors.secondary;
    return AppColors.tertiary;
  }

  static String _detail(TopicMastery topic) {
    final attempts =
        '${topic.attempts} ${topic.attempts == 1 ? 'attempt' : 'attempts'}';
    if (topic.attempts == 0) return attempts;
    final successPct = (topic.successRate.clamp(0.0, 1.0) * 100).round();
    return '$attempts • $successPct% correct';
  }
}

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

class _ZeroState extends StatelessWidget {
  const _ZeroState({required this.studentName});

  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
      child: EmptyStateView(
        icon: Icons.insights_rounded,
        title: 'No activity yet',
        subtitle:
            "$studentName hasn't answered a question or rated a flashcard in "
            'this workspace yet. Encourage them to start a study session!',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Admin-scoped progress provider
// ─────────────────────────────────────────────────────────────────────────

/// Composite key — the per-student admin view family-keys by both
/// workspace and target student id, distinct from the student-self
/// notifier that resolves its id off the auth state.
typedef AdminStudentProgressKey = ({String workspaceId, String userId});

/// Loads any student's progress snapshot for the admin detail view.
@riverpod
Future<StudentProgress> adminStudentProgress(
  AdminStudentProgressRef ref,
  AdminStudentProgressKey key,
) {
  return ref.read(progressRepositoryProvider).fetch(
        workspaceId: key.workspaceId,
        userId: key.userId,
      );
}
