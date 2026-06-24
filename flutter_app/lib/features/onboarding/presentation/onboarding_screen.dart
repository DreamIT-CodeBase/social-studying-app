import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';

/// Sprint 6.9 — first-launch admin onboarding wizard.
///
/// Two screens of state in one widget:
///
/// 1. **Role choice** — "I'm a parent" vs "I'm a teacher". The choice
///    seeds the default workspace name + description in step 2, and
///    affects nothing else; both flow into the same workspace
///    creation API.
/// 2. **Workspace setup** — name + description pre-filled per the
///    role, with a Create button that calls the workspace repository
///    and pushes to the admin dashboard on success.
///
/// **Gating**: the router redirects authenticated admins with zero
/// workspace memberships to ``/admin/onboarding``. The redirect
/// stops firing the moment a workspace exists, so this screen
/// genuinely only appears on first launch.
///
/// Why the role question even matters
/// ----------------------------------
/// The app supports two markets (families + schools) with the same
/// codebase. The role choice picks a default workspace name +
/// description ("Family Study" / "My Class") that the admin can
/// override in step 2. Both flow into the same ``createWorkspace``
/// call — the role isn't persisted on the workspace itself, just
/// used to seed the form.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { roleChoice, workspaceSetup }

enum AdminRole {
  parent('Parent', 'Family Study', 'Daily learning at home.'),
  teacher('Teacher', 'My Class', 'Classroom learning space.');

  const AdminRole(this.label, this.defaultWorkspaceName, this.defaultDescription);

  final String label;
  final String defaultWorkspaceName;
  final String defaultDescription;
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.roleChoice;
  AdminRole? _role;

  late final TextEditingController _nameController =
      TextEditingController();
  late final TextEditingController _descriptionController =
      TextEditingController();

  bool _creating = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_step) {
            _Step.roleChoice => _RoleChoiceView(
                key: const ValueKey('role'),
                onSelect: _onRoleSelected,
              ),
            _Step.workspaceSetup => _WorkspaceSetupView(
                key: const ValueKey('workspace'),
                role: _role!,
                nameController: _nameController,
                descriptionController: _descriptionController,
                nameError: _nameError,
                creating: _creating,
                onBack: () => setState(() => _step = _Step.roleChoice),
                onCreate: _createWorkspace,
              ),
          },
        ),
      ),
    );
  }

  void _onRoleSelected(AdminRole role) {
    setState(() {
      _role = role;
      _nameController.text = role.defaultWorkspaceName;
      _descriptionController.text = role.defaultDescription;
      _step = _Step.workspaceSetup;
    });
  }

  Future<void> _createWorkspace() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Workspace name is required');
      return;
    }

    setState(() {
      _nameError = null;
      _creating = true;
    });

    final description = _descriptionController.text.trim();

    try {
      await ref.read(workspacesListProvider.notifier).createWorkspace(
            name: name,
            description: description.isEmpty ? null : description,
          );
      if (!mounted) return;
      // Sprint 6 /review fix — re-hydrate auth so ``user.workspace
      // Memberships`` includes the new workspace. Without this, the
      // router's redirect re-runs against stale auth state and bounces
      // the admin back here, hitting a 409 on the next create attempt.
      await ref.read(authNotifierProvider.notifier).refresh();
      if (!mounted) return;
      // Push to the admin dashboard. The redirect guard that brought
      // us here clears now that the user has a workspace.
      context.go(AppRoutes.adminDashboard);
    } on WorkspaceNameConflictException catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _nameError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      _snack(context, 'Could not create workspace: $error');
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────
// Step 1 — role choice
// ─────────────────────────────────────────────────────────────────────────


class _RoleChoiceView extends StatelessWidget {
  const _RoleChoiceView({super.key, required this.onSelect});

  final ValueChanged<AdminRole> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Spacing.xxl),
          const _Hero(),
          const SizedBox(height: Spacing.xxl),
          Text(
            'Welcome!',
            textAlign: TextAlign.center,
            style: context.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Tell us who you are. We will set up your first workspace.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          for (final role in AdminRole.values) ...[
            _RoleCard(
              role: role,
              onTap: () => onSelect(role),
            ),
            const SizedBox(height: Spacing.md),
          ],
        ],
      ),
    );
  }
}


class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(
          Icons.auto_stories_rounded,
          color: AppColors.primary,
          size: 56,
        ),
      ),
    );
  }
}


class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onTap});

  final AdminRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isParent = role == AdminRole.parent;
    final (icon, blurb) = isParent
        ? (
            Icons.family_restroom_rounded,
            'Build a study habit at home with your child.',
          )
        : (
            Icons.school_rounded,
            'Personalised practice for your classroom.',
          );
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "I'm a ${role.label}",
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      blurb,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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


// ─────────────────────────────────────────────────────────────────────────
// Step 2 — workspace setup form
// ─────────────────────────────────────────────────────────────────────────


class _WorkspaceSetupView extends StatelessWidget {
  const _WorkspaceSetupView({
    super.key,
    required this.role,
    required this.nameController,
    required this.descriptionController,
    required this.nameError,
    required this.creating,
    required this.onBack,
    required this.onCreate,
  });

  final AdminRole role;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? nameError;
  final bool creating;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button + step indicator.
          Row(
            children: [
              IconButton(
                onPressed: creating ? null : onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              Text(
                'Step 2 of 2',
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            "Name your workspace",
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            role == AdminRole.parent
                ? "A space for your child's practice. "
                    "You can change the name later."
                : "A space for your students. "
                    "You can change the name later.",
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xl),
          TextField(
            controller: nameController,
            enabled: !creating,
            decoration: InputDecoration(
              labelText: 'Workspace name',
              errorText: nameError,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.workspaces_rounded),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: descriptionController,
            enabled: !creating,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            maxLines: 2,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: creating ? null : onCreate,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            icon: creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(creating ? 'Creating…' : 'Create workspace'),
          ),
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}


void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
