import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_screen.dart'
    show FlipCard, FlashcardFace, FlashcardSide;
import 'package:social_study_app/features/questions/presentation/question_screen.dart'
    show AnswerInput;
import 'package:social_study_app/features/revision/domain/revision_session.dart';
import 'package:social_study_app/features/revision/presentation/revision_session_notifier.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/models/question.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';

/// Revision mode (Sprint 4.10).
///
/// A bounded, focused session that interleaves AI-generated questions
/// with flashcards. The plan is fixed-length (10 items by default,
/// alternating question/flashcard), and the AppBar progress bar shows
/// the student where they are in the session.
///
/// Reuses [AnswerInput] from the question loop and [FlipCard] +
/// [FlashcardFace] from the flashcard loop so the same widgets render
/// the same content in both contexts. The grading + rating verdicts
/// inside revision are deliberately leaner than the standalone screens'
/// — revision keeps the student moving through items.
class RevisionScreen extends ConsumerStatefulWidget {
  const RevisionScreen({super.key, required this.workspaceId});

  final String workspaceId;

  /// Test hook — when set, [RevisionSessionNotifier.start] is invoked
  /// with this count instead of the production default of 10. Lets
  /// widget tests exercise a short session end-to-end without 10 taps.
  @visibleForTesting
  static int? debugItemCount;

  @override
  ConsumerState<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends ConsumerState<RevisionScreen> {
  RevisionSessionNotifier get _notifier =>
      ref.read(revisionSessionNotifierProvider(widget.workspaceId).notifier);

  @override
  void initState() {
    super.initState();
    if (RevisionScreen.debugItemCount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifier.start(itemCount: RevisionScreen.debugItemCount);
      });
    }
  }

  /// Reset the family provider to a fresh idle session, then fetch —
  /// the only escape hatch from `error` / `unavailable` / `complete`.
  void _restart() {
    ref.invalidate(revisionSessionNotifierProvider(widget.workspaceId));
    final notifier = ref
        .read(revisionSessionNotifierProvider(widget.workspaceId).notifier);
    final count = RevisionScreen.debugItemCount;
    final progressVal = ref.read(studentProgressNotifierProvider(widget.workspaceId)).valueOrNull;
    count == null
        ? notifier.start(mastery: progressVal?.overallMastery)
        : notifier.start(itemCount: count, mastery: progressVal?.overallMastery);
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ref.watch(revisionSessionNotifierProvider(widget.workspaceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Revision',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: _RevisionProgressBar(progress: _progressFor(session)),
      ),
      body: session.when(
        idle: () {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.psychology_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      'Daily Revision',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Practice a custom mix of questions and flashcards. The session length is automatically customized based on your mastery.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    FilledButton.icon(
                      onPressed: () {
                        final progressVal = ref.read(studentProgressNotifierProvider(widget.workspaceId)).valueOrNull;
                        _notifier.start(mastery: progressVal?.overallMastery);
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Revision Session'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: (progress) => LoadingIndicator(
          message: 'Loading item ${progress.position} of ${progress.total}…',
        ),
        question: (question, draftAnswer, progress) => _QuestionItem(
          workspaceId: widget.workspaceId,
          question: question,
          draftAnswer: draftAnswer,
          submitting: false,
        ),
        questionSubmitting: (question, draftAnswer, progress) => _QuestionItem(
          workspaceId: widget.workspaceId,
          question: question,
          draftAnswer: draftAnswer,
          submitting: true,
        ),
        questionGraded: (question, submittedAnswer, feedback, progress) =>
            _GradedItem(
          key: ValueKey('graded:${question.id}'),
          workspaceId: widget.workspaceId,
          question: question,
          submittedAnswer: submittedAnswer,
          feedback: feedback,
        ),
        flashcardFront: (card, progress) => _FlashcardItem(
          workspaceId: widget.workspaceId,
          card: card,
          phase: _FlashcardPhase.front,
        ),
        flashcardBack: (card, progress) => _FlashcardItem(
          workspaceId: widget.workspaceId,
          card: card,
          phase: _FlashcardPhase.back,
        ),
        flashcardRating: (card, rating, progress) => _FlashcardItem(
          workspaceId: widget.workspaceId,
          card: card,
          phase: _FlashcardPhase.rating,
          pendingRating: rating,
        ),
        flashcardRated: (card, rating, progress) => _FlashcardItem(
          workspaceId: widget.workspaceId,
          card: card,
          phase: _FlashcardPhase.rated,
          recordedRating: rating,
        ),
        complete: (summary) => _SummaryView(
          summary: summary,
          onRestart: _restart,
          onDone: () => context.pop(),
        ),
        unavailable: (message, isNoTopics) => EmptyStateView(
          icon: isNoTopics
              ? Icons.menu_book_rounded
              : Icons.hourglass_empty_rounded,
          title: isNoTopics ? 'No content yet' : 'Generator is busy',
          subtitle: isNoTopics
              ? 'Your teacher needs to upload study material before '
                  'revision can run.'
              : message,
          action: isNoTopics
              ? null
              : FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
        ),
        error: (message) => ErrorView(message: message, onRetry: _restart),
      ),
    );
  }
}

/// Extracts the progress out of any state that carries one. Returns
/// null for `idle`, `complete` (the summary takes over), `unavailable`,
/// and `error` — states where a partial progress bar would mislead.
RevisionProgress? _progressFor(RevisionSession session) => session.maybeWhen(
      loading: (p) => p,
      question: (_, __, p) => p,
      questionSubmitting: (_, __, p) => p,
      questionGraded: (_, __, ___, p) => p,
      flashcardFront: (_, p) => p,
      flashcardBack: (_, p) => p,
      flashcardRating: (_, __, p) => p,
      flashcardRated: (_, __, p) => p,
      orElse: () => null,
    );

/// AppBar bottom bar — a linear progress indicator plus a "3 of 10"
/// label. Renders empty space when [progress] is null so the AppBar
/// height stays stable across states.
class _RevisionProgressBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _RevisionProgressBar({required this.progress});

  final RevisionProgress? progress;

  @override
  Size get preferredSize => const Size.fromHeight(28);

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null) return const SizedBox(height: 28);
    final fraction = p.position / p.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        0,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: context.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Item ${p.position} of ${p.total}',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Question item — answering phase
