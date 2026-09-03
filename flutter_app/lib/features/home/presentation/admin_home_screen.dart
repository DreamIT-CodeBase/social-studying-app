import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/features/admin/analytics/data/analytics_repository.dart';
import 'package:social_study_app/features/admin/analytics/presentation/learning_progress_card.dart';
import 'package:social_study_app/features/admin/notifications/admin_notifications_tab.dart'
    show adminProgressNotificationsEnabledProvider;
import 'package:social_study_app/features/admin/users/presentation/users_screen.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/documents/presentation/documents_list_screen.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/selected_workspace_provider.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/models/learning_progress.dart';
import 'package:social_study_app/shared/models/workspace.dart';

const _dashboardBackground = Color(0xFF06101F);
const _dashboardSurface = Color(0xFF0D1A30);
const _dashboardSurfaceAlt = Color(0xFF111F37);
const _dashboardBorder = Color(0xFF213451);
const _dashboardMuted = Color(0xFFA7B5CF);
const _dashboardBlue = Color(0xFF3674FF);
const _dashboardPurple = Color(0xFF7846F5);
const _dashboardGreen = Color(0xFF23E6A0);

final _dashboardTrendProvider =
    FutureProvider.autoDispose.family<LearningProgressTrend, String>(
  (ref, workspaceId) {
    final today = DateTime.now();
    return ref.read(analyticsRepositoryProvider).fetchLearningProgress(
          workspaceId: workspaceId,
          startDate: today.subtract(const Duration(days: 29)),
          endDate: today,
        );
  },
);

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
    final dashboardTheme = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: _dashboardBackground,
      colorScheme: const ColorScheme.dark(
        primary: _dashboardBlue,
        secondary: _dashboardPurple,
        tertiary: _dashboardGreen,
        surface: _dashboardSurface,
        surfaceContainerHighest: _dashboardSurfaceAlt,
        onSurface: Colors.white,
        onSurfaceVariant: _dashboardMuted,
        outline: _dashboardBorder,
        outlineVariant: Color(0xFF182A44),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _dashboardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _dashboardBorder),
        ),
      ),
    );
    return Theme(
      data: dashboardTheme,
      child: Scaffold(
        backgroundColor: _dashboardBackground,
        appBar: AppBar(
          toolbarHeight: 70,
          backgroundColor: _dashboardBackground,
          surfaceTintColor: Colors.transparent,
          titleSpacing: Spacing.lg,
          title: Text(
            _tabs[_selectedIndex].label,
            style: const TextStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
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
            if (workspaces.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: Spacing.sm),
                child: _WorkspaceSwitcherButton(
                  workspaces: workspaces,
                  selectedId: workspaceId,
                  onSelect: (id) => ref
                      .read(selectedWorkspaceProvider.notifier)
                      .selectWorkspace(id),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: Spacing.lg),
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.profile),
                child: CircleAvatar(
                  backgroundColor: _dashboardPurple,
                  radius: 18,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _DashboardTab(
                    displayName: displayName,
                    workspaceId: workspaceId,
                    workspaceName: workspaceName,
                    onSelectTab: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                  _DocumentsTab(workspaceId: workspaceId),
                  _StudentsTab(workspaceId: workspaceId),
                  _SettingsTab(workspaceId: workspaceId),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _dashboardSurface,
                border: Border(
                  top: BorderSide(color: _dashboardBorder),
                ),
              ),
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  height: 66,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  indicatorColor: const Color(0xFF25237E),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: [
                    ..._tabs.asMap().entries.map((entry) {
                      final tab = entry.value;
                      return NavigationDestination(
                        icon: Icon(tab.icon,
                            color: _dashboardMuted, size: 22),
                        selectedIcon: Icon(tab.icon,
                            color: Colors.white, size: 22),
                        label: tab.label,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => _showSwitcher(context),
      icon: const Icon(Icons.group_rounded, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected?.name ?? 'Select',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
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
            Spacing.xl,
            0,
            Spacing.xl,
            Spacing.sm,
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
                color: ws.id == selectedId ? context.colorScheme.primary : null,
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
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        0,
        Spacing.lg,
        Spacing.xl,
      ),
      children: [
        _ReferenceWelcomeBanner(
          displayName: displayName,
          workspaceName: workspaceName,
        ),
        const SizedBox(height: Spacing.lg),
        _ReferenceStatsPanel(workspaceId: workspaceId),
        if (wsId != null) ...[
          const SizedBox(height: Spacing.md),
          LearningProgressCard(workspaceId: wsId),
        ],
        const SizedBox(height: Spacing.xl),
        Text(
          'Get Started',
          style: context.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.md),
        _GetStartedCard(
          step: 1,
          title: 'Upload study materials',
          subtitle: 'Add PDFs, Word docs, or images to your classroom',
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
          onTap: () => wsId != null
              ? context.push('/admin/analytics/$wsId')
              : onSelectTab(1),
        ),
      ],
    );
  }
}

class _ReferenceWelcomeBanner extends StatelessWidget {
  const _ReferenceWelcomeBanner({
    required this.displayName,
    required this.workspaceName,
  });

  final String displayName;
  final String workspaceName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1738EA),
            Color(0xFF3734F2),
            Color(0xFF7329EC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: 4,
            bottom: -2,
            width: 195,
            child: Image.asset(
              'assets/mascot/admin_dashboard_hero.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: Spacing.lg,
            top: 12,
            right: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '👋 Welcome back,',
                  style: TextStyle(
                    color: Color(0xFFC9D4FF),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _firstName(displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Here’s what’s happening\nin your class today.',
                  style: TextStyle(
                    color: Color(0xFFC9D4FF),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 190),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white.withAlpha(24)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.group_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          workspaceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Text(
                        '  •  Admin',
                        style: TextStyle(
                          color: Color(0xFFD1D7FF),
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
    );
  }
}

String _firstName(String displayName) {
  final trimmedName = displayName.trim();
  if (trimmedName.isEmpty) return 'Admin';
  return trimmedName.split(RegExp(r'\s+')).first;
}

class _ReferenceStatsPanel extends ConsumerWidget {
  const _ReferenceStatsPanel({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspacesListProvider);
    final workspaces = workspacesAsync.valueOrNull ?? [];
    final workspace = workspaceId == null
        ? workspaces.firstOrNull
        : workspaces.where((item) => item.id == workspaceId).firstOrNull;
    final trend = workspaceId == null
        ? null
        : ref.watch(_dashboardTrendProvider(workspaceId!));
    final trendData = trend?.valueOrNull;
    final activeStudents = trendData?.students
        .where((student) => student.activityCount > 0)
        .length;
    final mastery = trendData?.kpis.overallMastery;
    final masteryChange = trendData?.kpis.masteryChange;

    return Row(
      children: [
        Expanded(
          child: _ReferenceStatCard(
            value: workspacesAsync.isLoading
                ? '—'
                : '${workspace?.studentCount ?? 0}',
            label: 'Students',
            subtitle: activeStudents == null
                ? 'Loading activity'
                : '$activeStudents active',
            icon: Icons.people_rounded,
            color: _dashboardBlue,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _ReferenceStatCard(
            value: workspacesAsync.isLoading
                ? '—'
                : '${workspace?.documentCount ?? 0}',
            label: 'Documents',
            subtitle: 'In workspace',
            icon: Icons.description_rounded,
            color: const Color(0xFFF28B45),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _ReferenceStatCard(
            value: mastery == null ? '—' : _dashboardPercent(mastery),
            label: 'Class Progress',
            subtitle: masteryChange == null
                ? 'Loading trend'
                : '${masteryChange >= 0 ? '↑' : '↓'} '
                    '${_dashboardPercent(masteryChange.abs())}',
            icon: Icons.bar_chart_rounded,
            color: _dashboardPurple,
          ),
        ),
      ],
    );
  }
}

class _ReferenceStatCard extends StatelessWidget {
  const _ReferenceStatCard({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _dashboardSurface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _dashboardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withAlpha(42),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _dashboardMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _dashboardGreen,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _dashboardPercent(double value) =>
    '${(value * 100).toStringAsFixed(0)}%';

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
    final accent = step == 1 ? const Color(0xFF4094FF) : _dashboardPurple;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: _dashboardSurface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _dashboardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(17),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withAlpha(220), const Color(0xFFB7C7FF)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withAlpha(45),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : icon,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _dashboardMuted,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDone)
                const Padding(
                  padding: EdgeInsets.only(right: Spacing.md),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _dashboardMuted,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
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

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.workspaceId});

  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsId = workspaceId;
    return ListView(
      children: [
        const SizedBox(height: Spacing.sm),
        _SettingsTile(
          icon: Icons.notifications_active_rounded,
          title: 'Progress Notifications',
          subtitle: 'Student study completions, streaks, and milestone alerts',
          onTap: () => _showProgressNotificationsSheet(context, ref),
        ),
        _SettingsTile(
          icon: Icons.folder_shared_rounded,
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
            icon: Icons.phonelink_lock_rounded,
            title: 'Screen Time & Blocking',
            subtitle: 'Configure app blocking and XP rules',
            onTap: () => context.push(
              AppRoutes.studentScreenTimeSettings,
            ),
          ),
          _SettingsTile(
            icon: Icons.policy_rounded,
            title: 'Content Moderation',
            subtitle: 'Review flagged questions and documents',
            onTap: () => context.push(
              '${AppRoutes.adminModeration}/$wsId',
            ),
          ),
          _SettingsTile(
            icon: Icons.insights_rounded,
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
        child: Icon(icon, color: Colors.white, size: 22),
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

void _showProgressNotificationsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0D1A30),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: Color(0xFF213451)),
    ),
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final isEnabled =
              ref.watch(adminProgressNotificationsEnabledProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withAlpha(35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF06B6D4).withAlpha(80),
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFF06B6D4),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Child Progress Alerts',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Real-time study updates for parents',
                              style: TextStyle(
                                color: Color(0xFFA7B5CF),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),
                  Container(
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111F37),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF213451)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Progress Notifications',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Receive notifications when your child completes study sessions, achieves streaks, or levels up.',
                                style: TextStyle(
                                  color: Color(0xFFA7B5CF),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Switch(
                          value: isEnabled,
                          onChanged: (val) {
                            ref
                                .read(adminProgressNotificationsEnabledProvider.notifier)
                                .setEnabled(val);
                          },
                          activeThumbColor: const Color(0xFF06B6D4),
                          activeTrackColor: const Color(0xFF06B6D4).withAlpha(80),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  const Text(
                    'INCLUDED ALERTS',
                    style: TextStyle(
                      color: Color(0xFFA7B5CF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  const _ProgressAlertItem(
                    icon: Icons.school_rounded,
                    color: Color(0xFF3B82F6),
                    title: 'Session Completions',
                    subtitle: 'Subject, topic, accuracy, and XP earned per session',
                  ),
                  const SizedBox(height: Spacing.xs),
                  const _ProgressAlertItem(
                    icon: Icons.local_fire_department_rounded,
                    color: Color(0xFFF97316),
                    title: 'Daily Streak Milestones',
                    subtitle: '3-day, 5-day, 7-day+ continuous learning streaks',
                  ),
                  const SizedBox(height: Spacing.xs),
                  const _ProgressAlertItem(
                    icon: Icons.military_tech_rounded,
                    color: Color(0xFFF59E0B),
                    title: 'Mastery & Level Ups',
                    subtitle: 'New levels reached and topic mastery milestones',
                  ),
                  const SizedBox(height: Spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _ProgressAlertItem extends StatelessWidget {
  const _ProgressAlertItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFA7B5CF),
                    fontSize: 11.5,
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
