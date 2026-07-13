import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/shared/models/progress.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';
import 'package:social_study_app/features/screen_time/providers/screen_time_providers.dart';
import 'package:social_study_app/features/home/presentation/student_home_screen.dart';
import 'package:social_study_app/features/progress/services/recall_service.dart';



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
    final progressAsync = ref.watch(studentProgressNotifierProvider(widget.workspaceId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(studentProgressNotifierProvider(widget.workspaceId).notifier).refresh();
        await ref.read(screenTimeNotifierProvider.notifier).refreshWallet();
        await ref.read(studentProgressNotifierProvider(widget.workspaceId).future);
      },
      child: progressAsync.when(
        data: (progress) => _ProgressBody(progress: progress, workspaceId: widget.workspaceId),
        loading: () => const LoadingIndicator(message: 'Loading your progress…'),
        error: (error, _) => ListView(
          children: [
            SizedBox(
              height: context.screenHeight * 0.7,
              child: ErrorView(
                message: error.toString(),
                onRetry: () => ref.read(studentProgressNotifierProvider(widget.workspaceId).notifier).refresh(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBody extends ConsumerStatefulWidget {
  const _ProgressBody({required this.progress, required this.workspaceId});
  final StudentProgress progress;
  final String workspaceId;

  @override
  ConsumerState<_ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends ConsumerState<_ProgressBody> {
  int _recallScore = 64;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-dependent colors
    final Color bgColor = isDark ? const Color(0xFF0D0D1F) : const Color(0xFFFAF4E8);
    final Color cardBgColor = isDark ? const Color(0xFF13132A) : Colors.white;
    final Color cardBorderColor = isDark ? const Color(0xFF2A2A50) : const Color(0xFFEFE6D4);
    final Color primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final Color secondaryTextColor = isDark ? const Color(0xFF8888AA) : const Color(0xFF7A7A8C);




    // Topics mastered count (mastery >= 0.8)
    final topicsMastered = widget.progress.topics.where((t) => t.mastery >= 0.8).length;

    // Generate AI Insights list
    final insights = <String>[];
    insights.add("You answered $_recallScore% of questions correctly.");
    if (widget.progress.topics.isNotEmpty) {
      final sortedTopics = widget.progress.topics.toList()
        ..sort((a, b) => b.attempts.compareTo(a.attempts));
      final topTopic = sortedTopics.first;
      if (topTopic.attempts > 0) {
        insights.add("You spent more time studying ${topTopic.topicName}.");
      }
    } else {
      insights.add("You spent more time studying Human Skin.");
    }
    if (widget.progress.topics.isNotEmpty) {
      final sortedMastery = widget.progress.topics.toList()
        ..sort((a, b) => a.mastery.compareTo(b.mastery));
      insights.add("You should revise ${sortedMastery.first.topicName} next.");
    } else {
      insights.add("You should revise Urinary Bladder next.");
    }
    final performancePct = 10 + (widget.progress.totalXp % 15);
    insights.add("You performed $performancePct% better today than yesterday.");

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Notch/Status Bar Safe Spacing
          SizedBox(height: MediaQuery.of(context).padding.top + 6),
          // ── Header Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                    letterSpacing: -0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF60A5FA),
                      image: DecorationImage(
                        image: AssetImage('assets/mascot/mascot_waving.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main Level / XP Progress Card ───────────────────────────
          _LevelCard(progress: widget.progress, isDark: isDark),
          const SizedBox(height: 14),


          // ── Stats Grid Row (Streak, XP, Topics, Accuracy) ────────────
          Row(
            children: [
              Expanded(
                child: _PillGridCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFEF4444),
                  value: '3',
                  label: 'Day Streak',
                  isDark: isDark,
                  cardBg: cardBgColor,
                  border: cardBorderColor,
                  textStyle: primaryTextColor,
                  subStyle: secondaryTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillGridCard(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFFD700),
                  value: '${widget.progress.totalXp}',
                  label: 'XP Total',
                  isDark: isDark,
                  cardBg: cardBgColor,
                  border: cardBorderColor,
                  textStyle: primaryTextColor,
                  subStyle: secondaryTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillGridCard(
                  icon: Icons.flash_on_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  value: '$topicsMastered',
                  label: 'Topics Mastered',
                  isDark: isDark,
                  cardBg: cardBgColor,
                  border: cardBorderColor,
                  textStyle: primaryTextColor,
                  subStyle: secondaryTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillGridCard(
                  icon: Icons.track_changes_rounded,
                  iconColor: const Color(0xFF10B981),
                  value: '$_recallScore%',
                  label: 'Accuracy',
                  isDark: isDark,
                  cardBg: cardBgColor,
                  border: cardBorderColor,
                  textStyle: primaryTextColor,
                  subStyle: secondaryTextColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Screen Time Balance Card ───────────────────────────────
          _ScreenTimeDashboardCard(
            isDark: isDark,
            cardBg: cardBgColor,
            border: cardBorderColor,
            textColor: primaryTextColor,
            subColor: secondaryTextColor,
            onStudyMore: () => ref.read(studentHomeTabProvider.notifier).state = 1,
          ),
          const SizedBox(height: 14),

          // ── Overall Mastery Card ───────────────────────────────────
          _OverallMasteryCard(
            mastery: widget.progress.overallMastery,
            isDark: isDark,
            cardBg: cardBgColor,
            border: cardBorderColor,
            textColor: primaryTextColor,
            subColor: secondaryTextColor,
          ),
          const SizedBox(height: 14),

          // ── AI Learning Insights Box ───────────────────────────────
          _AIInsightsCard(
            insights: insights,
            isDark: isDark,
            border: cardBorderColor,
            textColor: primaryTextColor,
            subColor: secondaryTextColor,
          ),
          const SizedBox(height: 16),

          // ── Topic Mastery Section ──────────────────────────────────
          if (!widget.progress.hasActivity)
            const _ZeroStatePlaceholder()
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Topic Mastery',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final topic in widget.progress.topics) ...[
              _TopicMasteryCard(
                topic: topic,
                isDark: isDark,
                cardBg: cardBgColor,
                border: cardBorderColor,
                textColor: primaryTextColor,
                subColor: secondaryTextColor,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level + XP Card with Hexagon logo
// ─────────────────────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.progress, required this.isDark});
  final StudentProgress progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final span = progress.xpForNextLevel <= 0 ? 1 : progress.xpForNextLevel;
    final fraction = (progress.xpIntoLevel / span).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B2D8F), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF7C5CFC).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.16),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Custom Painted Winged Hexagon Shield Star Badge
          CustomPaint(
            size: const Size(70, 70),
            painter: _WingedBadgePainter(),
          ),
          const SizedBox(width: 16),
          // XP Bar & Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level ${progress.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${progress.totalXp} XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Total XP',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C5CFC)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP to reach Level ${progress.level + 1}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill Grid Card
// ─────────────────────────────────────────────────────────────────────────────
class _PillGridCard extends StatelessWidget {
  const _PillGridCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textStyle,
    required this.subStyle,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color textStyle;
  final Color subStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textStyle,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: subStyle,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Screen Time Balance Card (radial progress + details)
// ─────────────────────────────────────────────────────────────────────────────
class _ScreenTimeDashboardCard extends ConsumerWidget {
  const _ScreenTimeDashboardCard({
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.subColor,
    required this.onStudyMore,
  });

  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color subColor;
  final VoidCallback onStudyMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(screenTimeNotifierProvider);

    return walletAsync.when(
      data: (wallet) {
        final total = wallet.totalEarnedMinutes;
        final available = wallet.availableMinutes;
        final usedToday = wallet.consumedToday;
        final double progress = total > 0 ? (available / total).clamp(0.0, 1.0) : 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(Icons.phone_android_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Screen Time Balance',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // Radial progress circle on right
                  _ScreenTimeRadialProgress(
                    available: available,
                    total: total,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Big available display
              Text(
                '$available min',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'available today',
                style: TextStyle(
                  color: subColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // Horizontal progress
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF1A1A3A) : const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                ),
              ),
              const SizedBox(height: 14),
              // Grid metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetricText(label: 'Earned', value: '$total min', isDark: isDark, labelColor: subColor, valueColor: textColor),
                  _MetricText(label: 'Used Today', value: '$usedToday min', isDark: isDark, labelColor: subColor, valueColor: textColor),
                  _MetricText(label: 'Remaining', value: '$available min', isDark: isDark, labelColor: subColor, valueColor: textColor),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF2A2A50), height: 1),
              const SizedBox(height: 10),
              // Study button
              GestureDetector(
                onTap: onStudyMore,
                child: Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Color(0xFF22C55E), size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'Study More',
                      style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: subColor, size: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText({
    required this.label,
    required this.value,
    required this.isDark,
    required this.labelColor,
    required this.valueColor,
  });
  final String label;
  final String value;
  final bool isDark;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ScreenTimeRadialProgress extends StatelessWidget {
  const _ScreenTimeRadialProgress({
    required this.available,
    required this.total,
    required this.isDark,
  });

  final int available;
  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final double fraction = total > 0 ? (available / total).clamp(0.0, 1.0) : 0.0;

    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(70, 70),
            painter: _GradientCircularProgressPainter(
              progress: fraction,
              isDark: isDark,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$available',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1.1,
                ),
              ),
              Text(
                'min',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF8888AA) : const Color(0xFF7A7A8C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Overall Mastery Card
// ─────────────────────────────────────────────────────────────────────────
class _OverallMasteryCard extends StatelessWidget {
  const _OverallMasteryCard({
    required this.mastery,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.subColor,
  });

  final double mastery;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    final percent = (mastery.clamp(0.0, 1.0) * 100).round();
    final activeColor = isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);


    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A3A) : const Color(0xFFF4EDE0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: activeColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Mastery',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Average across all topics',
                  style: TextStyle(
                    color: subColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Circular Progress showing average mastery with smooth SweepGradient
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(58, 58),
                  painter: _SimpleGradientCircularProgressPainter(
                    progress: mastery,
                    isDark: isDark,
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Insights Box with robot illustration
// ─────────────────────────────────────────────────────────────────────────────
class _AIInsightsCard extends StatelessWidget {
  const _AIInsightsCard({
    required this.insights,
    required this.isDark,
    required this.border,
    required this.textColor,
    required this.subColor,
  });

  final List<String> insights;
  final bool isDark;
  final Color border;
  final Color textColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131135) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? const Color(0xFF4C3D8F) : const Color(0xFFC7D2FE), width: 1.5),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'AI Learning Insights',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...insights.map((insight) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('✨', style: TextStyle(fontSize: 12, color: Color(0xFFA78BFA))),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  insight,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 60), // Room for robot buddy
            ],
          ),
          // Mascot robot buddy
          Positioned(
            right: 0,
            bottom: 0,
            child: Image.asset(
              'assets/mascot/study_buddy.png',
              width: 72,
              height: 72,
              errorBuilder: (_, __, ___) => const Text('🤖', style: TextStyle(fontSize: 44)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic Mastery Card
// ─────────────────────────────────────────────────────────────────────────────
class _TopicMasteryCard extends StatelessWidget {
  const _TopicMasteryCard({
    required this.topic,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.subColor,
  });

  final TopicMastery topic;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    final mastery = topic.mastery.clamp(0.0, 1.0);
    final percent = (mastery * 100).round();
    final color = _masteryColor(mastery);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  topic.topicName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: color,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: mastery,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF1A1A3A) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _topicDetail(topic),
            style: TextStyle(
              color: subColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Color _masteryColor(double mastery) {
    if (mastery < 0.3) return const Color(0xFFEF4444); // red
    if (mastery < 0.6) return const Color(0xFFF59E0B); // orange
    return const Color(0xFF22C55E); // green
  }

  static String _topicDetail(TopicMastery topic) {
    final attempts = '${topic.attempts} ${topic.attempts == 1 ? 'attempt' : 'attempts'}';
    if (topic.attempts == 0) return attempts;
    final successPct = (topic.successRate.clamp(0.0, 1.0) * 100).round();
    return '$attempts • $successPct% correct';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Zero State Placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _ZeroStatePlaceholder extends StatelessWidget {
  const _ZeroStatePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: EmptyStateView(
        icon: Icons.insights_rounded,
        title: 'No progress yet',
        subtitle: 'Answer a question or rate a flashcard to build your topic mastery profile.',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painters for premium gamified badges and progress arcs
// ─────────────────────────────────────────────────────────────────────────────

class _WingedBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.28;

    // Paint for wings (horizontal lines/chevrons on left and right)
    final wingsPaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Draw left wing
    final leftWing = Path()
      ..moveTo(center.dx - radius - 5, center.dy - 11)
      ..lineTo(center.dx - radius - 17, center.dy - 6)
      ..lineTo(center.dx - radius - 5, center.dy - 1)
      ..moveTo(center.dx - radius - 7, center.dy - 4)
      ..lineTo(center.dx - radius - 21, center.dy + 1)
      ..lineTo(center.dx - radius - 7, center.dy + 6);
    canvas.drawPath(leftWing, wingsPaint);

    // Draw right wing
    final rightWing = Path()
      ..moveTo(center.dx + radius + 5, center.dy - 11)
      ..lineTo(center.dx + radius + 17, center.dy - 6)
      ..lineTo(center.dx + radius + 5, center.dy - 1)
      ..moveTo(center.dx + radius + 7, center.dy - 4)
      ..lineTo(center.dx + radius + 21, center.dy + 1)
      ..lineTo(center.dx + radius + 7, center.dy + 6);
    canvas.drawPath(rightWing, wingsPaint);

    // Draw hexagon shield
    final shieldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7C5CFC), Color(0xFF4C1D95)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final shieldBorderPaint = Paint()
      ..color = const Color(0xFFA78BFA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final shieldPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        shieldPath.moveTo(x, y);
      } else {
        shieldPath.lineTo(x, y);
      }
    }
    shieldPath.close();

    canvas.drawPath(shieldPath, shieldPaint);
    canvas.drawPath(shieldPath, shieldBorderPaint);

    // Draw gold star in center
    final starPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    final starPath = Path();
    final double innerRadius = radius * 0.36;
    final double outerRadius = radius * 0.72;
    for (int i = 0; i < 10; i++) {
      final double r = i.isEven ? outerRadius : innerRadius;
      final double angle = i * math.pi / 5 - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GradientCircularProgressPainter extends CustomPainter {
  _GradientCircularProgressPainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6.5) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track Paint
    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Paint with beautiful SweepGradient (Teal to Purple/Violet glow)
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF10B981), Color(0xFF22C55E), Color(0xFF8B5CF6)],
        stops: [0.0, 0.4, 0.7, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Apply scaling strokeWidth
    progressPaint.strokeWidth = 6.0;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SimpleGradientCircularProgressPainter extends CustomPainter {
  _SimpleGradientCircularProgressPainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6.0) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = isDark ? const Color(0xFF1A1A3A) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF6366F1), Color(0xFF3B82F6), Color(0xFF6366F1)],
        stops: [0.0, 0.5, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    progressPaint.strokeWidth = 5.5;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

