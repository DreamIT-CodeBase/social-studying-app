import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/admin/users/data/demo_users_repository.dart';
import 'package:social_study_app/features/admin/users/presentation/users_notifier.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/shared/models/invite_code.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Workspace user management (Sprint 4.2).
///
/// Renders inside the Students tab of the admin home Scaffold, so it
/// carries no AppBar of its own. Shows the roster for one workspace and
/// supports inviting students by code, adding users directly, changing
/// roles, and removing users.
///
/// Handles all four states (Boil the Lake): loading, error, empty (the
/// invite card still shows so the admin can act), and a populated
/// roster.
class WorkspaceUsersScreen extends ConsumerWidget {
  const WorkspaceUsersScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(workspaceUsersListProvider(workspaceId));

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref
                .read(workspaceUsersListProvider(workspaceId).notifier)
                .refresh();
            await ref.read(workspaceUsersListProvider(workspaceId).future);
          },
          child: usersAsync.when(
            data: (users) => _Roster(workspaceId: workspaceId, users: users),
            loading: () => const LoadingIndicator(message: 'Loading roster…'),
            error: (error, _) => ListView(
              // ListView so the error state stays pull-to-refreshable.
              children: [
                SizedBox(
                  height: context.screenHeight * 0.7,
                  child: ErrorView(
                    message: error.toString(),
                    onRetry: () => ref
                        .read(workspaceUsersListProvider(workspaceId).notifier)
                        .refresh(),
                  ),
                ),
              ],
            ),
          ),
        ),
        // The "Add" button only shows once a roster has rendered.
        if (usersAsync.hasValue)
          Positioned(
            bottom: Spacing.lg,
            right: Spacing.lg,
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _openAddUserForm(context, ref, workspaceId),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add'),
            ),
          ),
      ],
    );
  }
}

/// Sorts admins above students, then alphabetically, so teachers and
/// parents are easy to find at the top of the roster.
int _rosterOrder(User a, User b) {
  int rank(UserRole r) => r == UserRole.student ? 1 : 0;
  final byRole = rank(a.role).compareTo(rank(b.role));
  if (byRole != 0) return byRole;
  return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
}

class _Roster extends StatelessWidget {
  const _Roster({required this.workspaceId, required this.users});

  final String workspaceId;
  final List<User> users;

  @override
  Widget build(BuildContext context) {
    final sorted = [...users]..sort(_rosterOrder);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        // Leave room for the floating Add button.
        96,
      ),
      children: [
        _InviteCard(workspaceId: workspaceId),
        const SizedBox(height: Spacing.lg),
        Text(
          users.isEmpty
              ? 'Roster'
              : '${users.length} ${users.length == 1 ? 'member' : 'members'}',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
            child: Column(
              children: [
                Icon(
                  Icons.group_outlined,
                  size: 40,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'No members yet',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Share an invite code or add a user directly.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          for (final user in sorted) ...[
            _UserRow(workspaceId: workspaceId, user: user),
            const SizedBox(height: Spacing.sm),
          ],
      ],
    );
  }
}

/// Tappable card that mints a fresh invite code and shows it in a
/// dialog. Carries its own busy state so a slow backend can't be
/// double-tapped into two codes.
class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: context.colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _generating ? null : _generate,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.add_link_rounded,
                color: context.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite students',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Generate a code students enter to join',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onPrimaryContainer
                            .withAlpha(204),
                      ),
                    ),
                  ],
                ),
              ),
              if (_generating)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colorScheme.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final invite = await ref
          .read(workspacesListProvider.notifier)
          .generateInviteCode(widget.workspaceId);
      if (!mounted) return;
      setState(() => _generating = false);
      await showDialog<void>(
        context: context,
        builder: (_) => _InviteCodeDialog(invite: invite),
      );
    } on WorkspaceNotFoundException {
      if (!mounted) return;
      setState(() => _generating = false);
      _snack(context, 'This workspace is no longer available');
    } catch (error) {
      if (!mounted) return;
      setState(() => _generating = false);
      _snack(context, 'Could not generate a code: $error');
    }
  }
}

/// Shows a freshly minted invite code with a copy-to-clipboard action.
class _InviteCodeDialog extends StatelessWidget {
  const _InviteCodeDialog({required this.invite});

