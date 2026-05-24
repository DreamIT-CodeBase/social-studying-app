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

  GamificationKey get _key =>
      (workspaceId: workspaceId, userId: userId);

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
                  onRetry: () =>
                      ref.invalidate(badgesSummaryProvider(_key)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgesBody extends StatelessWidget {
  const _BadgesBody({required this.summary});

  final BadgesSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.totalCount == 0) {
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

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _ProgressHeader(summary: summary),
        const SizedBox(height: Spacing.xl),
        if (summary.hasEarned) ...[
          const _SectionHeader(title: 'Earned'),
          const SizedBox(height: Spacing.md),
          _BadgeGrid(
            children: [
              for (final badge in summary.earned)
                _EarnedBadgeTile(badge: badge),
            ],
          ),
          const SizedBox(height: Spacing.xl),
        ],
        if (summary.available.isNotEmpty) ...[
          const _SectionHeader(title: 'Up next'),
          const SizedBox(height: Spacing.md),
          _BadgeGrid(
            children: [
              for (final badge in summary.available)
                _LockedBadgeTile(badge: badge),
            ],
          ),
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
    final accent = locked
        ? context.colorScheme.onSurfaceVariant
        : AppColors.secondary;
    return Material(
      color: locked
          ? context.colorScheme.surfaceContainerHighest
          : context.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: locked
                  ? context.colorScheme.outlineVariant
                  : accent.withAlpha(102),
              width: 1.5,
            ),
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
                  color: accent.withAlpha(locked ? 31 : 51),
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
                  fontWeight: FontWeight.w700,
                  color: locked
                      ? context.colorScheme.onSurfaceVariant
                      : context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
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
    final accent = locked
        ? context.colorScheme.onSurfaceVariant
        : AppColors.secondary;
    return Padding(
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}';
}
