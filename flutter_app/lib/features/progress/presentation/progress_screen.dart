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
import 'package:social_study_app/core/theme/theme_manager.dart';

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
    final isMature = ref.watch(appThemeModeProvider) == AppThemeMode.mature;

    // ── Theme-dependent colors ──────────────────────────────────────────────
    final Color bgColor = isDark ? const Color(0xFF0D0D1F) : Colors.white;
    final Color cardBgColor = isDark ? const Color(0xFF13132A) : Colors.white;
    final Color cardBorderColor =
        isDark ? const Color(0xFF2A2A50) : const Color(0xFFE5E7EB);
    final Color primaryTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A2E);
    final Color secondaryTextColor =
        isDark ? const Color(0xFF8888AA) : const Color(0xFF7A7A8C);

    // ── Gamification data: streak + sessions ────────────────────────────────
    final authValue = ref.watch(authNotifierProvider).valueOrNull;
    final userId = authValue?.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );

    int streakDays = 0;
    int sessionsCompleted = 0;

    if (userId != null) {
      final gamKey = (workspaceId: widget.workspaceId, userId: userId);
      final profileAsync = ref.watch(gamificationProfileProvider(gamKey));
      streakDays = profileAsync.valueOrNull?.streakDays ?? 0;
      sessionsCompleted = profileAsync.valueOrNull?.questionsAnswered ?? 0;
    }

    final overallMasteryPercent =
        (widget.progress.overallMastery.clamp(0.0, 1.0) * 100).round();

    // ── Pagination ──────────────────────────────────────────────────────────
    final allTopics = widget.progress.topics;
    final displayedTopics = allTopics.take(_displayedTopicCount).toList();
    final hasMoreTopics = allTopics.length > _displayedTopicCount;

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
            padding: const EdgeInsets.only(bottom: 16),
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isMature
                          ? (isDark
                              ? const Color(0xFF1E3A5F)
                              : const Color(0xFFEFF6FF))
                          : const Color(0xFF60A5FA),
                      image: isMature
                          ? null
                          : const DecorationImage(
                              image: AssetImage(
                                  'assets/mascot/mascot_waving.png'),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: isMature
                        ? Icon(Icons.account_circle_rounded,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : const Color(0xFF2563EB),
                            size: 26)
                        : null,
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
              mastery: widget.progress.overallMastery,
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
            for (final topic in displayedTopics) ...[
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
            if (hasMoreTopics) ...[
              const SizedBox(height: 8),
              _ShowMoreButton(
                onTap: () {
                  setState(() => _displayedTopicCount += 20);
                },
                isDark: isDark,
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
    final xpNeeded =
        (progress.xpForNextLevel - progress.xpIntoLevel).clamp(0, progress.xpForNextLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B2D8F), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.6), width: 1.5),
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
          _LevelMedal(level: progress.level),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Level title + Total XP pill
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
                      child: Text(
                        '${progress.totalXp} XP',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Animated progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: fraction),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF7C5CFC)),
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
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$xpNeeded XP until Level ${progress.level + 1}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
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

class _LevelMedal extends StatelessWidget {
  const _LevelMedal({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFA78BFA), width: 1.5),
        gradient: const LinearGradient(
          colors: [Color(0xFF5140A5), Color(0xFF26215E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF201A4F),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFFCD34D), size: 20),
            Text(
              '$level',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 0.95),
            ),
          ],
        ),
      ),
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
          // Card title
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: isDark
                    ? const Color(0xFFA78BFA)
                    : const Color(0xFF7C5CFC),
              ),
              const SizedBox(width: 8),
              Text(
                'Learning Overview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 1: XP + Mastery
          Row(
            children: [
              Expanded(
                child: _OverviewChip(
                  emoji: '⭐',
                  value: '$totalXp',
                  label: 'Total XP',
                  bgColor: isDark
                      ? const Color(0xFF251D0A)
                      : const Color(0xFFFFFBEB),
                  valueColor: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OverviewChip(
                  emoji: '🎯',
                  value: '$overallMasteryPercent%',
                  label: 'Mastery',
                  bgColor: isDark
                      ? const Color(0xFF14102E)
                      : const Color(0xFFEEF2FF),
                  valueColor: const Color(0xFF6366F1),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Streak + Sessions
          Row(
            children: [
              Expanded(
                child: _OverviewChip(
                  emoji: '🔥',
                  value: '$streakDays',
                  label: 'Day Streak',
                  bgColor: isDark
                      ? const Color(0xFF250E0E)
                      : const Color(0xFFFFF7ED),
                  valueColor: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OverviewChip(
                  emoji: '📚',
                  value: '$sessionsCompleted',
                  label: 'Sessions',
                  bgColor: isDark
                      ? const Color(0xFF0A1525)
                      : const Color(0xFFEFF6FF),
                  valueColor: const Color(0xFF3B82F6),
                  isDark: isDark,
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
    required this.emoji,
    required this.value,
    required this.label,
    required this.bgColor,
    required this.valueColor,
    required this.isDark,
  });

  final String emoji;
  final String value;
  final String label;
  final Color bgColor;
  final Color valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? const Color(0xFF8888AA)
                  : const Color(0xFF64748B),
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
    final activeColor =
        isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);

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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A3A) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.trending_up_rounded, color: activeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Mastery',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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
          const SizedBox(width: 14),
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(62, 62),
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
        color: isDark ? const Color(0xFF1A1A3A) : const Color(0xFFF8FAFC),
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
              color: isDark
                  ? const Color(0xFF8888AA)
                  : const Color(0xFF64748B),
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
    if (mastery < 0.3) return const Color(0xFFEF4444);   // red
    if (mastery < 0.6) return const Color(0xFFF59E0B);   // amber
    return const Color(0xFF22C55E);                        // green
  }

  @override
  Widget build(BuildContext context) {
    final mastery = topic.mastery.clamp(0.0, 1.0);
    final percent = (mastery * 100).round();
    final color = _masteryColor(mastery);
    final successPct =
        topic.attempts > 0 ? (topic.successRate.clamp(0.0, 1.0) * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
  const _ShowMoreButton({required this.onTap, required this.isDark});
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color buttonBgColor = isDark ? const Color(0xFF1A1A3A) : const Color(0xFFF5F3FF);
    final Color borderColor = isDark ? const Color(0xFF3A2A6A) : const Color(0xFFDDD6FE);
    final Color textColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C5CFC);

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
                    Icons.expand_more_rounded,
                    size: 20,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Show 20 More',
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

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter — gradient circular arc for Overall Mastery fallback card
// ─────────────────────────────────────────────────────────────────────────────
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