// ─────────────────────────────────────────────────────────────────────────

class _QuestionItem extends ConsumerWidget {
  const _QuestionItem({
    required this.workspaceId,
    required this.question,
    required this.draftAnswer,
    required this.submitting,
  });

  final String workspaceId;
  final Question question;
  final String? draftAnswer;
  final bool submitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(revisionSessionNotifierProvider(workspaceId).notifier);
    final canSubmit =
        !submitting && (draftAnswer?.trim().isNotEmpty ?? false);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              _ItemHeader(
                topic: question.topic,
                kindLabel: 'QUESTION',
                accent: context.colorScheme.primary,
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                question.body,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              AnswerInput(
                key: ValueKey('answer:${question.id}'),
                question: question,
                draftAnswer: draftAnswer,
                enabled: !submitting,
                onChanged: notifier.setDraftAnswer,
              ),
            ],
          ),
        ),
        _BottomBar(
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: canSubmit ? () => notifier.submitAnswer() : null,
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit Answer'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Graded question item — compact feedback + continue
// ─────────────────────────────────────────────────────────────────────────

class _GradedItem extends ConsumerStatefulWidget {
  const _GradedItem({
    super.key,
    required this.workspaceId,
    required this.question,
    required this.submittedAnswer,
    required this.feedback,
  });

  final String workspaceId;
  final Question question;
  final String submittedAnswer;
  final AnswerFeedback feedback;

  @override
  ConsumerState<_GradedItem> createState() => _GradedItemState();
}

class _GradedItemState extends ConsumerState<_GradedItem> {
  @override
  void initState() {
    super.initState();
    if (widget.feedback.isCorrect) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(
      revisionSessionNotifierProvider(widget.workspaceId).notifier,
    );
    final feedback = widget.feedback;
    final correct = feedback.isCorrect;
    final accent = correct ? AppColors.tertiary : AppColors.error;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              _VerdictBanner(correct: correct, accent: accent),
              const SizedBox(height: Spacing.lg),
              _AnswerLine(
                label: 'Your answer',
                value: _displayAnswer(widget.question, widget.submittedAnswer),
                color: accent,
              ),
              if (!correct) ...[
                const SizedBox(height: Spacing.md),
                _AnswerLine(
                  label: 'Correct answer',
                  value: _displayAnswer(
                    widget.question,
                    feedback.canonicalAnswer,
                  ),
                  color: AppColors.tertiary,
                ),
              ],
              const SizedBox(height: Spacing.lg),
              _ExplanationBox(explanation: feedback.explanation),
              const SizedBox(height: Spacing.lg),
              Row(
                children: [
                  _RewardChip(
                    icon: Icons.bolt_rounded,
                    color: AppColors.secondary,
                    label: '+${feedback.xpEarned} XP',
                  ),
                  const SizedBox(width: Spacing.sm),
                  _RewardChip(
                    icon: Icons.trending_up_rounded,
                    color: AppColors.primary,
                    label:
                        '${(feedback.newTopicMastery * 100).round()}% mastery',
                  ),
                ],
              ),
            ],
          ),
        ),
        _BottomBar(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: () => notifier.advance(),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.correct, required this.accent});

  final bool correct;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: accent.withAlpha(31),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: accent,
              size: 32,
            ),
            const SizedBox(width: Spacing.md),
            Text(
              correct ? 'Correct!' : 'Not quite',
              style: context.textTheme.titleLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          value,
          style: context.textTheme.bodyLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                'Explanation',
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            explanation,
            style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: Spacing.xs),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Flashcard item — flip + rate phases
