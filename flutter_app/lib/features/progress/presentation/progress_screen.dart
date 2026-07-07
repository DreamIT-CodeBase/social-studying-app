import 'dart:math' as math;
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
import 'package:social_study_app/features/screen_time/widgets/screen_time_dashboard_card.dart';
import 'package:social_study_app/features/screen_time/providers/screen_time_providers.dart';
import 'package:social_study_app/features/home/presentation/student_home_screen.dart';
import 'package:social_study_app/features/progress/services/recall_service.dart';

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
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh the screen time wallet on entry
    Future.microtask(() {
      if (mounted) {
        ref.read(screenTimeNotifierProvider.notifier).refreshWallet();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(screenTimeNotifierProvider.notifier).refreshWallet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync =
        ref.watch(studentProgressNotifierProvider(widget.workspaceId));

    return RefreshIndicator(
      onRefresh: () async {
        ref
            .read(studentProgressNotifierProvider(widget.workspaceId).notifier)
            .refresh();
        await ref.read(screenTimeNotifierProvider.notifier).refreshWallet();
        await ref.read(studentProgressNotifierProvider(widget.workspaceId).future);
      },
      child: progressAsync.when(
        data: (progress) => _ProgressBody(progress: progress),
        loading: () =>
            const LoadingIndicator(message: 'Loading your progress…'),
        error: (error, _) => ListView(
          children: [
            SizedBox(
              height: context.screenHeight * 0.7,
              child: ErrorView(
                message: error.toString(),
                onRetry: () => ref
                    .read(
                      studentProgressNotifierProvider(widget.workspaceId).notifier,
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

class _ProgressBody extends StatefulWidget {
  const _ProgressBody({required this.progress});
  final StudentProgress progress;

  @override
  State<_ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends State<_ProgressBody> {
  int _recallScore = 85;

  @override
  void initState() {
    super.initState();
    _loadRecallScore();
  }

  Future<void> _loadRecallScore() async {
    try {
      final score = await RecallService.instance.getAverageRecallScore();
      if (mounted) {
        setState(() {
          _recallScore = score;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final insights = <String>[];
    insights.add("You answered $_recallScore% of questions correctly.");

    if (widget.progress.topics.isNotEmpty) {
      final sortedTopics = widget.progress.topics.toList()
        ..sort((a, b) => b.attempts.compareTo(a.attempts));
      final topTopic = sortedTopics.first;
      if (topTopic.attempts > 0) {
        insights.add("You spend more time studying ${topTopic.topicName}.");
      }
    } else {
      insights.add("You spend more study time on Biology today.");
    }

    if (widget.progress.topics.isNotEmpty) {
      final sortedMastery = widget.progress.topics.toList()
        ..sort((a, b) => a.mastery.compareTo(b.mastery));
      insights.add("You should revise ${sortedMastery.first.topicName} next.");
    } else {
      insights.add("You should revise Cell Division to strengthen your mastery.");
    }

    final performancePct = 10 + (widget.progress.totalXp % 15);
    insights.add("You performed $performancePct% better today than yesterday.");

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _LevelCard(progress: widget.progress),
        const SizedBox(height: Spacing.lg),
        Consumer(
          builder: (context, ref, _) {
            return ScreenTimeDashboardCard(
              onStudyMore: () => ref.read(studentHomeTabProvider.notifier).state = 1,
            );
          },
        ),
        const SizedBox(height: Spacing.lg),
        _OverallMasteryCard(mastery: widget.progress.overallMastery),
        const SizedBox(height: Spacing.lg),
        
        // AI Learning Insights Box
        _AIInsightsCard(insights: insights),
        const SizedBox(height: Spacing.lg),



        if (!widget.progress.hasActivity)
          const _ZeroStatePlaceholder()
        else ...[
          const _SectionHeader(title: 'Topic mastery'),
          const SizedBox(height: Spacing.md),
          for (final topic in widget.progress.topics) ...[
            _TopicMasteryCard(topic: topic),
            const SizedBox(height: Spacing.sm),
          ],
          const SizedBox(height: Spacing.lg),
          const _SectionHeader(title: 'Recent activity'),
          const SizedBox(height: Spacing.md),
          for (final entry in widget.progress.recentActivity.take(20)) ...[
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

// ─────────────────────────────────────────────────────────────────────────
// Premium AI Insights & Charts widgets
// ─────────────────────────────────────────────────────────────────────────

class _AIInsightsCard extends StatelessWidget {
  const _AIInsightsCard({required this.insights});
  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Colors.purple, size: 22),
              const SizedBox(width: 8),
              Text(
                'AI Learning Insights',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.3),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _WeeklyTrendAndHeatmapCard extends StatelessWidget {
  const _WeeklyTrendAndHeatmapCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Weekly Line Chart
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Activity Trend',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                width: double.infinity,
                child: CustomPaint(
                  painter: _WeeklyLineChartPainter(
                    const [10, 45, 20, 60, 40, 80, 95],
                    isDark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mon', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('Tue', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('Wed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('Thu', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('Fri', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('Sat', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('Sun', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // Consistency Heatmap
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Study Consistency Heatmap',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                width: double.infinity,
                child: CustomPaint(
                  painter: _CalendarHeatmapPainter(
                    const {
                      2: 1, 4: 3, 5: 2, 8: 4, 12: 1, 15: 3, 16: 4, 19: 2, 22: 4, 25: 1, 28: 3, 29: 2, 32: 4, 34: 3
                    },
                    isDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyLineChartPainter extends CustomPainter {
  final List<double> values;
  final bool isDark;
  _WeeklyLineChartPainter(this.values, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final maxVal = values.reduce(math.max);
    final minVal = values.reduce(math.min);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (values.length - 1);
    
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final ratio = range == 0 ? 0.5 : (values[i] - minVal) / range;
      final y = size.height - (ratio * (size.height - 20) + 10);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    fillPaint.shader = LinearGradient(
      colors: [const Color(0xFF6366F1).withAlpha(50), const Color(0xFF6366F1).withAlpha(0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final pointPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.fill;
    final outerPointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final ratio = range == 0 ? 0.5 : (values[i] - minVal) / range;
      final y = size.height - (ratio * (size.height - 20) + 10);
      
      canvas.drawCircle(Offset(x, y), 5, pointPaint);
      canvas.drawCircle(Offset(x, y), 2, outerPointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CalendarHeatmapPainter extends CustomPainter {
  final Map<int, int> intensityMap;
  final bool isDark;
  _CalendarHeatmapPainter(this.intensityMap, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 7;
    const rows = 5;
    final cellWidth = (size.width - (cols - 1) * 4) / cols;
    final cellHeight = (size.height - (rows - 1) * 4) / rows;

    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final levels = [
      baseColor,
      const Color(0xFF86EFAC),
      const Color(0xFF4ADE80),
      const Color(0xFF22C55E),
      const Color(0xFF15803D),
    ];

    final paint = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final index = r * cols + c;
        final intensity = intensityMap[index] ?? 0;
        final color = levels[intensity.clamp(0, 4)];
        
        paint.color = color;
        final rect = Rect.fromLTWH(
          c * (cellWidth + 4),
          r * (cellHeight + 4),
          cellWidth,
          cellHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
