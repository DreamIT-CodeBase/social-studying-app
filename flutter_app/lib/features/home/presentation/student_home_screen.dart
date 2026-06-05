import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_screen.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_screen.dart';
import 'package:social_study_app/features/questions/presentation/question_screen.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  int _selectedIndex = 0;

  void _showProfileMenu(BuildContext context, WidgetRef ref, String name) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Spacing.md),
            Text(
              name,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.md),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                ref.read(authNotifierProvider.notifier).signOut();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Account?'),
                    content: const Text(
                      'This will permanently deactivate your account. '
                      'This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  if (context.mounted) Navigator.pop(context);
                  ref.read(authNotifierProvider.notifier).deleteAccount();
                }
              },
            ),
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.quiz_rounded, label: 'Study'),
    (icon: Icons.style_rounded, label: 'Flashcards'),
    (icon: Icons.insights_rounded, label: 'Progress'),
  ];

  @override
  Widget build(BuildContext context) {
    final authValue = ref.watch(authNotifierProvider).valueOrNull;
    final displayName = authValue?.maybeWhen(
          authenticated: (user) => user.displayName,
          orElse: () => 'Student',
        ) ??
        'Student';
    final workspaceId = authValue?.maybeWhen(
      authenticated: (user) => user.workspaceMemberships.isNotEmpty
          ? user.workspaceMemberships.first.workspaceId
          : null,
      orElse: () => null,
    );
    final userId = authValue?.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabs[_selectedIndex].label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Spacing.lg),
            child: GestureDetector(
              onTap: () => _showProfileMenu(context, ref, displayName),
              child: CircleAvatar(
                backgroundColor: AppColors.primaryContainer,
                radius: 18,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(
            displayName: displayName,
            workspaceId: workspaceId,
            userId: userId,
            onStartStudy: () => setState(() => _selectedIndex = 1),
            onStartRevision: workspaceId == null
                ? null
                : () => context.push(
                      '${AppRoutes.studentRevision}/$workspaceId',
                    ),
            onOpenBadges: (workspaceId == null || userId == null)
                ? null
                : () => context.push(
                      '/student/badges/$workspaceId/$userId',
                    ),
            onOpenLeaderboard: workspaceId == null
                ? null
                : () => context.push(
                      '/student/leaderboard/$workspaceId',
                    ),
          ),
          _StudyTab(workspaceId: workspaceId),
          _FlashcardsTab(workspaceId: workspaceId),
          _ProgressTab(workspaceId: workspaceId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: _tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.displayName,
    required this.workspaceId,
    required this.userId,
    required this.onStartStudy,
    required this.onStartRevision,
    required this.onOpenBadges,
    required this.onOpenLeaderboard,
  });

  final String displayName;

  /// `null` when there's no active workspace — gates the streak card
  /// to its zero state and disables every workspace-scoped launcher.
  final String? workspaceId;
  final String? userId;

  final VoidCallback onStartStudy;
  final VoidCallback? onStartRevision;
  final VoidCallback? onOpenBadges;
  final VoidCallback? onOpenLeaderboard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _GreetingCard(displayName: displayName),
        const SizedBox(height: Spacing.lg),
        _StreakCard(workspaceId: workspaceId, userId: userId),
        const SizedBox(height: Spacing.lg),
        _QuickStudyButton(onPressed: onStartStudy),
        const SizedBox(height: Spacing.md),
        _RevisionButton(onPressed: onStartRevision),
        const SizedBox(height: Spacing.lg),
        _GamificationShortcuts(
          onOpenBadges: onOpenBadges,
          onOpenLeaderboard: onOpenLeaderboard,
        ),
        const SizedBox(height: Spacing.xl),
        Text(
          'Recent Activity',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.md),
        const EmptyStateView(
          icon: Icons.history_rounded,
          title: 'No activity yet',
          subtitle: 'Start a study session to see your progress here.',
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.displayName});

  final String displayName;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withAlpha(179),
                  ),
                ),
                Text(
                  displayName,
                  style: context.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  "Ready to study?",
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.auto_stories_rounded,
            size: 56,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Streak + XP card. Reads the gamification streak summary (cheap)
/// for the headline number, and falls back to a static zero state
/// when there's no workspace yet OR while the streak is loading.
///
/// The XP chip on the right reads the full profile — a slightly
/// heavier call but the home page already pays the round-trip and
/// the cached provider value is shared with the dedicated profile
/// view if that's opened next.
class _StreakCard extends ConsumerWidget {
  const _StreakCard({required this.workspaceId, required this.userId});

  final String? workspaceId;
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workspaceId == null || userId == null) {
      return _zeroStateCard(
        context,
        title: '0-day streak',
        subtitle: 'Join a workspace to start your streak!',
        xpChip: '0 XP',
      );
    }
    final key = (workspaceId: workspaceId!, userId: userId!);
    final streakAsync = ref.watch(streakSummaryProvider(key));
    final profileAsync = ref.watch(gamificationProfileProvider(key));

    final streak = streakAsync.valueOrNull;
    final xpTotal = profileAsync.valueOrNull?.xpTotal ?? 0;
    final days = streak?.streakDays ?? 0;
    final activeToday = streak?.activeToday ?? false;

    return _streakCard(
      context,
      days: days,
      activeToday: activeToday,
      xpTotal: xpTotal,
    );
  }

  Widget _streakCard(
    BuildContext context, {
    required int days,
    required bool activeToday,
    required int xpTotal,
  }) {
    final title = days == 1 ? '1-day streak' : '$days-day streak';
    final subtitle = days == 0
        ? 'Study today to start your streak!'
        : activeToday
            ? "You've studied today — keep it going!"
            : 'Study today to keep your streak alive.';
    return _zeroStateCard(
      context,
      title: title,
      subtitle: subtitle,
      xpChip: '$xpTotal XP',
      // Pulse the flame on an active streak so the card feels alive.
      animate: activeToday && days > 0,
    );
  }

  Widget _zeroStateCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String xpChip,
    bool animate = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            _FlameIcon(animate: animate),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                xpChip,
                style: context.textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing flame icon. Animation only runs on active streaks so a
