import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/theme/theme_manager.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/services/sound_service.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/gamification/presentation/widgets/badge_icon.dart';
import 'package:social_study_app/features/mascot/models/mascot_state.dart';
import 'package:social_study_app/features/mascot/widgets/study_buddy.dart';

/// Sprint 5.5 celebration helpers — drop these into a feedback flow
/// when a [AnswerFeedback] / [FlashcardRatingResponse] comes back with
/// ``leveledUp == true`` or non-empty ``badgesUnlocked``.
///
/// Two entry points:
///
/// - [showLevelUpBurst] — full-screen confetti-style overlay that
///   reveals the new level number with a scale-in bounce, then fades
///   itself out. Awaits the animation so callers can chain it before
///   advancing to the next item. Fires a heavy haptic.
///
/// - [showBadgeUnlockSheet] — modal bottom sheet showing the badge
///   icon, name, and description. The student dismisses with a tap;
///   `selectionClick` haptic when it opens. Returns when the sheet
///   closes so callers can chain multiple unlocks.
///
/// **Why not a single overlay.** A level-up + badge unlock can happen
/// in the same answer (e.g. crossing into Level 5 unlocks the
/// Apprentice badge). The screens chain them one-at-a-time so the
/// student sees each celebration distinctly instead of one busy
/// composite animation.

/// Configuration for the level-up burst. Tuned so a snappy student
/// taps through quickly; the whole thing wraps in ~1.6s.
const Duration _levelBurstDuration = Duration(milliseconds: 1600);

/// Show a full-screen level-up celebration. Resolves once the animation
/// completes (or the user taps to skip — currently no skip surface).
Future<void> showLevelUpBurst(
  BuildContext context, {
  required int newLevel,
}) async {
  HapticFeedback.heavyImpact();
  SoundService.instance.playLevelUp();
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(120),
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _LevelUpOverlay(newLevel: newLevel),
    ),
  );
}

/// Show a single-badge unlock modal. Returns when the sheet closes.
Future<void> showBadgeUnlockSheet(
  BuildContext context, {
  required String badgeId,
  required String name,
  required String description,
  required String icon,
}) async {
  HapticFeedback.selectionClick();
  SoundService.instance.playBadgeUnlock();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    builder: (_) => _BadgeUnlockSheet(
      badgeId: badgeId,
      name: name,
      description: description,
      icon: icon,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Level-up overlay
// ─────────────────────────────────────────────────────────────────────────

class _LevelUpOverlay extends StatefulWidget {
  const _LevelUpOverlay({required this.newLevel});

  final int newLevel;

  @override
  State<_LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<_LevelUpOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _levelBurstDuration,
    )..addStatusListener((status) {
        // Auto-dismiss when the choreography finishes — the caller is
        // ``await``ing this Navigator push to chain the next step.
        if (status == AnimationStatus.completed && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Confetti particles drift down behind the badge card.
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              size: Size.infinite,
              painter: _ConfettiPainter(progress: _controller.value),
            ),
          ),
          Center(
            child: _LevelUpCard(
              newLevel: widget.newLevel,
              controller: _controller,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelUpCard extends ConsumerWidget {
  const _LevelUpCard({
    required this.newLevel,
    required this.controller,
  });

  final int newLevel;
  final AnimationController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    // Bounce in for the first 40% of the timeline, hold, fade out for
    // the last 15%.
    final scale = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    );
    final opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 25,
      ),
    ]).animate(controller);

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Opacity(
        opacity: opacity.value,
        child: Transform.scale(
          scale: scale.value,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(120),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                themeMode == AppThemeMode.mature
                    ? const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.amber,
                        size: 96,
                      )
                    : const StudyBuddy(
                        state: MascotState.celebrate,
                        size: 96,
                      ),
                const SizedBox(height: Spacing.lg),
                Text(
                  'Level Up!',
                  style: context.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'You reached Level $newLevel',
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withAlpha(230),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Confetti painter — falling rectangles, no asset deps.
// ─────────────────────────────────────────────────────────────────────────

/// Deterministic particle painter. Seed is fixed so repeated frames
/// produce the same particles — drives smooth animation rather than
/// the "every frame is a new random scene" jitter.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  /// Deterministic per-particle data, computed once. Each entry is
  /// (xFraction, startDelay, hue, rotationSpeed, size).
  static final List<_Particle> _particles = _seedParticles();

  static List<_Particle> _seedParticles() {
    final rng = math.Random(42);
    return List.generate(64, (_) {
      return _Particle(
        xFraction: rng.nextDouble(),
        delay: rng.nextDouble() * 0.4,
        colorIndex: rng.nextInt(_palette.length),
        rotationSpeed: 4 + rng.nextDouble() * 8,
        size: 6 + rng.nextDouble() * 8,
      );
    });
  }

  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.tertiary,
    Color(0xFFFFC93C),
    Color(0xFFE53935),
    Color(0xFF6366F1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final t = (progress - p.delay).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = p.xFraction * size.width;
      // Particle falls from -size.height (above the screen) to
      // size.height (off the bottom) over its t window. Accelerate
      // slightly for gravity feel.
      final y = -50 + (size.height + 100) * (t * t * 0.5 + t * 0.5);

      // Fade in/out at the edges of the timeline.
      final opacity =
          (t < 0.15) ? (t / 0.15) : (t > 0.85 ? (1.0 - (t - 0.85) / 0.15) : 1.0);
      paint.color = _palette[p.colorIndex].withAlpha((opacity * 230).round());

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * t);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress;
}

class _Particle {
  const _Particle({
    required this.xFraction,
    required this.delay,
    required this.colorIndex,
    required this.rotationSpeed,
    required this.size,
  });

  final double xFraction;
  final double delay;
  final int colorIndex;
  final double rotationSpeed;
  final double size;
}

// ─────────────────────────────────────────────────────────────────────────
// Badge unlock sheet
// ─────────────────────────────────────────────────────────────────────────

class _BadgeUnlockSheet extends StatefulWidget {
  const _BadgeUnlockSheet({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.icon,
  });

  final String badgeId;
  final String name;
  final String description;
  final String icon;

  @override
  State<_BadgeUnlockSheet> createState() => _BadgeUnlockSheetState();
}

class _BadgeUnlockSheetState extends State<_BadgeUnlockSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          Spacing.lg,
          Spacing.xl,
          Spacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BADGE UNLOCKED',
              style: context.textTheme.labelMedium?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) => Transform.scale(
                scale: scale.value,
                child: child,
              ),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(51),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withAlpha(120),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  iconForBadgeName(widget.icon),
                  color: AppColors.secondary,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              widget.name,
              textAlign: TextAlign.center,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nice!'),
            ),
          ],
        ),
      ),
    );
  }
}
