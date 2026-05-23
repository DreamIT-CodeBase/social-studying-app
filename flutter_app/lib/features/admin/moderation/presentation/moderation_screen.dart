import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/admin/moderation/data/demo_moderation_repository.dart';
import 'package:social_study_app/features/admin/moderation/presentation/moderation_notifier.dart';
import 'package:social_study_app/shared/models/moderation.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Moderation dashboard (Sprint 4.5).
///
/// A standalone pushed screen with two tabs: the live **Queue** of
/// flagged content awaiting an admin decision, and the read-only
/// **Audit log** of everything already resolved. Approving or rejecting
/// a queue item moves it out of the queue and into the log — so a
/// resolve invalidates both providers.
///
/// Both tabs handle all four states (Boil the Lake): loading, error,
/// empty, and a populated list.
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Moderation',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Queue'),
              Tab(text: 'Audit Log'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _QueueTab(workspaceId: workspaceId),
            _LogTab(workspaceId: workspaceId),
          ],
        ),
      ),
    );
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(moderationQueueProvider(workspaceId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(moderationQueueProvider(workspaceId).notifier).refresh();
        await ref.read(moderationQueueProvider(workspaceId).future);
      },
      child: queueAsync.when(
        data: (items) => items.isEmpty
            ? const _FullHeight(
                child: EmptyStateView(
                  icon: Icons.verified_rounded,
                  title: 'Nothing to review',
                  subtitle:
                      'Flagged questions, flashcards, and documents will '
                      'appear here for approval.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(Spacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: Spacing.sm),
                itemBuilder: (_, i) => _QueueCard(
                  workspaceId: workspaceId,
                  item: items[i],
                ),
              ),
        loading: () =>
            const LoadingIndicator(message: 'Loading review queue…'),
        error: (error, _) => _FullHeight(
          child: ErrorView(
            message: error.toString(),
            onRetry: () => ref
                .read(moderationQueueProvider(workspaceId).notifier)
                .refresh(),
          ),
        ),
      ),
    );
  }
}

class _LogTab extends ConsumerWidget {
  const _LogTab({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(moderationLogProvider(workspaceId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(moderationLogProvider(workspaceId).notifier).refresh();
        await ref.read(moderationLogProvider(workspaceId).future);
      },
      child: logAsync.when(
        data: (items) => items.isEmpty
            ? const _FullHeight(
                child: EmptyStateView(
                  icon: Icons.history_rounded,
                  title: 'No resolved items',
                  subtitle:
                      'Once you approve or reject flagged content it is '
                      'recorded here.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(Spacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: Spacing.sm),
                itemBuilder: (_, i) => _FlaggedCard(item: items[i]),
              ),
        loading: () => const LoadingIndicator(message: 'Loading audit log…'),
        error: (error, _) => _FullHeight(
          child: ErrorView(
            message: error.toString(),
            onRetry: () =>
                ref.read(moderationLogProvider(workspaceId).notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

/// Wraps a centered state widget in a scrollable, full-viewport-height
/// box so pull-to-refresh stays reachable on empty/error states.
class _FullHeight extends StatelessWidget {
  const _FullHeight({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: context.screenHeight * 0.7, child: child),
      ],
    );
  }
}

/// A queue card — flagged content plus the approve/reject actions.
/// Carries a busy flag so a slow backend can't be double-resolved.
class _QueueCard extends ConsumerStatefulWidget {
  const _QueueCard({required this.workspaceId, required this.item});

  final String workspaceId;
  final FlaggedItem item;

  @override
  ConsumerState<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends ConsumerState<_QueueCard> {
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    return _FlaggedCard(
      item: widget.item,
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _resolving ? null : () => _resolve(approved: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colorScheme.error,
                side: BorderSide(color: context.colorScheme.error),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Reject'),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: FilledButton.icon(
              onPressed: _resolving ? null : () => _resolve(approved: true),
              icon: _resolving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Approve'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve({required bool approved}) async {
    setState(() => _resolving = true);
    try {
      await ref
          .read(moderationQueueProvider(widget.workspaceId).notifier)
          .resolve(
            workspaceId: widget.workspaceId,
            itemId: widget.item.id,
            approved: approved,
          );
      // The audit log is a separate provider — invalidate it so the
      // just-resolved item shows up there immediately.
      ref.invalidate(moderationLogProvider(widget.workspaceId));
      if (mounted) {
        _snack(context, approved ? 'Content approved' : 'Content rejected');
      }
    } on FlaggedItemNotFoundException {
      // Already resolved elsewhere — drop the busy state and let a
      // pull-to-refresh correct the stale row.
      if (mounted) {
        setState(() => _resolving = false);
        _snack(context, 'That item was already resolved');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _resolving = false);
        _snack(context, 'Could not resolve item: $error');
      }
    }
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shared presentation of one flagged item. [footer] carries the
/// approve/reject row on queue cards; on log cards it is null and a
/// verdict chip is shown instead.
class _FlaggedCard extends StatelessWidget {
  const _FlaggedCard({required this.item, this.footer});

  final FlaggedItem item;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _kindIcon(item.contentKind),
                  size: 18,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  _kindLabel(item.contentKind),
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (footer == null)
                  _VerdictChip(verdict: item.verdict)
                else
                  _SeverityChip(severity: item.severity),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              item.topic,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              item.excerpt,
              style: context.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 14,
                  color: context.colorScheme.error,
                ),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    '${item.reason} • ${_relativeTime(item.flaggedAt)}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Queue cards show severity in the header; log cards use
                // the header for the verdict, so severity moves here.
                if (footer == null) _SeverityChip(severity: item.severity),
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: Spacing.md),
              footer!,
            ],
          ],
        ),
      ),
    );
  }

  static IconData _kindIcon(FlaggedContentKind kind) => switch (kind) {
        FlaggedContentKind.question => Icons.quiz_rounded,
        FlaggedContentKind.flashcard => Icons.style_rounded,
        FlaggedContentKind.document => Icons.description_rounded,
      };

  static String _kindLabel(FlaggedContentKind kind) => switch (kind) {
        FlaggedContentKind.question => 'Question',
        FlaggedContentKind.flashcard => 'Flashcard',
        FlaggedContentKind.document => 'Document',
      };
}

/// Severity badge. Azure Content Safety severity is 0–6; the band
/// (low / medium / high) drives the color so an admin can triage at a
/// glance.
class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final int severity;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (severity) {
      <= 1 => (
          'Low',
          context.colorScheme.surfaceContainerHighest,
          context.colorScheme.onSurfaceVariant,
        ),
      <= 3 => (
          'Medium',
          context.colorScheme.secondaryContainer,
          context.colorScheme.onSecondaryContainer,
        ),
      _ => (
          'High',
          context.colorScheme.errorContainer,
          context.colorScheme.onErrorContainer,
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
        'Severity $severity • $label',
        style: context.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.verdict});

  final ModerationVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (verdict) {
      ModerationVerdict.approved => (
          'Approved',
          Icons.check_circle_rounded,
          context.colorScheme.tertiaryContainer,
          context.colorScheme.onTertiaryContainer,
        ),
      ModerationVerdict.rejected => (
          'Rejected',
          Icons.cancel_rounded,
          context.colorScheme.errorContainer,
          context.colorScheme.onErrorContainer,
        ),
      ModerationVerdict.pending => (
          'Pending',
          Icons.schedule_rounded,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: Spacing.xs),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders an ISO-8601 timestamp as a compact relative string. Falls
/// back to the raw value if the string can't be parsed.
String _relativeTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}';
}
