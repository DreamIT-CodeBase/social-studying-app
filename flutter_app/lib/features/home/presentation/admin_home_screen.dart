import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/admin/users/presentation/users_screen.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/documents/presentation/documents_list_screen.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _selectedIndex = 0;

  static const _tabs = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.description_rounded, label: 'Documents'),
    (icon: Icons.people_rounded, label: 'Students'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authNotifierProvider);
    final displayName = authAsync.valueOrNull?.maybeWhen(
          authenticated: (user) => user.displayName,
          orElse: () => 'Admin',
        ) ??
        'Admin';
    final workspaceId = authAsync.valueOrNull?.maybeWhen(
      authenticated: (user) =>
          user.workspaceMemberships.isNotEmpty
              ? user.workspaceMemberships.first.workspaceId
              : null,
      orElse: () => null,
    );

    final isDocumentsTab = _tabs[_selectedIndex].label == 'Documents';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabs[_selectedIndex].label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          // Sprint 2.13 — taxonomy viewer entry point. Only meaningful
          // inside the Documents tab and only when the user has a
          // workspace; tucked into the AppBar to avoid stealing space
          // from the documents FAB.
          if (isDocumentsTab && workspaceId != null)
            IconButton(
              tooltip: 'Topic taxonomy',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () =>
                  context.push('${AppRoutes.adminTaxonomy}/$workspaceId'),
            ),
          Padding(
            padding: const EdgeInsets.only(right: Spacing.lg),
            child: GestureDetector(
              onTap: () => _showSignOutDialog(context),
              child: CircleAvatar(
                backgroundColor: AppColors.primaryContainer,
                radius: 18,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
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
          _DashboardTab(displayName: displayName),
          _DocumentsTab(workspaceId: workspaceId),
          _StudentsTab(workspaceId: workspaceId),
          _SettingsTab(
            workspaceId: workspaceId,
            onSignOut: () => _signOut(),
          ),
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

  Future<void> _showSignOutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) _signOut();
  }

  void _signOut() => ref.read(authNotifierProvider.notifier).signOut();
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _WelcomeBanner(displayName: displayName),
        const SizedBox(height: Spacing.lg),
        const _StatsRow(),
        const SizedBox(height: Spacing.xl),
        Text(
          'Get Started',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.md),
        const _GetStartedCard(
          step: 1,
          title: 'Upload study materials',
          subtitle: 'Add PDFs, Word docs, or images to your workspace',
          icon: Icons.upload_file_rounded,
          isDone: false,
        ),
        const SizedBox(height: Spacing.sm),
        const _GetStartedCard(
          step: 2,
          title: 'Invite your students',
          subtitle: 'Share an invite code so students can join',
          icon: Icons.person_add_rounded,
          isDone: false,
        ),
        const SizedBox(height: Spacing.sm),
        const _GetStartedCard(
          step: 3,
          title: 'Watch them learn',
          subtitle: 'AI generates personalized questions for each student',
          icon: Icons.auto_awesome_rounded,
          isDone: false,
        ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.displayName});

  final String displayName;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
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
          const SizedBox(height: Spacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Demo Classroom  •  Admin',
              style: context.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '0',
            label: 'Students',
            icon: Icons.people_rounded,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: Spacing.md),
        Expanded(
          child: _StatCard(
            value: '0',
            label: 'Documents',
            icon: Icons.description_rounded,
            color: AppColors.secondary,
          ),
        ),
        SizedBox(width: Spacing.md),
        Expanded(
          child: _StatCard(
            value: '0',
            label: 'Questions',
            icon: Icons.quiz_rounded,
            color: AppColors.tertiary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: Spacing.sm),
            Text(
              value,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GetStartedCard extends StatelessWidget {
  const _GetStartedCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDone,
  });

  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.sm,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.tertiaryContainer
                : AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: isDone
              ? const Icon(Icons.check_rounded,
                  color: AppColors.tertiary, size: 20)
              : Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: context.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isDone
            ? null
            : Icon(Icons.chevron_right_rounded,
                color: context.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context) {
    if (workspaceId == null) {
      return const EmptyStateView(
        icon: Icons.workspaces_outline,
        title: 'No workspace yet',
        subtitle:
            'You need to create or join a workspace before uploading documents.',
      );
    }
    return DocumentsListScreen(workspaceId: workspaceId!);
  }
}

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context) {
    if (workspaceId == null) {
      return const EmptyStateView(
        icon: Icons.workspaces_outline,
        title: 'No workspace yet',
        subtitle: 'Create or join a workspace before managing students.',
      );
    }
    // Sprint 4.2 — full roster management for the active workspace.
    return WorkspaceUsersScreen(workspaceId: workspaceId!);
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.workspaceId, required this.onSignOut});

  final String? workspaceId;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final wsId = workspaceId;
    return ListView(
      children: [
        const SizedBox(height: Spacing.sm),
        _SettingsTile(
          icon: Icons.workspace_premium_rounded,
          title: 'Workspaces',
          subtitle: 'Create, edit, and manage workspaces',
          onTap: () => context.push(AppRoutes.adminWorkspaces),
        ),
        // Workspace-scoped settings only resolve once the admin has a
        // workspace — until then the Workspaces tile is the way in.
        if (wsId != null) ...[
          _SettingsTile(
            icon: Icons.tune_rounded,
            title: 'Workspace Settings',
            subtitle: 'Question frequency, formats, gamification',
            onTap: () => context.push(
              '${AppRoutes.adminWorkspaceSettings}/$wsId',
            ),
          ),
          _SettingsTile(
            icon: Icons.shield_rounded,
            title: 'Content Moderation',
            subtitle: 'Review flagged questions and documents',
            onTap: () => context.push(
              '${AppRoutes.adminModeration}/$wsId',
            ),
          ),
        ],
        const Divider(height: Spacing.xl),
        _SettingsTile(
          icon: Icons.logout_rounded,
          title: 'Sign out',
          subtitle: 'demo@socialstudyapp.com',
          onTap: onSignOut,
          isDestructive: true,
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? context.colorScheme.error : context.colorScheme.primary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive
              ? context.colorScheme.errorContainer
              : context.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDestructive ? context.colorScheme.error : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isDestructive
          ? null
          : Icon(Icons.chevron_right_rounded,
              color: context.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
