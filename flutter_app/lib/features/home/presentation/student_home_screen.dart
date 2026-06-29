import 'dart:ui';
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
import 'package:social_study_app/shared/models/workspace.dart';



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
    (icon: Icons.menu_book_rounded, label: 'Study'),
    (icon: Icons.style_rounded, label: 'Flashcards'),
    (icon: Icons.bar_chart_rounded, label: 'Progress'),
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
    final showCustomAppBar = selectedIndex == 0 || selectedIndex == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true, // Let body extend underneath floating bottom nav capsule
      appBar: showCustomAppBar
          ? null
          : AppBar(
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

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceVariantDark : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isSelected = selectedIndex == index;
                return GestureDetector(
                  onTap: () => ref.read(studentHomeTabProvider.notifier).state = index,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          color: isSelected
                              ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
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
                    fontWeight: FontWeight.w700,
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
    
    // Check role for collaborative upload access
    final roleAsync = workspaceId != null
        ? ref.watch(currentCollaborativeRoleProvider(workspaceId!))
        : const AsyncValue<String>.data('viewer');
    final role = roleAsync.valueOrNull;
    final isCollaborativeAdmin = role == 'owner' || role == 'editor';
    final isStandardAdmin = ref.watch(isActiveWorkspaceAdminProvider);
    final canManageStudy = isCollaborative ? isCollaborativeAdmin : isStandardAdmin;

    final authValue = ref.watch(authNotifierProvider).valueOrNull;
    final user = authValue?.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );
    final memberships = user?.workspaceMemberships ?? [];

    // Extract progress parameters safely
    final progressKey = (workspaceId: workspaceId ?? '', userId: userId ?? '');
    final streakAsync = (workspaceId != null && userId != null)
        ? ref.watch(streakSummaryProvider(progressKey))
        : null;
    final profileAsync = (workspaceId != null && userId != null)
        ? ref.watch(gamificationProfileProvider(progressKey))
        : null;

    final streakDays = streakAsync?.valueOrNull?.streakDays ?? 0;
    final totalXp = profileAsync?.valueOrNull?.xpTotal ?? progressAsync.valueOrNull?.totalXp ?? 0;
    final level = progressAsync.valueOrNull?.level ?? profileAsync?.valueOrNull?.level ?? 1;
    final xpIntoLevel = progressAsync.valueOrNull?.xpIntoLevel ?? profileAsync?.valueOrNull?.xpIntoLevel ?? 0;
    final xpForNextLevel = progressAsync.valueOrNull?.xpForNextLevel ?? profileAsync?.valueOrNull?.xpForNextLevel ?? 100;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Local greeting message based on time of day
    final hour = DateTime.now().hour;
    final greetingText = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final screenWidth = MediaQuery.of(context).size.width;

    // The immersive full illustrated hero section
    final heroSection = SizedBox(
      height: 260, // Increased hero section height
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Landscape background image with custom height and alignment to avoid cropping mascot & overlap
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320, // Increased to zoom out (show more of) the cover image
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE0F2FE),
                image: DecorationImage(
                  image: const AssetImage('assets/mascot/headerherosection.png'),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.42, -0.1), // Zoomed-out alignment shows more of the image
                  colorFilter: isDark
                      ? ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.5),
                          BlendMode.srcOver,
                        )
                      : null,
                ),
              ),
            ),
          ),
          
          // Header items (Greeting & Switches)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Left: Greetings — 4 lines like reference
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Line 1: greeting
                        Text(
                          '$greetingText,',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Line 2: name — large bold animated shimmer
                        _AnimatedHeadline(displayName: displayName),
                        const SizedBox(height: 4),
                        // Lines 3-4: subtitle
                        Text(
                          "Let's continue your\nlearning journey!",
                          style: TextStyle(
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Top Right: Switch Profile / User Profile Profile Button (in place of notification button)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (memberships.isNotEmpty)
                        _HeroWorkspaceSwitcher(
                          memberships: memberships,
                          selectedId: workspaceId,
                          onSelect: (id) =>
                              ref.read(activeWorkspaceIdProvider.notifier).setWorkspaceId(id),
                          onCreateWorkspace: () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const _CreateWorkspaceDialog(),
                          ),
                          onCreateCollaborativeWorkspace: () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const _CreateCollaborativeWorkspaceDialog(),
                          ),
                          onJoinWorkspace: () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const _StudentJoinWorkspaceDialog(),
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.push(AppRoutes.profile),
                        child: CircleAvatar(
                          backgroundColor: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.9),
                          radius: 18,
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Floating Player Progress Card - positioned over the bottom-left of the image to not cover the mascot
          Positioned(
            left: 16,
            right: screenWidth > 600 ? null : screenWidth * 0.30, // Increased width (from 0.38 right margin back to 0.30)
            width: screenWidth > 600 ? 320 : null,
            bottom: 5, // Lowered down to reduce gap to study card
            child: _PlayerProgressCard(
              level: level,
              xpIntoLevel: xpIntoLevel,
              xpForNextLevel: xpForNextLevel,
              streakDays: streakDays,
              totalXp: totalXp,
            ),
          ),
        ],
      ),
    );

    // Standard Study Center contents
    Widget buildStudyCenterContent(BuildContext context, Widget hero) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          hero,
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start Study Card
                _StartStudySessionCard(onStartStudy: onStartStudy),
                const SizedBox(height: 10),

                // Small secondary action pills: Manage Study
                if (canManageStudy && onManageStudy != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SmallPillButton(
                          icon: Icons.my_library_books_rounded,
                          label: 'Manage Study',
                          onTap: onManageStudy!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Weekly Progress Graph Card
                _WeeklyProgressCard(
                  userWeeklyXp: totalXp > 0 ? totalXp : 2026,
                  buddyWeeklyXp: totalXp > 0 ? (totalXp * 2).clamp(totalXp + 500, 9999) : 4024,
                ),
                
                const SizedBox(height: 20),
                
                // Quick Actions Row
                _QuickActionsSection(
                  onOpenBadges: onOpenBadges,
                  onOpenLeaderboard: onOpenLeaderboard,
                  onStartStudy: onStartStudy,
                ),
                
                const SizedBox(height: 28),
                
                // Recent Activity Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (workspaceId != null)
                      GestureDetector(
                        onTap: () {
                          // Navigate to progress tab
                          ref.read(studentHomeTabProvider.notifier).state = 3;
                        },
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Activity list loading/data states
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
                          final entries = progress.recentActivity.take(10).toList();
                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE8EDF2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                children: [
                                  for (int i = 0; i < entries.length; i++) ...[
                                    _ActivityEntryItem(entry: entries[i]),
                                    if (i < entries.length - 1)
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: isDark
                                            ? const Color(0xFF2D3748)
                                            : const Color(0xFFE8EDF2),
                                      ),
                                  ],
                                ],
                              ),
                            ),
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
          ),
        ],
      );
    }

    if (isCollaborative && workspaceId != null) {
      final selectedSubTab = ref.watch(collaborativeHomeTabProvider);
      return Column(
        children: [
          heroSection,
          // Sub tabs chips row below hero section
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _SubTabChip(
                    label: 'Study Center',
                    icon: Icons.school_rounded,
                    selected: selectedSubTab == 0,
                    onSelected: () => ref.read(collaborativeHomeTabProvider.notifier).state = 0,
                  ),
                  const SizedBox(width: 8),
                  _SubTabChip(
                    label: 'Discussion',
                    icon: Icons.chat_bubble_rounded,
                    selected: selectedSubTab == 1,
                    onSelected: () => ref.read(collaborativeHomeTabProvider.notifier).state = 1,
                  ),
                  const SizedBox(width: 8),
                  _SubTabChip(
                    label: 'Activity Logs',
                    icon: Icons.history_rounded,
                    selected: selectedSubTab == 2,
                    onSelected: () => ref.read(collaborativeHomeTabProvider.notifier).state = 2,
                  ),
                  const SizedBox(width: 8),
                  _SubTabChip(
                    label: 'Members',
                    icon: Icons.people_rounded,
                    selected: selectedSubTab == 3,
                    onSelected: () => ref.read(collaborativeHomeTabProvider.notifier).state = 3,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: selectedSubTab,
              children: [
                // Study Center list (without duplicating heroSection)
                RefreshIndicator(
                  onRefresh: () async {
                    ref.read(authNotifierProvider.notifier).refresh();
                    await ref.read(authNotifierProvider.future);
                    ref.read(studentProgressNotifierProvider(workspaceId!).notifier).refresh();
                    await ref.read(studentProgressNotifierProvider(workspaceId!).future);
                  },
                  child: buildStudyCenterContent(context, const SizedBox.shrink()),
                ),
                _CollaborativeChatWidget(workspaceId: workspaceId!),
                _CollaborativeActivityWidget(workspaceId: workspaceId!),
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

    // Standard workspace or no workspace
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(authNotifierProvider.notifier).refresh();
        await ref.read(authNotifierProvider.future);
        if (workspaceId != null) {
          ref.read(studentProgressNotifierProvider(workspaceId!).notifier).refresh();
          await ref.read(studentProgressNotifierProvider(workspaceId!).future);
        }
      },
      child: workspaceId == null
          ? ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                heroSection,
                const SizedBox(height: 15),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _RedeemInviteCard(),
                ),
              ],
            )
          : buildStudyCenterContent(context, heroSection),
    );
  }
}

