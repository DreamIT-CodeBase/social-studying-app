import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_screen.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_screen.dart';
import 'package:social_study_app/features/questions/presentation/question_screen.dart';
import 'package:social_study_app/shared/models/progress.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/core/routing/router.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
import 'package:social_study_app/features/admin/workspaces/data/workspaces_repository.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/features/mascot/models/mascot_state.dart';
import 'package:social_study_app/features/mascot/widgets/study_buddy.dart';


final studentHomeTabProvider = StateProvider<int>((ref) => 0);
final collaborativeHomeTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.quiz_rounded, label: 'Study'),
    (icon: Icons.style_rounded, label: 'Flashcards'),
    (icon: Icons.insights_rounded, label: 'Progress'),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingInviteCodeProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        _showRedeemDialog(context, next);
      }
    });

    final authValue = ref.watch(authNotifierProvider).valueOrNull;
    final displayName = authValue?.maybeWhen(
          authenticated: (user) => user.displayName,
          orElse: () => 'Student',
        ) ??
        'Student';
    final user = authValue?.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );
    final memberships = user?.workspaceMemberships ?? [];
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final userId = authValue?.maybeWhen(
      authenticated: (user) => user.id,
      orElse: () => null,
    );

    final selectedIndex = ref.watch(studentHomeTabProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabs[selectedIndex].label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (memberships.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: _StudentWorkspaceSwitcherButton(
                memberships: memberships,
                selectedId: workspaceId,
                onSelect: (id) =>
                    ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(id),
                onCreateWorkspace: () => _showCreateWorkspaceDialog(context),
                onCreateCollaborativeWorkspace: () => _showCreateCollaborativeWorkspaceDialog(context),
                onJoinWorkspace: () => _showJoinWorkspaceDialog(context),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: Spacing.lg),
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.profile),
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
        index: selectedIndex,
        children: [
          _HomeTab(
            displayName: displayName,
            workspaceId: workspaceId,
            userId: userId,
            onStartStudy: () => ref.read(studentHomeTabProvider.notifier).state = 1,
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
            onManageStudy: workspaceId == null
                ? null
                : () => context.push(
                      '/student/documents/$workspaceId',
                    ),
          ),
          _StudyTab(workspaceId: workspaceId),
          _FlashcardsTab(workspaceId: workspaceId),
          _ProgressTab(workspaceId: workspaceId),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            ref.read(studentHomeTabProvider.notifier).state = index,
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

  void _showRedeemDialog(BuildContext context, String code) {
    // Clear the pending code immediately so we don't prompt multiple times
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingInviteCodeProvider.notifier).clear();
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: Spacing.md),
              const Text(
                'Join Workspace',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have a pending invite to join a workspace.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: Spacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.md,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'Would you like to redeem this code and join now?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: Spacing.xs),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  _showLoadingIndicator(context);
                  final isCollaborative = code.length == 6;
                  if (isCollaborative) {
                    final repo = ref.read(workspacesRepositoryProvider);
                    final ws = await repo.joinCollaborative(joinCode: code);
                    await ref.read(authNotifierProvider.notifier).refresh();
                    ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(ws.id);
                  } else {
                    await ref.read(authNotifierProvider.notifier).redeemInviteCode(code);
                    // Select the new workspace
                    final authValue = ref.read(authNotifierProvider).valueOrNull;
                    final user = authValue?.maybeWhen(authenticated: (u) => u, orElse: () => null);
                    if (user != null && user.workspaceMemberships.isNotEmpty) {
                      final joinedWorkspaceId = user.workspaceMemberships.last.workspaceId;
                      ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(joinedWorkspaceId);
                    }
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Dismiss loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Successfully joined the workspace!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Dismiss loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to join workspace: ${e.toString().replaceAll('Exception: ', '')}',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Join Workspace'),
            ),
          ],
        );
      },
    );
  }

  void _showLoadingIndicator(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  void _showCreateWorkspaceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateWorkspaceDialog(),
    );
  }

  void _showCreateCollaborativeWorkspaceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateCollaborativeWorkspaceDialog(),
    );
  }

  void _showJoinWorkspaceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _StudentJoinWorkspaceDialog(),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({
    required this.displayName,
    required this.workspaceId,
    required this.userId,
    required this.onStartStudy,
    required this.onStartRevision,
    required this.onOpenBadges,
    required this.onOpenLeaderboard,
    required this.onManageStudy,
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
  final VoidCallback? onManageStudy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWorkspace = ref.watch(activeStudentWorkspaceProvider);
    final isCollaborative = activeWorkspace?.type == 'collaborative';
    final progressAsync = workspaceId != null
        ? ref.watch(studentProgressNotifierProvider(workspaceId!))
        : const AsyncValue.loading();
    final isAdmin = ref.watch(isActiveWorkspaceAdminProvider);

    if (isCollaborative && workspaceId != null) {
      final selectedSubTab = ref.watch(collaborativeHomeTabProvider);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: _GreetingCard(displayName: displayName),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Row(
              children: [
                _SubTabChip(
                  label: 'Study Center',
                  icon: Icons.school_rounded,
                  selected: selectedSubTab == 0,
                  onSelected: () => ref.read(collaborativeHomeTabProvider.notifier).state = 0,
                ),
                const SizedBox(width: Spacing.xs),
                _SubTabChip(
                  label: 'Discussion',
                  icon: Icons.chat_bubble_rounded,
                  selected: selectedSubTab == 1,
                  onSelected: () => ref.read(collaborativeHomeTabProvider.notifier).state = 1,
                ),
                const SizedBox(width: Spacing.xs),
                _SubTabChip(
                  label: 'Activity Logs',
                  icon: Icons.history_rounded,
                  selected: selectedSubTab == 2,
                  onSelected: () => ref.read(collaborativeHomeTabProvider.notifier).state = 2,
                ),
                const SizedBox(width: Spacing.xs),
                _SubTabChip(
                  label: 'Members',
                  icon: Icons.people_rounded,
                  selected: selectedSubTab == 3,
                  onSelected: () => ref.read(collaborativeHomeTabProvider.notifier).state = 3,
                ),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: selectedSubTab,
              children: [
                // Sub-tab 0: Study Center (shows Streak, study button, etc.)
                RefreshIndicator(
                  onRefresh: () async {
                    ref.read(authNotifierProvider.notifier).refresh();
                    await ref.read(authNotifierProvider.future);
                    ref.read(studentProgressNotifierProvider(workspaceId!).notifier).refresh();
                    await ref.read(studentProgressNotifierProvider(workspaceId!).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                    children: [
                      _StreakCard(workspaceId: workspaceId, userId: userId),
                      const SizedBox(height: Spacing.lg),
                      _QuickStudyButton(onPressed: onStartStudy),
                      const SizedBox(height: Spacing.md),
                      _RevisionButton(onPressed: onStartRevision),
                      // Check collaborative role to show upload button
                      Consumer(
                        builder: (context, ref, child) {
                          final roleAsync = ref.watch(currentCollaborativeRoleProvider(workspaceId!));
                          final role = roleAsync.valueOrNull;
                          final canUpload = role == 'owner' || role == 'editor';
                          if (canUpload && onManageStudy != null) {
                            return Column(
                              children: [
                                const SizedBox(height: Spacing.md),
                                _ManageStudyMaterialsButton(onPressed: onManageStudy!),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: Spacing.lg),
                      _GamificationShortcuts(
                        onOpenBadges: onOpenBadges,
                        onOpenLeaderboard: onOpenLeaderboard,
                      ),
                      const SizedBox(height: Spacing.xl),
                    ],
                  ),
                ),
                // Sub-tab 1: Discussion
                _CollaborativeChatWidget(workspaceId: workspaceId!),
                // Sub-tab 2: Activity Logs
                _CollaborativeActivityWidget(workspaceId: workspaceId!),
                // Sub-tab 3: Members List
                _CollaborativeMembersWidget(
                  workspaceId: workspaceId!,
                  ownerId: activeWorkspace!.ownerId,
                ),

              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(authNotifierProvider.notifier).refresh();
        await ref.read(authNotifierProvider.future);
        if (workspaceId != null) {
          ref.read(studentProgressNotifierProvider(workspaceId!).notifier).refresh();
          await ref.read(studentProgressNotifierProvider(workspaceId!).future);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          _GreetingCard(displayName: displayName),
          if (workspaceId == null) ...[
            const SizedBox(height: Spacing.lg),
            const _RedeemInviteCard(),
          ],
          const SizedBox(height: Spacing.lg),
          _StreakCard(workspaceId: workspaceId, userId: userId),
          const SizedBox(height: Spacing.lg),
          _QuickStudyButton(onPressed: onStartStudy),
          const SizedBox(height: Spacing.md),
          _RevisionButton(onPressed: onStartRevision),
          if (isAdmin && onManageStudy != null) ...[
            const SizedBox(height: Spacing.md),
            _ManageStudyMaterialsButton(onPressed: onManageStudy!),
          ],
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
          workspaceId == null
              ? const EmptyStateView(
                  icon: Icons.history_rounded,
                  title: 'No activity yet',
                  subtitle: 'Join a workspace to see your progress here.',
                )
              : progressAsync.when(
                  data: (progress) {
                    if (progress.recentActivity.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.history_rounded,
                        title: 'No activity yet',
                        subtitle: 'Start a study session to see your progress here.',
                      );
                    }
                    return Column(
                      children: [
                        for (final entry in progress.recentActivity.take(20))
                          _ActivityEntryCard(entry: entry),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(Spacing.xl),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, stack) => Center(
                    child: Text('Failed to load activity: $err'),
                  ),
                ),
        ],
      ),
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
          const StudyBuddy(
            state: MascotState.idle,
            size: 70,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // On narrow cards (< 160px) reduce padding & icon size.
            final narrow = constraints.maxWidth < 160;
            final iconSize = narrow ? 18.0 : 22.0;
            final pad = narrow ? Spacing.md : Spacing.lg;
            final gap = narrow ? Spacing.sm : Spacing.md;
            return Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                border: Border.all(color: context.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: disabled
                        ? context.colorScheme.onSurfaceVariant
                        : AppColors.primary,
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: narrow ? 12 : 14,
                        color: disabled
                            ? context.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: iconSize,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            );
          },
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

class _ActivityEntryCard extends StatelessWidget {
  const _ActivityEntryCard({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final isQuestion = entry.kind == ActivityKind.question;
    final icon = isQuestion ? Icons.quiz_rounded : Icons.style_rounded;
    final iconColor = isQuestion ? AppColors.primary : AppColors.secondary;

    String subtitle = '';
    if (isQuestion && entry.isCorrect != null) {
      subtitle = entry.isCorrect! ? 'Correct (+${entry.xpEarned} XP)' : 'Incorrect';
    } else if (!isQuestion) {
      subtitle = 'Reviewed (+${entry.xpEarned} XP)';
    }

    // Format date simple "yyyy-MM-dd"
    final date = DateTime.tryParse(entry.occurredAt)?.toLocal() ?? DateTime.now();
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          foregroundColor: iconColor,
          child: Icon(icon, size: 20),
        ),
        title: Text(
          entry.topic,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: Text(
          dateString,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RedeemInviteCard extends ConsumerStatefulWidget {
  const _RedeemInviteCard();

  @override
  ConsumerState<_RedeemInviteCard> createState() => _RedeemInviteCardState();
}

class _RedeemInviteCardState extends ConsumerState<_RedeemInviteCard>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late final AnimationController _animController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter an invite code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isCollaborative = code.length == 6;
      if (isCollaborative) {
        final repo = ref.read(workspacesRepositoryProvider);
        final ws = await repo.joinCollaborative(joinCode: code);
        await ref.read(authNotifierProvider.notifier).refresh();
        ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(ws.id);
      } else {
        await ref.read(authNotifierProvider.notifier).redeemInviteCode(code);
        // Select the new workspace
        final authValue = ref.read(authNotifierProvider).valueOrNull;
        final user = authValue?.maybeWhen(authenticated: (u) => u, orElse: () => null);
        if (user != null && user.workspaceMemberships.isNotEmpty) {
          final joinedWorkspaceId = user.workspaceMemberships.last.workspaceId;
          ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(joinedWorkspaceId);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the workspace!'),
            backgroundColor: Colors.green,
          ),
        );
        _controller.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF334155),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Join a Workspace',
                        style: context.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Enter an invite code from your teacher or parent',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'e.g. WS-123456',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white60),
                filled: true,
                fillColor: const Color(0xFF0F172A).withOpacity(0.8),
                errorText: _errorMessage,
                errorStyle: const TextStyle(color: Colors.redAccent),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.md,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF475569)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: Spacing.lg),
            GestureDetector(
              onTapDown: (_) => _animController.reverse(),
              onTapUp: (_) {
                _animController.forward();
                if (!_isLoading) _redeem();
              },
              onTapCancel: () => _animController.forward(),
              child: ScaleTransition(
                scale: _animController,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primary,
                        Color(0xFF818CF8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Redeem Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: Spacing.xs),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentWorkspaceSwitcherButton extends StatelessWidget {
  const _StudentWorkspaceSwitcherButton({
    required this.memberships,
    required this.selectedId,
    required this.onSelect,
    required this.onCreateWorkspace,
    required this.onCreateCollaborativeWorkspace,
    required this.onJoinWorkspace,
  });

  final List<WorkspaceMembership> memberships;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onCreateCollaborativeWorkspace;
  final VoidCallback onJoinWorkspace;

  @override
  Widget build(BuildContext context) {
    final selected = memberships.where((m) => m.workspaceId == selectedId).firstOrNull;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: context.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => _showSwitcher(context),
      icon: const Icon(Icons.workspaces_rounded, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected?.workspaceName ?? 'Switch Workspace',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down_rounded, size: 18),
        ],
      ),
    );
  }

  void _showSwitcher(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _StudentWorkspaceSwitcherSheet(
        memberships: memberships,
        selectedId: selectedId,
        onSelect: (id) {
          Navigator.of(context).pop();
          onSelect(id);
        },
        onCreateWorkspace: () {
          Navigator.of(context).pop();
          onCreateWorkspace();
        },
        onCreateCollaborativeWorkspace: () {
          Navigator.of(context).pop();
          onCreateCollaborativeWorkspace();
        },
        onJoinWorkspace: () {
          Navigator.of(context).pop();
          onJoinWorkspace();
        },
      ),
    );
  }
}

class _StudentWorkspaceSwitcherSheet extends StatelessWidget {
  const _StudentWorkspaceSwitcherSheet({
    required this.memberships,
    required this.selectedId,
    required this.onSelect,
    required this.onCreateWorkspace,
    required this.onCreateCollaborativeWorkspace,
    required this.onJoinWorkspace,
  });

  final List<WorkspaceMembership> memberships;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onCreateCollaborativeWorkspace;
  final VoidCallback onJoinWorkspace;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl, 0, Spacing.xl, Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.layers_outlined,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Switch Workspace',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: context.screenHeight * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: memberships.length,
              itemBuilder: (context, index) {
                final m = memberships[index];
                final isSelected = m.workspaceId == selectedId;
                final isPersonal = m.role == UserRole.workspaceAdmin || m.role == UserRole.tenantAdmin;
                
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xl,
                    vertical: Spacing.xs,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                context.colorScheme.surfaceContainerHighest,
                                context.colorScheme.surfaceContainer,
                              ],
                            ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPersonal ? Icons.person_rounded : Icons.groups_rounded,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    m.workspaceName ?? 'Study Workspace',
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? context.colorScheme.primary : null,
                    ),
                  ),
                  subtitle: Text(
                    isPersonal ? 'Personal Workspace' : 'Classroom',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.colorScheme.primary,
                        )
                      : null,
                  onTap: () => onSelect(m.workspaceId),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              children: [
                InkWell(
                  onTap: onCreateWorkspace,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: context.colorScheme.primary.withOpacity(0.5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Text(
                            'Create Personal Workspace',
                            style: context.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                InkWell(
                  onTap: onCreateCollaborativeWorkspace,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.5),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          color: Color(0xFF6366F1),
                        ),
                        SizedBox(width: Spacing.md),
                        Expanded(
                          child: Text(
                            'Create Collaborative Workspace',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF6366F1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                InkWell(
                  onTap: onJoinWorkspace,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: context.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Text(
                            'Join Workspace (via Code)',
                            style: context.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageStudyMaterialsButton extends StatelessWidget {
  const _ManageStudyMaterialsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.my_library_books_rounded, size: 22),
        label: const Text('Manage Study Materials'),
      ),
    );
  }
}

class _CreateWorkspaceDialog extends ConsumerStatefulWidget {
  const _CreateWorkspaceDialog();

  @override
  ConsumerState<_CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends ConsumerState<_CreateWorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(workspacesRepositoryProvider);
      final newWorkspace = await repo.create(name: _nameController.text.trim());
      
      // Refresh user memberships
      await ref.read(authNotifierProvider.notifier).refresh();
      
      // Switch active workspace to new workspace ID
      ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(newWorkspace.id);
      
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Personal workspace "${newWorkspace.name}" created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_business_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: Spacing.md),
          const Text(
            'New Workspace',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a personal study workspace to upload your own documents and study on them.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: Spacing.lg),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Workspace Name',
                hintText: 'e.g. My History Prep',
                errorText: _errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.school_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: Spacing.xs),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _StudentJoinWorkspaceDialog extends ConsumerStatefulWidget {
  const _StudentJoinWorkspaceDialog({this.initialCode = ''});

  final String initialCode;

  @override
  ConsumerState<_StudentJoinWorkspaceDialog> createState() => _StudentJoinWorkspaceDialogState();
}

class _StudentJoinWorkspaceDialogState extends ConsumerState<_StudentJoinWorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _codeController = TextEditingController(text: widget.initialCode);
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final code = _codeController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isCollaborative = code.length == 6;
      if (isCollaborative) {
        final repo = ref.read(workspacesRepositoryProvider);
        final ws = await repo.joinCollaborative(joinCode: code);
        await ref.read(authNotifierProvider.notifier).refresh();
        ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(ws.id);
      } else {
        await ref.read(authNotifierProvider.notifier).redeemInviteCode(code);
        // Select the new workspace
        final authValue = ref.read(authNotifierProvider).valueOrNull;
        final user = authValue?.maybeWhen(authenticated: (u) => u, orElse: () => null);
        if (user != null && user.workspaceMemberships.isNotEmpty) {
          final joinedWorkspaceId = user.workspaceMemberships.last.workspaceId;
          ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(joinedWorkspaceId);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the workspace!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.vpn_key_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: Spacing.md),
          const Text(
            'Join Workspace',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter an invite code provided by your teacher or parent to join their classroom workspace.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: Spacing.lg),
            TextFormField(
              controller: _codeController,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Invite Code',
                hintText: 'e.g. WS-123456',
                errorText: _errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter an invite code';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: Spacing.xs),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}

class _SubTabChip extends StatelessWidget {
  const _SubTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: selected
            ? context.colorScheme.onPrimary
            : context.colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: context.colorScheme.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected
            ? context.colorScheme.onPrimary
            : context.colorScheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      side: selected ? BorderSide.none : BorderSide(color: context.colorScheme.outlineVariant),
    );
  }
}

class _CollaborativeChatWidget extends ConsumerStatefulWidget {
  const _CollaborativeChatWidget({required this.workspaceId});
  final String workspaceId;

  @override
  ConsumerState<_CollaborativeChatWidget> createState() => _CollaborativeChatWidgetState();
}

class _CollaborativeChatWidgetState extends ConsumerState<_CollaborativeChatWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    setState(() => _isSending = true);
    try {
      await ref.read(workspaceMessagesProvider(widget.workspaceId).notifier).sendMessage(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(workspaceMessagesProvider(widget.workspaceId));
    final roleAsync = ref.watch(currentCollaborativeRoleProvider(widget.workspaceId));
    final role = roleAsync.valueOrNull;
    final canPost = role == 'owner' || role == 'editor';

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No messages yet',
                  subtitle: 'Start the conversation by posting a message below.',
                  useMascot: true,
                );
              }

              // Scroll to bottom after frame is built if needed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              final currentUserId = ref.watch(authNotifierProvider).valueOrNull?.maybeWhen(
                    authenticated: (u) => u.id,
                    orElse: () => null,
                  );

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(Spacing.md),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg['sender_id'] == currentUserId;
                  final timeStr = msg['created_at'] != null
                      ? DateTime.tryParse(msg['created_at'].toString())
                              ?.toLocal()
                              .toString()
                              .substring(11, 16) ??
                          ''
                      : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment:
                            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                              child: Text(
                                msg['sender_name'] ?? 'Unknown',
                                style: context.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: context.screenWidth * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? context.colorScheme.primary
                                  : context.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  msg['content'] ?? '',
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: isMe
                                        ? context.colorScheme.onPrimary
                                        : context.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeStr,
                                  style: context.textTheme.bodySmall?.copyWith(
                                    fontSize: 9,
                                    color: isMe
                                        ? context.colorScheme.onPrimary.withOpacity(0.7)
                                        : context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading messages: $err')),
          ),
        ),
        if (canPost)
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              border: Border(
                top: BorderSide(color: context.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Message workspace...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: context.colorScheme.surfaceContainer,
                    ),
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                IconButton.filled(
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            width: double.infinity,
            color: context.colorScheme.surfaceContainerLow,
            child: Text(
              'You have view-only access to this Discussion Board.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _CollaborativeActivityWidget extends ConsumerWidget {
  const _CollaborativeActivityWidget({required this.workspaceId});
  final String workspaceId;

  IconData _iconForType(String? type) {
    switch (type) {
      case 'member_joined':
        return Icons.person_add_rounded;
      case 'member_left':
        return Icons.person_remove_rounded;
      case 'role_changed':
        return Icons.manage_accounts_rounded;
      case 'document_uploaded':
        return Icons.description_rounded;
      case 'flashcards_generated':
        return Icons.style_rounded;
      case 'questions_generated':
        return Icons.quiz_rounded;
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorForType(BuildContext context, String? type) {
    switch (type) {
      case 'member_joined':
        return Colors.green;
      case 'member_left':
        return Colors.red;
      case 'role_changed':
        return Colors.orange;
      case 'document_uploaded':
        return AppColors.primary;
      case 'flashcards_generated':
        return Colors.purple;
      case 'questions_generated':
        return Colors.teal;
      default:
        return context.colorScheme.secondary;
    }
  }

  String _descriptionForActivity(Map<String, dynamic> act) {
    final type = act['activity_type'] as String?;
    final userName = act['user_name'] as String? ?? 'Someone';
    final details = act['details'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'member_joined':
        return '$userName joined the workspace';
      case 'member_left':
        return '$userName left the workspace';
      case 'role_changed':
        return '$userName role changed to ${details['new_role']}';
      case 'document_uploaded':
        return '$userName uploaded "${details['document_name'] ?? 'document'}"';
      case 'flashcards_generated':
        return '$userName generated flashcards';
      case 'questions_generated':
        return '$userName generated study questions';
      case 'chat_message':
        return '$userName posted a message';
      default:
        return 'Activity logged by $userName';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(workspaceActivityProvider(workspaceId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(workspaceActivityProvider(workspaceId));
      },
      child: activityAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const EmptyStateView(
              icon: Icons.history_rounded,
              title: 'No activity logs',
              subtitle: 'Actions taken in this workspace will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Spacing.md),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final act = logs[index];
              final date = act['created_at'] != null
                  ? DateTime.tryParse(act['created_at'].toString())?.toLocal()
                  : null;
              final dateStr = date != null
                  ? '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                  : '';

              return Card(
                margin: const EdgeInsets.only(bottom: Spacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _colorForType(context, act['activity_type'] as String?).withOpacity(0.1),
                    foregroundColor: _colorForType(context, act['activity_type'] as String?),
                    child: Icon(_iconForType(act['activity_type'] as String?), size: 20),
                  ),
                  title: Text(
                    _descriptionForActivity(act),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  trailing: Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading activity: $err')),
      ),
    );
  }
}

class _CollaborativeMembersWidget extends ConsumerStatefulWidget {
  const _CollaborativeMembersWidget({required this.workspaceId, required this.ownerId});
  final String workspaceId;
  final String? ownerId;

  @override
  ConsumerState<_CollaborativeMembersWidget> createState() => _CollaborativeMembersWidgetState();
}

class _CollaborativeMembersWidgetState extends ConsumerState<_CollaborativeMembersWidget> {
  bool _isGeneratingInvite = false;
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  String _selectedInviteRole = 'editor';

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    if (email.isEmpty && username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email or username')),
      );
      return;
    }

    setState(() => _isGeneratingInvite = true);
    try {
      await ref.read(workspacesRepositoryProvider).inviteToCollaborative(
            widget.workspaceId,
            email: email.isNotEmpty ? email : null,
            username: username.isNotEmpty ? username : null,
            role: _selectedInviteRole,
          );
      _emailController.clear();
      _usernameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingInvite = false);
      }
    }
  }

  Future<void> _leave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Workspace'),
        content: const Text('Are you sure you want to leave this workspace? You will need an invite code to join again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(workspacesRepositoryProvider).leaveCollaborative(widget.workspaceId);
      await ref.read(authNotifierProvider.notifier).refresh();
      ref.read(activeWorkspaceIdProvider.notifier).build(); // reset
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the workspace.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave workspace: $e'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(workspaceMembersListProvider(widget.workspaceId));
    final activeWorkspace = ref.watch(activeStudentWorkspaceProvider);
    final joinCode = activeWorkspace?.joinCode ?? '';
    final roleAsync = ref.watch(currentCollaborativeRoleProvider(widget.workspaceId));
    final myRole = roleAsync.valueOrNull;
    final isOwner = myRole == 'owner';
    final isEditorOrOwner = myRole == 'owner' || myRole == 'editor';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(workspaceMembersListProvider(widget.workspaceId));
      },
      child: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          if (joinCode.isNotEmpty) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.share_rounded, color: context.colorScheme.primary),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          'Invite Collaborators',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Share this 6-character code with other students so they can join and study with you.',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg,
                        vertical: Spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            joinCode,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: 1.5,
                              color: context.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: joinCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Join code copied to clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
          if (isEditorOrOwner) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mail_outline_rounded, color: context.colorScheme.primary),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          'Send Direct Invite',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address (optional)',
                        hintText: 'student@example.com',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username (optional)',
                        hintText: 'john_doe',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    DropdownButtonFormField<String>(
                      value: _selectedInviteRole,
                      decoration: const InputDecoration(labelText: 'Invite Role'),
                      items: const [
                        DropdownMenuItem(value: 'editor', child: Text('Editor (Can upload/generate)')),
                        DropdownMenuItem(value: 'viewer', child: Text('Viewer (View only)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedInviteRole = val);
                        }
                      },
                    ),
                    const SizedBox(height: Spacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isGeneratingInvite ? null : _invite,
                        icon: _isGeneratingInvite
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Send Invitation'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
          Text(
            'Workspace Members',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          membersAsync.when(
            data: (members) {
              return Column(
                children: [
                  for (final m in members)
                    Card(
                      margin: const EdgeInsets.only(bottom: Spacing.xs),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            m['display_name'] != null && m['display_name'].toString().isNotEmpty
                                ? m['display_name'].toString()[0].toUpperCase()
                                : 'U',
                          ),
                        ),
                        title: Text(
                          m['display_name'] ?? 'Unknown Member',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${m['email'] ?? ''} • ${m['role'].toString().toUpperCase()}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isOwner && m['role'] != 'owner'
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (role) async {
                                  try {
                                    await ref
                                        .read(workspaceMembersListProvider(widget.workspaceId).notifier)
                                        .changeRole(m['user_id'], role);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Member role updated to $role.'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to change role: $e'),
                                          backgroundColor: context.colorScheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'editor',
                                    child: Text('Make Editor'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'viewer',
                                    child: Text('Make Viewer'),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Failed to load members: $err')),
          ),
          const SizedBox(height: Spacing.lg),
          if (!isOwner)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: _leave,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Leave Workspace'),
            ),
        ],
      ),
    );
  }
}

class _CreateCollaborativeWorkspaceDialog extends ConsumerStatefulWidget {
  const _CreateCollaborativeWorkspaceDialog();

  @override
  ConsumerState<_CreateCollaborativeWorkspaceDialog> createState() =>
      _CreateCollaborativeWorkspaceDialogState();
}

class _CreateCollaborativeWorkspaceDialogState
    extends ConsumerState<_CreateCollaborativeWorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(workspacesRepositoryProvider);
      final newWorkspace =
          await repo.createCollaborative(name: _nameController.text.trim());

      // Refresh user memberships
      await ref.read(authNotifierProvider.notifier).refresh();

      // Switch active workspace to new workspace ID
      ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(newWorkspace.id);

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Collaborative workspace "${newWorkspace.name}" created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: Spacing.md),
          const Text(
            'Collaborative Space',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a collaborative space where multiple students can upload documents, chat, and study together.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: Spacing.lg),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Workspace Name',
                hintText: 'e.g. Study Group Biology',
                errorText: _errorMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.people_outline_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: Spacing.xs),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

