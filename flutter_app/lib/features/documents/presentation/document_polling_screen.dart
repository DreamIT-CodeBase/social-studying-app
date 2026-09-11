import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/utils/subject_classifier.dart';
import 'package:social_study_app/features/documents/data/demo_documents_repository.dart'
    show DocumentNotFoundException;
import 'package:social_study_app/features/documents/presentation/document_polling_notifier.dart';
import 'package:social_study_app/features/documents/presentation/widgets/pipeline_stages.dart';
import 'package:social_study_app/features/documents/presentation/widgets/stage_stepper.dart';
import 'package:social_study_app/shared/models/document.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

/// Polling-and-progress screen for one document.
///
/// Watches `documentPollingProvider(workspaceId, documentId)` which
/// auto-polls every couple of seconds until the doc reaches a terminal
/// state. The screen renders three layers depending on `AsyncValue`:
///   - loading (first fetch only — subsequent polls keep the prior data)
///   - error (DocumentNotFoundException on initial fetch → 404 view)
///   - data (the stage stepper + a hero card for the current stage)
class DocumentPollingScreen extends ConsumerWidget {
  const DocumentPollingScreen({
    super.key,
    required this.workspaceId,
    required this.documentId,
  });

  final String workspaceId;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollingAsync = ref.watch(
      documentPollingProvider(
        workspaceId: workspaceId,
        documentId: documentId,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pollingAsync.valueOrNull?.filename ?? 'Document',
          style: const TextStyle(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: pollingAsync.when(
        data: (doc) => _Body(doc: doc),
        loading: () => const LoadingIndicator(message: 'Loading document…'),
        error: (error, _) => ErrorView(
          message: error is DocumentNotFoundException
              ? 'This document is no longer available.'
              : error.toString(),
          onRetry: () => ref
              .read(
                documentPollingProvider(
                  workspaceId: workspaceId,
                  documentId: documentId,
                ).notifier,
              )
              .pollNow(),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView + Column (not ListView) on purpose: the body has
    // at most four fixed-height cards, the lazy-build optimization of a
    // ListView doesn't help here, and eager build means widget tests can
    // assert against every section without scroll-into-view scaffolding.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CurrentStageHero(doc: doc),
          if (doc.status.isUsableForStudy) ...[
            const SizedBox(height: Spacing.lg),
            _StudyActionsCard(doc: doc),
          ],
          const SizedBox(height: Spacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: StageStepper(rows: buildStageRows(doc)),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          _MetadataCard(doc: doc),
          if (doc.topicTags.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            _TopicsCard(topics: doc.topicTags),
          ],
        ],
      ),
    );
  }
}

/// Big "what's happening right now" card. Shows a different surface
/// for in-flight, ready, failed, and flagged. The hero copy is
/// intentionally action-oriented for terminal states (Ready =
/// celebrate; Failed = retry hint; Flagged = next-step) because the
/// polling screen is the only place an admin lands after upload.
class _CurrentStageHero extends StatelessWidget {
  const _CurrentStageHero({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context) {
    return switch (doc.status) {
      DocumentStatus.ready => _HeroCard(
          icon: Icons.check_circle_rounded,
          tone: _HeroTone.success,
          title: 'Ready for questions',
          subtitle: '${doc.chunkCount} indexed chunks across '
              '${doc.topicTags.length} topics. '
              'Students can now generate study questions from this material.',
        ),
      DocumentStatus.failed => _HeroCard(
          icon: Icons.error_outline_rounded,
          tone: _HeroTone.error,
          title: 'Processing failed',
          subtitle: doc.processingError ??
              'Something went wrong while processing this file. '
                  'Try uploading it again.',
        ),
      DocumentStatus.flagged => _HeroCard(
          icon: Icons.shield_outlined,
          tone: _HeroTone.warning,
          title: 'Flagged for review',
          subtitle: doc.processingError ??
              'Content safety flagged this document. '
                  'A workspace admin needs to review it before it can be used.',
        ),
      _ => _HeroCard(
          icon: Icons.hourglass_top_rounded,
          tone: _HeroTone.inProgress,
          title: _activeStage(doc.status).label,
          subtitle: _activeStage(doc.status).detail,
          showSpinner: true,
        ),
    };
  }
}

PipelineStage _activeStage(DocumentStatus status) {
  // Mirrors the active-stage mapping in pipeline_stages.dart but for
  // the hero's display text. Kept here rather than exporting a private
  // helper so the stepper file stays a pure data module.
  return switch (status) {
    DocumentStatus.pending => PipelineStage.uploaded,
    DocumentStatus.extracting => PipelineStage.extracting,
    DocumentStatus.textExtracted ||
    DocumentStatus.extractingTopics =>
      PipelineStage.topics,
    DocumentStatus.topicsExtracted ||
    DocumentStatus.chunking =>
      PipelineStage.chunking,
    DocumentStatus.chunked ||
    DocumentStatus.vectorizing =>
      PipelineStage.vectorizing,
    DocumentStatus.ready => PipelineStage.ready,
    DocumentStatus.flagged || DocumentStatus.failed => PipelineStage.uploaded,
  };
}

enum _HeroTone { inProgress, success, warning, error }

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    this.showSpinner = false,
  });