// -----------------------------------------------------------------------------
// ANIMATED HEADLINE
// -----------------------------------------------------------------------------

class _AnimatedHeadline extends StatefulWidget {
  const _AnimatedHeadline({required this.displayName});

  final String displayName;

  @override
  State<_AnimatedHeadline> createState() => _AnimatedHeadlineState();
}

class _AnimatedHeadlineState extends State<_AnimatedHeadline>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    ));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, child) {
            final sweep = _shimmerCtrl.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment(-1.5 + sweep * 3.5, 0),
                        end: Alignment(-0.5 + sweep * 3.5, 0),
                        colors: isDark
                            ? const [
                                Colors.white,
                                Color(0xFFE2E8F0),
                                Colors.white,
                                Color(0xFFCBD5E1),
                                Colors.white,
                              ]
                            : const [
                                Color(0xFF0F172A), // Slate Black
                                Color(0xFF475569), // Slate Grey
                                Color(0xFF0F172A),
                                Color(0xFF334155), // Slate Dark Grey
                                Color(0xFF0F172A),
                              ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcIn,
                    child: child,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '👋',
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.1,
                  ),
                ),
              ],
            );
          },
          child: Text(
            widget.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1.1,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PREMIUM SUPPORT WIDGETS
// -----------------------------------------------------------------------------

class _HeroWorkspaceSwitcher extends ConsumerWidget {
  const _HeroWorkspaceSwitcher({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = memberships.where((m) => m.workspaceId == selectedId).firstOrNull;
    final workspaces = ref.watch(studentWorkspacesProvider).valueOrNull ?? [];
    Workspace? workspace;
    for (final w in workspaces) {
      if (w.id == selectedId) {
        workspace = w;
        break;
      }
    }
    final displayName = workspace?.name ?? selected?.workspaceName ?? 'Switch';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF047857).withOpacity(0.8), // Translucent green matching hill
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showSwitcher(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_rounded, size: 10, color: Colors.white), // Smaller group icon
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 10, color: Colors.white), // Smaller arrow icon
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSwitcher(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StudentWorkspaceSwitcherSheet(
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

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({this.hasUnread = true});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: Colors.grey.shade800,
            size: 20,
          ),
          if (hasUnread)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerProgressCard extends StatelessWidget {
  const _PlayerProgressCard({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.streakDays,
    required this.totalXp,
  });

  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int streakDays;
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fraction = xpForNextLevel > 0
        ? (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Level Shield
          LevelShield(level: level),
          const SizedBox(width: 8),

          // XP Progress Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Level',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                // XP Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5, // Reduced height of progress bar
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(isDark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$xpIntoLevel / $xpForNextLevel XP',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 40,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Streak
          _StatColumn(
            iconWidget: Image.asset(
              'assets/icons/streak.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFF97316),
                size: 24,
              ),
            ),
            value: '$streakDays',
            label: 'Day Streak',
          ),

          // Divider
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFFF1F5F9),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Total XP
          _StatColumn(
            iconWidget: Image.asset(
              'assets/icons/coin.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            value: '$totalXp',
            label: 'Total XP',
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.iconWidget,
    required this.value,
    required this.label,
  });

  final Widget iconWidget;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class LevelShield extends StatelessWidget {
  const LevelShield({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 50,
      child: CustomPaint(
        painter: _ShieldPainter(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Level',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF22C55E), Color(0xFF15803D)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF166534)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.22)
      ..lineTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.22)
      ..lineTo(size.width, size.height * 0.78)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.78)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StartStudySessionCard extends StatelessWidget {
  const _StartStudySessionCard({required this.onStartStudy});

  final VoidCallback onStartStudy;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Star sparkle top-right
          Positioned(
            right: 100,
            top: 12,
            child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: 0.2), size: 14),
          ),
          Positioned(
            right: 60,
            top: 32,
            child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: 0.15), size: 9),
          ),
          // Rocket bottom-right background
          Positioned(
            right: 8,
            bottom: 0,
            child: Transform.rotate(
              angle: -0.25,
              child: Opacity(
                opacity: 0.7,
                child: Image.asset(
                  'assets/icons/icons8-rocket-48.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white54,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
          // Explore chip pinned to top-right corner
          Positioned(
            top: 8,
            right: 12,
            child: GestureDetector(
              onTap: onStartStudy,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Explore',
                      style: TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Play button
                GestureDetector(
                  onTap: onStartStudy,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Start Study Session',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Let's continue your learning journey!",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
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
    );
  }
}

class _WeeklyProgressCard extends ConsumerWidget {
  const _WeeklyProgressCard({
    required this.userWeeklyXp,
    required this.buddyWeeklyXp,
  });

  final int userWeeklyXp;
  final int buddyWeeklyXp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to Progress tab
                  ref.read(studentHomeTabProvider.notifier).state = 3;
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Legend row
          Row(
            children: [
              // You legend
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'You',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$userWeeklyXp XP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E), // GREEN as in reference
                ),
              ),
              const Spacer(),
              // Growth chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      color: Color(0xFF166534),
                      size: 13,
                    ),
                    SizedBox(width: 3),
                    Text(
                      '+15%',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Text(
                      'vs last week',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: _WeeklySplineChart(userWeeklyXp: userWeeklyXp),
          ),
        ],
      ),
    );
  }
}

class _WeeklySplineChart extends StatefulWidget {
  const _WeeklySplineChart({required this.userWeeklyXp});

  final int userWeeklyXp;

  @override
  State<_WeeklySplineChart> createState() => _WeeklySplineChartState();
}

class _WeeklySplineChartState extends State<_WeeklySplineChart>
    with TickerProviderStateMixin {
  late final AnimationController _drawCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _drawAnim;

  @override
  void initState() {
    super.initState();

    _drawCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _drawAnim = CurvedAnimation(
      parent: _drawCtrl,
      curve: Curves.easeInOutCubic,
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _drawCtrl.forward();
    });
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: Listenable.merge([_drawAnim, _pulseCtrl]),
      builder: (context, _) {
        return CustomPaint(
          painter: _SplineChartPainter(
            userWeeklyXp: widget.userWeeklyXp,
            isDark: isDark,
            drawProgress: _drawAnim.value,
            pulseRadius: 5.0 + _pulseCtrl.value * 3.5,
          ),
        );
      },
    );
  }
}

class _SplineChartPainter extends CustomPainter {
  _SplineChartPainter({
    required this.userWeeklyXp,
    required this.isDark,
    this.drawProgress = 1.0,
    this.pulseRadius = 6.0,
  });

  final int userWeeklyXp;
  final bool isDark;
  final double drawProgress;
  final double pulseRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadding = 30.0;
    final bottomPadding = 20.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - bottomPadding;

    final double maxVal = (userWeeklyXp * 1.3).clamp(100.0, 10000.0);
    final yValues = [maxVal, maxVal * 2 / 3, maxVal * 1 / 3, 0.0];
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : Colors.grey.shade100
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < yValues.length; i++) {
      final yLabel = yValues[i].toInt().toString();
      final fraction = i / (yValues.length - 1);
      final y = fraction * chartHeight;

      textPainter.text = TextSpan(
        text: yLabel,
        style: TextStyle(
          color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(0, y - textPainter.height / 2),
      );

      _drawDashedLine(canvas, leftPadding, size.width, y, gridPaint);
    }

    final xCoords = <double>[];
    for (int i = 0; i < 7; i++) {
      final fraction = i / 6;
      final x = leftPadding + fraction * (chartWidth - 10);
      xCoords.add(x);

      textPainter.text = TextSpan(
        text: days[i],
        style: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 14),
      );
    }

    final youXP = [
      0.45 * userWeeklyXp,
      0.7 * userWeeklyXp,
      1.0 * userWeeklyXp,
      0.65 * userWeeklyXp,
      0.8 * userWeeklyXp,
      0.5 * userWeeklyXp,
      0.6 * userWeeklyXp,
    ];

    double getY(double xp) {
      final fraction = xp / maxVal;
      return chartHeight - (fraction * chartHeight);
    }

    final youPoints = <Offset>[];
    for (int i = 0; i < 7; i++) {
      youPoints.add(Offset(xCoords[i], getY(youXP[i])));
    }

    // Draw-on effect: clip to only show the portion drawn so far
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        0, 0,
        leftPadding + chartWidth * drawProgress,
        size.height,
      ),
    );
    _drawSpline(canvas, youPoints, const Color(0xFF2563EB), chartHeight);
    canvas.restore();

    // Animated peak dot — appears when draw-on passes it
    const wedIndex = 2;
    final youWedOffset = youPoints[wedIndex];
    final dotFraction = wedIndex / 6.0;

    if (drawProgress >= dotFraction) {
      // Outer glow ring
      canvas.drawCircle(
        youWedOffset,
        pulseRadius + 3,
        Paint()
          ..color = const Color(0xFF2563EB).withOpacity(0.15)
          ..style = PaintingStyle.fill,
      );
      // Solid dot
      canvas.drawCircle(
        youWedOffset,
        pulseRadius,
        Paint()
          ..color = const Color(0xFF2563EB)
          ..style = PaintingStyle.fill,
      );
      // Inner white dot
      canvas.drawCircle(
        youWedOffset,
        pulseRadius * 0.42,
        Paint()
          ..color = isDark ? const Color(0xFF1E293B) : Colors.white
          ..style = PaintingStyle.fill,
      );

      // Tooltip fades in just after dot appears
      final tooltipOpacity =
          ((drawProgress - dotFraction) / 0.15).clamp(0.0, 1.0);
      if (tooltipOpacity > 0) {
        _drawTooltip(
          canvas,
          offset: youWedOffset - const Offset(0, 10),
          text: '${userWeeklyXp.toInt()} XP',
          color: const Color(0xFF2563EB),
          isAbove: true,
          opacity: tooltipOpacity,
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, double x1, double x2, double y, Paint paint) {
    double curX = x1;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    while (curX < x2) {
      canvas.drawLine(Offset(curX, y), Offset(curX + dashWidth, y), paint);
      curX += dashWidth + dashSpace;
    }
  }

  void _drawSpline(Canvas canvas, List<Offset> points, Color color, double baselineY) {
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final dx = p2.dx - p1.dx;
      path.cubicTo(
        p1.dx + dx * 0.45,
        p1.dy,
        p2.dx - dx * 0.45,
        p2.dy,
        p2.dx,
        p2.dy,
      );
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, baselineY)
      ..lineTo(points.first.dx, baselineY)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.15), color.withOpacity(0.00)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(points.first.dx, points.map((p) => p.dy).reduce((a, b) => a < b ? a : b), points.last.dx, baselineY))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  void _drawTooltip(
    Canvas canvas, {
    required Offset offset,
    required String text,
    required Color color,
    required bool isAbove,
    double opacity = 1.0,
  }) {
    if (opacity <= 0) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 8.0;
    const paddingV = 5.0;
    final w = textPainter.width + paddingH * 2;
    final h = textPainter.height + paddingV * 2;
    const arrowSize = 4.0;

    final rect = isAbove
        ? Rect.fromLTWH(offset.dx - w / 2, offset.dy - h - arrowSize, w, h)
        : Rect.fromLTWH(offset.dx - w / 2, offset.dy + arrowSize, w, h);

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    final tooltipPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    if (isAbove) {
      arrowPath.moveTo(offset.dx, offset.dy);
      arrowPath.lineTo(offset.dx - arrowSize, offset.dy - arrowSize);
      arrowPath.lineTo(offset.dx + arrowSize, offset.dy - arrowSize);
    } else {
      arrowPath.moveTo(offset.dx, offset.dy);
      arrowPath.lineTo(offset.dx - arrowSize, offset.dy + arrowSize);
      arrowPath.lineTo(offset.dx + arrowSize, offset.dy + arrowSize);
    }
    arrowPath.close();

    if (opacity < 1.0) {
      canvas.saveLayer(
        rect.inflate(10),
        Paint()..color = Colors.white.withOpacity(opacity),
      );
    }

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final shadowPath = Path()..addRRect(rrect)..addPath(arrowPath, Offset.zero);
    canvas.drawPath(shadowPath, shadowPaint);

    canvas.drawRRect(rrect, tooltipPaint);
    canvas.drawPath(arrowPath, tooltipPaint);

    textPainter.paint(
      canvas,
      Offset(rect.left + paddingH, rect.top + paddingV),
    );

    if (opacity < 1.0) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplineChartPainter old) =>
      old.drawProgress != drawProgress ||
      old.pulseRadius != pulseRadius ||
      old.userWeeklyXp != userWeeklyXp;
}


