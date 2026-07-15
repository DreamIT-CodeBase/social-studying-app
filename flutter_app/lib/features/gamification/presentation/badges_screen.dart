import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/features/gamification/presentation/widgets/badge_icon.dart';
import 'package:social_study_app/shared/models/gamification.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Badge showcase grid (Sprint 5.4).
///
/// A standalone pushed screen — reached from the student home or
/// progress view — that shows both earned and available badges in
/// a 3-column responsive grid. Tapping a badge opens a detail sheet
/// with description + earn date (if earned) or unlock criteria (if
/// available).
///
/// Handles all four states (Boil the Lake): loading, error, empty,
/// and populated. Empty is rendered with a helpful prompt rather
/// than a blank grid — a brand-new student should see what's
/// available to chase.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({
    super.key,
    required this.workspaceId,
    required this.userId,
  });

  final String workspaceId;
  final String userId;

  GamificationKey get _key => (workspaceId: workspaceId, userId: userId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesSummaryProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Badges',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(badgesSummaryProvider(_key));
          await ref.read(badgesSummaryProvider(_key).future);
        },
        child: badgesAsync.when(
          data: (summary) => _BadgesBody(summary: summary),
          loading: () => const LoadingIndicator(message: 'Loading badges…'),
          error: (error, _) => ListView(
            children: [
              SizedBox(
                height: context.screenHeight * 0.7,
                child: ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(badgesSummaryProvider(_key)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgesBody extends StatefulWidget {
  const _BadgesBody({required this.summary});

  final BadgesSummary summary;

  @override
  State<_BadgesBody> createState() => _BadgesBodyState();
}

class _BadgesBodyState extends State<_BadgesBody> {
  String _selectedFilter = 'All'; // 'All', 'Earned', 'Locked'
  String _selectedCategory = 'All'; // 'All', 'Biology', 'Chemistry', 'General'
  bool _isGridView = true;

  bool _matchesCategory(String badgeName, String category) {
    if (category == 'All') return true;
    final name = badgeName.toLowerCase();
    if (category == 'Biology') {
      return name.contains('cell') ||
          name.contains('bio') ||
          name.contains('mitosis') ||
          name.contains('photosynthesis') ||
          name.contains('genetics');
    }
    if (category == 'Chemistry') {
      return name.contains('chem') ||
          name.contains('atom') ||
          name.contains('bond') ||
          name.contains('reaction');
    }
    if (category == 'General') {
      return !name.contains('cell') &&
          !name.contains('bio') &&
          !name.contains('mitosis') &&
          !name.contains('photosynthesis') &&
          !name.contains('genetics') &&
          !name.contains('chem') &&
          !name.contains('atom') &&
          !name.contains('bond') &&
          !name.contains('reaction');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.summary.totalCount == 0) {
      // Catalog is empty — should never happen in production but the
      // empty-state widget reads cleanly here without faking a list.
      return ListView(
        children: [
          SizedBox(
            height: context.screenHeight * 0.7,
            child: const EmptyStateView(
              icon: Icons.shield_outlined,
              title: 'No badges yet',
              subtitle: 'Check back soon — new badges are on the way.',
            ),
          ),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter lists based on drop-down selections
    final filteredEarned = widget.summary.earned.where((b) {
      if (_selectedFilter == 'Locked') return false;
      return _matchesCategory(b.name, _selectedCategory);
    }).toList();

    final filteredAvailable = widget.summary.available.where((b) {
      if (_selectedFilter == 'Earned') return false;
      return _matchesCategory(b.name, _selectedCategory);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _ProgressHeader(summary: widget.summary),
        const SizedBox(height: Spacing.lg),

        // ── Render actual list ───────────────────────────────────────────
        if (_isGridView) ...[
          if (filteredEarned.isNotEmpty) ...[
            const _SectionHeader(title: 'Earned'),
            const SizedBox(height: Spacing.md),
            _BadgeGrid(
              children: [
                for (final badge in filteredEarned)
                  _EarnedBadgeTile(badge: badge),
              ],
            ),
            const SizedBox(height: Spacing.xl),
          ],
          if (filteredAvailable.isNotEmpty) ...[
            const _SectionHeader(title: 'Up next'),
            const SizedBox(height: Spacing.md),
            _BadgeGrid(
              children: [
                for (final badge in filteredAvailable)
                  _LockedBadgeTile(badge: badge),
              ],
            ),
          ],
        ] else ...[
          // ── Timeline View ──────────────────────────────────────────────
          if (filteredEarned.isNotEmpty) ...[
            const _SectionHeader(title: 'Timeline & History'),
            const SizedBox(height: Spacing.md),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredEarned.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final badge = filteredEarned[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconForBadgeName(badge.icon),
                            color: AppColors.secondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(badge.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(badge.description,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeEarned(badge.earnedAt),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.xl),
          ],
          if (filteredAvailable.isNotEmpty) ...[
            const _SectionHeader(title: 'Locked Badges'),
            const SizedBox(height: Spacing.md),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredAvailable.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final badge = filteredAvailable[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded,
                            color: Colors.grey),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(badge.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(badge.description,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ],
    );
  }
}

/// Gradient progress header — "5 of 17 unlocked", with a fraction bar.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.summary});

  final BadgesSummary summary;

  @override
  Widget build(BuildContext context) {
    final fraction = summary.totalCount == 0
        ? 0.0
        : (summary.earnedCount / summary.totalCount).clamp(0.0, 1.0);
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
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '${summary.earnedCount} of ${summary.totalCount} unlocked',
                style: context.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }
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

/// 3-column responsive grid host. ``children`` are tiles of arbitrary
/// height — the grid sizes by aspect ratio so the row heights stay
/// consistent.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      // Grid lives inside an outer ListView, so the grid itself
      // mustn't scroll.
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Spacing.md,
      crossAxisSpacing: Spacing.md,
      childAspectRatio: 0.85,
      children: children,
    );
  }
}

class _EarnedBadgeTile extends StatelessWidget {
  const _EarnedBadgeTile({required this.badge});

  final EarnedBadge badge;

  @override
  Widget build(BuildContext context) {
    return _BadgeTile(
      icon: iconForBadgeName(badge.icon),
      title: badge.name,
      // Three sentence-case display — the wire description is a full
      // sentence; truncate on overflow.
      subtitle: _relativeEarned(badge.earnedAt),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _BadgeDetailSheet(
          icon: iconForBadgeName(badge.icon),
          name: badge.name,
          description: badge.description,
          earnedAt: badge.earnedAt,
          locked: false,
        ),
      ),
      locked: false,
    );
  }
}

class _LockedBadgeTile extends StatelessWidget {
  const _LockedBadgeTile({required this.badge});

  final AvailableBadge badge;

  @override
  Widget build(BuildContext context) {
    return _BadgeTile(
      icon: iconForBadgeName(badge.icon),
      title: badge.name,
      subtitle: 'Locked',
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _BadgeDetailSheet(
          icon: iconForBadgeName(badge.icon),
          name: badge.name,
          description: badge.description,
          earnedAt: null,
          locked: true,
        ),
      ),
      locked: true,
    );
  }
}

enum BadgeTier { common, rare, epic, legendary }

BadgeTier getBadgeTier(String title) {
  final name = title.toLowerCase();
  if (name.contains('legend') ||
      name.contains('gold') ||
      name.contains('champion')) {
    return BadgeTier.legendary;
  }
  if (name.contains('epic') ||
      name.contains('silver') ||
      name.contains('streak') ||
      name.contains('master')) {
    return BadgeTier.epic;
  }
  if (name.contains('rare') ||
      name.contains('bronze') ||
      name.contains('scholar')) {
    return BadgeTier.rare;
  }
  return BadgeTier.common;
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.locked,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tier = getBadgeTier(title);

    Color tierColor;
    List<BoxShadow> glowShadows = [];

    switch (tier) {
      case BadgeTier.legendary:
        tierColor = const Color(0xFFF59E0B);
        if (!locked) {
          glowShadows = [
            BoxShadow(
              color: const Color(0xFFF59E0B).withAlpha(isDark ? 90 : 50),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ];
        }
        break;
      case BadgeTier.epic:
        tierColor = const Color(0xFF8B5CF6);
        if (!locked) {
          glowShadows = [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withAlpha(isDark ? 70 : 40),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ];
        }
        break;
      case BadgeTier.rare:
        tierColor = const Color(0xFF3B82F6);
        if (!locked) {
          glowShadows = [
            BoxShadow(
              color: const Color(0xFF3B82F6).withAlpha(isDark ? 50 : 30),
              blurRadius: 6,
            ),
          ];
        }
        break;
      case BadgeTier.common:
        tierColor = AppColors.secondary;
        break;
    }

    final accent = locked ? context.colorScheme.onSurfaceVariant : tierColor;

    return Material(
      color: locked
          ? context.colorScheme.surfaceContainerHighest
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: locked
                  ? context.colorScheme.outlineVariant
                  : accent.withAlpha(180),
              width: locked ? 1.0 : (tier == BadgeTier.legendary ? 2.5 : 1.5),
            ),
            boxShadow: glowShadows,
          ),
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withAlpha(locked ? 31 : 45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  locked ? Icons.lock_outline_rounded : icon,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: locked
                      ? context.colorScheme.onSurfaceVariant
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeDetailSheet extends StatelessWidget {
  const _BadgeDetailSheet({
    required this.icon,
    required this.name,
    required this.description,
    required this.earnedAt,
    required this.locked,
  });

  final IconData icon;
  final String name;
  final String description;
  final String? earnedAt;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final accent =
        locked ? context.colorScheme.onSurfaceVariant : AppColors.secondary;
    return SizedBox(
      key: const ValueKey('badge-detail-sheet'),
      width: double.infinity,
      height: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          Spacing.md,
          Spacing.xl,
          Spacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withAlpha(locked ? 31 : 51),
                shape: BoxShape.circle,
              ),
              child: Icon(
                locked ? Icons.lock_outline_rounded : icon,
                color: accent,
                size: 36,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              name,
              textAlign: TextAlign.center,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (earnedAt != null) ...[
              const SizedBox(height: Spacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withAlpha(31),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.tertiary,
                      size: 16,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      'Earned ${_formatDate(earnedAt!)}',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: AppColors.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Earned 3 days ago" / "Earned Jun 1" — short, friendly.
String _relativeEarned(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return 'Earned';
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inDays < 1) return 'Earned today';
  if (diff.inDays == 1) return 'Earned yesterday';
  if (diff.inDays < 7) return 'Earned ${diff.inDays}d ago';
  return 'Earned ${_formatDate(iso)}';
}

String _formatDate(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return 'recently';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}';
}
