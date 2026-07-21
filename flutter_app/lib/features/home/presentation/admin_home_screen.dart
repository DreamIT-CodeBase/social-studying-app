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
import 'package:social_study_app/features/admin/workspaces/presentation/selected_workspace_provider.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/models/workspace.dart';

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


    final workspaceId = ref.watch(selectedWorkspaceProvider);
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final workspacesAsync = ref.watch(workspacesListProvider);
    final workspaces = workspacesAsync.valueOrNull ?? [];
    final workspaceName = activeWorkspace?.name ?? 'No Workspace';

    final isDocumentsTab = _tabs[_selectedIndex].label == 'Documents';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabs[_selectedIndex].label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          // Sprint 2.13 — taxonomy viewer entry point.
          if (isDocumentsTab && workspaceId != null)
            IconButton(
              tooltip: 'Topic taxonomy',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () =>
                  context.push('${AppRoutes.adminTaxonomy}/$workspaceId'),
            ),
          // Workspace switcher — only visible when there are 2+ workspaces
          if (workspaces.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: _WorkspaceSwitcherButton(
                workspaces: workspaces,
                selectedId: workspaceId,
                onSelect: (id) =>
                    ref.read(selectedWorkspaceProvider.notifier).selectWorkspace(id),
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
          _DashboardTab(
            displayName: displayName,
            workspaceId: workspaceId,
            workspaceName: workspaceName,
            onSelectTab: (index) => setState(() => _selectedIndex = index),
          ),
          _DocumentsTab(workspaceId: workspaceId),
          _StudentsTab(workspaceId: workspaceId),
          _SettingsTab(workspaceId: workspaceId),
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

/// Button that opens a bottom sheet to switch between workspaces.
class _WorkspaceSwitcherButton extends StatelessWidget {
  const _WorkspaceSwitcherButton({
    required this.workspaces,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Workspace> workspaces;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = workspaces.where((w) => w.id == selectedId).firstOrNull;
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => _showSwitcher(context),
      icon: const Icon(Icons.workspaces_rounded, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected?.name ?? 'Select',
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
      builder: (_) => _WorkspaceSwitcherSheet(
        workspaces: workspaces,
        selectedId: selectedId,
        onSelect: (id) {
          Navigator.of(context).pop();
          onSelect(id);
        },
      ),
    );
  }
}

class _WorkspaceSwitcherSheet extends StatelessWidget {
  const _WorkspaceSwitcherSheet({
    required this.workspaces,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Workspace> workspaces;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl, 0, Spacing.xl, Spacing.sm,
          ),
          child: Text(
            'Switch Workspace',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final ws in workspaces)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.xl,
              vertical: 0,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ws.id == selectedId
                    ? context.colorScheme.primaryContainer
                    : context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.workspaces_rounded,
                size: 20,
                color: ws.id == selectedId
                    ? context.colorScheme.onPrimaryContainer
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              ws.name,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: ws.id == selectedId
                    ? context.colorScheme.primary
                    : null,
              ),
            ),
            subtitle: Text(
              '${ws.studentCount} students • ${ws.documentCount} documents',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: ws.id == selectedId
                ? Icon(
                    Icons.check_circle_rounded,
                    color: context.colorScheme.primary,
                  )
                : null,
            onTap: () => onSelect(ws.id),
          ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.displayName,
    required this.workspaceId,
    required this.workspaceName,
    required this.onSelectTab,
  });

  final String displayName;
  final String? workspaceId;
  final String workspaceName;

  /// Switches the parent's bottom-nav tab — lets the Get Started cards jump
  /// to the Documents / Students tabs they describe.
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final wsId = workspaceId;
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _WelcomeBanner(
          displayName: displayName,
          workspaceName: workspaceName,
        ),
        const SizedBox(height: Spacing.lg),
        _StatsRow(workspaceId: workspaceId),
        const SizedBox(height: Spacing.xl),
        Text(
          'Get Started',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.md),
        _GetStartedCard(
          step: 1,
          title: 'Upload study materials',
          subtitle: 'Add PDFs, Word docs, or images to your workspace',
          icon: Icons.upload_file_rounded,
          isDone: false,
          onTap: () => onSelectTab(1), // Documents tab
        ),
        const SizedBox(height: Spacing.sm),
        _GetStartedCard(
          step: 2,
          title: 'Invite your students',
          subtitle: 'Share an invite code so students can join',
          icon: Icons.person_add_rounded,
          isDone: false,
          onTap: () => onSelectTab(2), // Students tab (roster + invite codes)
        ),
        const SizedBox(height: Spacing.sm),
        _GetStartedCard(
          step: 3,
          title: 'Watch them learn',
          subtitle: 'AI generates personalized questions for each student',
          icon: Icons.auto_awesome_rounded,
          isDone: false,
          // Engagement/mastery view lives at workspace analytics.
          onTap: () => wsId != null
              ? context.push('/admin/analytics/$wsId')
              : onSelectTab(1),
        ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.displayName,
    required this.workspaceName,
  });

  final String displayName;
  final String workspaceName;

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
              '$workspaceName  •  Admin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

/// Live stats row that reads from the currently selected workspace.
class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspacesListProvider);
    final isMobile = context.isMobile;

    // While loading show skeleton placeholders
    if (workspacesAsync.isLoading) {
      if (isMobile) {
        return const Column(
          children: [
            Row(
              children: [
                Expanded(child: _StatCard(value: '—', label: 'Students', icon: Icons.people_rounded, color: AppColors.primary)),
                SizedBox(width: Spacing.md),
                Expanded(child: _StatCard(value: '—', label: 'Documents', icon: Icons.description_rounded, color: AppColors.secondary)),
              ],
            ),
            SizedBox(height: Spacing.md),
            _StatCard(value: '—', label: 'Admins', icon: Icons.shield_rounded, color: AppColors.tertiary, horizontal: true),
          ],
        );
      }
      return const Row(
        children: [
          Expanded(child: _StatCard(value: '—', label: 'Students', icon: Icons.people_rounded, color: AppColors.primary)),
          SizedBox(width: Spacing.md),
          Expanded(child: _StatCard(value: '—', label: 'Documents', icon: Icons.description_rounded, color: AppColors.secondary)),
          SizedBox(width: Spacing.md),
          Expanded(child: _StatCard(value: '—', label: 'Admins', icon: Icons.shield_rounded, color: AppColors.tertiary)),
        ],
      );
    }

    final workspaces = workspacesAsync.valueOrNull ?? [];
    final activeWs = workspaceId != null
        ? workspaces.where((w) => w.id == workspaceId).firstOrNull
        : workspaces.isNotEmpty
            ? workspaces.first
            : null;

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: activeWs != null ? '${activeWs.studentCount}' : '0',
                  label: 'Students',
                  icon: Icons.people_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _StatCard(
                  value: activeWs != null ? '${activeWs.documentCount}' : '0',
                  label: 'Documents',
                  icon: Icons.description_rounded,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          _StatCard(
            value: activeWs != null ? '${activeWs.adminCount}' : '0',
            label: 'Admins',
            icon: Icons.shield_rounded,
            color: AppColors.tertiary,
            horizontal: true,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: activeWs != null ? '${activeWs.studentCount}' : '0',
            label: 'Students',
            icon: Icons.people_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _StatCard(
            value: activeWs != null ? '${activeWs.documentCount}' : '0',
            label: 'Documents',
            icon: Icons.description_rounded,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _StatCard(
            value: activeWs != null ? '${activeWs.adminCount}' : '0',
            label: 'Admins',
            icon: Icons.shield_rounded,
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
    this.horizontal = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: horizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: Spacing.md),
                  Text(
                    value,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    label,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Column(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
    required this.onTap,
  });

  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
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
  const _SettingsTab({required this.workspaceId});

  final String? workspaceId;

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
            icon: Icons.screen_lock_portrait_rounded,
            title: 'Screen Time & Blocking',
            subtitle: 'Configure app blocking and XP rules',
            onTap: () => context.push(
              AppRoutes.studentScreenTimeSettings,
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
          _SettingsTile(
            icon: Icons.analytics_rounded,
            title: 'Workspace Analytics',
            subtitle: 'Engagement, mastery, and topic distribution',
            onTap: () => context.push(
              '/admin/analytics/$wsId',
            ),
          ),
        ],
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: context.colorScheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right_rounded,
          color: context.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
