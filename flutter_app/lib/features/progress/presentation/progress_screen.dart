import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/shared/models/progress.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';
import 'package:social_study_app/features/screen_time/providers/screen_time_providers.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({
    super.key,
    required this.workspaceId,
    this.topicMasterySummary,
  });

  final String workspaceId;
  final Widget? topicMasterySummary;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen>
    with WidgetsBindingObserver {
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
    final progressAsync =
        ref.watch(studentProgressNotifierProvider(widget.workspaceId));

    return RefreshIndicator(
      onRefresh: () async {
        ref
            .read(studentProgressNotifierProvider(widget.workspaceId).notifier)
            .refresh();
        await ref.read(screenTimeNotifierProvider.notifier).refreshWallet();
        await ref
            .read(studentProgressNotifierProvider(widget.workspaceId).future);
      },
      child: progressAsync.when(
        data: (progress) => _ProgressBody(
          progress: progress,
          workspaceId: widget.workspaceId,
          topicMasterySummary: widget.topicMasterySummary,
        ),
        loading: () =>
            const LoadingIndicator(message: 'Loading your progress…'),
        error: (error, _) => ListView(
          children: [
            SizedBox(
              height: context.screenHeight * 0.7,
              child: ErrorView(
                message: error.toString(),
                onRetry: () => ref
                    .read(studentProgressNotifierProvider(widget.workspaceId)
                        .notifier)
                    .refresh(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress Body — stateful to track pagination
// ─────────────────────────────────────────────────────────────────────────────
class _ProgressBody extends ConsumerStatefulWidget {
  const _ProgressBody({
    required this.progress,
    required this.workspaceId,
    this.topicMasterySummary,
  });
  final StudentProgress progress;
  final String workspaceId;
  final Widget? topicMasterySummary;

  @override
  ConsumerState<_ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends ConsumerState<_ProgressBody> {
  /// Number of topics currently shown — starts at 10, increases by 20 each tap.
  int _displayedTopicCount = 10;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Theme-dependent colors ──────────────────────────────────────────────
    final Color bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color cardBorderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final Color primaryTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A2E);
    final Color secondaryTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF7A7A8C);

    // ── Gamification data: streak + sessions ────────────────────────────────
    final authValue = ref.watch(authNotifierProvider).valueOrNull;
    final userId = authValue?.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );
    final displayName = authValue?.maybeWhen(
          authenticated: (user) => user.displayName,
          orElse: () => 'Student',
        ) ??
        'Student';

    int streakDays = 0;
    int sessionsCompleted = 0;

    if (userId != null) {
      final gamKey = (workspaceId: widget.workspaceId, userId: userId);
      final profileAsync = ref.watch(gamificationProfileProvider(gamKey));
      streakDays = profileAsync.valueOrNull?.streakDays ?? 0;
      sessionsCompleted = profileAsync.valueOrNull?.totalSessionsCompleted ?? 0;
    }

    final overallMasteryPercent =
        (widget.progress.overallMastery.clamp(0.0, 1.0) * 100).round();

    // ── Pagination ──────────────────────────────────────────────────────────
    final allTopics = widget.progress.topics;
    final displayedTopics = allTopics.take(_displayedTopicCount).toList();

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 110,
        ),
        children: [
          // ── Status bar safe spacing ──────────────────────────────────────
          SizedBox(height: MediaQuery.of(context).padding.top + 6),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track your learning journey',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF1E1E38) : Colors.white,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2A2A50)
                            : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'S',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFA78BFA)
                              : const Color(0xFF7C5CFC),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 1. Level Card ────────────────────────────────────────────────
          _LevelCard(progress: widget.progress, isDark: isDark),
          const SizedBox(height: 24),

          // ── 2. Learning Overview Card ────────────────────────────────────
          _LearningOverviewCard(
            totalXp: widget.progress.totalXp,
            overallMasteryPercent: overallMasteryPercent,
            streakDays: streakDays,
            sessionsCompleted: sessionsCompleted,
            isDark: isDark,
            cardBg: cardBgColor,
            border: cardBorderColor,
            textColor: primaryTextColor,
            subColor: secondaryTextColor,
          ),
          const SizedBox(height: 24),

          // ── 3. Topic Mastery Graph ───────────────────────────────────────
          if (widget.topicMasterySummary != null)
            widget.topicMasterySummary!
          else
            _OverallMasteryCard(
              progress: widget.progress,
              isDark: isDark,
              cardBg: cardBgColor,
              border: cardBorderColor,
              textColor: primaryTextColor,
              subColor: secondaryTextColor,
            ),
          const SizedBox(height: 24),

          // ── 4. Social Balance ────────────────────────────────────────────
          _SocialBalanceCard(
            isDark: isDark,
            cardBg: cardBgColor,
            border: cardBorderColor,
            textColor: primaryTextColor,
            subColor: secondaryTextColor,
          ),
          const SizedBox(height: 32),

          // ── 5. Topic Mastery List ────────────────────────────────────────
          if (!widget.progress.hasActivity)
            const _ZeroStatePlaceholder()
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Topic Mastery',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0;
                      index < displayedTopics.length;
                      index++) ...[
                    _TopicMasteryCard(
                      topic: displayedTopics[index],
                      isDark: isDark,
                      cardBg: cardBgColor,
                      border: Colors.transparent,
                      textColor: primaryTextColor,
                      subColor: secondaryTextColor,
                    ),
                    if (index < displayedTopics.length - 1)
                      Divider(height: 1, color: cardBorderColor),
                  ],
                ],
              ),
            ),
            if (allTopics.length > 10) ...[
              const SizedBox(height: 16),
              _ShowMoreButton(
                onTap: () => setState(() {
                  _displayedTopicCount =
                      _displayedTopicCount > 10 ? 10 : allTopics.length;
                }),
                isDark: isDark,
                expanded: _displayedTopicCount > 10,
              ),
            ],
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Level Card — animated XP bar, Total XP pill, XP needed for next level
// ─────────────────────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.progress, required this.isDark});
  final StudentProgress progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final span = progress.xpForNextLevel <= 0 ? 1 : progress.xpForNextLevel;
    final fraction = (progress.xpIntoLevel / span).clamp(0.0, 1.0);
    final xpNeeded = (progress.xpForNextLevel - progress.xpIntoLevel)
        .clamp(0, progress.xpForNextLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B3FD6), Color(0xFF3B2D8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HexagonBadge(level: progress.level),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Level title + Total XP pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level ${progress.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: Color(0xFFFBBF24), size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${progress.totalXp} XP',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Animated progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: fraction),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 12,
                        child: LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // XP fraction + XP until next level
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$xpNeeded XP until Level ${progress.level + 1}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _HexagonBadge extends StatelessWidget {
  const _HexagonBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Decorative sparkles around the hexagon badge
        Positioned(
          top: -6,
          right: -4,
          child: Icon(Icons.auto_awesome,
              size: 12, color: Colors.white.withValues(alpha: 0.7)),
        ),
        Positioned(
          bottom: -4,
          left: -6,
          child: Icon(Icons.auto_awesome,
              size: 9, color: const Color(0xFFFBBF24).withValues(alpha: 0.6)),
        ),
        // Outer Hexagon (Border)
        ClipPath(
          clipper: HexagonClipper(),
          child: Container(
            width: 72,
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA78BFA), Color(0xFF7C5CFC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        // Inner Hexagon
        ClipPath(
          clipper: HexagonClipper(),
          child: Container(
            width: 68,
            height: 76,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E1C8C), Color(0xFF1B115A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Star Icon
                const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFFBBF24),
                  size: 26,
                ),
                const SizedBox(height: 2),
                // Level Number
                Text(
                  '$level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Learning Overview Card — XP / Mastery / Streak / Sessions 4-chip grid
// ─────────────────────────────────────────────────────────────────────────────
class _LearningOverviewCard extends StatelessWidget {
  const _LearningOverviewCard({
    required this.totalXp,
    required this.overallMasteryPercent,
    required this.streakDays,
    required this.sessionsCompleted,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.subColor,
  });

  final int totalXp;
  final int overallMasteryPercent;
  final int streakDays;
  final int sessionsCompleted;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Title + Dropdown Pill
          Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 18,
                color:
                    isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C5CFC),
              ),
              const SizedBox(width: 8),
              Text(
                'Learning Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Horizontal Row of 4 Stat Columns
          Row(
            children: [
              Expanded(
                child: _OverviewChip(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: isDark
                      ? const Color(0xFF263449)
                      : const Color(0xFFFFFBEB),
                  value: '$totalXp',
                  label: 'Total XP',
                  trend: '↑ 18%',
                  trendColor: const Color(0xFF16A34A),
                  isDark: isDark,
                  textColor: textColor,
                  subColor: subColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewChip(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFF97316),
                  bgColor: isDark
                      ? const Color(0xFF2B3248)
                      : const Color(0xFFFFF7ED),
                  value: '$streakDays',
                  label: 'Day Streak',
                  trend: 'Keep it up!',
                  trendColor: const Color(0xFFEA580C),
                  isDark: isDark,
                  textColor: textColor,
                  subColor: subColor,
                  isFlame: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewChip(
                  icon: Icons.auto_stories_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: isDark
                      ? const Color(0xFF29384A)
                      : const Color(0xFFF5F3FF),
                  value: '$sessionsCompleted',
                  label: 'Sessions',
                  trend: '↑ 12%',
                  trendColor: const Color(0xFF16A34A),
                  isDark: isDark,
                  textColor: textColor,
                  subColor: subColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
    required this.trend,
    required this.trendColor,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    this.isFlame = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;
  final String trend;
  final Color trendColor;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final bool isFlame;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13132A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A50) : const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Icon background
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          // Value
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Overall Mastery Card (fallback when no topicMasterySummary injected)
// ─────────────────────────────────────────────────────────────────────────────
class _OverallMasteryCard extends StatelessWidget {
  const _OverallMasteryCard({
    required this.progress,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.subColor,
  });

  final StudentProgress progress;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color subColor;

  Color _getTopicColor(int index) {
    switch (index % 3) {
      case 0:
        return const Color(0xFF2563EB); // blue
      case 1:
        return const Color(0xFF8B5CF6); // purple
      default:
        return const Color(0xFF10B981); // green
    }
  }

  @override
  Widget build(BuildContext context) {
    final overallPercent =
        (progress.overallMastery.clamp(0.0, 1.0) * 100).round();
    final topTopics = progress.topics.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.donut_large_rounded,
                    size: 18,
                    color: isDark
                        ? const Color(0xFFA78BFA)
                        : const Color(0xFF7C5CFC),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Topic Mastery',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut chart + topic progress list side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut Chart on Left
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DonutChartPainter(
                          overallPercent:
                              progress.overallMastery.clamp(0.0, 1.0),
                          topics: topTopics,
                          isDark: isDark,
                          entranceProgress: 1.0,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$overallPercent%',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Overall',
                            style: TextStyle(
                              fontSize: 10,
                              color: subColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Topic List with progress bars on Right
              Expanded(
                child: Column(
                  children: List.generate(
                    topTopics.isEmpty ? 3 : topTopics.length,
                    (index) {
                      // Fallback dummy topics if no topic data
                      final topicName = topTopics.isEmpty
                          ? (index == 0
                              ? 'Biodiversity'
                              : index == 1
                                  ? 'Biology Definition'
                                  : 'Cell Structure')
                          : topTopics[index].topicName;
                      final masteryVal = topTopics.isEmpty
                          ? (index == 0
                              ? 0.37
                              : index == 1
                                  ? 0.40
                                  : 0.31)
                          : topTopics[index].mastery.clamp(0.0, 1.0);
                      final percentVal = (masteryVal * 100).round();
                      final color = _getTopicColor(index);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    topicName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$percentVal%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: masteryVal,
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.overallPercent,
    required this.topics,
    required this.isDark,
    required this.entranceProgress,
  });

  final double overallPercent;
  final List<TopicMastery> topics;
  final bool isDark;
  final double entranceProgress;

  Color _getTopicColor(int index) {
    switch (index % 3) {
      case 0:
        return const Color(0xFF2563EB); // blue
      case 1:
        return const Color(0xFF8B5CF6); // purple
      default:
        return const Color(0xFF10B981); // green
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Rect rect =
        Rect.fromCircle(center: Offset(radius, radius), radius: radius - 10);

    final Paint bgPaint = Paint()
      ..color = isDark
          ? const Color(0xFF334155).withValues(alpha: 0.3)
          : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0;

    canvas.drawCircle(Offset(radius, radius), radius - 10, bgPaint);

    if (topics.isEmpty) {
      // Draw 3 mock segments if topics list is empty
      final List<double> mockMasteries = [0.37, 0.40, 0.31];
      double sum = mockMasteries.reduce((a, b) => a + b);
      double currentAngle = -math.pi / 2;

      for (int i = 0; i < mockMasteries.length; i++) {
        final double fraction = mockMasteries[i] / sum;
        final double sweepAngle = 2 * math.pi * fraction * entranceProgress;

        final Paint segmentPaint = Paint()
          ..color = _getTopicColor(i)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = 14.0;

        if (sweepAngle > 0.05) {
          canvas.drawArc(rect, currentAngle + 0.015, sweepAngle - 0.03, false,
              segmentPaint);
        }
        currentAngle += sweepAngle;
      }
      return;
    }

    double sum = 0.0;
    for (final t in topics) {
      sum += t.mastery.clamp(0.0, 1.0);
    }

    final bool allZero = sum == 0.0;
    double currentAngle = -math.pi / 2;

    for (int i = 0; i < topics.length; i++) {
      final double mastery = topics[i].mastery.clamp(0.0, 1.0);
      final double fraction = allZero ? (1.0 / topics.length) : (mastery / sum);
      final double sweepAngle = 2 * math.pi * fraction * entranceProgress;

      final Paint segmentPaint = Paint()
        ..color = _getTopicColor(i)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = 14.0;

      if (sweepAngle > 0.05) {
        canvas.drawArc(
            rect, currentAngle + 0.015, sweepAngle - 0.03, false, segmentPaint);
      }
      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.entranceProgress != entranceProgress;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Social Balance Card — phone icon, Remaining/Used chips, horizontal bar
// ─────────────────────────────────────────────────────────────────────────────
class _SocialBalanceCard extends ConsumerWidget {
  const _SocialBalanceCard({
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.subColor,
  });

  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color subColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(screenTimeNotifierProvider);

    return walletAsync.when(
      data: (wallet) {
        final total = wallet.totalEarnedMinutes;
        final usedToday = wallet.consumedToday;
        final remaining = wallet.availableMinutes;

        // Usage fraction for bar and color
        final double usageFraction =
            total > 0 ? (usedToday / total).clamp(0.0, 1.0) : 0.0;

        // Green → Amber → Red as usage increases
        final Color barColor = usageFraction < 0.5
            ? const Color(0xFF22C55E)
            : usageFraction < 0.8
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ────────────────────────────────────────────────────
              Row(
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    color: isDark
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF2563EB),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Social Balance',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Remaining / Used stat chips ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _SocialStatChip(
                      label: 'Remaining',
                      value: '$remaining min',
                      valueColor: isDark
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF16A34A),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialStatChip(
                      label: 'Used',
                      value: '$usedToday min',
                      valueColor: barColor,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Horizontal progress bar ──────────────────────────────────
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: usageFraction),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 10,
                    backgroundColor: isDark
                        ? const Color(0xFF1A1A3A)
                        : const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$usedToday / $total min used',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
          height: 90, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SocialStatChip extends StatelessWidget {
  const _SocialStatChip({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isDark,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF263449) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8888AA) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Topic Mastery Card — enhanced with mastery badge + clear detail
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

  static Color _masteryColor(double mastery) {
    if (mastery < 0.3) return const Color(0xFFEF4444); // red
    if (mastery < 0.6) return const Color(0xFFF59E0B); // amber
    return const Color(0xFF22C55E); // green
  }

  @override
  Widget build(BuildContext context) {
    final mastery = topic.mastery.clamp(0.0, 1.0);
    final percent = (mastery * 100).round();
    final color = _masteryColor(mastery);
    final successPct = topic.attempts > 0
        ? (topic.successRate.clamp(0.0, 1.0) * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic name + mastery badge
          Row(
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
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: mastery,
              minHeight: 7,
              backgroundColor:
                  isDark ? const Color(0xFF1A1A3A) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),

          // Attempts + Correct %
          Row(
            children: [
              _TopicStatPill(
                icon: Icons.repeat_rounded,
                label:
                    '${topic.attempts} ${topic.attempts == 1 ? 'attempt' : 'attempts'}',
                isDark: isDark,
                subColor: subColor,
              ),
              if (topic.attempts > 0) ...[
                const SizedBox(width: 8),
                _TopicStatPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: '$successPct% correct',
                  isDark: isDark,
                  subColor: subColor,
                  iconColor: successPct >= 60
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFF59E0B),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TopicStatPill extends StatelessWidget {
  const _TopicStatPill({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.subColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final Color subColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? subColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: subColor,
          ),
        ),
      ],
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.onTap,
    required this.isDark,
    required this.expanded,
  });
  final VoidCallback onTap;
  final bool isDark;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Color buttonBgColor =
        isDark ? const Color(0xFF1A1A3A) : const Color(0xFFF5F3FF);
    final Color borderColor =
        isDark ? const Color(0xFF3A2A6A) : const Color(0xFFDDD6FE);
    final Color textColor =
        isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C5CFC);

    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: textColor.withValues(alpha: isDark ? 0.15 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: buttonBgColor,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    expanded ? 'View Less' : 'View More',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        subtitle:
            'Answer a question or rate a flashcard to build your topic mastery profile.',
      ),
    );
  }
}
