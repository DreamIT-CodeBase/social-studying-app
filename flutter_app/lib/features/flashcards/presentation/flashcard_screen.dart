import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/services/sound_service.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/flashcards/domain/flashcard_session.dart';
import 'package:social_study_app/features/flashcards/presentation/flashcard_session_notifier.dart';
import 'package:social_study_app/features/gamification/presentation/widgets/celebration_overlay.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';

/// Flashcard review interface — Sprint 4.9 (MCQ redesign).
///
/// Renders inside the Flashcards tab of the student home Scaffold, so it
/// has no AppBar of its own. Drives the [FlashcardSession] state machine.
///
/// **Interaction flow (MCQ redesign):**
/// 1. Front card shown → student taps → two MCQ options appear at the bottom
///    (card stays on front face, no flip yet).
/// 2. Student selects an option:
///    - Selected option is highlighted immediately.
///    - System pauses briefly (250ms) to confirm the selection.
///    - Card flips to reveal the back.
/// 3. Back card displays validation & rich feedback:
///    - Correct: Green success badge ("Correct!").
///    - Incorrect: Red incorrect badge ("Incorrect"), showing what was selected (strikethrough)
///      and the correct answer clearly highlighted.
///    - Concise explanation is shown below the answer.
/// 4. "Next Card" button advances the session.
class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  FlashcardSessionNotifier get _notifier =>
      ref.read(flashcardSessionNotifierProvider(widget.workspaceId).notifier);

  @override
  void initState() {
    super.initState();
    // Auto-start the session immediately — skip the idle landing screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progressVal =
          ref.read(studentProgressNotifierProvider(widget.workspaceId)).valueOrNull;
      _notifier.start(mastery: progressVal?.overallMastery);
    });
  }

  @override
  void didUpdateWidget(FlashcardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workspaceId != oldWidget.workspaceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.invalidate(flashcardSessionNotifierProvider(widget.workspaceId));
        }
      });
    }
  }

  /// Run level-up burst and badge unlocks in sequence on the root navigator.
  Future<void> _playCelebrations(
    BuildContext context,
    FlashcardRatingResponse response,
  ) async {
    if (response.leveledUp) {
      if (!context.mounted) return;
      await showLevelUpBurst(context, newLevel: response.newLevel);
    }
    for (final unlock in response.badgesUnlocked) {
      if (!context.mounted) return;
      await showBadgeUnlockSheet(
        context,
        badgeId: unlock.badgeId,
        name: unlock.name,
        description: unlock.description,
        icon: unlock.icon,
      );
    }
  }

  void _restart() {
    ref.invalidate(flashcardSessionNotifierProvider(widget.workspaceId));
    final progressVal = ref.read(studentProgressNotifierProvider(widget.workspaceId)).valueOrNull;
    ref
        .read(flashcardSessionNotifierProvider(widget.workspaceId).notifier)
        .start(mastery: progressVal?.overallMastery);
  }

  @override
  Widget build(BuildContext context) {
    // Fire celebrations exactly once per transition into `rated`.
    ref.listen(
      flashcardSessionNotifierProvider(widget.workspaceId),
      (prev, next) {
        next.whenOrNull(
          rated: (_, response) {
            _playCelebrations(context, response);
            Future.delayed(const Duration(milliseconds: 400), () {
              if (context.mounted) {
                ref
                    .read(flashcardSessionNotifierProvider(widget.workspaceId).notifier)
                    .next();
              }
            });
          },
        );
      },
    );

    final session =
        ref.watch(flashcardSessionNotifierProvider(widget.workspaceId));
    final notifier =
        ref.read(flashcardSessionNotifierProvider(widget.workspaceId).notifier);
    final currentIndex = notifier.currentIndex;
    final isAdmin = ref.watch(isActiveWorkspaceAdminProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return session.when(
      idle: () => Scaffold(
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
                  child: Icon(Icons.style_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: Spacing.xl),
                Text(
                  'Flashcard Review',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Your review session length is automatically customized based on your mastery.',
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
                  label: const Text('Start Review Session'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      loading: () => const LoadingIndicator(message: 'Finding a card…'),
      // Key by card id so _CardViewState resets when a new card arrives.
      viewingFront: (card) => _CardView(
        key: ValueKey(card.id),
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.front,
        currentIndex: currentIndex,
      ),
      revealed: (card) => _CardView(
        key: ValueKey(card.id),
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.revealed,
        currentIndex: currentIndex,
      ),
      rating: (card, _) => _CardView(
        key: ValueKey(card.id),
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.rating,
        currentIndex: currentIndex,
      ),
      rated: (card, _) => _CardView(
        key: ValueKey(card.id),
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.rated,
        currentIndex: currentIndex,
      ),
      completed: (easyCount, mediumCount, hardCount) =>
          _SessionCompletedView(
        correctCount: easyCount,
        incorrectCount: hardCount,
        onRestart: notifier.resetSession,
      ),
      unavailable: (message, isNoTopics, retryAfterSeconds) => EmptyStateView(
        icon: isNoTopics
            ? Icons.menu_book_rounded
            : Icons.hourglass_empty_rounded,
        title: isNoTopics ? 'No flashcards yet' : 'Generator is busy',
        subtitle: isNoTopics
            ? (isAdmin
                ? 'Upload study material in the Home tab before '
                    'flashcards can be generated.'
                : 'Your teacher needs to upload study material before '
                    'flashcards can be generated.')
            : message,
        useMascot: true,
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

// ─────────────────────────────────────────────────────────────────────────────
// Phase + answer-result enums
// ─────────────────────────────────────────────────────────────────────────────

/// The session phase for the card currently on screen.
enum _Phase { front, revealed, rating, rated }

/// Whether the student's MCQ selection was correct or incorrect.
/// Passed into [FlashcardFace] to render the result banner on the back face.
enum _AnswerResult { correct, incorrect }

// ─────────────────────────────────────────────────────────────────────────────
// _CardView — stateful, owns MCQ local state
// ─────────────────────────────────────────────────────────────────────────────

class _CardView extends ConsumerStatefulWidget {
  const _CardView({
    super.key,
    required this.workspaceId,
    required this.card,
    required this.phase,
    required this.currentIndex,
  });

  final String workspaceId;
  final Flashcard card;
  final _Phase phase;
  final int currentIndex;

  bool get _showBack => phase != _Phase.front;

  @override
  ConsumerState<_CardView> createState() => _CardViewState();
}

class _CardViewState extends ConsumerState<_CardView> {
  double _dragOffset = 0.0;
  late Stopwatch _stopwatch;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _revealed = widget.phase != _Phase.front;
  }

  @override
  void didUpdateWidget(_CardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.id != oldWidget.card.id) {
      _stopwatch.reset();
      _stopwatch.start();
      _dragOffset = 0.0;
      _revealed = widget.phase != _Phase.front;
    }
    if (widget.phase != oldWidget.phase) {
      _revealed = widget.phase != _Phase.front;
    }
  }

  double _calculateAccuracy(List<FlashcardRating> ratings, FlashcardRating currentRating) {
    final allRatings = [...ratings, currentRating];
    final correctCount = allRatings.where((r) => r == FlashcardRating.easy).length;
    return (correctCount / allRatings.length) * 100.0;
  }

  void _onCardTap() {
    if (widget.phase != _Phase.front) return;
    SoundService.instance.playCardFlip();
    ref.read(flashcardSessionNotifierProvider(widget.workspaceId).notifier).flip();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(
      flashcardSessionNotifierProvider(widget.workspaceId).notifier,
    );
    final targetLength = notifier.sessionTargetLength;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBorder = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    
    Color borderColor = baseBorder;
    double borderWidth = 1.0;
    
    if (widget.phase == _Phase.revealed && _dragOffset != 0) {
      final progress = (_dragOffset.abs() / 150).clamp(0.0, 1.0);
      final activeColor = _dragOffset > 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
      borderColor = Color.lerp(baseBorder, activeColor, progress)!;
      borderWidth = 1.0 + (progress * 2.0);
    }

    return Column(
      children: [
        // ── Session progress bar ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Session Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${widget.currentIndex} of $targetLength',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.currentIndex / targetLength,
                  minHeight: 6,
                  backgroundColor:
                      context.colorScheme.primaryContainer.withAlpha(50),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Flip card ───────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: GestureDetector(
              onTap: widget.phase == _Phase.front ? _onCardTap : null,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragOffset += details.delta.dx;
                });
              },
              onHorizontalDragEnd: (details) async {
                if (_dragOffset.abs() > 120) {
                  final isRight = _dragOffset > 0;
                  final rating = isRight ? FlashcardRating.hard : FlashcardRating.easy;
                  
                  setState(() {
                    _dragOffset = isRight ? 600 : -600;
                  });
                  
                  final responseTimeMs = _stopwatch.elapsedMilliseconds;
                  _stopwatch.stop();
                  
                  final accuracy = _calculateAccuracy(notifier.sessionRatings, rating);
                  
                  // Submit rating
                  notifier.rate(
                    rating,
                    isCorrect: !isRight,
                    responseTimeMs: responseTimeMs,
                    sessionProgress: widget.currentIndex,
                    accuracyPercentage: accuracy,
                  );
                } else {
                  setState(() {
                    _dragOffset = 0.0;
                  });
                }
              },
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translate(_dragOffset, 0.0, 0.0)
                  ..rotateZ(_dragOffset / 1000.0),
                child: Stack(
                  children: [
                    FlipCard(
                      key: ValueKey('card:${widget.card.id}'),
                      showBack: _revealed,
                      front: FlashcardFace(
                        card: widget.card,
                        side: FlashcardSide.front,
                        swipeColor: _dragOffset != 0 ? borderColor : null,
                        swipeBorderWidth: borderWidth,
                      ),
                      back: FlashcardFace(
                        card: widget.card,
                        side: FlashcardSide.back,
                        swipeColor: _dragOffset != 0 ? borderColor : null,
                        swipeBorderWidth: borderWidth,
                      ),
                    ),
                    // Floating status overlays during swipe
                    if (_dragOffset.abs() > 20)
                      Positioned(
                        top: 40,
                        left: _dragOffset > 0 ? 40 : null,
                        right: _dragOffset < 0 ? 40 : null,
                        child: Transform.rotate(
                          angle: _dragOffset > 0 ? -0.2 : 0.2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_dragOffset > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E)).withAlpha(220),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _dragOffset > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              _dragOffset > 0 ? 'FORGOT' : 'REMEMBERED',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── Bottom action area ──────────────────────────────────────────
        _ActionArea(phase: widget.phase),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flip card (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

/// A card that rotates around its vertical axis to reveal [back].
///
/// The flip is driven by [showBack]: the parent rebuilds this widget
/// with a new value when the session transitions viewingFront →
/// revealed, and [didUpdateWidget] runs the animation. The widget is
/// keyed by card id, so a new card resets to the front.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.showBack,
    required this.front,
    required this.back,
  });

  final bool showBack;
  final Widget front;
  final Widget back;

  @override
  State<FlipCard> createState() => FlipCardState();
}

class FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.showBack ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack != oldWidget.showBack) {
      widget.showBack ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * math.pi;
        final isFront = _controller.value < 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          child: isFront
              ? widget.front
              // The back face is counter-rotated so its content reads
              // correctly once the card has flipped past halfway.
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: widget.back,
                ),
        );
      },
    );
  }
}

enum FlashcardSide { front, back }

// ─────────────────────────────────────────────────────────────────────────────
// FlashcardFace
// ─────────────────────────────────────────────────────────────────────────────

class FlashcardFace extends StatelessWidget {
  const FlashcardFace({
    super.key,
    required this.card,
    required this.side,
    this.answerResult,
    this.selectedOptionText,
    this.showMcq = false,
    this.options,
    this.selectedOptionIndex,
    this.correctOptionIndex,
    this.onSelectOption,
    this.swipeColor,
    this.swipeBorderWidth,
  });

  final Flashcard card;
  final FlashcardSide side;
  final Color? swipeColor;
  final double? swipeBorderWidth;

  /// When non-null (back face only), renders a colour-coded result banner
  /// above the explanation — green for correct, red for incorrect.
  final _AnswerResult? answerResult;

  /// The text of the option the student selected.
  final String? selectedOptionText;

  // MCQ parameters (front face only)
  final bool showMcq;
  final List<String>? options;
  final int? selectedOptionIndex;
  final int? correctOptionIndex;
  final void Function(int)? onSelectOption;

  bool get _isFront => side == FlashcardSide.front;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _isFront ? context.colorScheme.primary : AppColors.tertiary;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subtleColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final onSurfaceVariant =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final resultColor = answerResult == _AnswerResult.correct
        ? const Color(0xFF22C55E)
        : AppColors.error;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: swipeColor ?? (isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0)),
          width: swipeBorderWidth ?? 1,
        ),
        boxShadow: [
          if (swipeColor != null)
            BoxShadow(
              color: swipeColor!.withAlpha(isDark ? 40 : 25),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else ...[
            BoxShadow(
              color: accent.withAlpha(isDark ? 25 : 18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Subtle top accent gradient strip
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withAlpha(0),
                      accent,
                      accent.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row: topic chip + side badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card.topic,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(isDark ? 30 : 18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isFront ? 'QUESTION' : 'ANSWER',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? const Color(0xFF2D3748)
                          : const Color(0xFFF1F5F9),
                    ),
                  ),
                  // Main body — centred, scrollable
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isFront) ...[
                              // ── Front: Question text ───────────────────
                              Text(
                                card.front,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: showMcq ? 18 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                  height: 1.4,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              // ── Front: MCQ panel INSIDE card ───────────
                              if (showMcq && options != null) ...[
                                const SizedBox(height: Spacing.lg),
                                Text(
                                  'Choose the correct answer:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: Spacing.sm),
                                _OptionButton(
                                  text: options![0],
                                  isSelected: selectedOptionIndex == 0,
                                  isCorrect: 0 == correctOptionIndex,
                                  isAnswered: selectedOptionIndex != null,
                                  onTap: () => onSelectOption!(0),
                                ),
                                _OptionButton(
                                  text: options![1],
                                  isSelected: selectedOptionIndex == 1,
                                  isCorrect: 1 == correctOptionIndex,
                                  isAnswered: selectedOptionIndex != null,
                                  onTap: () => onSelectOption!(1),
                                ),
                              ],
                            ] else ...[
                              // ── Back: Success/Error status badge ────────
                              if (answerResult != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: resultColor.withAlpha(
                                      isDark ? 35 : 22,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: resultColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        answerResult == _AnswerResult.correct
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 16,
                                        color: resultColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        answerResult == _AnswerResult.correct
                                            ? 'Correct!'
                                            : 'Incorrect',
                                        style: TextStyle(
                                          color: resultColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              
                              // ── Back: Dynamic Correction Details ────────
                              if (answerResult == _AnswerResult.incorrect && selectedOptionText != null) ...[
                                Text(
                                  'You selected:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error.withAlpha(220),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedOptionText!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: onSurface.withAlpha(180),
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.error,
                                    decorationThickness: 2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Correct answer:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF22C55E),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  card.back,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: onSurface,
                                  ),
                                ),
                              ] else ...[
                                // Correct or unrated: standard correct answer text
                                Text(
                                  card.back,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: onSurface,
                                    height: 1.4,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                              
                              () {
                                String explanationText = card.explanation;
                                final tipIndex = card.explanation.indexOf('Memory Tip:');
                                final pointIndex = card.explanation.indexOf('Important Point:');

                                if (tipIndex != -1) {
                                  explanationText = card.explanation.substring(0, tipIndex).trim();
                                } else if (pointIndex != -1) {
                                  explanationText = card.explanation.substring(0, pointIndex).trim();
                                }

                                if (explanationText.isEmpty) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        explanationText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: onSurfaceVariant,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Bottom hint pill (front face only) ──────────────
                  if (_isFront && !showMcq)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: subtleColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 14,
                              color: onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to answer',
                              style: TextStyle(
                                color: onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// MCQ Option Button Widget
// ─────────────────────────────────────────────────────────────────────────────

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isAnswered,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isAnswered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color? bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    IconData? icon;

    if (isAnswered) {
      if (isCorrect) {
        borderColor = const Color(0xFF22C55E);
        bgColor = borderColor.withAlpha(isDark ? 30 : 15);
        textColor = const Color(0xFF22C55E);
        icon = Icons.check_circle_rounded;
      } else if (isSelected) {
        borderColor = AppColors.error;
        bgColor = borderColor.withAlpha(isDark ? 30 : 15);
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
      } else {
        textColor = textColor.withAlpha(120);
      }
    } else {
      if (isSelected) {
        borderColor = context.colorScheme.primary;
        bgColor = borderColor.withAlpha(isDark ? 35 : 22);
        textColor = context.colorScheme.primary;
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton(
        onPressed: isAnswered ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: borderColor,
            width: isSelected || (isAnswered && isCorrect) ? 1.5 : 1.0,
          ),
          backgroundColor: bgColor,
          foregroundColor: textColor,
          disabledForegroundColor: textColor,
          disabledBackgroundColor: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: textColor),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom action area
// ─────────────────────────────────────────────────────────────────────────────

class _ActionArea extends StatelessWidget {
  const _ActionArea({required this.phase});

  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFront = phase == _Phase.front;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: isFront
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Tap card to reveal answer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF22C55E), size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Swipe Left\nRemembered',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF22C55E), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Swipe Right\nForgot',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: AppColors.error, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hint text (pre-MCQ state)
// ─────────────────────────────────────────────────────────────────────────────

class _HintText extends StatelessWidget {
  const _HintText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Concise correct answer formatter
// ─────────────────────────────────────────────────────────────────────────────

/// Clean up the answer text to make it concise if it's too long or has subclauses.
String _getConciseAnswer(String text) {
  String concise = text.trim();

  // Split by em-dash or colons if they separate definition from term
  final dashIndex = concise.indexOf('—');
  if (dashIndex != -1) {
    concise = concise.substring(0, dashIndex).trim();
  } else {
    final colonIndex = concise.indexOf(':');
    if (colonIndex != -1) {
      concise = concise.substring(0, colonIndex).trim();
    }
  }

  // Remove trailing period or punctuation
  while (concise.endsWith('.') || concise.endsWith(',') || concise.endsWith(';')) {
    concise = concise.substring(0, concise.length - 1).trim();
  }

  return concise;
}

// ─────────────────────────────────────────────────────────────────────────────
// High-Quality biology and topic distractors
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<String>> _topicDistractors = {
  'photosynthesis': ['Respiration', 'Fermentation', 'Glycolysis', 'Transpiration', 'Stomata', 'Carotenoids'],
  'cell biology': ['Nucleus', 'Mitochondria', 'Ribosomes', 'Chloroplasts', 'Lysosomes', 'Cell wall', 'Vacuole'],
  'genetics': ['Genotype', 'Phenotype', 'Chromosomes', 'Alleles', 'Mutations', 'Mitosis', 'Meiosis'],
  'circulatory': ['Heart', 'Platelets', 'Capillaries', 'Veins', 'Arteries', 'Plasma', 'Red blood cells'],
  'immune': ['White blood cells', 'Antibodies', 'Antigens', 'Pathogens', 'T-cells', 'B-cells', 'Lymph nodes'],
  'history': ['The Treaty of Versailles', 'The Declaration of Independence', 'The French Revolution', 'The Industrial Revolution'],
  'geography': ['Paris', 'London', 'Berlin', 'Rome', 'Madrid', 'Vienna', 'Tokyo', 'Washington D.C.'],
};

const List<String> _genericDistractors = [
  'Active transport',
  'Chemical equilibrium',
  'Homeostasis',
  'Thermodynamics',
  'Osmotic pressure',
  'Genetic drift',
  'Natural selection',
  'Electromagnetic force',
  'Kinetic energy',
  'Potential difference',
  'Covalent bonding',
  'Acid-base neutralization',
  'Metabolic pathway',
  'Symbiotic relationship',
  'Geological transformation',
];

/// Generate one believable and concise incorrect answer for [card] based on the correct answer.
String _generateDistractor(Flashcard card, String conciseCorrectAnswer) {
  final cleanCorrect = conciseCorrectAnswer.toLowerCase().trim();
  final topic = card.topic.toLowerCase().trim();
  final front = card.front.toLowerCase().trim();
  final seed = card.id.hashCode.abs();

  String dist = '';

  // 1. Precise functional biology mappings
  if (front.contains('platelet') || topic.contains('platelet') || cleanCorrect.contains('clot')) {
    if (front.contains('primary') || front.contains('function') || front.contains('role') || cleanCorrect.contains('help')) {
      return 'Transport oxygen';
    }
    return 'Red blood cells';
  }
  if (cleanCorrect.contains('oxygen') || cleanCorrect.contains('rbc') || cleanCorrect.contains('hemoglobin')) {
    return 'Fight infections';
  }
  if (cleanCorrect.contains('infection') || cleanCorrect.contains('immune') || cleanCorrect.contains('antibody')) {
    return 'Transport oxygen';
  }

  // Cell organelles functions
  if (cleanCorrect.contains('mitochondrion') || cleanCorrect.contains('mitochondria') || cleanCorrect.contains('produce atp')) {
    if (cleanCorrect.contains('produce')) return 'Synthesize proteins';
    return 'The ribosome';
  }
  if (cleanCorrect.contains('ribosome') || cleanCorrect.contains('synthesize proteins')) {
    if (cleanCorrect.contains('synthesize')) return 'Produce ATP';
    return 'The mitochondrion';
  }

  // Genotype vs Phenotype
  if (cleanCorrect.contains('complete set of genes') || cleanCorrect.contains('genotype') || cleanCorrect.contains('genetic makeup')) {
    return 'Its physical traits and appearance';
  }
  if (cleanCorrect.contains('physical traits') || cleanCorrect.contains('phenotype') || cleanCorrect.contains('expressed')) {
    return 'Its genetic makeup and inherited code';
  }

  // Mitosis vs Meiosis
  if (cleanCorrect == 'mitosis') return 'Meiosis';
  if (cleanCorrect == 'meiosis') return 'Mitosis';

  // Topic specific lists
  for (final key in _topicDistractors.keys) {
    if (topic.contains(key) || cleanCorrect.contains(key) || front.contains(key)) {
      final list = _topicDistractors[key]!;
      final alternate = list.firstWhere(
        (item) => !cleanCorrect.contains(item.toLowerCase()),
        orElse: () => '',
      );
      if (alternate.isNotEmpty) {
        dist = alternate;
        break;
      }
    }
  }

  // 2. Numeric logic if answer has digits
  if (dist.isEmpty) {
    final numberRegex = RegExp(r'\b\d+\b');
    final match = numberRegex.firstMatch(conciseCorrectAnswer);
    if (match != null) {
      final numberStr = match.group(0)!;
      final num = int.tryParse(numberStr);
      if (num != null && num > 0) {
        final alternateNum = num == 46 ? 23 : (num <= 50 ? num * 2 : (num / 2).round());
        dist = conciseCorrectAnswer.replaceFirst(numberStr, alternateNum.toString());
      }
    }
  }

  // 3. Boolean / Binary mappings
  if (dist.isEmpty) {
    if (cleanCorrect == 'true') dist = 'False';
    if (cleanCorrect == 'false') dist = 'True';
    if (cleanCorrect == 'yes') dist = 'No';
    if (cleanCorrect == 'no') dist = 'Yes';
  }

  // 4. Default high-quality scientific list
  if (dist.isEmpty) {
    final index = seed % _genericDistractors.length;
    dist = _genericDistractors[index];
  }

  // 5. Grammatical matching for articles (e.g. matching "The " prefix)
  if (conciseCorrectAnswer.toLowerCase().startsWith('the ') && !dist.toLowerCase().startsWith('the ')) {
    dist = 'The ${dist.toLowerCase()}';
  } else if (conciseCorrectAnswer.toLowerCase().startsWith('a ') && !dist.toLowerCase().startsWith('a ')) {
    dist = 'a ${dist.toLowerCase()}';
  } else if (conciseCorrectAnswer.toLowerCase().startsWith('an ') && !dist.toLowerCase().startsWith('an ')) {
    dist = 'an ${dist.toLowerCase()}';
  }
  
  // Capitalize first letter
  dist = dist[0].toUpperCase() + dist.substring(1);
  return dist;
}

// ─────────────────────────────────────────────────────────────────────────────
// Session completed view
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCompletedView extends StatelessWidget {
  const _SessionCompletedView({
    required this.correctCount,
    required this.incorrectCount,
    required this.onRestart,
  });

  final int correctCount;
  final int incorrectCount;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final total = correctCount + incorrectCount;
    final pct = total > 0 ? (correctCount / total * 100).round() : 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withAlpha(isDark ? 30 : 15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 80,
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'Session Complete!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              '$correctCount of $total correct ($pct%)',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D3748)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 30 : 10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Session Results',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  _SummaryRow(
                    label: 'Correct',
                    count: correctCount,
                    color: const Color(0xFF22C55E),
                    icon: Icons.check_circle_rounded,
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    label: 'Incorrect',
                    count: incorrectCount,
                    color: AppColors.error,
                    icon: Icons.cancel_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Start New Session',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter button + bottom sheet (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class FlashcardFilterButton extends ConsumerWidget {
  const FlashcardFilterButton({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.filter_list_rounded),
      tooltip: 'Filter Topics',
      onPressed: () => _showFilterBottomSheet(context, ref),
    );
  }

  void _showFilterBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(workspaceId: workspaceId),
    );
  }
}

class _FilterBottomSheet extends ConsumerStatefulWidget {
  const _FilterBottomSheet({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_FilterBottomSheet> createState() =>
      _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  late Set<String> _selectedIds;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final taxonomyState = ref.watch(
      taxonomyViewerProvider(workspaceId: widget.workspaceId),
    );
    final notifier = ref.read(
      flashcardSessionNotifierProvider(widget.workspaceId).notifier,
    );

    return taxonomyState.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 200,
        child: Center(child: Text('Error loading topics: $err')),
      ),
      data: (stateObj) {
        final topics = stateObj.taxonomy.topics;

        if (!_initialized) {
          final activeFilters = notifier.selectedTopicIds;
          if (activeFilters == null) {
            _selectedIds = topics.map((t) => t.id).toSet();
          } else {
            _selectedIds = Set.from(activeFilters);
          }
          _initialized = true;
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Study Topics',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.select_all_rounded, size: 16),
                    label: const Text('Select All'),
                    onPressed: () {
                      setState(() {
                        _selectedIds = topics.map((t) => t.id).toSet();
                      });
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.deselect_rounded, size: 16),
                    label: const Text('Clear All'),
                    onPressed: () {
                      setState(() {
                        _selectedIds.clear();
                      });
                    },
                  ),
                ],
              ),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: topics.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(Spacing.xl),
                        child: Text(
                          'No topics in this workspace.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: topics.length,
                        itemBuilder: (context, index) {
                          final t = topics[index];
                          final isSelected = _selectedIds.contains(t.id);
                          return CheckboxListTile(
                            title: Text(t.name),
                            value: isSelected,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: context.colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.add(t.id);
                                } else {
                                  _selectedIds.remove(t.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: Spacing.md),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final filters = _selectedIds.length == topics.length
                      ? null
                      : _selectedIds.toList();
                  notifier.updateFilters(filters);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