  final IconData icon;
  final _HeroTone tone;
  final String title;
  final String subtitle;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final palette = _toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          showSpinner
              ? SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: palette.foreground,
                  ),
                )
              : Icon(icon, color: palette.foreground, size: 40),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: palette.foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  subtitle,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: palette.foreground.withAlpha(204),
                    height: 1.4,
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

class _Palette {
  const _Palette({required this.foreground, required this.background});
  final Color foreground;
  final Color background;
}

_Palette _toneColors(BuildContext context, _HeroTone tone) {
  return switch (tone) {
    _HeroTone.inProgress => _Palette(
        foreground: context.colorScheme.onPrimaryContainer,
        background: context.colorScheme.primaryContainer,
      ),
    _HeroTone.success => _Palette(
        foreground: context.colorScheme.onTertiaryContainer,
        background: context.colorScheme.tertiaryContainer,
      ),
    _HeroTone.warning => _Palette(
        foreground: context.colorScheme.onSecondaryContainer,
        background: context.colorScheme.secondaryContainer,
      ),
    _HeroTone.error => _Palette(
        foreground: context.colorScheme.onErrorContainer,
        background: context.colorScheme.errorContainer,
      ),
  };
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('File type', doc.docType.name.toUpperCase()),
      if (doc.pageCount != null) ('Pages', '${doc.pageCount}'),
      if (doc.textCharCount != null)
        ('Characters extracted', _formatNumber(doc.textCharCount!)),
      if (doc.languages.isNotEmpty)
        ('Languages', doc.languages.join(', ').toUpperCase()),
      if (doc.chunkCount > 0) ('Chunks', '${doc.chunkCount}'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document details',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.md),
            for (final (label, value) in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopicsCard extends StatelessWidget {
  const _TopicsCard({required this.topics});

  final List<TopicTag> topics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Topics found',
                  style: context.textTheme.titleSmall?.copyWith(
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
                    color: context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${topics.length}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [for (final t in topics) _TopicPill(topic: t)],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.topic});

  final TopicTag topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        topic.name,
        style: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _formatNumber(int n) {
  // Insert commas as thousands separators without pulling intl in.
  final s = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

class _StudyActionsCard extends StatelessWidget {
  const _StudyActionsCard({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context) {
    final subject = subjectForDocument(doc);
    final subjectParam =
        subject.isNotEmpty ? '&subject=${Uri.encodeComponent(subject)}' : '';

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.primary.withAlpha(40),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.primary.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.bolt_rounded, color: Colors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Material Ready for Study!',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Launch an adaptive session directly from this content in one go.',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('start_study_session_button'),
                  onPressed: () {
                    context.push(
                        '/student/session/${doc.workspaceId}?mode=study$subjectParam');
                  },
                  icon: const Icon(Icons.school_rounded, size: 18),
                  label: const Text('Start Study'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('review_flashcards_button'),
                  onPressed: () {
                    context.push(
                        '/student/session/${doc.workspaceId}?mode=flashcard$subjectParam');
                  },
                  icon: const Icon(Icons.style_rounded, size: 18),
                  label: const Text('Flashcards'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

