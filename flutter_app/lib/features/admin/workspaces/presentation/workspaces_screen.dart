import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/admin/workspaces/data/demo_workspaces_repository.dart';
import 'package:social_study_app/features/admin/workspaces/presentation/workspaces_notifier.dart';
import 'package:social_study_app/shared/models/workspace.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Workspace management (Sprint 4.1).
///
/// A standalone pushed screen — reached from the admin Settings tab —
/// that lists every workspace in the tenant and supports the full
/// create / edit / delete lifecycle. Mutations route through
/// [WorkspacesList], which re-fetches after each change so the derived
/// `*_count` fields stay honest.
///
/// Handles all four states (Boil the Lake): loading, error, empty, and
/// a populated list.
class WorkspacesScreen extends ConsumerWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspacesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workspaces',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      // An admin may create and manage any number of workspaces.
      // Keep this available whenever the list has loaded, including when the
      // first workspace already exists.
      floatingActionButton: workspacesAsync.hasValue
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Workspace'),
            )
          : null,
      body: workspacesAsync.when(
        data: (workspaces) => workspaces.isEmpty
            ? _EmptyState(onCreate: () => _openForm(context, ref))
            : _WorkspacesList(workspaces: workspaces),
        loading: () => const LoadingIndicator(message: 'Loading workspaces…'),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(workspacesListProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

/// Opens the create/edit bottom sheet. When [existing] is null the sheet
/// creates a workspace; otherwise it patches that one. Shows a SnackBar
/// confirming the result.
Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  Workspace? existing,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _WorkspaceFormSheet(existing: existing),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Workspace created' : 'Workspace updated',
          ),
        ),
      );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView keeps pull-to-refresh reachable on the empty state.
      children: [
        SizedBox(
          height: context.screenHeight * 0.7,
          child: EmptyStateView(
            icon: Icons.workspaces_outline,
            title: 'No workspaces yet',
            subtitle: 'Create a workspace to organize study materials and '
                'students into a classroom or family group.',
            action: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Workspace'),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspacesList extends ConsumerWidget {
  const _WorkspacesList({required this.workspaces});

  final List<Workspace> workspaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(workspacesListProvider.notifier).refresh();
        await ref.read(workspacesListProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.lg,
          Spacing.lg,
          Spacing.xl,
        ),
        children: [
          // Workspaces are independent classrooms or family groups.
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: context.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Create a workspace for each classroom or family group you manage.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          for (final ws in workspaces) ...[
            _WorkspaceCard(workspace: ws),
            const SizedBox(height: Spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceCard extends ConsumerWidget {
  const _WorkspaceCard({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.workspaces_rounded,
                    color: context.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (workspace.description.isNotEmpty) ...[
                        const SizedBox(height: Spacing.xs),
                        Text(
                          workspace.description,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                _WorkspaceMenu(workspace: workspace),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                _CountChip(
                  icon: Icons.people_rounded,
                  value: workspace.studentCount,
                  label: 'students',
                ),
                _CountChip(
                  icon: Icons.description_rounded,
                  value: workspace.documentCount,
                  label: 'documents',
                ),
                _CountChip(
                  icon: Icons.shield_rounded,
                  value: workspace.adminCount,
                  label: 'admins',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colorScheme.onSurfaceVariant),
          const SizedBox(width: Spacing.xs),
          Text(
            '$value $label',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overflow menu — edit and delete. Delete confirms first; both actions
/// surface failures via SnackBar so the list stays put.
class _WorkspaceMenu extends ConsumerWidget {
  const _WorkspaceMenu({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_WorkspaceAction>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: context.colorScheme.onSurfaceVariant,
      ),
      onSelected: (action) => switch (action) {
        _WorkspaceAction.edit => _openForm(context, ref, existing: workspace),
        _WorkspaceAction.delete => _confirmDelete(context, ref),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _WorkspaceAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _WorkspaceAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete workspace?'),
        content: Text(
          "'${workspace.name}' and its documents, students, and progress "
          'will no longer be accessible. This cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(workspacesListProvider.notifier)
          .deleteWorkspace(workspace.id);
      if (context.mounted) {
        _snack(context, "'${workspace.name}' deleted");
      }
    } on WorkspaceNotFoundException {
      // Already gone — the refresh that follows still corrects the list.
      if (context.mounted) {
        _snack(context, 'Workspace was already removed');
      }
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'Could not delete workspace: $error');
      }
    }
  }
}

enum _WorkspaceAction { edit, delete }

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Create/edit form. Pops `true` when a save succeeds. A name conflict
/// (409) is shown inline on the name field rather than as a SnackBar so
/// the admin can correct it without losing the rest of the form.
class _WorkspaceFormSheet extends ConsumerStatefulWidget {
  const _WorkspaceFormSheet({this.existing});

  final Workspace? existing;

  @override
  ConsumerState<_WorkspaceFormSheet> createState() =>
      _WorkspaceFormSheetState();
}

class _WorkspaceFormSheetState extends ConsumerState<_WorkspaceFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String? _nameError;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the keyboard.
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
            _isEdit ? 'Edit Workspace' : 'New Workspace',
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
              labelText: 'Name',
              hintText: 'e.g. Grade 5 Science',
              errorText: _nameError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _descriptionController,
            enabled: !_submitting,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'What this workspace is for',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
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
                : Text(_isEdit ? 'Save Changes' : 'Create Workspace'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a workspace name');
      return;
    }

    setState(() {
      _submitting = true;
      _nameError = null;
    });

    final notifier = ref.read(workspacesListProvider.notifier);
    final description = _descriptionController.text.trim();
    try {
      if (_isEdit) {
        await notifier.updateWorkspace(
          workspaceId: widget.existing!.id,
          name: name,
          description: description,
        );
      } else {
        await notifier.createWorkspace(
          name: name,
          description: description.isEmpty ? null : description,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on WorkspaceNameConflictException catch (error) {
      setState(() {
        _submitting = false;
        _nameError = error.message;
      });
    } on WorkspaceNotFoundException {
      // The workspace being edited vanished — close and let the list
      // refresh reveal that.
      if (mounted) Navigator.of(context).pop(false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(context, 'Could not save workspace: $error');
    }
  }
}