// ─────────────────────────────────────────────────────────────────────────

enum _FlashcardPhase { front, back, rating, rated }

class _FlashcardItem extends ConsumerWidget {
  const _FlashcardItem({
    required this.workspaceId,
    required this.card,
    required this.phase,
    this.pendingRating,
    this.recordedRating,
  });

  final String workspaceId;
  final Flashcard card;
  final _FlashcardPhase phase;
  final FlashcardRating? pendingRating;
  final FlashcardRating? recordedRating;

  bool get _showBack => phase != _FlashcardPhase.front;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(revisionSessionNotifierProvider(workspaceId).notifier);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: GestureDetector(
              onTap: phase == _FlashcardPhase.front
                  ? () {
                      HapticFeedback.selectionClick();
                      notifier.flip();
                    }
                  : null,
              child: FlipCard(
                key: ValueKey('rev:card:${card.id}'),
                showBack: _showBack,
                front: FlashcardFace(card: card, side: FlashcardSide.front),
                back: FlashcardFace(card: card, side: FlashcardSide.back),
              ),
            ),
          ),
        ),
        _BottomBar(
          child: switch (phase) {
            _FlashcardPhase.front => Text(
                'Recall the answer, then tap the card.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            _FlashcardPhase.back => _CompactRatingRow(
                enabled: true,
                pendingRating: null,
                onRate: notifier.rate,
              ),
            _FlashcardPhase.rating => _CompactRatingRow(
                enabled: false,
                pendingRating: pendingRating,
                onRate: notifier.rate,
              ),
            _FlashcardPhase.rated => _RatedRow(
                recordedRating: recordedRating!,
                onContinue: () => notifier.advance(),
              ),
          },
        ),
      ],
    );
  }
}

({String label, Color color, IconData icon}) _ratingStyle(
  FlashcardRating rating,
) =>
    switch (rating) {
      FlashcardRating.hard => (
          label: 'Hard',
          color: AppColors.error,
          icon: Icons.sentiment_dissatisfied_rounded,
        ),
      FlashcardRating.medium => (
          label: 'Medium',
          color: AppColors.secondary,
          icon: Icons.sentiment_neutral_rounded,
        ),
      FlashcardRating.easy => (
          label: 'Easy',
          color: AppColors.tertiary,
          icon: Icons.sentiment_very_satisfied_rounded,
        ),
    };

class _CompactRatingRow extends StatelessWidget {
  const _CompactRatingRow({
    required this.enabled,
    required this.pendingRating,
    required this.onRate,
  });

