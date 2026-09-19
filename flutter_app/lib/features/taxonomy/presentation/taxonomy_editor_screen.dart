import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/presentation/widgets/topic_tree_builder.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Editable view of the workspace canonical taxonomy (Sprint 4.3).
///
/// Loads the current taxonomy into a local editable copy, lets the
/// admin rename / re-parent / edit / delete topics, and PUTs the result
/// with optimistic concurrency. A 409 reload-and-warn path keeps two
/// concurrent admins from silently clobbering each other; a 422 maps
/// the backend's validation message inline.
///
/// Re-parenting is supported via two paths:
/// 1. **Drag-and-drop** — long-press a topic, drag onto another topic
///    (= become its child) or onto the "Make root" target at the top
///    (= clear parent). Drops that would create a cycle are refused.
/// 2. **The edit sheet's parent dropdown** — the comprehensive path
///    for desktop/accessibility users; lists every non-descendant
///    topic + "None (root)".
///
/// State lives in [_TaxonomyEditorScreenState] (not a Riverpod notifier)
/// because the editable copy is intrinsically local to this screen and
/// nothing else needs to observe it.
class TaxonomyEditorScreen extends ConsumerStatefulWidget {
  const TaxonomyEditorScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<TaxonomyEditorScreen> createState() =>
      _TaxonomyEditorScreenState();
}

class _TaxonomyEditorScreenState extends ConsumerState<TaxonomyEditorScreen> {
  /// Current editable list. `null` until the initial load resolves.
  List<CanonicalTopic>? _topics;

  /// The snapshot we loaded. Used for the dirty check (compare current
  /// `_topics` against this) and for full-reset after a 409 reload.
  List<CanonicalTopic>? _loadedSnapshot;

  /// `taxonomy_version` we read at load time. The save PUT sends this
  /// so the backend can CAS-reject concurrent edits.
  int? _loadedVersion;

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _validationError;

  TaxonomyRepository get _repo => ref.read(taxonomyRepositoryProvider);

  bool get _dirty =>
      _topics != null &&
      _loadedSnapshot != null &&
      !listEquals(_topics, _loadedSnapshot);

