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

/// Flashcard review interface (Sprint 4.9).
///
/// Renders inside the Flashcards tab of the student home Scaffold, so it
/// has no AppBar of its own. Drives the [FlashcardSession] state machine:
/// the student taps the card to flip it (a 3D rotation animation), then
/// self-rates recall as easy / medium / hard.
///
/// Every state in the union maps to a branch here (Boil the Lake):
/// loading, viewing the front, the revealed back, the in-flight rating,
/// the recorded rating, the unavailable cases, and a generic error.
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
    // `start` is a no-op unless the session is idle, so this is safe
    // even though the IndexedStack keeps the screen alive across tab
    // switches.
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifier.start());
  }

  @override
  void didUpdateWidget(FlashcardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workspaceId != oldWidget.workspaceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(flashcardSessionNotifierProvider(widget.workspaceId).notifier)
              .start();
        }
      });
    }
  }

  /// Run the level-up burst and any badge unlocks in sequence. Each
  /// uses the root navigator so the chain survives if the flashcards
  /// tab itself is swapped out (the celebration sheet still resolves).
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

  /// Reset the family provider to a fresh idle session, then fetch —
  /// the only escape hatch from `error` / `unavailable`, whose
  /// transitions the notifier's `start`/`next` deliberately guard.
  void _restart() {
    ref.invalidate(flashcardSessionNotifierProvider(widget.workspaceId));
    ref
        .read(flashcardSessionNotifierProvider(widget.workspaceId).notifier)
        .start();
  }

  @override
  Widget build(BuildContext context) {
    // Sprint 5.5: when a rating lands, run the level-up + badge-unlock
    // celebrations. Using ``ref.listen`` so the side effect fires
    // exactly once per transition into ``rated`` — ``initState`` would
    // miss subsequent ratings within the same screen lifetime, and
    // doing it from build would re-run every frame.
    ref.listen(
      flashcardSessionNotifierProvider(widget.workspaceId),
      (prev, next) {
        next.whenOrNull(
          rated: (_, response) {
            // Fire and forget — the celebration push/pop runs on the
            // root navigator. Capturing ``context`` once and checking
            // ``context.mounted`` after each await satisfies the
            // ``use_build_context_synchronously`` lint and the actual
            // tree-disposal invariant.
            _playCelebrations(context, response);
          },
        );
      },
    );

    final session =
        ref.watch(flashcardSessionNotifierProvider(widget.workspaceId));
    final isAdmin = ref.watch(isActiveWorkspaceAdminProvider);

    return session.when(
      idle: () => const LoadingIndicator(),
      loading: () => const LoadingIndicator(message: 'Finding a card…'),
      viewingFront: (card) => _CardView(
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.front,
      ),
      revealed: (card) => _CardView(
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.revealed,
      ),
      rating: (card, rating) => _CardView(
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.rating,
        pendingRating: rating,
      ),
      rated: (card, response) => _CardView(
        workspaceId: widget.workspaceId,
        card: card,
        phase: _Phase.rated,
        recordedRating: response.rating,
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

/// The phase of the review for the card currently on screen.
enum _Phase { front, revealed, rating, rated }

class _CardView extends ConsumerWidget {
  const _CardView({
    required this.workspaceId,
    required this.card,
    required this.phase,
    this.pendingRating,
    this.recordedRating,
  });

  final String workspaceId;
  final Flashcard card;
  final _Phase phase;

  /// The rating being recorded, while [phase] is [_Phase.rating].
  final FlashcardRating? pendingRating;

  /// The rating the backend stored, once [phase] is [_Phase.rated].
  final FlashcardRating? recordedRating;

  bool get _showBack => phase != _Phase.front;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(flashcardSessionNotifierProvider(workspaceId).notifier);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: GestureDetector(
              onTap: phase == _Phase.front
                  ? () {
                      HapticFeedback.selectionClick();
                      SoundService.instance.playCardFlip();
                      notifier.flip();
                    }
                  : null,
              child: FlipCard(
                key: ValueKey('card:${card.id}'),
                showBack: _showBack,
                front: FlashcardFace(
                  card: card,
                  side: FlashcardSide.front,
                ),
                back: FlashcardFace(
                  card: card,
                  side: FlashcardSide.back,
                ),
              ),
            ),
          ),
        ),
        _ActionArea(
          workspaceId: workspaceId,
          phase: phase,
          pendingRating: pendingRating,
          recordedRating: recordedRating,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Flip card
// ─────────────────────────────────────────────────────────────────────────

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
              // The back face is rotated 180° so its content reads
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

class FlashcardFace extends StatelessWidget {
  const FlashcardFace({super.key, required this.card, required this.side});

  final Flashcard card;
  final FlashcardSide side;

  bool get _isFront => side == FlashcardSide.front;

  @override
  Widget build(BuildContext context) {
    final accent =
        _isFront ? context.colorScheme.primary : AppColors.tertiary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(102), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.topic.toUpperCase(),
                  style: context.textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                _isFront ? 'QUESTION' : 'ANSWER',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isFront ? card.front : card.back,
                      textAlign: TextAlign.center,
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (!_isFront && card.explanation.isNotEmpty) ...[
                      const SizedBox(height: Spacing.lg),
                      Text(
                        card.explanation,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isFront
                    ? Icons.touch_app_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                _isFront ? 'Tap to reveal the answer' : 'Rate your recall',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bottom action area
// ─────────────────────────────────────────────────────────────────────────

class _ActionArea extends ConsumerWidget {
  const _ActionArea({
    required this.workspaceId,
    required this.phase,
    required this.pendingRating,
    required this.recordedRating,
  });

  final String workspaceId;
  final _Phase phase;
  final FlashcardRating? pendingRating;
  final FlashcardRating? recordedRating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(flashcardSessionNotifierProvider(workspaceId).notifier);

    return Material(
      elevation: 8,
      color: context.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: switch (phase) {
            _Phase.front => const _HintText(
                text: 'Recall the answer, then tap the card to check.',
              ),
            _Phase.revealed => _RatingButtons(
                enabled: true,
                pendingRating: null,
                onRate: notifier.rate,
              ),
            _Phase.rating => _RatingButtons(
                enabled: false,
                pendingRating: pendingRating,
                onRate: notifier.rate,
              ),
            _Phase.rated => _RatedActions(
                recordedRating: recordedRating!,
                onNext: notifier.next,
              ),
          },
        ),
      ),
    );
  }
}

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

/// The three self-rating buckets. While a rating is in flight,
/// [enabled] is false and [pendingRating] marks which bucket shows a
/// spinner.
class _RatingButtons extends StatelessWidget {
  const _RatingButtons({
    required this.enabled,
    required this.pendingRating,
    required this.onRate,
  });

  final bool enabled;
  final FlashcardRating? pendingRating;
  final Future<void> Function(FlashcardRating) onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'How well did you recall it?',
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            for (final rating in FlashcardRating.values) ...[
              Expanded(
                child: _RatingButton(
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

class _RatingButton extends StatelessWidget {
  const _RatingButton({
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
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(style.icon, size: 22),
                const SizedBox(height: Spacing.xs),
                Text(
                  style.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
    );
  }
}

class _RatedActions extends StatelessWidget {
  const _RatedActions({required this.recordedRating, required this.onNext});

  final FlashcardRating recordedRating;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final style = _ratingStyle(recordedRating);
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
          onPressed: () => onNext(),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Next Card'),
        ),
      ],
    );
  }
}
