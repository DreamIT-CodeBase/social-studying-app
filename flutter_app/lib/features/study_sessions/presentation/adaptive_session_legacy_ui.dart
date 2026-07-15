import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/theme/theme_manager.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_screen.dart'
    show FlashcardFace, FlashcardSide, FlipCard;
import 'package:social_study_app/features/questions/presentation/question_screen.dart'
    show AnswerInput;
import 'package:social_study_app/features/study_sessions/domain/adaptive_session_models.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/models/question.dart';

const _purple = Color(0xFF7C5CFC);
const _purpleLight = Color(0xFFA78BFA);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

class LegacyAdaptiveQuestionView extends ConsumerWidget {
  const LegacyAdaptiveQuestionView({
    super.key,
    required this.question,
    required this.current,
    required this.total,
    required this.remainingSeconds,
    required this.sessionXp,
    required this.lastXpDelta,
    required this.draftAnswer,
    required this.answerRevealed,
    required this.answerSubmitting,
    required this.answerMatched,
    required this.isLast,
    required this.onClose,
    required this.onAnswerChanged,
    required this.onSubmit,
    required this.onNext,
  });

  final PreparedQuestion question;
  final int current;
  final int total;
  final int remainingSeconds;
  final int sessionXp;
  final int? lastXpDelta;
  final String draftAnswer;
  final bool answerRevealed;
  final bool answerSubmitting;
  final bool? answerMatched;
  final bool isLast;
  final VoidCallback onClose;
  final ValueChanged<String> onAnswerChanged;
  final VoidCallback onSubmit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(appThemeModeProvider);
    final adaptedQuestion = _asQuestion(question);
    final feedback = answerRevealed
        ? AnswerFeedback(
            questionId: question.id,
            isCorrect: answerMatched!,
            canonicalAnswer: question.answer,
            explanation: question.explanation,
            xpEarned: answerMatched! ? 1 : -1,
            newTopicMastery: 0,
            newOverallMastery: 0,
          )
        : null;

    return ColoredBox(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: themeMode == AppThemeMode.mature
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
                            : const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/mascot/studytabbackgroundimage.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                  ),
          ),
          Column(
            children: [
              LegacySessionHeader(
                current: current,
                total: total,
                remainingSeconds: remainingSeconds,
                sessionXp: sessionXp,
                lastXpDelta: lastXpDelta,
                onClose: onClose,
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    SizedBox(
                      height: themeMode == AppThemeMode.kids ? 48 : 10,
                    ),
                    _QuestionCard(question: question),
                    const SizedBox(height: 12),
                    AnswerInput(
                      key: ValueKey('adaptive-input:${question.id}'),
                      question: adaptedQuestion,
                      draftAnswer: draftAnswer,
                      enabled: !answerRevealed && !answerSubmitting,
                      onChanged: onAnswerChanged,
                      feedback: feedback,
                    ),
                    if (answerRevealed) ...[
                      const SizedBox(height: 12),
                      _AnswerFeedbackCard(
                        correct: answerMatched!,
                        correctAnswer:
                            _displayAnswer(question, question.answer),
                        explanation: question.explanation,
                      ),
                    ],
                  ],
                ),
              ),
              _StudyActionBar(
                enabled: !answerSubmitting &&
                    (answerRevealed || draftAnswer.trim().isNotEmpty),
                submitting: answerSubmitting,
                feedbackVisible: answerRevealed,
                isLast: isLast,
                onPressed: answerRevealed ? onNext : onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Question _asQuestion(PreparedQuestion source) => Question(
        id: source.id,
        topic: source.topic,
        questionType: switch (source.questionType) {
          'mcq' => QuestionType.mcq,
          'true_false' => QuestionType.trueFalse,
          'long_answer' => QuestionType.longAnswer,
          'mathematical' => QuestionType.mathematical,
          _ => QuestionType.shortAnswer,
        },
        difficulty: switch (source.difficulty) {
          'advanced' => DifficultyLevel.advanced,
          'intermediate' => DifficultyLevel.intermediate,
          _ => DifficultyLevel.beginner,
        },
        body: source.body,
        options: source.options
            .map((option) => McqOption(key: option.key, text: option.text))
            .toList(growable: false),
      );
}