  final bool enabled;
  final FlashcardRating? pendingRating;
  final Future<void> Function(FlashcardRating) onRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final rating in FlashcardRating.values) ...[
          Expanded(
            child: _CompactRatingButton(
              rating: rating,
              enabled: enabled,
              busy: pendingRating == rating,
              onTap: () => onRate(rating),
            ),
          ),
          if (rating != FlashcardRating.values.last)
            const SizedBox(width: Spacing.sm),
        ],
      ],
    );
  }
}

class _CompactRatingButton extends StatelessWidget {
  const _CompactRatingButton({
    required this.rating,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final FlashcardRating rating;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _ratingStyle(rating);
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: style.color,
        side: BorderSide(color: style.color),
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      ),
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(style.icon, size: 18),
                const SizedBox(width: Spacing.xs),
                Text(
                  style.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
    );
  }
}

class _RatedRow extends StatelessWidget {
  const _RatedRow({required this.recordedRating, required this.onContinue});

  final FlashcardRating recordedRating;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final style = _ratingStyle(recordedRating);
    // Label + button stacked vertically — `Material(elevation:8)` in the
    // parent `_BottomBar` triggers an intrinsic-width pass on its child,
    // and a Row containing a non-flex `FilledButton.icon` blows that
    // measurement up with "BoxConstraints forces an infinite width".
    // A Column sidesteps the intrinsic-width propagation entirely.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(style.icon, size: 18, color: style.color),
            const SizedBox(width: Spacing.xs),
            Text(
              'Rated ${style.label}',
              style: context.textTheme.labelLarge?.copyWith(
                color: style.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          onPressed: onContinue,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Continue'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Summary view
// ─────────────────────────────────────────────────────────────────────────

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.summary,
    required this.onRestart,
    required this.onDone,
  });

  final RevisionSummary summary;
  final VoidCallback onRestart;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final accuracy = summary.questionsAnswered == 0
        ? null
        : summary.questionsCorrect / summary.questionsAnswered;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              const SizedBox(height: Spacing.xl),
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withAlpha(31),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 56,
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'Session complete!',
                textAlign: TextAlign.center,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'You worked through ${summary.total} items.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              _SummaryRow(
                icon: Icons.quiz_rounded,
                color: AppColors.primary,
                label: 'Questions answered',
                value: '${summary.questionsAnswered}',
              ),
              _SummaryRow(
                icon: Icons.check_circle_rounded,
                color: AppColors.tertiary,
                label: 'Correct',
                value: '${summary.questionsCorrect}',
              ),
              if (accuracy != null)
                _SummaryRow(
                  icon: Icons.percent_rounded,
                  color: AppColors.secondary,
                  label: 'Accuracy',
                  value: '${(accuracy * 100).round()}%',
                ),
              _SummaryRow(
                icon: Icons.style_rounded,
                color: AppColors.primary,
                label: 'Flashcards reviewed',
                value: '${summary.flashcardsReviewed}',
              ),
            ],
          ),
        ),
        _BottomBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Restart'),
                  // Min height only — Expanded already drives the
                  // width, so `Size.infinite` here would conflict.
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Done'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          border: Border.all(color: context.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withAlpha(31),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                label,
                style: context.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({
    required this.topic,
    required this.kindLabel,
    required this.accent,
  });

  final String topic;
  final String kindLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            topic.toUpperCase(),
            style: context.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Text(
          kindLabel,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: context.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: child,
        ),
      ),
    );
  }
}

String _displayAnswer(Question question, String raw) {
  final trimmed = raw.trim();
  switch (question.questionType) {
    case QuestionType.mcq:
      final match = question.options
          .where((o) => o.key.toLowerCase() == trimmed.toLowerCase())
          .firstOrNull;
      return match == null ? trimmed : '${match.key}.  ${match.text}';
    case QuestionType.trueFalse:
      if (trimmed.toLowerCase() == 'true') return 'True';
      if (trimmed.toLowerCase() == 'false') return 'False';
      return trimmed;
    case QuestionType.shortAnswer:
    case QuestionType.longAnswer:
    case QuestionType.mathematical:
      return trimmed;
  }
}
