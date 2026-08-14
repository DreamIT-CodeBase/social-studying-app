import 'dart:async';
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
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
import 'package:social_study_app/shared/models/flashcard.dart';
import 'package:social_study_app/shared/widgets/empty_state_view.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';
import 'package:social_study_app/features/taxonomy/presentation/taxonomy_notifier.dart';
import 'package:social_study_app/features/progress/presentation/progress_notifier.dart';
import 'package:social_study_app/features/notifications/data/notification_token_repository.dart';

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
  Timer? _sessionTimer;
  int _remainingSeconds = 0;

  FlashcardSessionNotifier get _notifier =>
      ref.read(flashcardSessionNotifierProvider(widget.workspaceId).notifier);

  @override
  void initState() {
    super.initState();
    // Auto-start the session immediately — skip the idle landing screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progressVal = ref
          .read(studentProgressNotifierProvider(widget.workspaceId))
          .valueOrNull;
      _startSession(progressVal?.overallMastery);
    });
  }

  Future<void> _startSession(double? mastery) async {
    await _notifier.start(mastery: mastery);
    if (!mounted) return;
    _sessionTimer?.cancel();
    setState(() => _remainingSeconds = _notifier.sessionTargetLength * 2 * 60);
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        _notifier.completeDueToTimeout();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
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
    final progressVal = ref
        .read(studentProgressNotifierProvider(widget.workspaceId))
        .valueOrNull;
    _startSession(progressVal?.overallMastery);
  }

  @override
  Widget build(BuildContext context) {
    // Fire celebrations exactly once per transition into `rated`.
    ref.listen(
      flashcardSessionNotifierProvider(widget.workspaceId),
      (prev, next) {
        next.whenOrNull(
          completed: (_, __, ___) => _sessionTimer?.cancel(),
          rated: (_, response) {
            _playCelebrations(context, response);
            ref.read(notificationTokenRepositoryProvider).sendActivityPush(
                  title: 'Flashcard reviewed',
                  body: 'Your flashcard progress was saved successfully.',
                  workspaceId: widget.workspaceId,
                ).ignore();
            Future.delayed(const Duration(milliseconds: 400), () {
              if (context.mounted) {
                ref
                    .read(flashcardSessionNotifierProvider(widget.workspaceId)
                        .notifier)
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
    final sessionTarget = notifier.sessionTargetLength;
    final tierLabel = notifier.masteryTierLabel;
    final isAdmin = ref.watch(isActiveWorkspaceAdminProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final child = session.when(
      idle: () => _FlashcardReadyView(
        workspaceId: widget.workspaceId,
        onStart: () {
          final progressVal = ref
              .read(studentProgressNotifierProvider(widget.workspaceId))
              .valueOrNull;
          _notifier.start(mastery: progressVal?.overallMastery);
        },
      ),
      loading: () => _CardTransitionScreen(
        currentIndex: currentIndex,
        sessionTarget: sessionTarget,
        tierLabel: tierLabel,
      ),
      // Key by card id so _CardViewState resets when a new card arrives.
      viewingFront: (card) => _CardView(
        key: ValueKey(card.id),
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.front,
        currentIndex: currentIndex,
        remainingSeconds: _remainingSeconds,
      ),
      revealed: (card) => _CardView(
        key: ValueKey(card.id),
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.revealed,
        currentIndex: currentIndex,
        remainingSeconds: _remainingSeconds,
      ),
      rating: (card, _) => _CardView(
        key: ValueKey(card.id),
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.rating,
        currentIndex: currentIndex,
        remainingSeconds: _remainingSeconds,
      ),
      rated: (card, _) => _CardView(
        key: ValueKey(card.id),
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.rated,
        currentIndex: currentIndex,
        remainingSeconds: _remainingSeconds,
      ),
      completed: (easyCount, mediumCount, hardCount) => _SessionCompletedView(
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(
        key: ValueKey(session.runtimeType),
        child: child,
      ),
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

// ─── Design tokens ───────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D1F);
const _kCardBg = Color(0xFF13132A);
const _kPurple = Color(0xFF7C5CFC);
const _kPurpleLight = Color(0xFFA78BFA);
const _kGreen = Color(0xFF22C55E);
const _kGreenDark = Color(0xFF16A34A);
const _kRed = Color(0xFFEF4444);
const _kRedDark = Color(0xFFDC2626);
const _kStarGold = Color(0xFFFBBF24);
const _kSurface2 = Color(0xFF1A1A3A);
const _kBorder = Color(0xFF2A2A50);
const _kTextMuted = Color(0xFF8888AA);

/// Maps a numeric [level] to a tier label shown in the stats strip.
String _levelTitle(int level) {
  if (level <= 3) return 'Novice';
  if (level <= 6) return 'Apprentice';
  if (level <= 9) return 'Scholar';
  if (level <= 13) return 'Expert';
  return 'Master';
}

class _CardView extends ConsumerStatefulWidget {
  const _CardView({
    super.key,
    required this.workspaceId,
    required this.card,
    required this.phase,
    required this.currentIndex,
    required this.remainingSeconds,
  });

  final String workspaceId;
  final Flashcard card;
  final _Phase phase;
  final int currentIndex;
  final int remainingSeconds;

  bool get _showBack => phase != _Phase.front;

  @override
  ConsumerState<_CardView> createState() => _CardViewState();
}

class _CardViewState extends ConsumerState<_CardView>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  late Stopwatch _stopwatch;
  bool _revealed = false;
  late final AnimationController _swipeController;
  Animation<double>? _swipeAnimation;
  bool _committingSwipe = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _revealed = widget.phase != _Phase.front;
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final animation = _swipeAnimation;
        if (animation != null && mounted) {
          setState(() => _dragOffset = animation.value);
        }
      });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
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

  double _calculateAccuracy(
      List<FlashcardRating> ratings, FlashcardRating currentRating) {
    final allRatings = [...ratings, currentRating];
    final correctCount =
        allRatings.where((r) => r == FlashcardRating.easy).length;
    return (correctCount / allRatings.length) * 100.0;
  }

  void _onCardTap() {
    if (widget.phase != _Phase.front) return;
    SoundService.instance.playCardFlip();
    ref
        .read(flashcardSessionNotifierProvider(widget.workspaceId).notifier)
        .flip();
  }

  Future<void> _animateTo(double destination) async {
    _swipeController.stop();
    _swipeController.reset();
    _swipeAnimation = Tween<double>(begin: _dragOffset, end: destination)
        .animate(CurvedAnimation(
      parent: _swipeController,
      curve: destination == 0 ? Curves.easeOutBack : Curves.easeInCubic,
    ));
    await _swipeController.forward();
  }

  Future<void> _finishSwipe({required bool forgot}) async {
    if (_committingSwipe) return;
    _committingSwipe = true;
    HapticFeedback.mediumImpact();
    final width = MediaQuery.sizeOf(context).width;
    await _animateTo((forgot ? 1 : -1) * (width + 180));
    if (!mounted) return;

    final notifier = ref.read(
      flashcardSessionNotifierProvider(widget.workspaceId).notifier,
    );
    final rating = forgot ? FlashcardRating.hard : FlashcardRating.easy;
    final responseTimeMs = _stopwatch.elapsedMilliseconds;
    _stopwatch.stop();
    final accuracy = _calculateAccuracy(notifier.sessionRatings, rating);
    await notifier.rate(
      rating,
      isCorrect: !forgot,
      responseTimeMs: responseTimeMs,
      sessionProgress: widget.currentIndex,
      accuracyPercentage: accuracy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier =
        ref.read(flashcardSessionNotifierProvider(widget.workspaceId).notifier);
    final targetLength = notifier.sessionTargetLength;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _kBg = isDark ? const Color(0xFF0D0D1F) : Colors.white;
    final _kCardBg = isDark ? const Color(0xFF13132A) : Colors.white;
    final _kSurface2 = isDark ? const Color(0xFF1A1A3A) : Colors.white;
    final _kBorder = isDark ? const Color(0xFF2A2A50) : const Color(0xFFE5E7EB);
    final _kTextMuted =
        isDark ? const Color(0xFF8888AA) : const Color(0xFF7A7A8C);
    final _kPrimaryText = isDark ? Colors.white : const Color(0xFF1A1A2E);

    // Gamification stats for stats strip
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final authUser =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    final gamProfile = authUser == null
        ? null
        : ref
            .watch(gamificationProfileProvider(
                (workspaceId: widget.workspaceId, userId: authUser.id)))
            .valueOrNull;

    final streakDays = gamProfile?.streakDays ?? 0;
    final xpToday = gamProfile?.xpThisWeek ?? 0;
    final level = gamProfile?.level ?? 1;
    final levelLabel = _levelTitle(level);

    // Swipe border lerp colour
    Color swipeColor = _kBorder;
    if (_dragOffset.abs() > 10) {
      final progress = (_dragOffset.abs() / 150).clamp(0.0, 1.0);
      final target = _dragOffset > 0 ? _kRed : _kGreen;
      swipeColor = Color.lerp(_kBorder, target, progress)!;
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Notch/Status Bar Safe Spacing
            const SizedBox(height: 6),
            // ── Session progress (compact) ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session Progress',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kTextMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 13, color: _kPurpleLight),
                          const SizedBox(width: 4),
                          Text(
                            '${(widget.remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(widget.remainingSeconds % 60).toString().padLeft(2, '0')}  ·  ${widget.currentIndex} of $targetLength',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _kPurpleLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:
                          (widget.currentIndex / targetLength).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: _kBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(_kPurple),
                    ),
                  ),
                ],
              ),
            ),

            // ── Flip card ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: GestureDetector(
                  onTap: widget.phase == _Phase.front ? _onCardTap : null,
                  onHorizontalDragUpdate: (details) {
                    if (widget.phase != _Phase.revealed || _committingSwipe)
                      return;
                    setState(() {
                      _dragOffset += details.delta.dx;
                    });
                  },
                  onHorizontalDragEnd: (details) async {
                    if (widget.phase != _Phase.revealed || _committingSwipe)
                      return;
                    final velocity = details.primaryVelocity ?? 0;
                    if (_dragOffset.abs() > 96 || velocity.abs() > 700) {
                      final forgot =
                          velocity.abs() > 700 ? velocity > 0 : _dragOffset > 0;
                      await _finishSwipe(forgot: forgot);
                    } else {
                      await _animateTo(0);
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
                            swipeColor: swipeColor,
                          ),
                          back: FlashcardFace(
                            card: widget.card,
                            side: FlashcardSide.back,
                            swipeColor: swipeColor,
                          ),
                        ),
                        // Swipe overlay labels
                        if (_dragOffset.abs() > 20)
                          Positioned(
                            top: 32,
                            left: _dragOffset > 0 ? 24 : null,
                            right: _dragOffset < 0 ? 24 : null,
                            child: Transform.rotate(
                              angle: _dragOffset > 0 ? -0.2 : 0.2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: (_dragOffset > 0 ? _kRed : _kGreen)
                                      .withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _dragOffset > 0 ? _kRed : _kGreen,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  _dragOffset > 0 ? 'FORGOT' : 'REMEMBERED',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
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

            // ── Bottom action area ─────────────────────────────────────────
            _ActionArea(
              phase: widget.phase,
              workspaceId: widget.workspaceId,
              card: widget.card,
              currentIndex: widget.currentIndex,
              showGestureHint: widget.currentIndex == 1,
              onRemembered: () {
                final responseTimeMs = _stopwatch.elapsedMilliseconds;
                _stopwatch.stop();
                final accuracy = _calculateAccuracy(
                    notifier.sessionRatings, FlashcardRating.easy);
                notifier.rate(
                  FlashcardRating.easy,
                  isCorrect: true,
                  responseTimeMs: responseTimeMs,
                  sessionProgress: widget.currentIndex,
                  accuracyPercentage: accuracy,
                );
              },
              onForgot: () {
                final responseTimeMs = _stopwatch.elapsedMilliseconds;
                _stopwatch.stop();
                final accuracy = _calculateAccuracy(
                    notifier.sessionRatings, FlashcardRating.hard);
                notifier.rate(
                  FlashcardRating.hard,
                  isCorrect: false,
                  responseTimeMs: responseTimeMs,
                  sessionProgress: widget.currentIndex,
                  accuracyPercentage: accuracy,
                );
              },
            ),
          ],
        ),
      ),
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
// _StatsStrip — Streak / XP Today / Level chips
// ─────────────────────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.streakDays,
    required this.xpToday,
    required this.level,
    required this.levelLabel,
  });

  final int streakDays;
  final int xpToday;
  final int level;
  final String levelLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: '🔥',
          value: '$streakDays',
          label: 'Day Streak',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: '⭐',
          value: '$xpToday',
          label: 'XP Today',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: '⚡',
          value: 'Level $level',
          label: levelLabel,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _kBg = isDark ? const Color(0xFF0D0D1F) : Colors.white;
    final _kCardBg = isDark ? const Color(0xFF13132A) : Colors.white;
    final _kSurface2 = isDark ? const Color(0xFF1A1A3A) : Colors.white;
    final _kBorder = isDark ? const Color(0xFF2A2A50) : const Color(0xFFE5E7EB);
    final _kTextMuted =
        isDark ? const Color(0xFF8888AA) : const Color(0xFF7A7A8C);
    final _kPrimaryText = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: _kPrimaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: _kTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FlashcardFace — redesigned premium dark card
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
  final _AnswerResult? answerResult;
  final String? selectedOptionText;
  final bool showMcq;
  final List<String>? options;
  final int? selectedOptionIndex;
  final int? correctOptionIndex;
  final void Function(int)? onSelectOption;

  bool get _isFront => side == FlashcardSide.front;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _kBg = isDark ? const Color(0xFF0D0D1F) : Colors.white;
    final _kCardBg = isDark ? const Color(0xFF13132A) : Colors.white;
    final _kSurface2 = isDark ? const Color(0xFF1A1A3A) : Colors.white;
    final _kBorder = isDark ? const Color(0xFF2A2A50) : const Color(0xFFE5E7EB);
    final _kTextMuted =
        isDark ? const Color(0xFF8888AA) : const Color(0xFF7A7A8C);
    final _kPrimaryText = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final accent = _isFront ? _kPurple : _kGreen;
    final accentDark = _isFront ? const Color(0xFF5B3FD6) : _kGreenDark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: swipeColor ??
              (_isFront
                  ? _kPurple.withOpacity(0.35)
                  : _kGreen.withOpacity(0.35)),
          width: swipeBorderWidth ?? 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top accent bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0),
                    accent,
                    accent.withOpacity(0),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row: topic chip + QUESTION/ANSWER badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _isFront
                                ? Icons.quiz_rounded
                                : Icons.menu_book_rounded,
                            color: accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            card.topic,
                            style: TextStyle(
                              color: _kPrimaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isFront ? 'QUESTION' : 'ANSWER',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Main body
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isFront) ...[
                                // Glowing hexagon icon
                                _GlowHexagon(color: _kPurple),
                                const SizedBox(height: 20),
                                Text(
                                  card.front,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: _kPrimaryText,
                                    height: 1.4,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ] else ...[
                                // Green check hexagon
                                _GlowHexagon(
                                  color: _kGreen,
                                  isCheck: true,
                                ),
                                const SizedBox(height: 20),
                                // Answer — key words in green
                                _RichAnswerText(text: card.back),
                                // Explanation
                                if (card.explanation.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    _trimExplanation(card.explanation),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14.5,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
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

  String _trimExplanation(String explanation) {
    for (final marker in ['Memory Tip:', 'Important Point:']) {
      final idx = explanation.indexOf(marker);
      if (idx != -1) return explanation.substring(0, idx).trim();
    }
    return explanation.trim();
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

    Color borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
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
// _GlowHexagon — pulsing icon with sparkles
// ─────────────────────────────────────────────────────────────────────────────

class _GlowHexagon extends StatefulWidget {
  const _GlowHexagon({required this.color, this.isCheck = false});

  final Color color;
  final bool isCheck;

  @override
  State<_GlowHexagon> createState() => _GlowHexagonState();
}

class _GlowHexagonState extends State<_GlowHexagon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _scale = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          AnimatedBuilder(
            animation: _scale,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.30),
                      blurRadius: 36,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Hexagon
          CustomPaint(
            size: const Size(80, 80),
            painter: _HexPainter(color: color),
          ),
          // Icon inside
          Icon(
            widget.isCheck ? Icons.check_rounded : Icons.question_mark_rounded,
            color: Colors.white,
            size: 34,
          ),
          // Sparkles
          ..._sparklePositions.map((pos) => Positioned(
                left: pos.dx,
                top: pos.dy,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Opacity(
                    opacity: (_pulse.value * 0.7).clamp(0.2, 0.9),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pos.color,
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  static final _sparklePositions = [
    _Sparkle(dx: 8, dy: 32, color: const Color(0xFFFBBF24)),
    _Sparkle(dx: 118, dy: 20, color: const Color(0xFF60A5FA)),
    _Sparkle(dx: 20, dy: 98, color: const Color(0xFFF472B6)),
    _Sparkle(dx: 110, dy: 95, color: const Color(0xFF34D399)),
    _Sparkle(dx: 65, dy: 4, color: const Color(0xFFA78BFA)),
    _Sparkle(dx: 55, dy: 126, color: const Color(0xFFFBBF24)),
  ];
}

class _Sparkle {
  const _Sparkle({required this.dx, required this.dy, required this.color});
  final double dx;
  final double dy;
  final Color color;
}

class _HexPainter extends CustomPainter {
  const _HexPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 180) * (60 * i - 30);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// _RichAnswerText — highlights last 2-3 words in green
// ─────────────────────────────────────────────────────────────────────────────

class _RichAnswerText extends StatelessWidget {
  const _RichAnswerText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _kPrimaryText = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final words = text.trim().split(' ');
    if (words.length <= 3) {
      // All green for short answers
      return Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: _kGreen,
          height: 1.4,
        ),
      );
    }
    // First part white, last ~3 words green
    final splitAt = words.length - 3;
    final firstPart = words.sublist(0, splitAt).join(' ');
    final greenPart = words.sublist(splitAt).join(' ');
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
        children: [
          TextSpan(
            text: '$firstPart ',
            style: TextStyle(color: _kPrimaryText),
          ),
          TextSpan(
            text: greenPart,
            style: const TextStyle(color: _kGreen),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _XpChip — gold star + XP number
// ─────────────────────────────────────────────────────────────────────────────

class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _kStarGold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kStarGold.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '+$xp XP',
            style: const TextStyle(
              color: _kStarGold,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom action area — redesigned Remembered / Forgot buttons
// ─────────────────────────────────────────────────────────────────────────────

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.phase,
    required this.workspaceId,
    required this.card,
    required this.currentIndex,
    required this.showGestureHint,
    required this.onRemembered,
    required this.onForgot,
  });

  final _Phase phase;
  final String workspaceId;
  final Flashcard card;
  final int currentIndex;
  final bool showGestureHint;
  final VoidCallback onRemembered;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final _kBg = isDark ? const Color(0xFF0D0D1F) : Colors.white;
    final _kCardBg = isDark ? const Color(0xFF13132A) : Colors.white;
    final _kSurface2 = isDark ? const Color(0xFF1A1A3A) : Colors.white;
    final _kBorder = isDark ? const Color(0xFF2A2A50) : const Color(0xFFE5E7EB);
    final _kTextMuted =
        isDark ? const Color(0xFF8888AA) : const Color(0xFF7A7A8C);
    final _kPrimaryText = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final isRevealed = phase == _Phase.revealed || phase == _Phase.rating;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      color: _kBg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // No tap-to-reveal hint shown — tapping the card still works.
            if (showGestureHint)
              // Single unified pill: ← Swipe Left | Swipe Right →
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kSurface2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _kBorder, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      // ── Left: Remembered ──────────────────────────────
                      Expanded(
                        child: GestureDetector(
                          onTap: isRevealed ? onRemembered : null,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Arrow circle
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: _kGreen, width: 1.5),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: _kGreen,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Swipe Left',
                                      style: TextStyle(
                                        color: _kGreen,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Remembered',
                                      style: TextStyle(
                                        color: _kGreen,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // ── Divider ────────────────────────────────────────
                      Container(
                        width: 1,
                        height: 48,
                        color: _kBorder,
                      ),
                      // ── Right: Forgot ──────────────────────────────────
                      Expanded(
                        child: GestureDetector(
                          onTap: isRevealed ? onForgot : null,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Swipe Right',
                                      style: TextStyle(
                                        color: _kRed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Forgot',
                                      style: TextStyle(
                                        color: _kRed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                // Arrow circle
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: _kRed, width: 1.5),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: _kRed,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
}

/// Motivational strip shown while on the front of the card.
class _MotivationalStrip extends ConsumerWidget {
  const _MotivationalStrip({required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final authUser =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    final gamProfile = authUser == null
        ? null
        : ref
            .watch(gamificationProfileProvider(
                (workspaceId: workspaceId, userId: authUser.id)))
            .valueOrNull;
    final streak = gamProfile?.streakDays ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: _kSurface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keep going! You\'re doing great! 🔥',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Streak: $streak days',
                  style: const TextStyle(
                    color: _kPurpleLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Dot progress indicator
          Row(
            children: List.generate(
              4,
              (i) => Container(
                width: i < 2 ? 10 : 8,
                height: i < 2 ? 10 : 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < 2 ? _kPurple : _kBorder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold XP reward banner shown after card is revealed.
class _XpRewardBar extends StatelessWidget {
  const _XpRewardBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Great job! You\'re on fire! 🔥',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Keep it up and win the day!',
                  style: TextStyle(
                    color: _kTextMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '+7 XP',
            style: TextStyle(
              color: _kStarGold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy hint text widget (kept for compatibility).
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
  while (
      concise.endsWith('.') || concise.endsWith(',') || concise.endsWith(';')) {
    concise = concise.substring(0, concise.length - 1).trim();
  }

  return concise;
}

// ─────────────────────────────────────────────────────────────────────────────
// High-Quality biology and topic distractors
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<String>> _topicDistractors = {
  'photosynthesis': [
    'Respiration',
    'Fermentation',
    'Glycolysis',
    'Transpiration',
    'Stomata',
    'Carotenoids'
  ],
  'cell biology': [
    'Nucleus',
    'Mitochondria',
    'Ribosomes',
    'Chloroplasts',
    'Lysosomes',
    'Cell wall',
    'Vacuole'
  ],
  'genetics': [
    'Genotype',
    'Phenotype',
    'Chromosomes',
    'Alleles',
    'Mutations',
    'Mitosis',
    'Meiosis'
  ],
  'circulatory': [
    'Heart',
    'Platelets',
    'Capillaries',
    'Veins',
    'Arteries',
    'Plasma',
    'Red blood cells'
  ],
  'immune': [
    'White blood cells',
    'Antibodies',
    'Antigens',
    'Pathogens',
    'T-cells',
    'B-cells',
    'Lymph nodes'
  ],
  'history': [
    'The Treaty of Versailles',
    'The Declaration of Independence',
    'The French Revolution',
    'The Industrial Revolution'
  ],
  'geography': [
    'Paris',
    'London',
    'Berlin',
    'Rome',
    'Madrid',
    'Vienna',
    'Tokyo',
    'Washington D.C.'
  ],
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
  if (front.contains('platelet') ||
      topic.contains('platelet') ||
      cleanCorrect.contains('clot')) {
    if (front.contains('primary') ||
        front.contains('function') ||
        front.contains('role') ||
        cleanCorrect.contains('help')) {
      return 'Transport oxygen';
    }
    return 'Red blood cells';
  }
  if (cleanCorrect.contains('oxygen') ||
      cleanCorrect.contains('rbc') ||
      cleanCorrect.contains('hemoglobin')) {
    return 'Fight infections';
  }
  if (cleanCorrect.contains('infection') ||
      cleanCorrect.contains('immune') ||
      cleanCorrect.contains('antibody')) {
    return 'Transport oxygen';
  }

  // Cell organelles functions
  if (cleanCorrect.contains('mitochondrion') ||
      cleanCorrect.contains('mitochondria') ||
      cleanCorrect.contains('produce atp')) {
    if (cleanCorrect.contains('produce')) return 'Synthesize proteins';
    return 'The ribosome';
  }
  if (cleanCorrect.contains('ribosome') ||
      cleanCorrect.contains('synthesize proteins')) {
    if (cleanCorrect.contains('synthesize')) return 'Produce ATP';
    return 'The mitochondrion';
  }

  // Genotype vs Phenotype
  if (cleanCorrect.contains('complete set of genes') ||
      cleanCorrect.contains('genotype') ||
      cleanCorrect.contains('genetic makeup')) {
    return 'Its physical traits and appearance';
  }
  if (cleanCorrect.contains('physical traits') ||
      cleanCorrect.contains('phenotype') ||
      cleanCorrect.contains('expressed')) {
    return 'Its genetic makeup and inherited code';
  }

  // Mitosis vs Meiosis
  if (cleanCorrect == 'mitosis') return 'Meiosis';
  if (cleanCorrect == 'meiosis') return 'Mitosis';

  // Topic specific lists
  for (final key in _topicDistractors.keys) {
    if (topic.contains(key) ||
        cleanCorrect.contains(key) ||
        front.contains(key)) {
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
        final alternateNum =
            num == 46 ? 23 : (num <= 50 ? num * 2 : (num / 2).round());
        dist = conciseCorrectAnswer.replaceFirst(
            numberStr, alternateNum.toString());
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
  if (conciseCorrectAnswer.toLowerCase().startsWith('the ') &&
      !dist.toLowerCase().startsWith('the ')) {
    dist = 'The ${dist.toLowerCase()}';
  } else if (conciseCorrectAnswer.toLowerCase().startsWith('a ') &&
      !dist.toLowerCase().startsWith('a ')) {
    dist = 'a ${dist.toLowerCase()}';
  } else if (conciseCorrectAnswer.toLowerCase().startsWith('an ') &&
      !dist.toLowerCase().startsWith('an ')) {
    dist = 'an ${dist.toLowerCase()}';
  }

  // Capitalize first letter
  dist = dist[0].toUpperCase() + dist.substring(1);
  return dist;
}

// ─────────────────────────────────────────────────────────────────────────────
// Session completed view
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Flashcard Session Start Screen (idle state)
// ─────────────────────────────────────────────────────────────────────────────

class _FlashcardReadyView extends ConsumerWidget {
  const _FlashcardReadyView({
    required this.workspaceId,
    required this.onStart,
  });

  final String workspaceId;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final primaryContainer =
        isDark ? primary.withOpacity(0.15) : const Color(0xFFEEF2FF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Hero icon with decorative sparkles ───────────────────────
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Sparkle decorations
                  Positioned(
                    top: 4,
                    right: 24,
                    child: Icon(Icons.auto_awesome,
                        size: 16, color: const Color(0xFFFBBF24)),
                  ),
                  Positioned(
                    top: 24,
                    left: 18,
                    child: Icon(Icons.auto_awesome,
                        size: 10, color: primary.withOpacity(0.5)),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 16,
                    child: Icon(Icons.auto_awesome,
                        size: 12,
                        color: const Color(0xFFFBBF24).withOpacity(0.7)),
                  ),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.style_rounded,
                      size: 60,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Title & subtitle ─────────────────────────────────────────
              Text(
                'Flashcard Review',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your review session is personalized\nbased on your current mastery level.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Info card ────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _ReadyInfoRow(
                      icon: Icons.psychology_alt_rounded,
                      iconColor: primary,
                      iconBg: primaryContainer,
                      label: 'Adaptive Difficulty',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Smart',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0)),
                    _ReadyInfoRow(
                      icon: Icons.quiz_outlined,
                      iconColor: const Color(0xFF6366F1),
                      iconBg: const Color(0xFF6366F1).withOpacity(0.12),
                      label: 'Question Type',
                      trailing: Text(
                        'MCQ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF2D3748)
                            : const Color(0xFFE2E8F0)),
                    _ReadyInfoRow(
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      iconBg: const Color(0xFFF59E0B).withOpacity(0.12),
                      label: 'XP Reward',
                      trailing: Text(
                        '+1 to +10',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: primary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Motivational banner ──────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stay focused and do your best!',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            "Every card brings you closer to mastery.",
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Start button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Start Review Session',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyInfoRow extends StatelessWidget {
  const _ReadyInfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SessionCompletedView — premium session end screen
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
    final primary = context.colorScheme.primary;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final total = correctCount + incorrectCount;
    final pct = total > 0 ? (correctCount / total * 100).round() : 0;

    // Performance message
    final String performanceTitle;
    final String performanceBody;
    final Color performanceBg;
    final Color performanceIconColor;
    if (pct >= 80) {
      performanceTitle = 'Excellent work!';
      performanceBody = 'You nailed most of the cards. Keep it up!';
      performanceBg = const Color(0xFF22C55E).withOpacity(0.12);
      performanceIconColor = const Color(0xFF22C55E);
    } else if (pct >= 50) {
      performanceTitle = 'Good attempt!';
      performanceBody =
          'You missed ${incorrectCount > 0 ? '$incorrectCount card${incorrectCount > 1 ? 's' : ''}' : 'some cards'}. Review them to improve!';
      performanceBg = const Color(0xFFF59E0B).withOpacity(0.1);
      performanceIconColor = const Color(0xFFF59E0B);
    } else {
      performanceTitle = 'Keep practicing!';
      performanceBody = 'Focus on the cards you missed to build mastery.';
      performanceBg = AppColors.error.withOpacity(0.08);
      performanceIconColor = AppColors.error;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── Celebration icon with confetti dots ───────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Scattered decorative dots
                  Positioned(
                    top: 0.0,
                    left: 40.0,
                    child: Icon(Icons.auto_awesome,
                        size: 8.0, color: const Color(0xFFFBBF24)),
                  ),
                  Positioned(
                    top: 10.0,
                    right: 28.0,
                    child: Icon(Icons.auto_awesome,
                        size: 6.0, color: const Color(0xFF22C55E)),
                  ),
                  Positioned(
                    top: 40.0,
                    left: 16.0,
                    child: Icon(Icons.auto_awesome, size: 5.0, color: primary),
                  ),
                  Positioned(
                    bottom: 8.0,
                    right: 20.0,
                    child: Icon(Icons.auto_awesome,
                        size: 7.0, color: const Color(0xFFF472B6)),
                  ),
                  Positioned(
                    bottom: 4.0,
                    left: 36.0,
                    child: Icon(Icons.auto_awesome,
                        size: 5.0, color: const Color(0xFF818CF8)),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Title ─────────────────────────────────────────────────
              Text(
                'Session Complete!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Great job! You're making progress.",
                style: TextStyle(fontSize: 14, color: subtitleColor),
              ),
              const SizedBox(height: 24),

              // ── Circular accuracy gauge ───────────────────────────────
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: total > 0 ? pct / 100 : 0,
                      strokeWidth: 10,
                      backgroundColor: isDark
                          ? const Color(0xFF2D3748)
                          : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                          Text(
                            'Accuracy',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Stats grid ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2D3748)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryStatChip(
                      label: 'Reviewed',
                      value: '$total',
                      icon: Icons.help_outline_rounded,
                      iconColor: primary,
                    ),
                    _StatDivider(isDark: isDark),
                    _SummaryStatChip(
                      label: 'Correct',
                      value: '$correctCount',
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: const Color(0xFF22C55E),
                    ),
                    _StatDivider(isDark: isDark),
                    _SummaryStatChip(
                      label: 'Wrong',
                      value: '$incorrectCount',
                      icon: Icons.cancel_outlined,
                      iconColor: AppColors.error,
                    ),
                    _StatDivider(isDark: isDark),
                    _SummaryStatChip(
                      label: 'Accuracy',
                      value: '$pct%',
                      icon: Icons.track_changes_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Performance message ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: performanceBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      pct >= 80
                          ? '🌟'
                          : pct >= 50
                              ? '⭐'
                              : '💪',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            performanceTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: performanceIconColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            performanceBody,
                            style:
                                TextStyle(fontSize: 12, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Primary CTA ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onRestart,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text(
                    'Continue Learning',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Secondary CTA ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onRestart,
                  icon: Icon(Icons.menu_book_rounded, color: primary),
                  label: Text(
                    'Review Again',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStatChip extends StatelessWidget {
  const _SummaryStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
      );
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
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

// ─────────────────────────────────────────────────────────────────────────────
// _CardTransitionScreen — professional loading screen between cards
// ─────────────────────────────────────────────────────────────────────────────

/// Shown while the next card is being fetched from the backend.
///
/// Replaces the bare white flash with a premium animated screen that:
/// - Shows a pulsing flashcard icon so the UI feels alive
/// - Displays card progress ("Card 3 of 7") and a progress bar
/// - Shows the current mastery tier badge
class _CardTransitionScreen extends StatefulWidget {
  const _CardTransitionScreen({
    required this.currentIndex,
    required this.sessionTarget,
    required this.tierLabel,
  });

  final int currentIndex;
  final int sessionTarget;
  final String tierLabel;

  @override
  State<_CardTransitionScreen> createState() => _CardTransitionScreenState();
}

class _CardTransitionScreenState extends State<_CardTransitionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.88, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  IconData _tierIcon(String label) {
    switch (label) {
      case 'Expert':
        return Icons.workspace_premium_rounded;
      case 'Intermediate':
        return Icons.auto_graph_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  Color _tierColor(String label, ColorScheme cs) {
    switch (label) {
      case 'Expert':
        return const Color(0xFFFFB347); // amber-gold
      case 'Intermediate':
        return const Color(0xFF4FC3F7); // sky-blue
      default:
        return const Color(0xFF81C784); // mint-green
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final progress = widget.sessionTarget > 0
        ? (widget.currentIndex - 1) / widget.sessionTarget
        : 0.0;
    final tierColor = _tierColor(widget.tierLabel, cs);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top progress bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Card ${widget.currentIndex} of ${widget.sessionTarget}',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      // Tier badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tierColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: tierColor.withOpacity(0.4), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_tierIcon(widget.tierLabel),
                                size: 13, color: tierColor),
                            const SizedBox(width: 5),
                            Text(
                              widget.tierLabel,
                              style: tt.labelSmall?.copyWith(
                                color: tierColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                    ),
                  ),
                ],
              ),
            ),

            // ── Central pulsing icon ─────────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _opacity.value,
                          child: Transform.scale(
                            scale: _scale.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              cs.primary.withOpacity(0.25),
                              cs.primary.withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.20),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.style_rounded,
                          size: 48,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Loading next card…',
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withOpacity(0.55),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Keep it up! Every card builds your mastery.',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom decorative dots ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.sessionTarget.clamp(1, 10),
                  (i) {
                    final filled = i < widget.currentIndex - 1;
                    final active = i == widget.currentIndex - 1;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: filled
                            ? tierColor
                            : active
                                ? cs.primary
                                : cs.onSurface.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