class LegacyAdaptiveFlashcardView extends StatelessWidget {
  const LegacyAdaptiveFlashcardView({
    super.key,
    required this.card,
    required this.current,
    required this.total,
    required this.remainingSeconds,
    required this.sessionXp,
    required this.lastXpDelta,
    required this.revealed,
    required this.rating,
    required this.dragOffset,
    required this.onClose,
    required this.onReveal,
    required this.onDragUpdate,
    required this.onDragCancel,
    required this.onRate,
  });

  final PreparedFlashcard card;
  final int current;
  final int total;
  final int remainingSeconds;
  final int sessionXp;
  final int? lastXpDelta;
  final bool revealed;
  final bool rating;
  final double dragOffset;
  final VoidCallback onClose;
  final VoidCallback onReveal;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragCancel;
  final ValueChanged<bool> onRate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF2A2A50) : const Color(0xFFE5E7EB);
    final progress = (dragOffset.abs() / 150).clamp(0.0, 1.0);
    final target = dragOffset >= 0 ? _green : _red;
    final swipeColor =
        dragOffset.abs() < 10 ? border : Color.lerp(border, target, progress)!;
    final adaptedCard = Flashcard(
      id: card.id,
      topic: card.topic,
      front: card.front,
      back: card.back,
      explanation: card.explanation,
    );

    return ColoredBox(
      color: isDark ? const Color(0xFF0D0D1F) : Colors.white,
      child: Column(
        children: [
          LegacySessionHeader(
            current: current,
            total: total,
            remainingSeconds: remainingSeconds,
            sessionXp: sessionXp,
            lastXpDelta: lastXpDelta,
            onClose: onClose,
            flashcardStyle: true,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: GestureDetector(
                onTap: rating ? null : onReveal,
                onHorizontalDragUpdate: !revealed || rating
                    ? null
                    : (details) => onDragUpdate(details.delta.dx),
                onHorizontalDragEnd: !revealed || rating
                    ? null
                    : (_) {
                        if (dragOffset.abs() >= 95) {
                          onRate(dragOffset > 0);
                        } else {
                          onDragCancel();
                        }
                      },
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(dragOffset, 0.0, 0.0)
                    ..rotateZ(dragOffset / 1000),
                  child: Stack(
                    children: [
                      FlipCard(
                        key: ValueKey('adaptive-card:${card.id}'),
                        showBack: revealed,
                        front: FlashcardFace(
                          card: adaptedCard,
                          side: FlashcardSide.front,
                          swipeColor: swipeColor,
                        ),
                        back: FlashcardFace(
                          card: adaptedCard,
                          side: FlashcardSide.back,
                          swipeColor: swipeColor,
                        ),
                      ),
                      if (dragOffset.abs() > 24)
                        Positioned(
                          top: 32,
                          left: dragOffset > 0 ? 24 : null,
                          right: dragOffset < 0 ? 24 : null,
                          child: Transform.rotate(
                            angle: dragOffset > 0 ? -0.18 : 0.18,
                            child: _SwipeStamp(remembered: dragOffset > 0),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _FlashcardActions(
            revealed: revealed,
            enabled: !rating,
            isFirstCard: current == 1,
            onReveal: onReveal,
            onNeedsReview: () => onRate(false),
            onRemember: () => onRate(true),
          ),
        ],
      ),
    );
  }
}

class LegacySessionHeader extends StatelessWidget {
  const LegacySessionHeader({
    super.key,
    required this.current,
    required this.total,
    required this.remainingSeconds,
    required this.sessionXp,
    required this.lastXpDelta,
    required this.onClose,
    this.flashcardStyle = false,
  });

  final int current;
  final int total;
  final int remainingSeconds;
  final int sessionXp;
  final int? lastXpDelta;
  final VoidCallback onClose;
  final bool flashcardStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? (flashcardStyle ? const Color(0xFF13132A) : const Color(0xFF1E293B))
        : Colors.white;
    final border = isDark
        ? (flashcardStyle ? const Color(0xFF2A2A50) : const Color(0xFF2D3748))
        : const Color(0xFFE2E8F0);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _HeaderPill(
                    surface: surface,
                    border: border,
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    text: '${_signed(sessionXp)} XP',
                  ),
                  Positioned(
                    top: -15,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: lastXpDelta == null ? 0 : 1,
                      child: Text(
                        '${_signed(lastXpDelta ?? 0)} XP',
                        style: TextStyle(
                          color: (lastXpDelta ?? 0) < 0 ? _red : _green,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              _HeaderPill(
                surface: surface,
                border: border,
                icon: Icons.timer_outlined,
                iconColor: _purple,
                text: _formatRemainingTime(remainingSeconds),
              ),
              const Spacer(),
              _HeaderPill(
                surface: surface,
                border: border,
                icon: Icons.auto_stories_rounded,
                iconColor: _purple,
                text: '$current/$total',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Session Progress',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$current of $total',
                style: TextStyle(
                  color: flashcardStyle ? _purpleLight : _purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : current / total,
              minHeight: 5,
              backgroundColor: border,
              valueColor: const AlwaysStoppedAnimation<Color>(_purple),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRemainingTime(int totalSeconds) {
  final safeSeconds = totalSeconds.clamp(0, 99 * 60 + 59);
  final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (safeSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.surface,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final Color surface;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final PreparedQuestion question;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subject = _subjectFor(question.topic);
    final accent = _subjectColor(subject);
    final accentBackground = _subjectBackground(subject, isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: accentBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_subjectIcon(subject), color: accent, size: 28),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 82),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      subject.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  question.body,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: Icons.menu_book_rounded,
                  label: question.topic,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.star_half_rounded,
                label: _capitalized(question.difficulty),
                color: question.difficulty == 'advanced'
                    ? _red
                    : question.difficulty == 'intermediate'
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _AnswerFeedbackCard extends StatelessWidget {
  const _AnswerFeedbackCard({
    required this.correct,
    required this.correctAnswer,
    required this.explanation,
  });

  final bool correct;
  final String correctAnswer;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = correct ? _green : _red;
    final background = correct
        ? (isDark ? const Color(0xFF062F1D) : const Color(0xFFF0FDF4))
        : (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 18 * (1 - value)),
        child: Opacity(opacity: value.clamp(0, 1), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FeedbackBadge(correct: correct),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correct ? 'Correct!  +1 XP' : 'Not quite  -1 XP',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!correct) ...[
                    const SizedBox(height: 7),
                    const Text(
                      'CORRECT ANSWER',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      correctAnswer,
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      explanation,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBadge extends StatelessWidget {
  const _FeedbackBadge({required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    final color = correct ? _green : _red;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                correct ? Icons.shield_rounded : Icons.cancel_rounded,
                color: color,
                size: 28,
              ),
            ),
            if (correct)
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFD700), size: 14),
          ],
        ),
      ),
    );
  }
}

class _StudyActionBar extends StatelessWidget {
  const _StudyActionBar({
    required this.enabled,
    required this.feedbackVisible,
    required this.submitting,
    required this.isLast,
    required this.onPressed,
  });

  final bool enabled;
  final bool feedbackVisible;
  final bool submitting;
  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        feedbackVisible ? const Color(0xFF10B981) : const Color(0xFF4F46E5);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            backgroundColor: color,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      feedbackVisible
                          ? (isLast ? 'Finish Session' : 'Next Question')
                          : 'Submit Answer',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      feedbackVisible
                          ? (isLast
                              ? Icons.flag_rounded
                              : Icons.arrow_forward_rounded)
                          : Icons.check_rounded,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.remembered});

  final bool remembered;

  @override
  Widget build(BuildContext context) {
    final color = remembered ? _green : _red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        remembered ? 'REMEMBERED  +1' : 'NEEDS REVIEW  -1',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _FlashcardActions extends StatelessWidget {
  const _FlashcardActions({
    required this.revealed,
    required this.enabled,
    required this.isFirstCard,
    required this.onReveal,
    required this.onNeedsReview,
    required this.onRemember,
  });

  final bool revealed;
  final bool enabled;

  /// True only for the very first card in the session — shows swipe guidelines.
  final bool isFirstCard;
  final VoidCallback onReveal;
  final VoidCallback onNeedsReview;
  final VoidCallback onRemember;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0D0D1F) : Colors.white;
    final surface = isDark ? const Color(0xFF1A1A3A) : Colors.white;
    final border = isDark ? const Color(0xFF2A2A50) : const Color(0xFFE5E7EB);

    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        // After reveal: show swipe guide on card 1, nothing on later cards.
        // Before reveal: show nothing (tap-to-reveal hint removed).
        child: revealed
            ? (isFirstCard
                ? Container(
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SwipeAction(
                            icon: Icons.arrow_back_rounded,
                            title: 'Swipe Left',
                            subtitle: 'Needs Review  -1',
                            color: _red,
                            onTap: enabled ? onNeedsReview : null,
                          ),
                        ),
                        Container(width: 1, height: 50, color: border),
                        Expanded(
                          child: _SwipeAction(
                            icon: Icons.arrow_forward_rounded,
                            title: 'Swipe Right',
                            subtitle: 'Remember  +1',
                            color: _green,
                            trailingIcon: true,
                            onTap: enabled ? onRemember : null,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink())
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.trailingIcon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 17),
    );
    final label = Column(
      crossAxisAlignment:
          trailingIcon ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: trailingIcon
              ? [label, const SizedBox(width: 8), iconWidget]
              : [iconWidget, const SizedBox(width: 8), label],
        ),
      ),
    );
  }
}

String _signed(int value) => value > 0 ? '+$value' : '$value';

String _capitalized(String value) => value.isEmpty
    ? value
    : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';

String _displayAnswer(PreparedQuestion question, String answer) {
  if (question.questionType != 'mcq') return answer;
  for (final option in question.options) {
    if (option.key.toLowerCase() == answer.toLowerCase()) {
      return '${option.key}. ${option.text}';
    }
  }
  return answer;
}

String _subjectFor(String topic) {
  final value = topic.toLowerCase();
  if (value.contains('cell') ||
      value.contains('bio') ||
      value.contains('gene') ||
      value.contains('dna')) {
    return 'Biology';
  }
  if (value.contains('chem') ||
      value.contains('atom') ||
      value.contains('bond')) {
    return 'Chemistry';
  }
  if (value.contains('phys') ||
      value.contains('force') ||
      value.contains('motion')) {
    return 'Physics';
  }
  return 'Study';
}

IconData _subjectIcon(String subject) => switch (subject) {
      'Biology' => Icons.biotech_rounded,
      'Chemistry' => Icons.science_rounded,
      'Physics' => Icons.bolt_rounded,
      _ => Icons.menu_book_rounded,
    };

Color _subjectColor(String subject) => switch (subject) {
      'Biology' => const Color(0xFF7E22CE),
      'Chemistry' => const Color(0xFF0369A1),
      'Physics' => const Color(0xFFB45309),
      _ => const Color(0xFF2563EB),
    };

Color _subjectBackground(String subject, bool isDark) {
  if (isDark) return _subjectColor(subject).withValues(alpha: 0.18);
  return switch (subject) {
    'Biology' => const Color(0xFFF3E8FF),
    'Chemistry' => const Color(0xFFE0F2FE),
    'Physics' => const Color(0xFFFEF3C7),
    _ => const Color(0xFFEFF6FF),
  };
}
