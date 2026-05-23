import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/features/taxonomy/data/taxonomy_repository.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_notifier.dart';
import 'package:social_study_app/features/taxonomy/presentation/widgets/topic_tree_builder.dart';
import 'package:social_study_app/shared/models/taxonomy.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Read-only viewer for a workspace's canonical taxonomy (Sprint 2.13).
///
/// Renders the topic hierarchy as an indented list with per-topic
/// metadata (description, complexity, aliases, source-doc count). A
/// "Regenerate" action in the AppBar kicks off a full rebuild on the
/// backend and polls until the new version lands.
///
/// Editing — rename, re-parent, drag — is out of scope for 2.13; that's
/// Sprint 4.3's interactive editor.
class TaxonomyViewerScreen extends ConsumerWidget {
  const TaxonomyViewerScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewerAsync = ref.watch(
      taxonomyViewerProvider(workspaceId: workspaceId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Taxonomy',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          // Sprint 4.3 — pushes the editor with the same workspaceId.
          // Only meaningful once a taxonomy has loaded; the viewer
          // surfaces the regenerate-and-edit pair together.
          if (viewerAsync.hasValue)
            IconButton(
              tooltip: 'Edit taxonomy',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(
                '${AppRoutes.adminTaxonomy}/$workspaceId/edit',
              ),
            ),
          _RegenerateButton(workspaceId: workspaceId, state: viewerAsync),
        ],
      ),
      body: viewerAsync.when(
        data: (viewer) => _Body(workspaceId: workspaceId, state: viewer),
        loading: () => const LoadingIndicator(message: 'Loading taxonomy…'),
        error: (error, _) => ErrorView(
          message: error is TaxonomyWorkspaceNotFoundException
              ? 'This workspace is no longer available.'
              : error.toString(),
          onRetry: () => ref
              .read(taxonomyViewerProvider(workspaceId: workspaceId).notifier)
              .refresh(),
        ),
      ),
    );
  }
}

class _RegenerateButton extends ConsumerWidget {
  const _RegenerateButton({required this.workspaceId, required this.state});

  final String workspaceId;
  final AsyncValue<TaxonomyViewerState> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRegenerating = state.valueOrNull?.isRegenerating ?? false;
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.sm),
      child: TextButton.icon(
        onPressed: isRegenerating
            ? null
            : () => _onPressed(context, ref),
        icon: isRegenerating
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded, size: 18),
        label: Text(isRegenerating ? 'Rebuilding…' : 'Regenerate'),
      ),
    );
  }

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Regenerate taxonomy?'),
        content: const Text(
          'Wipes the current canonical taxonomy and rebuilds it by '
          'replaying every document’s topic tags. Existing alias '
          'mappings are recomputed. This can take a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref
        .read(taxonomyViewerProvider(workspaceId: workspaceId).notifier)
        .regenerate();
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.workspaceId, required this.state});

  final String workspaceId;
  final TaxonomyViewerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = buildTopicTree(state.taxonomy.topics);
    if (rows.isEmpty) {
      return _EmptyState(workspaceId: workspaceId);
    }
    return RefreshIndicator(
      onRefresh: () => ref
          .read(taxonomyViewerProvider(workspaceId: workspaceId).notifier)
          .refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(Spacing.lg),
        itemCount: rows.length + 1, // +1 for the version header
        separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _TaxonomyHeader(taxonomy: state.taxonomy);
          }
          return _TopicTreeRowCard(row: rows[i - 1]);
        },
      ),
    );
  }
}

class _TaxonomyHeader extends StatelessWidget {
  const _TaxonomyHeader({required this.taxonomy});

  final Taxonomy taxonomy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: [
          Text(
            '${taxonomy.topics.length} topics',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'v${taxonomy.taxonomyVersion}',
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref
          .read(taxonomyViewerProvider(workspaceId: workspaceId).notifier)
          .refresh(),
      child: ListView(
        children: [
          SizedBox(
            height: context.screenHeight * 0.7,
            child: const EmptyStateView(
              icon: Icons.account_tree_outlined,
              title: 'No topics yet',
              subtitle: 'Upload a document to start building this workspace’s '
                  'topic taxonomy.',
              action: null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicTreeRowCard extends StatelessWidget {
  const _TopicTreeRowCard({required this.row});

  final TopicTreeRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Depth-based left indent. 20px per level reads as "subtopic" at
      // a glance without overflowing the card area on deep trees.
      padding: EdgeInsets.only(left: row.depth * 20.0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    row.childCount > 0
                        ? Icons.folder_outlined
                        : Icons.label_outline_rounded,
                    color: context.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      row.topic.name,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (row.topic.complexityLevel != null)
                    _ComplexityChip(level: row.topic.complexityLevel!),
                ],
              ),
              if (row.topic.description != null) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  row.topic.description!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              if (row.topic.aliases.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                _AliasList(aliases: row.topic.aliases),
              ],
              const SizedBox(height: Spacing.sm),
              _Footer(row: row),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComplexityChip extends StatelessWidget {
  const _ComplexityChip({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'L${level.toStringAsFixed(level == level.toInt() ? 0 : 1)}',
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AliasList extends StatelessWidget {
  const _AliasList({required this.aliases});

  final List<String> aliases;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: [
        Text(
          'Also known as:',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final alias in aliases)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              alias,
              style: context.textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.row});

  final TopicTreeRow row;

  @override
  Widget build(BuildContext context) {
    final docCount = row.topic.sourceDocumentIds.length;
    final childCount = row.childCount;
    final parts = <String>[
      '$docCount ${docCount == 1 ? 'document' : 'documents'}',
      if (childCount > 0)
        '$childCount ${childCount == 1 ? 'subtopic' : 'subtopics'}',
    ];
    return Text(
      parts.join(' • '),
      style: context.textTheme.labelSmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