  bool get _canSave => _dirty && !_saving && _loading == false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _validationError = null;
    });
    try {
      final taxonomy = await _repo.get(workspaceId: widget.workspaceId);
      setState(() {
        _topics = [...taxonomy.topics];
        _loadedSnapshot = [...taxonomy.topics];
        _loadedVersion = taxonomy.taxonomyVersion;
        _loading = false;
      });
    } on TaxonomyWorkspaceNotFoundException {
      setState(() {
        _loadError = 'This workspace is no longer available.';
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit knowledge map',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Organize topics and learning order',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          _SaveAction(enabled: _canSave, saving: _saving, onSave: _save),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const LoadingIndicator(message: 'Loading taxonomy…');
    }
    if (_loadError != null) {
      return ErrorView(message: _loadError!, onRetry: _load);
    }
    final topics = _topics;
    if (topics == null || topics.isEmpty) {
      return const EmptyStateView(
        icon: Icons.account_tree_outlined,
        title: 'No topics to edit',
        subtitle: 'Upload a document so the AI can extract topics, then come '
            'back here to refine the taxonomy.',
      );
    }
    final rows = buildTopicTree(topics);
    return Column(
      children: [
        if (_validationError != null)
          _ValidationBanner(
            message: _validationError!,
            onDismiss: () => setState(() => _validationError = null),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xxxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EditorOverview(
                        topics: topics,
                        version: _loadedVersion ?? 0,
                        dirty: _dirty,
                        onDiscard: _discardChanges,
                      ),
                      const SizedBox(height: Spacing.lg),
                      _MakeRootDropTarget(
                        onDropTopic: (topic) => _reparent(topic.id, null),
                      ),
                      const SizedBox(height: Spacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Topic structure',
                              style: context.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${rows.length} topics',
                            style: context.textTheme.labelLarge?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Tap a topic to edit it. Long-press and drag to change its parent.',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      for (var index = 0; index < rows.length; index++) ...[
                        _EditableTopicRow(
                          row: rows[index],
                          topics: topics,
                          onTap: () => _openEditSheet(rows[index].topic),
                          onDelete: () => _confirmDelete(rows[index].topic),
                          canAcceptDrop: (dragged) =>
                              _canReparent(dragged.id, rows[index].topic.id),
                          onAcceptDrop: (dragged) =>
                              _reparent(dragged.id, rows[index].topic.id),
                        ),
                        if (index != rows.length - 1)
                          const SizedBox(height: Spacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Editing primitives ──────────────────────────────────────────────────

  /// Replace the topic with [id] using [replace] applied to the current
  /// instance. Clears any dirty-state validation banner so the admin
  /// sees fresh feedback on the next save.
  void _mutate(String id, CanonicalTopic Function(CanonicalTopic) replace) {
    setState(() {
      _validationError = null;
      _topics = [
        for (final topic in _topics!)
          if (topic.id == id) replace(topic) else topic,
      ];
    });
  }

  void _reparent(String id, String? newParentId) {
    _mutate(id, (t) => t.copyWith(parentId: newParentId));
  }

  void _applyEdit(String id, _TopicDraft draft) {
    _mutate(
        id,
        (t) => t.copyWith(
              name: draft.name,
              description: draft.description,
              aliases: draft.aliases,
              complexityLevel: draft.complexityLevel,
              parentId: draft.parentId,
            ));
  }

  void _deleteTopic(String id) {
    setState(() {
      _validationError = null;
      _topics = _topics!.where((t) => t.id != id).toList();
    });
  }

  void _discardChanges() {
    if (!_dirty) return;
    setState(() {
      _topics = [..._loadedSnapshot!];
      _validationError = null;
    });
  }

  /// True iff dragging [draggedId] onto [targetId] is a legal re-parent.
  /// Rejects self-drops and any drop onto a descendant (cycle).
  bool _canReparent(String draggedId, String targetId) {
    if (draggedId == targetId) return false;
    final descendants = _descendantsOf(draggedId);
    return !descendants.contains(targetId);
  }

  Set<String> _descendantsOf(String topicId) {
    final out = <String>{};
    final stack = <String>[topicId];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      for (final t in _topics!) {
        if (t.parentId == id && out.add(t.id)) stack.add(t.id);
      }
    }
    return out;
  }

  // ── Sheets / dialogs ────────────────────────────────────────────────────

  Future<void> _openEditSheet(CanonicalTopic topic) async {
    final updated = await showModalBottomSheet<_TopicDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TopicEditSheet(
        topic: topic,
        // Valid parents = every other topic that's NOT a descendant of
        // this one. Prevents the dropdown from offering a cycle.
        candidateParents: _topics!
            .where(
              (t) =>
                  t.id != topic.id && !_descendantsOf(topic.id).contains(t.id),
            )
            .toList(),
      ),
    );
    if (updated != null) _applyEdit(topic.id, updated);
  }

  Future<void> _confirmDelete(CanonicalTopic topic) async {
    final hasChildren = _topics!.any((t) => t.parentId == topic.id);
    if (hasChildren) {
      _snack(
        "Re-parent the subtopics under '${topic.name}' before deleting it.",
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete topic?'),
        content: Text(
          "'${topic.name}' will be removed from the taxonomy. This change "
          "isn't saved until you tap Save.",
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
    if (confirmed == true) _deleteTopic(topic.id);
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _validationError = null;
    });
    try {
      final updated = await _repo.update(
        workspaceId: widget.workspaceId,
        expectedVersion: _loadedVersion!,
        topics: _topics!,
      );
      if (!mounted) return;
      setState(() {
        _topics = [...updated.topics];
        _loadedSnapshot = [...updated.topics];
        _loadedVersion = updated.taxonomyVersion;
        _saving = false;
      });
      _snack('Taxonomy saved');
    } on TaxonomyVersionConflictException {
      // Someone else got there first. Reload the canonical state and
      // tell the admin so they don't think their last edit landed.
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _saving = false);
      await _showConflictDialog();
    } on TaxonomyValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _validationError = e.message;
      });
    } on TaxonomyWorkspaceNotFoundException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _loadError = 'This workspace is no longer available.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save: $error');
    }
  }

  Future<void> _showConflictDialog() {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edits out of date'),
        content: const Text(
          'Another admin saved a new version of this taxonomy. Your '
          'local edits have been discarded and the latest version is '
          'shown — re-apply your changes if you still need them.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// AppBar Save action
// ─────────────────────────────────────────────────────────────────────────

class _EditorOverview extends StatelessWidget {
  const _EditorOverview({
    required this.topics,
    required this.version,
    required this.dirty,
    required this.onDiscard,
  });

  final List<CanonicalTopic> topics;
  final int version;
  final bool dirty;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final rootCount = topics.where((topic) => topic.parentId == null).length;
    return Container(
      key: const ValueKey('taxonomy_editor_overview'),
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withAlpha(35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.schema_rounded,
                  color: colors.onPrimary,
                  size: 25,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shape the learning path',
                      style: context.textTheme.titleLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Parent topics are taught before their subtopics. Keep '
                      'the structure focused and easy to follow.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer.withAlpha(190),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _EditorStatusChip(
                icon: Icons.bubble_chart_rounded,
                label: '${topics.length} topics',
              ),
              _EditorStatusChip(
                icon: Icons.account_tree_rounded,
                label: '$rootCount roots',
              ),
              _EditorStatusChip(
                icon: Icons.history_rounded,
                label: 'Version $version',
              ),
              _EditorStatusChip(
                icon: dirty ? Icons.edit_note_rounded : Icons.check_rounded,
                label: dirty ? 'Unsaved changes' : 'All changes saved',
                emphasized: dirty,
              ),
            ],
          ),
          if (dirty) ...[
            const SizedBox(height: Spacing.md),
            TextButton.icon(
              onPressed: onDiscard,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Discard local changes'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorStatusChip extends StatelessWidget {
  const _EditorStatusChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: emphasized ? colors.secondaryContainer : colors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: emphasized
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: emphasized
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveAction extends StatelessWidget {
  const _SaveAction({
    required this.enabled,
    required this.saving,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.sm),
      child: TextButton.icon(
        onPressed: enabled ? onSave : null,
        icon: saving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_rounded, size: 18),
        label: Text(saving ? 'Saving…' : 'Save'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Validation banner (server 422)
// ─────────────────────────────────────────────────────────────────────────

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colorScheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.sm,
        Spacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: context.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: context.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// "Make root" drop target
// ─────────────────────────────────────────────────────────────────────────

class _MakeRootDropTarget extends StatelessWidget {
  const _MakeRootDropTarget({required this.onDropTopic});

  final void Function(CanonicalTopic) onDropTopic;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CanonicalTopic>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDropTopic(details.data),
      builder: (context, candidate, _) {
        final highlighted = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            Spacing.xs,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          decoration: BoxDecoration(
            color: highlighted
                ? context.colorScheme.primaryContainer
                : context.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted
                  ? context.colorScheme.primary
                  : context.colorScheme.outlineVariant,
              width: highlighted ? 2 : 1,
              style: highlighted ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.north_east_rounded,
                size: 18,
                color: context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  highlighted
                      ? 'Drop here to make this a root topic'
                      : 'Drag a topic here to clear its parent',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: highlighted
                        ? context.colorScheme.onPrimaryContainer
                        : context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Topic row
// ─────────────────────────────────────────────────────────────────────────

class _EditableTopicRow extends StatelessWidget {
  const _EditableTopicRow({
    required this.row,
    required this.topics,
    required this.onTap,
    required this.onDelete,
    required this.canAcceptDrop,
    required this.onAcceptDrop,
  });

  final TopicTreeRow row;
  final List<CanonicalTopic> topics;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool Function(CanonicalTopic dragged) canAcceptDrop;
  final void Function(CanonicalTopic dragged) onAcceptDrop;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CanonicalTopic>(
      onWillAcceptWithDetails: (details) => canAcceptDrop(details.data),
      onAcceptWithDetails: (details) => onAcceptDrop(details.data),
      builder: (context, candidate, _) {
        final highlighted = candidate.isNotEmpty;
        return Padding(
          padding: EdgeInsets.only(
              left: row.depth * (context.isMobile ? 10.0 : 20.0)),
          child: LongPressDraggable<CanonicalTopic>(
            data: row.topic,
            delay: const Duration(milliseconds: 250),
            feedback: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.md,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.drag_indicator_rounded,
                      color: context.colorScheme.onPrimaryContainer,
                      size: 18,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      row.topic.name,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: context.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: _RowCard(
                row: row,
                highlighted: false,
                onTap: null,
                onDelete: null,
              ),
            ),
            child: _RowCard(
              row: row,
              highlighted: highlighted,
              onTap: onTap,
              onDelete: onDelete,
            ),
          ),
        );
      },
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.row,
    required this.highlighted,
    required this.onTap,
    required this.onDelete,
  });

  final TopicTreeRow row;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final depthColor = row.depth == 0 ? colors.primary : colors.tertiary;
    final rowSurface = isDark ? colors.surfaceContainerHighest : colors.surface;
    final insetSurface =
        isDark ? colors.surface : colors.surfaceContainerHighest;
    return Container(
      key: ValueKey('taxonomy_editor_row_${row.topic.id}'),
      decoration: BoxDecoration(
        color: highlighted ? colors.primaryContainer : rowSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? colors.primary : colors.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(55)
                : colors.shadow.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sm,
              Spacing.md,
              Spacing.xs,
              Spacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant.withAlpha(125),
                ),
                const SizedBox(width: Spacing.xs),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: depthColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    row.childCount > 0
                        ? Icons.hub_outlined
                        : Icons.circle_outlined,
                    size: 20,
                    color: depthColor,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.depth == 0
                            ? 'ROOT CONCEPT'
                            : 'LEVEL ${row.depth + 1}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: depthColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.topic.name,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (row.topic.aliases.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          row.topic.aliases.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (row.topic.complexityLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: insetSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'L${_formatLevel(row.topic.complexityLevel!)}',
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Delete topic',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colors.error,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatLevel(double level) => level == level.toInt()
      ? level.toInt().toString()
      : level.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────────────────────
// Edit sheet — rename / description / aliases / complexity / parent
// ─────────────────────────────────────────────────────────────────────────

/// What the edit sheet hands back to the screen when the admin taps
/// Apply. The screen converts this into a [CanonicalTopic.copyWith] —
/// see `_applyEdit`.
class _TopicDraft {
  const _TopicDraft({
    required this.name,
    required this.description,
    required this.aliases,
    required this.complexityLevel,
    required this.parentId,
  });

  final String name;
  final String? description;
  final List<String> aliases;
  final double? complexityLevel;
  final String? parentId;
}

class _TopicEditSheet extends StatefulWidget {
  const _TopicEditSheet({
    required this.topic,
    required this.candidateParents,
  });

  final CanonicalTopic topic;

  /// Topics the admin may pick as the new parent — everything except
  /// this topic itself and its descendants (cycle prevention).
  final List<CanonicalTopic> candidateParents;

  @override
  State<_TopicEditSheet> createState() => _TopicEditSheetState();
}

class _TopicEditSheetState extends State<_TopicEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _aliasesController;

  // Special sentinel for the "no parent" option in the dropdown.
  static const _rootSentinel = '__ROOT__';

  late String _parentValue;
  late bool _complexityEnabled;
  late double _complexityLevel;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.topic.name);
    _descriptionController =
        TextEditingController(text: widget.topic.description ?? '');
    _aliasesController =
        TextEditingController(text: widget.topic.aliases.join(', '));
    _parentValue = widget.topic.parentId ?? _rootSentinel;
    _complexityEnabled = widget.topic.complexityLevel != null;
    _complexityLevel = widget.topic.complexityLevel ?? 3.0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _aliasesController.dispose();
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
      child: SingleChildScrollView(
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
                    color: context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Topic',
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Refine how this concept appears in the learning map',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            Text(
              'TOPIC DETAILS',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _aliasesController,
              decoration: const InputDecoration(
                labelText: 'Aliases (comma-separated, optional)',
                hintText: 'e.g. Plant Energy, Light Reactions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _parentValue,
              decoration: const InputDecoration(
                labelText: 'Parent',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: _rootSentinel,
                  child: Text('None (root topic)'),
                ),
                for (final parent in widget.candidateParents)
                  DropdownMenuItem<String>(
                    value: parent.id,
                    child: Text(
                      parent.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _parentValue = value ?? _rootSentinel),
            ),
            const SizedBox(height: Spacing.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set complexity rating'),
              subtitle: const Text(
                'Off keeps the topic uncalibrated — the generator will '
                "fall back to the workspace's adaptive default.",
              ),
              value: _complexityEnabled,
              onChanged: (v) => setState(() => _complexityEnabled = v),
            ),
            if (_complexityEnabled) ...[
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 5,
                      divisions: 8,
                      value: _complexityLevel,
                      label: _complexityLevel.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _complexityLevel = v),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      'L${_complexityLevel.toStringAsFixed(1)}',
                      textAlign: TextAlign.right,
                      style: context.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Spacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apply() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a topic name');
      return;
    }
    final description = _descriptionController.text.trim();
    final aliases = _aliasesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    Navigator.of(context).pop(_TopicDraft(
      name: name,
      description: description.isEmpty ? null : description,
      aliases: aliases,
      complexityLevel: _complexityEnabled ? _complexityLevel : null,
      parentId: _parentValue == _rootSentinel ? null : _parentValue,
    ));
  }
}
