import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/admin/analytics/data/analytics_repository.dart';
import 'package:social_study_app/shared/models/analytics.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

part 'workspace_analytics_screen.g.dart';

/// Workspace analytics dashboard (Sprint 5.11).
///
/// Pushed from the admin Settings tab. Reads the Sprint 5.9
/// ``GET /workspaces/{ws}/analytics`` payload and surfaces:
///
/// - A 4-tile metrics row (students, active 7d, avg mastery, avg accuracy)
/// - A 14-day engagement heatmap with colour-banded intensity
/// - A topic distribution list sorted by attempts (most-studied first)
///
/// Handles all four states (Boil the Lake): loading, error with
/// retry, empty (no students or no activity yet), and populated.
class WorkspaceAnalyticsScreen extends ConsumerWidget {
  const WorkspaceAnalyticsScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceAnalyticsProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workspace Analytics',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workspaceAnalyticsProvider(workspaceId));
          await ref.read(workspaceAnalyticsProvider(workspaceId).future);
        },
        child: async.when(
          data: (analytics) => _Body(analytics: analytics),
          loading: () =>
              const LoadingIndicator(message: 'Loading analytics…'),
          error: (error, _) => ListView(
            children: [
              SizedBox(
                height: context.screenHeight * 0.7,
                child: ErrorView(
                  message: error.toString(),
                  onRetry: () => ref
                      .invalidate(workspaceAnalyticsProvider(workspaceId)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.analytics});

  final WorkspaceAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    if (!analytics.hasActivity) {
      return ListView(
        children: [
          SizedBox(
            height: context.screenHeight * 0.7,
            child: const EmptyStateView(
              icon: Icons.insights_rounded,
              title: 'No analytics yet',
              subtitle:
                  'Once students join and start answering questions, '
                  'their activity and mastery will show up here.',
            ),
          ),
        ],
      );
    }

    // Topic list sorted by attempts desc so the most-studied topic
    // surfaces first. The backend orders alphabetically — this is a
    // purely presentational re-sort.
    final topicsByAttempts = [...analytics.topicDistribution]
      ..sort((a, b) => b.attempts.compareTo(a.attempts));

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _MetricsGrid(analytics: analytics),
        const SizedBox(height: Spacing.xl),
        const _SectionHeader(title: 'Engagement — last 14 days'),
        const SizedBox(height: Spacing.md),
        _EngagementHeatmap(cells: analytics.engagementHeatmap),
        const SizedBox(height: Spacing.xl),
        const _SectionHeader(title: 'Topic distribution'),
        const SizedBox(height: Spacing.md),
        for (final topic in topicsByAttempts) ...[
          _TopicCard(topic: topic),
          const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Metrics grid (2x2)
// ─────────────────────────────────────────────────────────────────────────

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.analytics});

  final WorkspaceAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final masteryPct =
        (analytics.avgOverallMastery.clamp(0.0, 1.0) * 100).round();
    final accuracyPct =
        (analytics.avgCorrectRate.clamp(0.0, 1.0) * 100).round();
    final qpsLabel = analytics.avgQuestionsPerStudent == 0
        ? '0'
        : analytics.avgQuestionsPerStudent.toStringAsFixed(1);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.people_rounded,
                color: AppColors.primary,
                label: 'Students',
                value: '${analytics.totalStudents}',
                subtitle: '${analytics.activeStudents7d} active this week',
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _MetricTile(
                icon: Icons.insights_rounded,
                color: AppColors.tertiary,
                label: 'Avg mastery',
                value: '$masteryPct%',
                subtitle: 'across all students',
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.quiz_rounded,
                color: AppColors.secondary,
                label: 'Questions / student',
                value: qpsLabel,
                subtitle: 'avg attempted',
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _MetricTile(
                icon: Icons.adjust_rounded,
                color: AppColors.primary,
                label: 'Accuracy',
                value: '$accuracyPct%',
                subtitle: 'across all attempts',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border.all(color: context.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            value,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Engagement heatmap
// ─────────────────────────────────────────────────────────────────────────

/// 14-day heatmap. Each day is a colored square whose intensity
/// scales with the day's event count, normalized to the busiest day
/// in the visible window so a quiet workspace still gets contrast.
class _EngagementHeatmap extends StatelessWidget {
  const _EngagementHeatmap({required this.cells});

  final List<HeatmapCell> cells;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No engagement data yet.',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final maxEvents = cells.fold<int>(0, (m, c) => c.events > m ? c.events : m);
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border.all(color: context.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The cell row stretches to fill the card; SizedBox sets
          // the row height so the days render as flat squares
          // regardless of card width.
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final cell in cells) ...[
                  Expanded(child: _HeatmapSquare(cell: cell, maxEvents: maxEvents)),
                  if (cell != cells.last) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Text(
                _shortDate(cells.first.date),
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                _shortDate(cells.last.date),
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _LegendRow(maxEvents: maxEvents),
        ],
      ),
    );
  }

  static String _shortDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}';
  }
}

class _HeatmapSquare extends StatelessWidget {
  const _HeatmapSquare({required this.cell, required this.maxEvents});

  final HeatmapCell cell;
  final int maxEvents;

  @override
  Widget build(BuildContext context) {
    final color = _shade(cell.events, maxEvents);
    return Tooltip(
      message: '${cell.date} • ${cell.events} '
          '${cell.events == 1 ? 'event' : 'events'}',
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  /// Five-step shade ramp anchored to the primary palette, with a
  /// distinct empty-day shade so zero stands apart from "barely
  /// active".
  static Color _shade(int events, int maxEvents) {
    if (events == 0 || maxEvents == 0) {
      return AppColors.primary.withAlpha(20);
    }
    final fraction = (events / maxEvents).clamp(0.0, 1.0);
    if (fraction <= 0.25) return AppColors.primary.withAlpha(60);
    if (fraction <= 0.5) return AppColors.primary.withAlpha(120);
    if (fraction <= 0.75) return AppColors.primary.withAlpha(180);
    return AppColors.primary;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.maxEvents});

  final int maxEvents;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Less',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: Spacing.xs),
        for (final alpha in const [20, 60, 120, 180, 255])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(alpha),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: Spacing.xs),
        Text(
          'More',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        if (maxEvents > 0) ...[
          const SizedBox(width: Spacing.sm),
          Text(
            '(peak: $maxEvents)',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Topic card
// ─────────────────────────────────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final TopicStats topic;

  @override
  Widget build(BuildContext context) {
    final mastery = topic.avgMastery.clamp(0.0, 1.0);
    final masteryPct = (mastery * 100).round();
    final accuracyPct =
        (topic.correctRate.clamp(0.0, 1.0) * 100).round();
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
                    topic.topic,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$masteryPct%',
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
              '${topic.attempts} attempts • $accuracyPct% correct',
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
}

// ─────────────────────────────────────────────────────────────────────────
// Section header
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

// ─────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────

@riverpod
Future<WorkspaceAnalytics> workspaceAnalytics(
  WorkspaceAnalyticsRef ref,
  String workspaceId,
) {
  return ref
      .read(analyticsRepositoryProvider)
      .fetchWorkspace(workspaceId: workspaceId);
}