class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({
    required this.onOpenBadges,
    required this.onOpenLeaderboard,
    required this.onStartStudy,
  });

  final VoidCallback? onOpenBadges;
  final VoidCallback? onOpenLeaderboard;
  final VoidCallback onStartStudy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        // Badges card
        Expanded(
          child: _QuickActionTile(
            title: 'Badges',
            iconData: Icons.emoji_events_rounded,
            iconColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
            iconBgColor: isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7),
            cardBgColor: isDark ? const Color(0xFF0F1F14) : const Color(0xFFF0FDF4),
            borderColor: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
            onTap: onOpenBadges,
          ),
        ),
        const SizedBox(width: 10),
        // Leaderboard card
        Expanded(
          child: _QuickActionTile(
            title: 'Leaderboard',
            iconData: Icons.bar_chart_rounded,
            iconColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
            iconBgColor: isDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE),
            cardBgColor: isDark ? const Color(0xFF160D2E) : const Color(0xFFF5F3FF),
            borderColor: isDark ? const Color(0xFF4C1D95) : const Color(0xFFDDD6FE),
            onTap: onOpenLeaderboard,
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.iconData,
    required this.iconColor,
    required this.iconBgColor,
    required this.cardBgColor,
    required this.borderColor,
    required this.onTap,
  });

  final String title;
  final IconData iconData;
  final Color iconColor;
  final Color iconBgColor;
  final Color cardBgColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: cardBgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: iconColor.withValues(alpha: 0.08),
        highlightColor: iconColor.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              // Title only — no subtitle
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      height: 1.2,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}class _ActivityEntryItem extends StatelessWidget {
  const _ActivityEntryItem({required this.entry});

  final ActivityEntry entry;

  // Assign a colorful icon style based on topic hash for visual variety
  static const _iconStyles = [
    (
      bgColor: Color(0xFFEFF6FF),
      iconColor: Color(0xFF3B82F6),
      borderColor: Color(0xFFBFD4FE),
      icon: Icons.help_outline_rounded,
    ),
    (
      bgColor: Color(0xFFF0FDF4),
      iconColor: Color(0xFF16A34A),
      borderColor: Color(0xFFBBF7D0),
      icon: Icons.chat_bubble_outline_rounded,
    ),
    (
      bgColor: Color(0xFFFFFBEB),
      iconColor: Color(0xFFF59E0B),
      borderColor: Color(0xFFFDE68A),
      icon: Icons.bolt_rounded,
    ),
    (
      bgColor: Color(0xFFF5F3FF),
      iconColor: Color(0xFF7C3AED),
      borderColor: Color(0xFFDDD6FE),
      icon: Icons.description_outlined,
    ),
    (
      bgColor: Color(0xFFEFF6FF),
      iconColor: Color(0xFF2563EB),
      borderColor: Color(0xFFBFD4FE),
      icon: Icons.bar_chart_rounded,
    ),
    (
      bgColor: Color(0xFFFFF7ED),
      iconColor: Color(0xFFEA580C),
      borderColor: Color(0xFFFED7AA),
      icon: Icons.category_rounded,
    ),
  ];

  static const _subjectsByHash = ['Biology', 'Biology', 'Chemistry', 'Physics', 'Chemistry', 'Physics'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCorrect = entry.isCorrect ?? false;

    // Pick icon style by topic hash for consistent per-topic look
    final styleIdx = entry.topic.hashCode.abs() % _iconStyles.length;
    final style = _iconStyles[styleIdx];
    final subjectTag = _subjectsByHash[styleIdx];

    final statusText  = isCorrect ? 'Correct'   : 'Incorrect';
    final statusColor = isCorrect
        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
        : (isDark ? const Color(0xFFFB923C) : const Color(0xFFEF4444));
    final xpText  = isCorrect ? '+${entry.xpEarned} XP' : '-${entry.xpEarned.abs()} XP';
    final xpColor = isCorrect
        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444));

    final date = DateTime.tryParse(entry.occurredAt)?.toLocal() ?? DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateString = '${date.day} ${months[date.month - 1]} ${date.year}';

    final iconBgColor     = isDark ? style.bgColor.withValues(alpha: 0.15)     : style.bgColor;
    final iconBorderColor = isDark ? style.borderColor.withValues(alpha: 0.3)  : style.borderColor;
    final iconColor       = isDark ? style.iconColor.withValues(alpha: 0.9)    : style.iconColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── App-icon style icon ──
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconBorderColor, width: 1.5),
                ),
                child: Icon(style.icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),

              // ── Topic + status + subject ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.topic,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFF0F4F8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            subjectTag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ── XP + date ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    xpText,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: xpColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateString,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallPillButton extends StatelessWidget {
  const _SmallPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
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

