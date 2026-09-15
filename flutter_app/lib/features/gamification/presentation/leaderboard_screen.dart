import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/shared/models/gamification.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours & constants
// ─────────────────────────────────────────────────────────────────────────────

const _gold = Color(0xFFFFD700);
const _silver = Color(0xFFC0C0C0);
const _bronze = Color(0xFFCD7F32);
const _accent = Color(0xFF58CC02); // Duolingo green
const _purple = Color(0xFF6366F1);

const _bgDark = Color(0xFF0D1117);
const _cardDark = Color(0xFF161B22);
const _divDark = Color(0xFF21262D);

// ─────────────────────────────────────────────────────────────────────────────
// Root screen widget
// ─────────────────────────────────────────────────────────────────────────────

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({
    super.key,
    required this.workspaceId,
    required this.currentUserId,
  });

  final String workspaceId;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider(workspaceId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _bgDark : Colors.white,
      body: RefreshIndicator(
        color: _accent,
        onRefresh: () async {
          ref.invalidate(leaderboardProvider(workspaceId));
          await ref.read(leaderboardProvider(workspaceId).future);
        },
        child: async.when(
          data: (response) => _LeaderboardBody(
            response: response,
            currentUserId: currentUserId,
            isDark: isDark,
          ),
          loading: () => const _ShimmerSkeleton(),
          error: (e, _) => ListView(children: [
            SizedBox(
              height: context.screenHeight * 0.7,
              child: ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(leaderboardProvider(workspaceId)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main body — hero + podium + list
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody({
    required this.response,
    required this.currentUserId,
    required this.isDark,
  });

  final LeaderboardResponse response;
  final String currentUserId;
  final bool isDark;

  String _flag(String id) {
    const flags = [
      '🇺🇸',
      '🇬🇧',
      '🇨🇦',
      '🇮🇳',
      '🇩🇪',
      '🇫🇷',
      '🇦🇺',
      '🇯🇵',
      '🇧🇷',
      '🇪🇸',
      '🇮🇹',
      '🇳🇱'
    ];
    return flags[id.hashCode.abs() % flags.length];
  }

  @override
  Widget build(BuildContext context) {
    if (!response.visible) {
      return const EmptyStateView(
        icon: Icons.visibility_off_rounded,
        title: 'Leaderboard hidden',
        subtitle: 'Your teacher has turned off the leaderboard.',
      );
    }
    if (response.entries.isEmpty) {
      return const EmptyStateView(
        icon: Icons.group_outlined,
        title: 'No students yet',
        subtitle: 'Once students start studying, they\'ll appear here.',
      );
    }

    final entries = response.entries;
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    final myEntry =
        entries.where((e) => e.studentId == currentUserId).firstOrNull;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Full-bleed gradient hero ──────────────────────────────────────
        SliverToBoxAdapter(
          child: _HeroHeader(
            isDark: isDark,
            myRank: response.currentUserRank,
            myEntry: myEntry,
            total: entries.length,
          ),
        ),

        // ── Podium ────────────────────────────────────────────────────────
        if (top3.isNotEmpty)
          SliverToBoxAdapter(
            child: _PodiumSection(
              top3: top3,
              currentUserId: currentUserId,
              isDark: isDark,
              getFlag: _flag,
            ).animate().fadeIn(duration: 600.ms).slideY(
                begin: 0.12,
                end: 0,
                duration: 600.ms,
                curve: Curves.easeOutCubic),
          ),

        // ── Section header ────────────────────────────────────────────────
        if (rest.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Text(
                    'ALL LEARNERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isDark
                          ? const Color(0xFF8B949E)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: isDark ? _divDark : const Color(0xFFE5E7EB),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Remaining list ────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _LeaderboardTile(
                entry: rest[i],
                isMe: rest[i].studentId == currentUserId,
                isDark: isDark,
                flag: _flag(rest[i].studentId),
              ).animate().fadeIn(duration: 300.ms, delay: (i * 40).ms).slideX(
                  begin: 0.06, end: 0, duration: 300.ms, delay: (i * 40).ms),
              childCount: rest.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header — full-bleed gradient with rank pill
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.isDark,
    required this.myRank,
    required this.myEntry,
    required this.total,
  });

  final bool isDark;
  final int? myRank;
  final LeaderboardEntry? myEntry;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          width: double.infinity,
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _purple.withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          bottom: -20,
          left: -20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.10),
            ),
          ),
        ),

        // Content
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back + title row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Leaderboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // League badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      const Text(
                        'Gold League',
                        style: TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Your rank pill
                if (myRank != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'You\'re #$myRank ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              TextSpan(
                                text: 'of $total learners',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.70),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(
        begin: -0.08, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Podium section
// ─────────────────────────────────────────────────────────────────────────────

class _PodiumSection extends StatelessWidget {
  const _PodiumSection({
    required this.top3,
    required this.currentUserId,
    required this.isDark,
    required this.getFlag,
  });

  final List<LeaderboardEntry> top3;
  final String currentUserId;
  final bool isDark;
  final String Function(String) getFlag;

  @override
  Widget build(BuildContext context) {
    LeaderboardEntry? r1, r2, r3;
    for (final e in top3) {
      if (e.rank == 1) r1 = e;
      if (e.rank == 2) r2 = e;
      if (e.rank == 3) r3 = e;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
      decoration: BoxDecoration(
        color: isDark ? _cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? _divDark : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rank 2
          if (r2 != null)
            Expanded(
              child: _PodiumPillar(
                entry: r2,
                pillarHeight: 120,
                medalColor: _silver,
                rank: 2,
                isMe: r2.studentId == currentUserId,
                flag: getFlag(r2.studentId),
                isDark: isDark,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: 8),

          // Rank 1
          if (r1 != null)
            Expanded(
              child: _PodiumPillar(
                entry: r1,
                pillarHeight: 160,
                medalColor: _gold,
                rank: 1,
                isMe: r1.studentId == currentUserId,
                flag: getFlag(r1.studentId),
                isDark: isDark,
                isWinner: true,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: 8),

          // Rank 3
          if (r3 != null)
            Expanded(
              child: _PodiumPillar(
                entry: r3,
                pillarHeight: 96,
                medalColor: _bronze,
                rank: 3,
                isMe: r3.studentId == currentUserId,
                flag: getFlag(r3.studentId),
                isDark: isDark,
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumPillar extends StatelessWidget {
  const _PodiumPillar({
    required this.entry,
    required this.pillarHeight,
    required this.medalColor,
    required this.rank,
    required this.isMe,
    required this.flag,
    required this.isDark,
    this.isWinner = false,
  });

  final LeaderboardEntry entry;
  final double pillarHeight;
  final Color medalColor;
  final int rank;
  final bool isMe;
  final String flag;
  final bool isDark;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final initial =
        entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?';
    final avatarSize = isWinner ? 58.0 : 48.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown above winner
        if (isWinner)
          const Text('👑', style: TextStyle(fontSize: 26)).animate().scaleXY(
              begin: 1.0, end: 1.12, duration: 900.ms, curve: Curves.easeInOut)
        else
          const SizedBox(height: 20),
        const SizedBox(height: 4),

        // Avatar
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow ring for winner
            if (isWinner)
              Container(
                width: avatarSize + 16,
                height: avatarSize + 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: medalColor.withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    medalColor.withValues(alpha: 0.8),
                    medalColor.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isMe ? _purple : medalColor,
                  width: isWinner ? 3.0 : 2.0,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: isWinner ? 22 : 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black38, blurRadius: 4)
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Name
        Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isMe
                ? _purple
                : (isDark ? Colors.white : const Color(0xFF111827)),
          ),
        ),
        const SizedBox(height: 2),
        Text(flag, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 8),

        // Pillar
        Container(
          height: pillarHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                medalColor.withValues(alpha: isDark ? 0.55 : 0.85),
                medalColor.withValues(alpha: isDark ? 0.20 : 0.40),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
                color: medalColor.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Medal badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                child: Center(
                  child: Text(
                    _rankEmoji(rank),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${entry.xpTotal}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                ),
              ),
              const Text(
                'XP',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _rankEmoji(int r) =>
      switch (r) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '#$r' };
}

// ─────────────────────────────────────────────────────────────────────────────
// Leaderboard tile (rank 4+)
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.entry,
    required this.isMe,
    required this.isDark,
    required this.flag,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final bool isDark;
  final String flag;

  @override
  Widget build(BuildContext context) {
    final initial =
        entry.displayName.isNotEmpty ? entry.displayName[0].toUpperCase() : '?';
    final xpProgress = (entry.xpTotal % 500) / 500.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark ? const Color(0xFF1C1C3A) : const Color(0xFFF0F0FF))
            : (isDark ? _cardDark : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? _purple.withValues(alpha: 0.6)
              : (isDark ? _divDark : const Color(0xFFE5E7EB)),
          width: isMe ? 1.5 : 1.0,
        ),
        boxShadow: isMe
            ? [
                BoxShadow(
                    color: _purple.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 3))
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 36,
              child: Text(
                '#${entry.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? const Color(0xFF8B949E)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isMe
                      ? [_purple, const Color(0xFF818CF8)]
                      : [const Color(0xFF374151), const Color(0xFF1F2937)],
                ),
                border: Border.all(
                  color: isMe
                      ? _purple
                      : (isDark ? _divDark : const Color(0xFFD1D5DB)),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + level + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isMe
                                ? _purple
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF111827)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(flag, style: const TextStyle(fontSize: 12)),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: _purple,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Level chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv ${entry.level}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _accent,
                          ),
                        ),
                      ),
                      if (entry.streakDays > 0) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.local_fire_department_rounded,
                            size: 13, color: Color(0xFFFF6B35)),
                        Text(
                          '${entry.streakDays}d',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // XP progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: xpProgress,
                      minHeight: 4,
                      backgroundColor:
                          isDark ? _divDark : const Color(0xFFF3F4F6),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isMe ? _purple : _accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // XP score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.xpTotal}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isMe
                        ? _purple
                        : (isDark ? Colors.white : const Color(0xFF111827)),
                  ),
                ),
                const Text(
                  'XP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                if (entry.xpThisWeek > 0)
                  Text(
                    '+${entry.xpThisWeek}w',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _accent.withValues(alpha: 0.9),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton();

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = (_anim.value * math.pi * 2);
        final shimmer = 0.5 + 0.5 * math.sin(t);
        final base = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
        final shine =
            isDark ? const Color(0xFF30363D) : const Color(0xFFF9FAFB);
        final bg = Color.lerp(base, shine, shimmer)!;

        return ListView(
          children: [
            Container(
                height: 220,
                color: isDark ? _cardDark : const Color(0xFFF3F4F6)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(
                    5,
                    (i) => Container(
                          height: 72,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        )),
              ),
            ),
          ],
        );
      },
    );
  }
}