/// brand-new student doesn't see a phantom heartbeat.
class _FlameIcon extends StatefulWidget {
  const _FlameIcon({required this.animate});

  final bool animate;

  @override
  State<_FlameIcon> createState() => _FlameIconState();
}

class _FlameIconState extends State<_FlameIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_FlameIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Subtle scale pulse — 1.0 → 1.08, no glow.
        final scale = 1.0 + (_controller.value * 0.08);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.local_fire_department_rounded,
          color: AppColors.secondary,
          size: 28,
        ),
      ),
    );
  }
}

/// Two side-by-side cards that push into the badges grid and the
/// workspace leaderboard. Disabled when there's no workspace yet —
/// nothing to show.
class _GamificationShortcuts extends StatelessWidget {
  const _GamificationShortcuts({
    required this.onOpenBadges,
    required this.onOpenLeaderboard,
  });

  final VoidCallback? onOpenBadges;
  final VoidCallback? onOpenLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutCard(
            icon: Icons.emoji_events_rounded,
            label: 'Badges',
            onTap: onOpenBadges,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _ShortcutCard(
            icon: Icons.leaderboard_rounded,
            label: 'Leaderboard',
            onTap: onOpenLeaderboard,
          ),
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled
          ? context.colorScheme.surfaceContainerHighest
          : context.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: context.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: disabled
                    ? context.colorScheme.onSurfaceVariant
                    : AppColors.primary,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: disabled
                        ? context.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStudyButton extends StatelessWidget {
  const _QuickStudyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.play_arrow_rounded, size: 24),
      label: const Text('Start Study Session'),
    );
  }
}

/// Launches the bounded revision session (Sprint 4.10) — disabled when
/// the student has no workspace yet.
class _RevisionButton extends StatelessWidget {
  const _RevisionButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.shuffle_rounded, size: 22),
      label: const Text('Mixed Revision'),
    );
  }
}

class _StudyTab extends StatelessWidget {
  const _StudyTab({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context) {
    if (workspaceId == null) {
      return const EmptyStateView(
        icon: Icons.workspaces_outline,
        title: 'No workspace yet',
        subtitle: 'Join a workspace with an invite code to start studying.',
      );
    }
    // Sprint 4.7 / 4.8 — the full question-answering loop.
    return QuestionScreen(workspaceId: workspaceId!);
  }
}

class _FlashcardsTab extends StatelessWidget {
  const _FlashcardsTab({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context) {
    if (workspaceId == null) {
      return const EmptyStateView(
        icon: Icons.workspaces_outline,
        title: 'No workspace yet',
        subtitle: 'Join a workspace with an invite code to review flashcards.',
      );
    }
    // Sprint 4.9 — the swipe-and-flip flashcard review loop.
    return FlashcardScreen(workspaceId: workspaceId!);
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context) {
    if (workspaceId == null) {
      return const EmptyStateView(
        icon: Icons.workspaces_outline,
        title: 'No workspace yet',
        subtitle: 'Join a workspace with an invite code to track progress.',
      );
    }
    // Sprint 4.11 — level/XP card, mastery bars, activity timeline.
    return ProgressScreen(workspaceId: workspaceId!);
  }
}
