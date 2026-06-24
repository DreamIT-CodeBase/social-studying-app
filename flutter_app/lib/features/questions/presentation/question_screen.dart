import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/services/sound_service.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/gamification/presentation/widgets/celebration_overlay.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
import 'package:social_study_app/features/questions/domain/question_session.dart';
import 'package:social_study_app/features/questions/presentation/question_session_notifier.dart';
import 'package:social_study_app/shared/models/question.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';
import 'package:social_study_app/features/mascot/models/mascot_state.dart';
import 'package:social_study_app/features/mascot/widgets/study_buddy.dart';

/// Question-answering interface (Sprint 4.7) and answer feedback
/// (Sprint 4.8) — one screen, because [QuestionSession] is a single
/// state machine spanning the whole loop: idle → loading → ready →
/// submitting → feedback → loading → …
///
/// Renders inside the Study tab of the student home Scaffold, so it
/// has no AppBar of its own. Every state in the union maps to a branch
/// here (Boil the Lake): loading, all five question formats, the
/// submitting state, feedback, the unavailable cases, and a generic
/// error with retry.
class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  QuestionSessionNotifier get _notifier =>
      ref.read(questionSessionNotifierProvider(widget.workspaceId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifier.start();
      }
    });
  }

  @override
  void didUpdateWidget(QuestionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workspaceId != oldWidget.workspaceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notifier.start();
        }
      });
    }
  }

  // Auto-starts on load. If the session is ever reset/ended, the idle view
  // shows a "Start Study Session" button that drives the session via _restart().

  /// Reset the family provider to a fresh idle session, then fetch.
  /// This is the only escape hatch from the `error` / `unavailable`
  /// states — the notifier's own `start`/`next` are deliberately
  /// guarded against those.
  void _restart() {
    ref.invalidate(questionSessionNotifierProvider(widget.workspaceId));
    _notifier.start();
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ref.watch(questionSessionNotifierProvider(widget.workspaceId));
    final isAdmin = ref.watch(isActiveWorkspaceAdminProvider);

    return session.when(
      idle: () => EmptyStateView(
        icon: Icons.quiz_rounded,
        title: 'Ready to study?',
        subtitle: 'Tap below to start a new question session.',
        action: FilledButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Study Session'),
        ),
      ),
      loading: () =>
          const LoadingIndicator(message: 'Generating your question…'),
      ready: (question, draftAnswer) => _QuestionView(
        workspaceId: widget.workspaceId,
        question: question,
        draftAnswer: draftAnswer,
        submitting: false,
      ),
      submitting: (question, draftAnswer) => _QuestionView(
        workspaceId: widget.workspaceId,
        question: question,
        draftAnswer: draftAnswer,
        submitting: true,
      ),
      feedback: (question, submittedAnswer, feedback) => _FeedbackView(
        key: ValueKey('feedback:${question.id}'),
        workspaceId: widget.workspaceId,
        question: question,
        submittedAnswer: submittedAnswer,
        feedback: feedback,
      ),
      unavailable: (message, isNoTopics, retryAfterSeconds) => EmptyStateView(
        icon: isNoTopics
            ? Icons.menu_book_rounded
            : Icons.hourglass_empty_rounded,
        title: isNoTopics ? 'No questions yet' : 'Generator is busy',
        subtitle: isNoTopics
            ? (isAdmin
                ? 'Upload study material in the Home tab before '
                    'questions can be generated.'
                : 'Your teacher needs to upload study material before '
                    'questions can be generated.')
            : message,
        // "No topics" can't be fixed by retrying — only the busy case
        // gets a retry button.
        action: isNoTopics
            ? null
            : FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
      ),
      error: (message) => ErrorView(message: message, onRetry: _restart),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Question view (4.7) — the answering interface
// ─────────────────────────────────────────────────────────────────────────

class _QuestionView extends ConsumerWidget {
  const _QuestionView({
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
        ref.read(questionSessionNotifierProvider(workspaceId).notifier);
    final canSubmit =
        !submitting && (draftAnswer?.trim().isNotEmpty ?? false);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              const Center(
                child: StudyBuddy(
                  state: MascotState.idle,
                  size: 64,
                ),
              ),
              const SizedBox(height: Spacing.md),
              _QuestionHeader(question: question),
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
                // Key by question id so a text controller is rebuilt
                // fresh when the next question arrives.
                key: ValueKey('input:${question.id}'),
                question: question,
                draftAnswer: draftAnswer,
                enabled: !submitting,
                onChanged: notifier.setDraftAnswer,
              ),
            ],
          ),
        ),
        _SubmitBar(
          enabled: canSubmit,
          submitting: submitting,
          onSubmit: notifier.submit,
        ),
      ],
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            question.topic.toUpperCase(),
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        _DifficultyChip(difficulty: question.difficulty),
      ],
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});

  final DifficultyLevel difficulty;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (difficulty) {
      DifficultyLevel.beginner => ('Beginner', AppColors.tertiary),
      DifficultyLevel.intermediate => ('Intermediate', AppColors.secondary),
      DifficultyLevel.advanced => ('Advanced', AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Dispatches to the right input widget for the question's format.
class AnswerInput extends StatelessWidget {
  const AnswerInput({
    super.key,
    required this.question,
    required this.draftAnswer,
    required this.enabled,
    required this.onChanged,
  });

  final Question question;
  final String? draftAnswer;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return switch (question.questionType) {
      QuestionType.mcq => _McqInput(
          options: question.options,
          selectedKey: draftAnswer,
          enabled: enabled,
          onSelect: onChanged,
        ),
      QuestionType.trueFalse => _TrueFalseInput(
          selected: draftAnswer,
          enabled: enabled,
          onSelect: onChanged,
        ),
      QuestionType.shortAnswer => _TextAnswerInput(
          initialValue: draftAnswer,
          enabled: enabled,
          onChanged: onChanged,
          hintText: 'Type your answer',
          minLines: 1,
          maxLines: 2,
        ),
      QuestionType.longAnswer => _TextAnswerInput(
          initialValue: draftAnswer,
          enabled: enabled,
          onChanged: onChanged,
          hintText: 'Write your full answer',
          minLines: 5,
          maxLines: 10,
        ),
      QuestionType.mathematical => _TextAnswerInput(
          initialValue: draftAnswer,
          enabled: enabled,
          onChanged: onChanged,
          hintText: 'Enter your answer — LaTeX notation is supported',
          minLines: 1,
          maxLines: 3,
          monospace: true,
        ),
    };
  }
}

class _McqInput extends StatelessWidget {
  const _McqInput({
    required this.options,
    required this.selectedKey,
    required this.enabled,
    required this.onSelect,
  });

  final List<McqOption> options;
  final String? selectedKey;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options) ...[
          _OptionCard(
            label: option.key,
            text: option.text,
            selected: option.key == selectedKey,
            enabled: enabled,
            onTap: () => onSelect(option.key),
          ),
          if (option != options.last) const SizedBox(height: Spacing.sm),
        ],
      ],
    );
  }
}

