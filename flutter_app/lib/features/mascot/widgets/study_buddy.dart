import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:social_study_app/features/mascot/models/mascot_state.dart';

class StudyBuddy extends StatelessWidget {
  const StudyBuddy({
    super.key,
    this.state = MascotState.idle,
    this.size = 80.0,
  });

  final MascotState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Using ValueKey(state) so the animation triggers/restarts whenever the state changes.
    return SizedBox(
      width: size,
      height: size,
      key: ValueKey(state),
      child: _buildAnimatedMascot(),
    );
  }

  Widget _buildAnimatedMascot() {
    final mascotImage = Image.asset(
      'assets/mascot/study_buddy.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.face_retouching_natural_rounded,
          size: size * 0.8,
          color: Theme.of(context).colorScheme.primary,
        );
      },
    );

    switch (state) {
      case MascotState.idle:
        // Continuous gentle float up and down
        return mascotImage
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .moveY(begin: -4, end: 4, duration: 1600.ms, curve: Curves.easeInOut);

      case MascotState.happy:
        // Bounce up and scale pulse
        return mascotImage
            .animate()
            .moveY(begin: 0, end: -12, duration: 250.ms, curve: Curves.easeOutQuad)
            .scaleXY(begin: 1.0, end: 1.15, duration: 250.ms, curve: Curves.easeOutQuad)
            .then()
            .moveY(begin: -12, end: 0, duration: 250.ms, curve: Curves.easeInQuad)
            .scaleXY(begin: 1.15, end: 1.0, duration: 250.ms, curve: Curves.easeInQuad)
            .then()
            .shake(hz: 3, duration: 300.ms);

      case MascotState.sad:
        // Horizontal shake to show wrong answer
        return mascotImage
            .animate()
            .shake(hz: 8, duration: 500.ms)
            .tint(color: Colors.red.withOpacity(0.15), duration: 200.ms)
            .then()
            .tint(color: Colors.transparent, duration: 200.ms);

      case MascotState.celebrate:
        // High energetic bounce + shimmer/glow loop
        return mascotImage
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .moveY(begin: 0, end: -20, duration: 400.ms, curve: Curves.easeOutQuad)
            .scaleXY(begin: 1.0, end: 1.2, duration: 400.ms, curve: Curves.easeOutQuad)
            .then()
            .moveY(begin: -20, end: 0, duration: 400.ms, curve: Curves.easeInQuad)
            .scaleXY(begin: 1.2, end: 0.95, duration: 300.ms, curve: Curves.easeInQuad)
            .then()
            .scaleXY(begin: 0.95, end: 1.0, duration: 150.ms)
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(delay: 500.ms, duration: 1200.ms, color: Colors.white.withOpacity(0.5));

      case MascotState.loading:
        // Scaling breathe + rotating indicator feel
        return mascotImage
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scaleXY(begin: 0.85, end: 1.05, duration: 1000.ms, curve: Curves.easeInOut)
            .animate(onPlay: (controller) => controller.repeat())
            .rotate(begin: -0.04, end: 0.04, duration: 1200.ms, curve: Curves.easeInOut);
    }
  }
}
