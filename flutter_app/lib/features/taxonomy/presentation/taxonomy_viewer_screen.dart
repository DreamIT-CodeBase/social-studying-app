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

/// Admin-facing visual map of the concepts extracted from study material.
class TaxonomyViewerScreen extends ConsumerStatefulWidget {
  const TaxonomyViewerScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<TaxonomyViewerScreen> createState() =>
      _TaxonomyViewerScreenState();
}

class _TaxonomyViewerScreenState extends ConsumerState<TaxonomyViewerScreen> {
  final _searchController = TextEditingController();
  _TopicFilter _filter = _TopicFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewerAsync = ref.watch(
      taxonomyViewerProvider(workspaceId: widget.workspaceId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Knowledge map',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Workspace taxonomy',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          if (viewerAsync.hasValue)
            IconButton(
              tooltip: 'Edit taxonomy',
              icon: const Icon(Icons.tune_rounded),
              onPressed: _openEditor,
            ),
          IconButton(
            tooltip: 'Refresh taxonomy',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: viewerAsync.isLoading ? null : _refresh,
          ),
          const SizedBox(width: Spacing.sm),
        ],
      ),
      body: viewerAsync.when(
        data: (viewer) => _buildLoaded(viewer),
        loading: () => const LoadingIndicator(
          message: 'Building your knowledge map…',
        ),
        error: (error, _) => ErrorView(
          message: error is TaxonomyWorkspaceNotFoundException
              ? 'This workspace is no longer available.'
              : error.toString(),
          onRetry: _refresh,
        ),
      ),
    );
  }

  Widget _buildLoaded(TaxonomyViewerState viewer) {
    if (viewer.taxonomy.topics.isEmpty) {
      return _EmptyTaxonomy(
        isRegenerating: viewer.isRegenerating,
        onRefresh: _refresh,
        onRegenerate: _confirmRegenerate,
      );
    }

    final allRows = buildTopicTree(viewer.taxonomy.topics);
    final visibleRows = _visibleRows(allRows, viewer.taxonomy.topics);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  _KnowledgeMapHero(
                    taxonomy: viewer.taxonomy,
                    rows: allRows,
                    isRegenerating: viewer.isRegenerating,
                    onEdit: _openEditor,
                    onRegenerate: _confirmRegenerate,
                  ),
                  const SizedBox(height: Spacing.lg),
                  _TaxonomyControls(
                    controller: _searchController,
                    filter: _filter,
                    onSearchChanged: (_) => setState(() {}),
                    onFilterChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: Spacing.xl),
                  _SectionHeading(
                    visibleCount: visibleRows.length,
                    totalCount: allRows.length,
                    filtered: _searchController.text.trim().isNotEmpty ||
                        _filter != _TopicFilter.all,
                  ),
                  const SizedBox(height: Spacing.md),
                  if (visibleRows.isEmpty)
                    _NoMatchingTopics(onClear: _clearFilters)
                  else
                    for (var index = 0;
                        index < visibleRows.length;
                        index++) ...[
                      _TopicMapCard(row: visibleRows[index]),
                      if (index != visibleRows.length - 1)
                        const SizedBox(height: Spacing.sm),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TopicTreeRow> _visibleRows(
    List<TopicTreeRow> rows,
    List<CanonicalTopic> topics,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final byId = {for (final topic in topics) topic.id: topic};
    final visibleIds = <String>{};

    for (final row in rows) {
      final topic = row.topic;
      final matchesQuery = query.isEmpty ||
          topic.name.toLowerCase().contains(query) ||
          (topic.description?.toLowerCase().contains(query) ?? false) ||
          topic.aliases.any((alias) => alias.toLowerCase().contains(query));
      final matchesFilter = switch (_filter) {
        _TopicFilter.all => true,
        _TopicFilter.foundations =>
          topic.complexityLevel != null && topic.complexityLevel! <= 2,
        _TopicFilter.advanced =>
          topic.complexityLevel != null && topic.complexityLevel! >= 4,
        _TopicFilter.unrated => topic.complexityLevel == null,
      };
      if (!matchesQuery || !matchesFilter) continue;

      visibleIds.add(topic.id);
      var parentId = topic.parentId;
      while (parentId != null && visibleIds.add(parentId)) {
        parentId = byId[parentId]?.parentId;
      }
    }

    return rows.where((row) => visibleIds.contains(row.topic.id)).toList();
  }

  Future<void> _refresh() => ref
      .read(
        taxonomyViewerProvider(workspaceId: widget.workspaceId).notifier,
      )
      .refresh();

  void _openEditor() {
    context.push('${AppRoutes.adminTaxonomy}/${widget.workspaceId}/edit');
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _filter = _TopicFilter.all);
  }

  Future<void> _confirmRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded),
        title: const Text('Regenerate taxonomy?'),
        content: const Text(
          'The knowledge map will be rebuilt from every uploaded document. '
          'Topic names, aliases, and relationships may change. This can take '
          'a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(
          taxonomyViewerProvider(workspaceId: widget.workspaceId).notifier,
        )
        .regenerate();
  }
}