class _TrueFalseInput extends StatelessWidget {
  const _TrueFalseInput({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OptionCard(
            label: 'T',
            text: 'True',
            selected: selected == 'true',
            enabled: enabled,
            onTap: () => onSelect('true'),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _OptionCard(
            label: 'F',
            text: 'False',
            selected: selected == 'false',
            enabled: enabled,
            onTap: () => onSelect('false'),
          ),
        ),
      ],
    );
  }
}

/// A tappable answer option — used for both MCQ choices and true/false.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? context.colorScheme.primary
        : context.colorScheme.outlineVariant;
    return Material(
      color: selected
          ? context.colorScheme.primaryContainer
          : context.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? context.colorScheme.primary
                      : context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? context.colorScheme.onPrimary
                        : context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  text,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: context.colorScheme.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free-text answer field for short_answer, long_answer, and
/// mathematical questions. Owns its [TextEditingController]; the parent
/// keys this widget by question id so the controller is fresh per
/// question.
class _TextAnswerInput extends StatefulWidget {
  const _TextAnswerInput({
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
    this.monospace = false,
  });

  final String? initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool monospace;

  @override
  State<_TextAnswerInput> createState() => _TextAnswerInputState();
}

class _TextAnswerInputState extends State<_TextAnswerInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      autocorrect: !widget.monospace,
      textCapitalization: widget.monospace
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      style: widget.monospace
          ? const TextStyle(fontFamily: 'monospace')
          : null,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// Persistent bottom bar carrying the submit action.
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.enabled,
    required this.submitting,
    required this.onSubmit,
  });

  final bool enabled;
  final bool submitting;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: context.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: enabled ? () => onSubmit() : null,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Feedback view (4.8) — correctness, explanation, XP, next CTA
// ─────────────────────────────────────────────────────────────────────────

