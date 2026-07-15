import 'dart:async';

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
import 'package:social_study_app/features/home/presentation/student_home_screen.dart'
    show studentHomeTabProvider;

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
  const RevisionScreen({
    super.key,
    required this.workspaceId,
    this.autoStart = false,
  });

  final String workspaceId;
  final bool autoStart;

  /// Test hook — when set, [RevisionSessionNotifier.start] is invoked
  /// with this count instead of the production default of 10. Lets
  /// widget tests exercise a short session end-to-end without 10 taps.
  @visibleForTesting
  static int? debugItemCount;

  @override
  ConsumerState<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends ConsumerState<RevisionScreen> {
  Timer? _timer;
  int _secondsRemaining = 0;

  RevisionSessionNotifier get _notifier =>
      ref.read(revisionSessionNotifierProvider(widget.workspaceId).notifier);

  int _limitForMastery(double? mastery) {
    final value = mastery ?? 0;
    if (value < 0.40) return 15 * 60;
    if (value < 0.75) return 25 * 60;
    return 30 * 60;
  }

  String get _timerText {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startTimer(double? mastery) {
    _timer?.cancel();
    setState(() => _secondsRemaining = _limitForMastery(mastery));
    // Widget tests use a shortened debug session and should not keep a
    // periodic timer alive between pumpAndSettle calls.
    if (RevisionScreen.debugItemCount != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
        if (context.canPop()) context.pop();
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  void _startSession({int? itemCount}) {
    final mastery = ref
        .read(studentProgressNotifierProvider(widget.workspaceId))
        .valueOrNull
        ?.overallMastery;
    _startTimer(mastery);
    itemCount == null
        ? _notifier.start(mastery: mastery)
        : _notifier.start(itemCount: itemCount, mastery: mastery);
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoStart || RevisionScreen.debugItemCount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startSession(itemCount: RevisionScreen.debugItemCount);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Reset the family provider to a fresh idle session, then fetch —
  /// the only escape hatch from `error` / `unavailable` / `complete`.
  void _restart() {
    ref.invalidate(revisionSessionNotifierProvider(widget.workspaceId));
    final notifier =
        ref.read(revisionSessionNotifierProvider(widget.workspaceId).notifier);
    final count = RevisionScreen.debugItemCount;
    final progressVal = ref
        .read(studentProgressNotifierProvider(widget.workspaceId))
        .valueOrNull;
    _startTimer(progressVal?.overallMastery);
    count == null
        ? notifier.start(mastery: progressVal?.overallMastery)
        : notifier.start(
            itemCount: count, mastery: progressVal?.overallMastery);
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ref.watch(revisionSessionNotifierProvider(widget.workspaceId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_secondsRemaining > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RevisionHeaderPill(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFFC93C),
                    label: '${_notifier.xpEarned} XP',
                  ),
                  const SizedBox(width: 6),
                  _RevisionHeaderPill(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF6366F1),
                    label: _timerText,
                  ),
                ],
              ),
            ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick Revision',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Review your weak areas and strengthen your memory.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
            backgroundColor:
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.psychology_rounded,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      'Quick Revision',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Review your weak areas and strengthen your memory.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    FilledButton.icon(
                      onPressed: () {
                        _startSession();
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Revision Session'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
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
          showGestureHint: progress.position <= 2,
        ),
        flashcardBack: (card, progress) => _FlashcardItem(
          workspaceId: widget.workspaceId,
          card: card,
          phase: _FlashcardPhase.back,
          showGestureHint: progress.position <= 2,
        ),
        flashcardRating: (card, rating, progress) => _FlashcardItem(
          workspaceId: widget.workspaceId,
          card: card,
          phase: _FlashcardPhase.rating,
          showGestureHint: progress.position <= 2,
          pendingRating: rating,
        ),
        flashcardRated: (card, rating, progress) => _FlashcardItem(
          workspaceId: widget.workspaceId,
          card: card,
          phase: _FlashcardPhase.rated,
          showGestureHint: progress.position <= 2,
          recordedRating: rating,
        ),
        complete: (summary) => _SummaryView(
          summary: summary,
          onRestart: _restart,
          onDone: () => context.pop(),
        ),
        unavailable: (message, isNoTopics) => EmptyStateView(
          icon: isNoTopics
              ? Icons.check_circle_outline_rounded
              : Icons.hourglass_empty_rounded,
          title: isNoTopics ? "You're all caught up!" : 'Generator is busy',
          subtitle: isNoTopics
              ? "Complete a few study sessions first, then we'll automatically create personalized revision sessions based on your learning progress."
              : message,
          action: isNoTopics
              ? FilledButton.icon(
                  onPressed: () {
                    ref.read(studentHomeTabProvider.notifier).state = 1;
                    context.pop();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Study Session'),
                )
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

class _RevisionHeaderPill extends StatelessWidget {
  const _RevisionHeaderPill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
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
    final canSubmit = !submitting && (draftAnswer?.trim().isNotEmpty ?? false);

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

class _FlashcardItem extends ConsumerStatefulWidget {
  const _FlashcardItem({
    required this.workspaceId,
    required this.card,
    required this.phase,
    required this.showGestureHint,
    this.pendingRating,
    this.recordedRating,
  });

  final String workspaceId;
  final Flashcard card;
  final _FlashcardPhase phase;
  final bool showGestureHint;
  final FlashcardRating? pendingRating;
  final FlashcardRating? recordedRating;

  bool get _showBack => phase != _FlashcardPhase.front;

  @override
  ConsumerState<_FlashcardItem> createState() => _FlashcardItemState();
}

class _FlashcardItemState extends ConsumerState<_FlashcardItem>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _committing = false;
  late final AnimationController _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final animation = _animation;
        if (animation != null && mounted) {
          setState(() => _dragOffset = animation.value);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateTo(double destination) async {
    _controller
      ..stop()
      ..reset();
    _animation = Tween<double>(begin: _dragOffset, end: destination).animate(
      CurvedAnimation(
        parent: _controller,
        curve: destination == 0 ? Curves.easeOutBack : Curves.easeInCubic,
      ),
    );
    await _controller.forward();
  }

  Future<void> _commitSwipe(bool forgot) async {
    if (_committing) return;
    _committing = true;
    HapticFeedback.mediumImpact();
    await _animateTo(
      (forgot ? 1 : -1) * (MediaQuery.sizeOf(context).width + 180),
    );
    if (!mounted) return;
    final notifier = ref.read(
      revisionSessionNotifierProvider(widget.workspaceId).notifier,
    );
    await notifier.rate(forgot ? FlashcardRating.hard : FlashcardRating.easy);
    if (mounted) notifier.advance();
  }

  @override
  Widget build(BuildContext context) {
    final notifier =
        ref.read(revisionSessionNotifierProvider(widget.workspaceId).notifier);
    final canSwipe = widget.phase == _FlashcardPhase.back && !_committing;
    final swipeColor = _dragOffset >= 0 ? AppColors.error : AppColors.tertiary;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: GestureDetector(
              onTap: widget.phase == _FlashcardPhase.front
                  ? () {
                      HapticFeedback.selectionClick();
                      notifier.flip();
                    }
                  : null,
              onHorizontalDragUpdate: canSwipe
                  ? (details) => setState(() => _dragOffset += details.delta.dx)
                  : null,
              onHorizontalDragEnd: canSwipe
                  ? (details) async {
                      final velocity = details.primaryVelocity ?? 0;
                      if (_dragOffset.abs() > 96 || velocity.abs() > 700) {
                        await _commitSwipe(
                          velocity.abs() > 700 ? velocity > 0 : _dragOffset > 0,
                        );
                      } else {
                        await _animateTo(0);
                      }
                    }
                  : null,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translate(_dragOffset, 0.0, 0.0)
                  ..rotateZ(_dragOffset / 1000),
                child: Stack(
                  children: [
                    FlipCard(
                      key: ValueKey('rev:card:${widget.card.id}'),
                      showBack: widget._showBack,
                      front: FlashcardFace(
                        card: widget.card,
                        side: FlashcardSide.front,
                      ),
                      back: FlashcardFace(
                        card: widget.card,
                        side: FlashcardSide.back,
                        swipeColor: _dragOffset.abs() > 8 ? swipeColor : null,
                      ),
                    ),
                    if (_dragOffset.abs() > 20)
                      Positioned(
                        top: 32,
                        left: _dragOffset > 0 ? 24 : null,
                        right: _dragOffset < 0 ? 24 : null,
                        child: _SwipeStamp(
                          label: _dragOffset > 0 ? 'FORGOT' : 'REMEMBERED',
                          color: swipeColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _BottomBar(
          child: switch (widget.phase) {
            _FlashcardPhase.front => Text(
                'Recall the answer, then tap the card.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            _FlashcardPhase.back => widget.showGestureHint
                ? const _RevisionSwipeHint()
                : const SizedBox(height: 12),
            _FlashcardPhase.rating => _CompactRatingRow(
                enabled: false,
                pendingRating: widget.pendingRating,
                onRate: notifier.rate,
              ),
            _FlashcardPhase.rated => _RatedRow(
                recordedRating: widget.recordedRating!,
                onContinue: () => notifier.advance(),
              ),
          },
        ),
      ],
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: label == 'FORGOT' ? -0.16 : 0.16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
      );
}

class _RevisionSwipeHint extends StatelessWidget {
  const _RevisionSwipeHint();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              '←  Swipe left\nRemembered',
              textAlign: TextAlign.center,
              style: context.textTheme.labelLarge?.copyWith(
                color: AppColors.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
              width: 1, height: 36, color: context.colorScheme.outlineVariant),
          Expanded(
            child: Text(
              'Swipe right  →\nForgot',
              textAlign: TextAlign.center,
              style: context.textTheme.labelLarge?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
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