class _StudentWorkspaceSwitcherButton extends ConsumerWidget {
  const _StudentWorkspaceSwitcherButton({
    super.key,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = memberships.where((m) => m.workspaceId == selectedId).firstOrNull;
    final workspaces = ref.watch(studentWorkspacesProvider).valueOrNull ?? [];
    Workspace? workspace;
    for (final w in workspaces) {
      if (w.id == selectedId) {
        workspace = w;
        break;
      }
    }
    final displayName = workspace?.name ?? selected?.workspaceName ?? 'Switch';
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: context.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => _showSwitcher(context),
      icon: const Icon(Icons.workspaces_rounded, size: 16),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              displayName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 1),
          const Icon(Icons.arrow_drop_down_rounded, size: 16),
        ],
      ),
    );
  }

  void _showSwitcher(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => StudentWorkspaceSwitcherSheet(
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

// Helper functions to show private dialogs from other files
void showStudentCreateWorkspaceDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CreateWorkspaceDialog(),
  );
}

void showStudentCreateCollaborativeWorkspaceDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CreateCollaborativeWorkspaceDialog(),
  );
}

void showStudentJoinWorkspaceDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _StudentJoinWorkspaceDialog(),
  );
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashGap = 4.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(
          strokeWidth / 2,
          strokeWidth / 2,
          size.width - strokeWidth,
          size.height - strokeWidth,
        ),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    double distance = 0.0;
    
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final len = dashWidth;
        if (distance + len > metric.length) {
          dashPath.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          dashPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len + dashGap;
      }
    }
    
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _SchoolBuildingWatermarkPainter extends CustomPainter {
  final Color color;
  _SchoolBuildingWatermarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Main building body: from y = 45% to y = 90%
    final double left = size.width * 0.15;
    final double right = size.width * 0.85;
    final double bottom = size.height * 0.9;
    final double bodyTop = size.height * 0.55;
    
    // Base line
    path.moveTo(size.width * 0.05, bottom);
    path.lineTo(size.width * 0.95, bottom);
    
    // Main body rectangle
    path.moveTo(left, bottom);
    path.lineTo(left, bodyTop);
    path.lineTo(right, bodyTop);
    path.lineTo(right, bottom);
    
    // Triangle roof on top of main body
    final double roofPeakY = size.height * 0.35;
    path.moveTo(left - 5, bodyTop);
    path.lineTo(size.width * 0.5, roofPeakY);
    path.lineTo(right + 5, bodyTop);
    
    // Bell tower/cupola on top of the roof peak
    final double towerLeft = size.width * 0.42;
    final double towerRight = size.width * 0.58;
    final double towerTop = size.height * 0.2;
    path.moveTo(towerLeft, size.height * 0.3);
    path.lineTo(towerLeft, towerTop);
    path.lineTo(towerRight, towerTop);
    path.lineTo(towerRight, size.height * 0.3);
    
    // Tower roof
    path.moveTo(towerLeft - 2, towerTop);
    path.lineTo(size.width * 0.5, size.height * 0.12);
    path.lineTo(towerRight + 2, towerTop);
    
    // Flag pole and flag
    path.moveTo(size.width * 0.5, size.height * 0.12);
    path.lineTo(size.width * 0.5, size.height * 0.05);
    path.lineTo(size.width * 0.62, size.height * 0.08);
    path.lineTo(size.width * 0.5, size.height * 0.11);
    
    // Door in the middle
    final double doorLeft = size.width * 0.44;
    final double doorRight = size.width * 0.56;
    final double doorTop = size.height * 0.72;
    path.moveTo(doorLeft, bottom);
    path.lineTo(doorLeft, doorTop);
    // Arched door top
    path.arcToPoint(
      Offset(doorRight, doorTop),
      radius: Radius.circular((doorRight - doorLeft) / 2),
      clockwise: true,
    );
    path.lineTo(doorRight, bottom);
    
    // Arched Window Left
    final double w1Left = size.width * 0.25;
    final double w1Right = size.width * 0.35;
    final double wTop = size.height * 0.62;
    final double wBottom = size.height * 0.76;
    path.moveTo(w1Left, wBottom);
    path.lineTo(w1Left, wTop);
    path.arcToPoint(
      Offset(w1Right, wTop),
      radius: Radius.circular((w1Right - w1Left) / 2),
      clockwise: true,
    );
    path.lineTo(w1Right, wBottom);
    path.close();
    
    // Arched Window Right
    final double w2Left = size.width * 0.65;
    final double w2Right = size.width * 0.75;
    path.moveTo(w2Left, wBottom);
    path.lineTo(w2Left, wTop);
    path.arcToPoint(
      Offset(w2Right, wTop),
      radius: Radius.circular((w2Right - w2Left) / 2),
      clockwise: true,
    );
    path.lineTo(w2Right, wBottom);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DeskLampWatermarkPainter extends CustomPainter {
  final Color color;
  _DeskLampWatermarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Desk surface base line at y = 90%
    final double bottom = size.height * 0.9;
    path.moveTo(size.width * 0.05, bottom);
    path.lineTo(size.width * 0.95, bottom);
    
    // --- Desk Lamp (on the right side) ---
    final double baseCenterX = size.width * 0.75;
    final double baseWidth = size.width * 0.16;
    // Lamp base (flattened oval/dome)
    path.moveTo(baseCenterX - baseWidth / 2, bottom);
    path.arcToPoint(
      Offset(baseCenterX + baseWidth / 2, bottom),
      radius: Radius.circular(baseWidth / 2),
      clockwise: true,
    );
    
    // Angled neck segment 1: base to joint
    final double jointX = size.width * 0.65;
    final double jointY = size.height * 0.55;
    path.moveTo(baseCenterX, bottom - 5);
    path.lineTo(jointX, jointY);
    
    // Neck joint circle
    canvas.drawCircle(Offset(jointX, jointY), 3, paint);
    
    // Angled neck segment 2: joint to head
    final double headX = size.width * 0.50;
    final double headY = size.height * 0.35;
    path.moveTo(jointX, jointY);
    path.lineTo(headX, headY);
    
    // Lamp head (lampshade pointing down-left)
    final double capCenterX = headX;
    final double capCenterY = headY;
    final double rimX1 = size.width * 0.38;
    final double rimY1 = size.height * 0.45;
    final double rimX2 = size.width * 0.48;
    final double rimY2 = size.height * 0.55;
    
    path.moveTo(capCenterX, capCenterY);
    path.lineTo(rimX1, rimY1);
    path.lineTo(rimX2, rimY2);
    path.lineTo(capCenterX, capCenterY);
    
    // Light rays
    path.moveTo(rimX1 - 5, rimY1 + 5);
    path.lineTo(rimX1 - 15, rimY1 + 15);
    path.moveTo((rimX1 + rimX2)/2 - 5, (rimY1 + rimY2)/2 + 5);
    path.lineTo((rimX1 + rimX2)/2 - 15, (rimY1 + rimY2)/2 + 20);
    path.moveTo(rimX2 - 2, rimY2 + 5);
    path.lineTo(rimX2 - 5, rimY2 + 20);
    
    // --- Coffee Mug (in the middle-left) ---
    final double mugLeft = size.width * 0.12;
    final double mugRight = size.width * 0.28;
    final double mugBottom = bottom;
    final double mugTop = size.height * 0.7;
    path.moveTo(mugLeft, mugBottom);
    path.lineTo(mugLeft, mugTop);
    path.lineTo(mugRight, mugTop);
    path.lineTo(mugRight, mugBottom);
    path.lineTo(mugLeft, mugBottom);
    // Mug handle on the left
    path.moveTo(mugLeft, mugTop + 5);
    path.cubicTo(
      mugLeft - 8, mugTop + 5,
      mugLeft - 8, mugBottom - 5,
      mugLeft, mugBottom - 5,
    );
    // Steam lines
    path.moveTo(size.width * 0.17, mugTop - 4);
    path.cubicTo(size.width * 0.18, mugTop - 8, size.width * 0.16, mugTop - 12, size.width * 0.17, mugTop - 16);
    path.moveTo(size.width * 0.23, mugTop - 4);
    path.cubicTo(size.width * 0.24, mugTop - 8, size.width * 0.22, mugTop - 12, size.width * 0.23, mugTop - 16);

    // --- Book Stack ---
    final double b1Left = size.width * 0.38;
    final double b1Right = size.width * 0.62;
    final double b1Bottom = bottom;
    final double b1Top = size.height * 0.82;
    
    path.moveTo(b1Left, b1Bottom);
    path.lineTo(b1Left, b1Top);
    path.lineTo(b1Right, b1Top);
    path.lineTo(b1Right, b1Bottom);
    path.moveTo(b1Right - 4, b1Top + 2);
    path.lineTo(b1Right - 4, b1Bottom - 2);
    
    final double b2Left = size.width * 0.42;
    final double b2Right = size.width * 0.66;
    final double b2Bottom = b1Top;
    final double b2Top = size.height * 0.74;
    path.moveTo(b2Left, b2Bottom);
    path.lineTo(b2Left, b2Top);
    path.lineTo(b2Right, b2Top);
    path.lineTo(b2Right, b2Bottom);
    path.moveTo(b2Right - 4, b2Top + 2);
    path.lineTo(b2Right - 4, b2Bottom - 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ComputerDeskWatermarkPainter extends CustomPainter {
  final Color color;
  _ComputerDeskWatermarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Desk surface base line at y = 82%
    final double deskY = size.height * 0.82;
    path.moveTo(size.width * 0.05, deskY);
    path.lineTo(size.width * 0.95, deskY);
    
    // Desk legs
    path.moveTo(size.width * 0.15, deskY);
    path.lineTo(size.width * 0.15, size.height * 0.95);
    path.moveTo(size.width * 0.85, deskY);
    path.lineTo(size.width * 0.85, size.height * 0.95);
    
    // --- Computer Monitor (centered) ---
    final double monitorWidth = size.width * 0.40;
    final double monitorHeight = size.height * 0.35;
    final double monitorLeft = size.width * 0.3;
    final double monitorRight = monitorLeft + monitorWidth;
    final double monitorTop = size.height * 0.35;
    final double monitorBottom = monitorTop + monitorHeight;
    
    path.moveTo(monitorLeft, monitorTop);
    path.lineTo(monitorRight, monitorTop);
    path.lineTo(monitorRight, monitorBottom);
    path.lineTo(monitorLeft, monitorBottom);
    path.close();
    
    // Monitor stand
    final double standLeft = size.width * 0.46;
    final double standRight = size.width * 0.54;
    path.moveTo(standLeft, monitorBottom);
    path.lineTo(standLeft, deskY - 3);
    path.moveTo(standRight, monitorBottom);
    path.lineTo(standRight, deskY - 3);
    
    // Monitor base
    path.moveTo(size.width * 0.42, deskY - 3);
    path.lineTo(size.width * 0.58, deskY - 3);
    
    // Faint inner lines representing code/layout on screen
    path.moveTo(monitorLeft + 8, monitorTop + 8);
    path.lineTo(monitorLeft + 25, monitorTop + 8);
    path.moveTo(monitorLeft + 8, monitorTop + 16);
    path.lineTo(monitorLeft + 40, monitorTop + 16);
    path.moveTo(monitorLeft + 8, monitorTop + 24);
    path.lineTo(monitorLeft + 30, monitorTop + 24);
    
    // --- Keyboard ---
    final double kbLeft = size.width * 0.38;
    final double kbRight = size.width * 0.58;
    final double kbTop = deskY - 8;
    final double kbBottom = deskY - 2;
    path.moveTo(kbLeft, kbTop);
    path.lineTo(kbRight, kbTop);
    path.lineTo(kbRight, kbBottom);
    path.lineTo(kbLeft, kbBottom);
    path.close();
    
    // --- Study Chair ---
    final double chairLeft = size.width * 0.08;
    final double chairRight = size.width * 0.22;
    final double chairSeatY = deskY - 10;
    final double chairBackTopY = size.height * 0.45;
    
    path.moveTo(chairLeft, chairSeatY);
    path.lineTo(chairRight, chairSeatY);
    
    path.moveTo(chairLeft + 3, chairSeatY);
    path.lineTo(chairLeft + 3, chairBackTopY);
    path.lineTo(chairLeft + 15, chairBackTopY);
    path.lineTo(chairLeft + 15, chairSeatY);
    
    final double chairLegsY = size.height * 0.95;
    path.moveTo((chairLeft + chairRight) / 2, chairSeatY);
    path.lineTo((chairLeft + chairRight) / 2, chairLegsY - 4);
    path.moveTo(chairLeft + 2, chairLegsY - 4);
    path.lineTo(chairRight - 2, chairLegsY - 4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StudentWorkspaceSwitcherSheet extends ConsumerWidget {
  const StudentWorkspaceSwitcherSheet({
    super.key,
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

  void _showCreateOptionsChooser(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Create or Join Workspace',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  _buildActionItem(
                    context: ctx,
                    icon: Icons.person_add_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Create Personal Workspace',
                    subtitle: 'Your private learning sandpit',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onCreateWorkspace();
                    },
                  ),
                  const SizedBox(height: Spacing.sm),
                  _buildActionItem(
                    context: ctx,
                    icon: Icons.group_add_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Create Collaborative Workspace',
                    subtitle: 'Study with friends or join a class',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onCreateCollaborativeWorkspace();
                    },
                  ),
                  const SizedBox(height: Spacing.sm),
                  _buildActionItem(
                    context: ctx,
                    icon: Icons.vpn_key_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Join Workspace (via Code)',
                    subtitle: 'Enter an invite code to join a classroom',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onJoinWorkspace();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.lg, Spacing.md),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // Centered Sparkle Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Switch Workspace',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a workspace to continue learning',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // Workspaces list
            if (memberships.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
                child: Text(
                  'No workspaces available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: memberships.length,
                  itemBuilder: (context, index) {
                    final m = memberships[index];
                    final isSelected = m.workspaceId == selectedId;
                    final isPersonal = m.role == UserRole.workspaceAdmin || m.role == UserRole.tenantAdmin;
                    
                    // Resolve actual workspace to check if collaborative and get name
                    final workspaces = ref.watch(studentWorkspacesProvider).valueOrNull ?? [];
                    Workspace? workspace;
                    for (final w in workspaces) {
                      if (w.id == m.workspaceId) {
                        workspace = w;
                        break;
                      }
                    }
                    final isCollaborative = workspace?.type == 'collaborative';
                    final resolvedName = workspace?.name ?? m.workspaceName ?? 'Study Workspace';

                    // Calculate classroomIndex state-lessly for the current workspace
                    int classroomIndex = 0;
                    for (int i = 0; i < index; i++) {
                      final mRole = memberships[i].role;
                      final mIsPersonal = mRole == UserRole.workspaceAdmin || mRole == UserRole.tenantAdmin;
                      if (!mIsPersonal) {
                        classroomIndex++;
                      }
                    }

                    // Style config mapping
                    final Color tagBg;
                    final Color tagText;
                    final String tagLabel;
                    final LinearGradient grad;
                    final IconData leadIcon;
                    final CustomPainter watermarkPainter;
                    final String subtitleText;

                    if (isPersonal) {
                       tagLabel = 'Personal';
                       tagBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
                       tagText = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
                       grad = const LinearGradient(
                         colors: [Color(0xFF10B981), Color(0xFF059669)],
                         begin: Alignment.topLeft,
                         end: Alignment.bottomRight,
                       );
                       leadIcon = Icons.person_rounded;
                       watermarkPainter = _DeskLampWatermarkPainter(
                         color: (isDark ? Colors.white : const Color(0xFF10B981))
                             .withOpacity(isDark ? 0.025 : 0.045),
                       );
                       subtitleText = isSelected ? 'Your current personal workspace' : 'Your private study space';
                    } else if (isCollaborative) {
                      tagLabel = 'Group Study';
                      tagBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFFF7ED);
                      tagText = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
                      grad = const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      );
                      leadIcon = Icons.groups_rounded;
                      watermarkPainter = _ComputerDeskWatermarkPainter(
                        color: (isDark ? Colors.white : const Color(0xFFD97706))
                            .withOpacity(isDark ? 0.025 : 0.045),
                      );
                      subtitleText = isSelected ? 'Your current group study' : 'Joined as a student';
                    } else {
                       tagLabel = 'Classroom';
                       if (classroomIndex % 2 == 0) {
                         tagBg = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF);
                         tagText = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
                         grad = const LinearGradient(
                           colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         );
                         leadIcon = Icons.groups_rounded;
                         watermarkPainter = _SchoolBuildingWatermarkPainter(
                           color: (isDark ? Colors.white : const Color(0xFF6366F1))
                               .withOpacity(isDark ? 0.025 : 0.045),
                         );
                       } else {
                         tagBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFFF7ED);
                         tagText = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
                         grad = const LinearGradient(
                           colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         );
                         leadIcon = Icons.groups_rounded;
                         watermarkPainter = _ComputerDeskWatermarkPainter(
                           color: (isDark ? Colors.white : const Color(0xFFD97706))
                               .withOpacity(isDark ? 0.025 : 0.045),
                         );
                       }
                       subtitleText = isSelected ? 'Your current classroom workspace' : 'Joined as a student';
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        height: 94,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8B5CF6)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelect(m.workspaceId),
                            child: Stack(
                              children: [
                                // Faint watermark drawing in background
                                Positioned(
                                  right: -10,
                                  bottom: -10,
                                  child: SizedBox(
                                    width: 90,
                                    height: 90,
                                    child: CustomPaint(
                                      painter: watermarkPainter,
                                    ),
                                  ),
                                ),
                                // Content row
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  child: Row(
                                    children: [
                                      // Leading Gradient Icon
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: grad,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          leadIcon,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Workspace Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              resolvedName,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                // Tag chip
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: tagBg,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    tagLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: tagText,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              subtitleText,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Right checkmark or empty radio
                                      if (isSelected)
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF8B5CF6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),

            // Create New Workspace Button (Dashed RRect Card)
            CustomPaint(
              painter: _DashedBorderPainter(
                color: const Color(0xFF8B5CF6),
                borderRadius: 16,
                strokeWidth: 1.5,
                dashWidth: 6.0,
                dashGap: 4.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E1065).withOpacity(0.15) : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showCreateOptionsChooser(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF4C1D95).withOpacity(0.4) : const Color(0xFFECE9FE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFF8B5CF6),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create New Workspace',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF6D28D9),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Create a personal or class workspace',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Security Footer Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gpp_good_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your data is always safe',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Switching workspace keeps your progress secure.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
                              fontWeight: FontWeight.w700,
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