enum _TopicFilter { all, foundations, advanced, unrated }

class _KnowledgeMapHero extends StatelessWidget {
  const _KnowledgeMapHero({
    required this.taxonomy,
    required this.rows,
    required this.isRegenerating,
    required this.onEdit,
    required this.onRegenerate,
  });

  final Taxonomy taxonomy;
  final List<TopicTreeRow> rows;
  final bool isRegenerating;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientStart =
        isDark ? colorScheme.primaryContainer : colorScheme.primary;
    final gradientEnd =
        isDark ? colorScheme.tertiaryContainer : colorScheme.tertiary;
    final heroForeground =
        isDark ? colorScheme.onPrimaryContainer : colorScheme.onPrimary;
    final rootCount = rows.where((row) => row.depth == 0).length;
    final sourceCount = taxonomy.topics
        .expand((topic) => topic.sourceDocumentIds)
        .toSet()
        .length;
    final scored = taxonomy.topics
        .where((topic) => topic.complexityLevel != null)
        .toList();
    final averageComplexity = scored.isEmpty
        ? '—'
        : (scored.fold<double>(
                  0,
                  (sum, topic) => sum + topic.complexityLevel!,
                ) /
                scored.length)
            .toStringAsFixed(1);

    return Container(
      key: const ValueKey('knowledge_map_hero'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradientStart,
            Color.lerp(gradientStart, gradientEnd, 0.42)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(90)
                : gradientStart.withAlpha(45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: heroForeground.withAlpha(35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: heroForeground.withAlpha(55)),
                ),
                child: Icon(
                  Icons.hub_rounded,
                  color: heroForeground,
                  size: 28,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your learning landscape',
                      style: TextStyle(
                        color: heroForeground,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'See how source material connects from core concepts '
                      'to advanced topics.',
                      style: TextStyle(
                        color: heroForeground.withAlpha(205),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Version ${taxonomy.taxonomyVersion}${_updatedLabel(taxonomy.lastMergedAt)}',
                      style: TextStyle(
                        color: heroForeground.withAlpha(180),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              _HeroMetric(
                value: '${taxonomy.topics.length}',
                label: 'Topics',
                icon: Icons.bubble_chart_rounded,
                foreground: heroForeground,
              ),
              _HeroMetric(
                value: '$rootCount',
                label: 'Root concepts',
                icon: Icons.account_tree_rounded,
                foreground: heroForeground,
              ),
              _HeroMetric(
                value: '$sourceCount',
                label: 'Sources',
                icon: Icons.description_rounded,
                foreground: heroForeground,
              ),
              _HeroMetric(
                value: averageComplexity,
                label: 'Avg. level',
                icon: Icons.insights_rounded,
                foreground: heroForeground,
              ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: heroForeground,
                  foregroundColor: gradientStart,
                ),
                onPressed: onEdit,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Edit map'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: heroForeground,
                  side: BorderSide(color: heroForeground.withAlpha(150)),
                ),
                onPressed: isRegenerating ? null : onRegenerate,
                icon: isRegenerating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: heroForeground,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(isRegenerating ? 'Rebuilding…' : 'Regenerate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _updatedLabel(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    final parsed = DateTime.tryParse(timestamp)?.toLocal();
    if (parsed == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return ' · Updated ${months[parsed.month - 1]} ${parsed.day}';
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.icon,
    required this.foreground,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: foreground.withAlpha(28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withAlpha(42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground.withAlpha(215), size: 18),
          const SizedBox(width: Spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: foreground.withAlpha(190),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaxonomyControls extends StatelessWidget {
  const _TaxonomyControls({
    required this.controller,
    required this.filter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final _TopicFilter filter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_TopicFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('taxonomy_search'),
          controller: controller,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search topics, descriptions, or aliases',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: context.colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All topics',
                icon: Icons.grid_view_rounded,
                value: _TopicFilter.all,
                selected: filter == _TopicFilter.all,
                onSelected: onFilterChanged,
              ),
              const SizedBox(width: Spacing.sm),
              _FilterChip(
                label: 'Foundations',
                icon: Icons.foundation_rounded,
                value: _TopicFilter.foundations,
                selected: filter == _TopicFilter.foundations,
                onSelected: onFilterChanged,
              ),
              const SizedBox(width: Spacing.sm),
              _FilterChip(
                label: 'Advanced',
                icon: Icons.trending_up_rounded,
                value: _TopicFilter.advanced,
                selected: filter == _TopicFilter.advanced,
                onSelected: onFilterChanged,
              ),
              const SizedBox(width: Spacing.sm),
              _FilterChip(
                label: 'Unrated',
                icon: Icons.help_outline_rounded,
                value: _TopicFilter.unrated,
                selected: filter == _TopicFilter.unrated,
                onSelected: onFilterChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final _TopicFilter value;
  final bool selected;
  final ValueChanged<_TopicFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(value),
      avatar: Icon(icon, size: 16),
      label: Text(label),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected
            ? context.colorScheme.onPrimaryContainer
            : context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.visibleCount,
    required this.totalCount,
    required this.filtered,
  });

  final int visibleCount;
  final int totalCount;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Topic hierarchy',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                filtered
                    ? '$visibleCount of $totalCount topics shown'
                    : '$totalCount topics arranged by prerequisite',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$visibleCount topics',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicMapCard extends StatelessWidget {
  const _TopicMapCard({required this.row});

  final TopicTreeRow row;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topic = row.topic;
    final accent = _complexityColor(colorScheme, topic.complexityLevel);
    final indent = row.depth.clamp(0, 4) * 18.0;
    final cardSurface =
        isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface;
    final insetSurface =
        isDark ? colorScheme.surface : colorScheme.surfaceContainerHighest;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (row.depth > 0) ...[
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent.withAlpha(75),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: Spacing.sm),
            ],
            Expanded(
              child: Container(
                key: ValueKey('taxonomy_topic_card_${topic.id}'),
                decoration: BoxDecoration(
                  color: cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withAlpha(55)
                          : colorScheme.shadow.withAlpha(12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            row.childCount > 0
                                ? Icons.hub_outlined
                                : Icons.circle_outlined,
                            color: accent,
                            size: 21,
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
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                topic.name,
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (topic.complexityLevel != null)
                          _ComplexityBadge(
                            level: topic.complexityLevel!,
                            color: accent,
                          ),
                      ],
                    ),
                    if (topic.description?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: Spacing.md),
                      Text(
                        topic.description!,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (topic.aliases.isNotEmpty) ...[
                      const SizedBox(height: Spacing.md),
                      Wrap(
                        spacing: Spacing.xs,
                        runSpacing: Spacing.xs,
                        children: [
                          for (final alias in topic.aliases)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.sm,
                                vertical: Spacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: insetSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                alias,
                                style: context.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Spacing.md),
                    Wrap(
                      spacing: Spacing.lg,
                      runSpacing: Spacing.xs,
                      children: [
                        _TopicMeta(
                          icon: Icons.description_outlined,
                          label: _plural(
                            topic.sourceDocumentIds.length,
                            'source',
                          ),
                        ),
                        if (row.childCount > 0)
                          _TopicMeta(
                            icon: Icons.account_tree_outlined,
                            label: _plural(row.childCount, 'subtopic'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _complexityColor(ColorScheme colors, double? level) {
    if (level == null) return colors.outline;
    if (level <= 2) return colors.tertiary;
    if (level >= 4) return colors.error;
    return colors.primary;
  }

  static String _plural(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 's'}';
}

class _ComplexityBadge extends StatelessWidget {
  const _ComplexityBadge({required this.level, required this.color});

  final double level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final formatted = level == level.toInt()
        ? level.toInt().toString()
        : level.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'L$formatted',
        style: context.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TopicMeta extends StatelessWidget {
  const _TopicMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.colorScheme.onSurfaceVariant),
        const SizedBox(width: Spacing.xs),
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NoMatchingTopics extends StatelessWidget {
  const _NoMatchingTopics({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 36,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'No matching topics',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Try another phrase or remove the complexity filter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.md),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    );
  }
}

class _EmptyTaxonomy extends ConsumerWidget {
  const _EmptyTaxonomy({
    required this.isRegenerating,
    required this.onRefresh,
    required this.onRegenerate,
  });

  final bool isRegenerating;
  final Future<void> Function() onRefresh;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: context.screenHeight * 0.72,
            child: EmptyStateView(
              icon: Icons.hub_outlined,
              title: 'No topics yet',
              subtitle: 'Upload study material first. The app will extract '
                  'concepts and connect them into a searchable knowledge map.',
              action: isRegenerating
                  ? FilledButton.icon(
                      onPressed: null,
                      icon: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Rebuilding…'),
                    )
                  : FilledButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Build knowledge map'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
