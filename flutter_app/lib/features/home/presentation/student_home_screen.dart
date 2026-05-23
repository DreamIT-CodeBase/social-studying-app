import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_screen.dart';
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
              onTap: () =>
                  ref.read(authNotifierProvider.notifier).signOut(),
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
            onStartStudy: () => setState(() => _selectedIndex = 1),
            onStartRevision: workspaceId == null
                ? null
                : () => context.push(
                      '${AppRoutes.studentRevision}/$workspaceId',
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
    required this.onStartStudy,
    required this.onStartRevision,
  });

  final String displayName;
  final VoidCallback onStartStudy;

  /// `null` when there's no active workspace, which disables the
  /// revision launch button.
  final VoidCallback? onStartRevision;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _GreetingCard(displayName: displayName),
        const SizedBox(height: Spacing.lg),
        _StreakCard(),
        const SizedBox(height: Spacing.lg),
        _QuickStudyButton(onPressed: onStartStudy),
        const SizedBox(height: Spacing.md),
        _RevisionButton(onPressed: onStartRevision),
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

class _StreakCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            Container(
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
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0-day streak',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Study today to start your streak!',
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
                '0 XP',
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