class _FeedbackView extends ConsumerStatefulWidget {
  const _FeedbackView({
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
  ConsumerState<_FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends ConsumerState<_FeedbackView> {
  late MascotState _mascotState;

  @override
  void initState() {
    super.initState();
    
    if (widget.feedback.isCorrect) {
      _mascotState = MascotState.happy;
      HapticFeedback.heavyImpact();
      // Play success chime on correct answer.
      SoundService.instance.playCorrectAnswer();
    } else {
      _mascotState = MascotState.sad;
      HapticFeedback.lightImpact();
      // Play wrong-answer sound on incorrect answer.
      SoundService.instance.playWrongAnswer();
    }

    // Reset mascot to idle after 2.5 seconds.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _mascotState = MascotState.idle;
        });
      }
    });

    // Sprint 5.5 celebrations. Run after the feedback view renders so
    // the overlay sits above the result banner (the user briefly sees
    // their score before the celebration kicks in). Each is awaited
    // sequentially — a level-up that also unlocks a badge shows the
    // burst first, then the badge sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCelebrations());
  }

  Future<void> _runCelebrations() async {
    final feedback = widget.feedback;
    if (feedback.leveledUp && mounted) {
      await showLevelUpBurst(context, newLevel: feedback.newLevel);
    }
    for (final unlock in feedback.badgesUnlocked) {
      if (!mounted) break;
      await showBadgeUnlockSheet(
        context,
        badgeId: unlock.badgeId,
        name: unlock.name,
        description: unlock.description,
        icon: unlock.icon,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final correct = feedback.isCorrect;
    final accent = correct ? AppColors.tertiary : AppColors.error;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              Center(
                child: StudyBuddy(
                  state: _mascotState,
                  size: 96,
                ),
              ),
              const SizedBox(height: Spacing.md),
              _ResultBanner(correct: correct, accent: accent),
              const SizedBox(height: Spacing.lg),
              _AnswerComparison(
                question: widget.question,
                submittedAnswer: widget.submittedAnswer,
                feedback: feedback,
                accent: accent,
              ),
              const SizedBox(height: Spacing.lg),
              _ExplanationCard(explanation: feedback.explanation),
              if (feedback.rubricScore != null) ...[
                const SizedBox(height: Spacing.lg),
                _RubricCard(
                  score: feedback.rubricScore!,
                  matchedHints: feedback.matchedHints,
                ),
              ],
              const SizedBox(height: Spacing.lg),
              _RewardRow(feedback: feedback),
            ],
          ),
        ),
        _NextBar(
          onNext: ref
              .read(
                questionSessionNotifierProvider(widget.workspaceId).notifier,
              )
              .next,
          onEndSession: ref
              .read(
                questionSessionNotifierProvider(widget.workspaceId).notifier,
              )
              .endSession,
        ),
      ],
    );
  }
}

/// Animated correct/incorrect banner — scales + fades in when feedback
/// first renders.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.correct, required this.accent});

  final bool correct;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: accent.withAlpha(31),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              correct
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: accent,
              size: 44,
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correct ? 'Correct!' : 'Not quite',
                    style: context.textTheme.headlineSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    correct
                        ? 'Nicely done — keep the streak going.'
                        : 'Review the explanation below and try the next one.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
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

class _AnswerComparison extends StatelessWidget {
  const _AnswerComparison({
    required this.question,
    required this.submittedAnswer,
    required this.feedback,
    required this.accent,
  });

  final Question question;
  final String submittedAnswer;
  final AnswerFeedback feedback;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnswerRow(
              label: 'Your answer',
              value: _displayAnswer(question, submittedAnswer),
              color: accent,
            ),
            if (!feedback.isCorrect) ...[
              const Divider(height: Spacing.xl),
              _AnswerRow(
                label: 'Correct answer',
                value: _displayAnswer(question, feedback.canonicalAnswer),
                color: AppColors.tertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
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

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.explanation});

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
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                'Explanation',
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            explanation,
            style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Rubric breakdown — only shown for rubric-scored question types
/// (long_answer, mathematical) where [AnswerFeedback.rubricScore] is set.
class _RubricCard extends StatelessWidget {
  const _RubricCard({required this.score, required this.matchedHints});

  final double score;
  final List<String> matchedHints;

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
                Expanded(
                  child: Text(
                    'Rubric score',
                    style: context.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${(score * 100).round()}%',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: context.colorScheme.surfaceContainerHighest,
              ),
            ),
            if (matchedHints.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              Text(
                'Points you covered',
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              for (final hint in matchedHints)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Expanded(
                        child: Text(
                          hint,
                          style: context.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// XP earned + the new topic mastery, side by side.
class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.feedback});

  final AnswerFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final xp = feedback.xpEarned;
    final isNegative = xp < 0;
    final xpColor = isNegative ? AppColors.error : AppColors.secondary;
    final xpIcon = isNegative
        ? Icons.bolt_rounded  // keep bolt but colour it red
        : Icons.bolt_rounded;
    final xpLabel = isNegative ? '$xp XP' : '+$xp XP';

    return Row(
      children: [
        Expanded(
          child: _RewardTile(
            icon: xpIcon,
            color: xpColor,
            value: xpLabel,
            label: isNegative ? 'XP penalty' : 'XP earned',
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _RewardTile(
            icon: Icons.trending_up_rounded,
            color: AppColors.primary,
            value: '${(feedback.newTopicMastery * 100).round()}%',
            label: 'Topic mastery',
          ),
        ),
      ],
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: Spacing.xs),
          Text(
            value,
            style: context.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextBar extends StatelessWidget {
  const _NextBar({required this.onNext, required this.onEndSession});

  final Future<void> Function() onNext;
  final VoidCallback onEndSession;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: context.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              TextButton(
                onPressed: onEndSession,
                child: const Text('End Session'),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: () => onNext(),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next Question'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a raw answer string in a student-friendly form: an MCQ key
/// becomes the option text, `true`/`false` is capitalized, free text is
/// shown as-is.
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