  final GeneratedInviteCode invite;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share this code with students. They enter it on the join '
            'screen to be added to the workspace.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.lg,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              invite.code,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            '${invite.usageLabel} • ${_expiryLabel()}',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: invite.code));
            if (context.mounted) {
              Navigator.of(context).pop();
              _snack(context, 'Code copied to clipboard');
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy'),
        ),
      ],
    );
  }

  String _expiryLabel() {
    final expiresAt = invite.expiresAt;
    if (expiresAt == null) return 'Never expires';
    final days = expiresAt.difference(DateTime.now()).inDays;
    if (days < 1) return 'Expires today';
    return 'Expires in $days days';
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.workspaceId, required this.user});

  final String workspaceId;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only students get the tap-to-progress affordance — admin/owner
    // rows don't have a progress view (they don't answer questions in
    // the workspace they manage).
    final canDrillIn = user.role == UserRole.student;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canDrillIn
            ? () => context.push(
                  '/admin/students/$workspaceId/${user.id}/progress'
                  '?name=${Uri.encodeQueryComponent(user.displayName)}',
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: context.colorScheme.primaryContainer,
                child: Text(
                  _initial(user.displayName),
                  style: TextStyle(
                    color: context.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              _RoleChip(role: user.role),
              _UserMenu(workspaceId: workspaceId, user: user),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (role) {
      UserRole.tenantAdmin => (
          'Owner',
          context.colorScheme.tertiaryContainer,
          context.colorScheme.onTertiaryContainer,
        ),
      UserRole.workspaceAdmin => (
          'Admin',
          context.colorScheme.secondaryContainer,
          context.colorScheme.onSecondaryContainer,
        ),
      UserRole.student => (
          'Student',
          context.colorScheme.surfaceContainerHighest,
          context.colorScheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Per-user overflow menu. The tenant owner has no menu — that role is
/// not reassignable or removable from a workspace screen.
class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.workspaceId, required this.user});

  final String workspaceId;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user.role == UserRole.tenantAdmin) {
      // Keep horizontal rhythm aligned with rows that do have a menu.
      return const SizedBox(width: 48);
    }

    final isStudent = user.role == UserRole.student;
    return PopupMenuButton<_UserAction>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: context.colorScheme.onSurfaceVariant,
      ),
      onSelected: (action) => switch (action) {
        _UserAction.promote => _changeRole(context, ref, UserRole.workspaceAdmin),
        _UserAction.demote => _changeRole(context, ref, UserRole.student),
        _UserAction.remove => _confirmRemove(context, ref),
      },
      itemBuilder: (_) => [
        if (isStudent)
          const PopupMenuItem(
            value: _UserAction.promote,
            child: ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Make admin'),
              contentPadding: EdgeInsets.zero,
            ),
          )
        else
          const PopupMenuItem(
            value: _UserAction.demote,
            child: ListTile(
              leading: Icon(Icons.school_outlined),
              title: Text('Make student'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: _UserAction.remove,
          child: ListTile(
            leading: Icon(Icons.person_remove_outlined),
            title: Text('Remove'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
  ) async {
    try {
      await ref
          .read(workspaceUsersListProvider(workspaceId).notifier)
          .changeRole(userId: user.id, role: role);
      if (context.mounted) {
        _snack(
          context,
          '${user.displayName} is now '
          '${role == UserRole.student ? 'a student' : 'an admin'}',
        );
      }
    } on UserNotFoundException {
      if (context.mounted) _snack(context, 'That user no longer exists');
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'Could not change role: $error');
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove user?'),
        content: Text(
          '${user.displayName} will lose access to this workspace. '
          'Their progress is kept and restored if they rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(workspaceUsersListProvider(workspaceId).notifier)
          .removeMember(user.id);
      if (context.mounted) {
        _snack(context, '${user.displayName} removed');
      }
    } on UserNotFoundException {
      if (context.mounted) _snack(context, 'That user was already removed');
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'Could not remove user: $error');
      }
    }
  }
}

enum _UserAction { promote, demote, remove }

/// Opens the add-user bottom sheet and confirms the result.
Future<void> _openAddUserForm(
  BuildContext context,
  WidgetRef ref,
  String workspaceId,
) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _UserFormSheet(workspaceId: workspaceId),
  );
  if (added == true && context.mounted) {
    _snack(context, 'User added');
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Direct user-creation form. Pops `true` on success. An email conflict
/// (409) shows inline on the email field.
class _UserFormSheet extends ConsumerStatefulWidget {
  const _UserFormSheet({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<_UserFormSheet> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();

  UserRole _role = UserRole.student;
  String? _emailError;
  String? _nameError;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.sm,
        Spacing.xl,
        Spacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add User',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: 'Display name',
              hintText: 'e.g. Maya Chen',
              errorText: _nameError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _emailController,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'name@example.com',
              errorText: _emailError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Role',
            style: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(
                value: UserRole.student,
                label: Text('Student'),
                icon: Icon(Icons.school_outlined),
              ),
              ButtonSegment(
                value: UserRole.workspaceAdmin,
                label: Text('Admin'),
                icon: Icon(Icons.shield_outlined),
              ),
            ],
            selected: {_role},
            onSelectionChanged: _submitting
                ? null
                : (selection) => setState(() => _role = selection.first),
          ),
          const SizedBox(height: Spacing.xl),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Add User'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    var valid = true;
    if (name.isEmpty) {
      _nameError = 'Enter a display name';
      valid = false;
    }
    // Minimal shape check — the backend is the real authority on
    // address validity, so we only catch obviously empty/malformed input.
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _emailError = 'Enter a valid email address';
      valid = false;
    }
    if (!valid) {
      setState(() {});
      return;
    }

    setState(() {
      _submitting = true;
      _emailError = null;
      _nameError = null;
    });

    try {
      await ref
          .read(workspaceUsersListProvider(widget.workspaceId).notifier)
          .createUser(email: email, displayName: name, role: _role);
      if (mounted) Navigator.of(context).pop(true);
    } on UserEmailConflictException catch (error) {
      setState(() {
        _submitting = false;
        _emailError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(context, 'Could not add user: $error');
    }
  }
}
