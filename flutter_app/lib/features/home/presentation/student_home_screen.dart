import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
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
    final displayName =
        ref.watch(authNotifierProvider).valueOrNull?.maybeWhen(
              authenticated: (user) => user.displayName,
              orElse: () => 'Student',
            ) ??
        'Student';

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
          _HomeTab(displayName: displayName),
          const _StudyTab(),
          const _FlashcardsTab(),
          const _ProgressTab(),
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
  const _HomeTab({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _GreetingCard(displayName: displayName),
        const SizedBox(height: Spacing.lg),
        _StreakCard(),
        const SizedBox(height: Spacing.lg),
        _QuickStudyButton(),
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
      onPressed: () {},
      icon: const Icon(Icons.play_arrow_rounded, size: 24),
      label: const Text('Start Study Session'),
    );
  }
}

class _StudyTab extends StatelessWidget {
  const _StudyTab();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      icon: Icons.quiz_rounded,
      title: 'No questions ready',
      subtitle:
          'Your teacher needs to upload study materials before questions can be generated.',
    );
  }
}

class _FlashcardsTab extends StatelessWidget {
  const _FlashcardsTab();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      icon: Icons.style_rounded,
      title: 'No flashcards yet',
      subtitle:
          'Flashcards will appear here once your teacher uploads study materials.',
    );
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        const _LevelCard(),
        const SizedBox(height: Spacing.lg),
        Text(
          'Topic Mastery',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.md),
        const EmptyStateView(
          icon: Icons.insights_rounded,
          title: 'No data yet',
          subtitle: 'Answer questions to build your topic mastery profile.',
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars_rounded,
                    color: AppColors.secondary, size: 28),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Level 1',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '0 / 100 XP',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0,
                minHeight: 8,
                backgroundColor: context.colorScheme.surfaceContainerHighest,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
