import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/widgets/app_logo.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      body: authAsync.when(
        data: (_) => _LoginBody(
          onMicrosoftSignIn: () => ref
              .read(authNotifierProvider.notifier)
              .signInWithMicrosoft(),
          onGoogleSignIn: () => ref
              .read(authNotifierProvider.notifier)
              .signInWithGoogle(),
        ),
        loading: () => const LoadingIndicator(message: 'Signing you in…'),
        error: (error, _) => Scaffold(
          body: SafeArea(
            child: ErrorView(
              message: error.toString(),
              onRetry: () => ref
                  .read(authNotifierProvider.notifier)
                  .signInWithMicrosoft(),
              retryLabel: 'Try Again',
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.onMicrosoftSignIn,
    required this.onGoogleSignIn,
  });

  final VoidCallback onMicrosoftSignIn;
  final VoidCallback onGoogleSignIn;

  bool _isTestEnvironment() {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Widget _animateIfReal(Widget child, {required Widget Function(Widget) animation}) {
    if (_isTestEnvironment()) {
      return child;
    }
    return animation(child);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ambient background gradient
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1E38),
              Color(0xFF0F172A),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFEEF2F6),
              Color(0xFFEFF6FF),
            ],
          );

    return Container(
      decoration: BoxDecoration(gradient: bgGradient),
      child: Stack(
        children: [
          // Background decorative glow blur 1
          Positioned(
            top: -100,
            right: -50,
            child: _animateIfReal(
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF3B82F6).withOpacity(0.15)
                      : const Color(0xFFDBEAFE),
                ),
              ),
              animation: (w) => w.animate().fade(duration: 1200.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.2, 1.2),
                    duration: 8.seconds,
                    curve: Curves.easeInOut,
                  ),
            ),
          ),
          // Background decorative glow blur 2
          Positioned(
            bottom: -80,
            left: -80,
            child: _animateIfReal(
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF8B5CF6).withOpacity(0.12)
                      : const Color(0xFFF3E8FF),
                ),
              ),
              animation: (w) => w.animate().fade(duration: 1200.ms).scale(
                    begin: const Offset(1.2, 1.2),
                    end: const Offset(0.9, 0.9),
                    duration: 6.seconds,
                    curve: Curves.easeInOut,
                  ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: Spacing.lg),
                    // Floating card design
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg,
                        vertical: Spacing.xl * 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B).withOpacity(0.8)
                            : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pulse Animated App Logo
                          _animateIfReal(
                            AppLogo(
                              shadows: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            animation: (w) => w.animate(
                              onPlay: (controller) => controller.repeat(reverse: true),
                            ).scale(
                              begin: const Offset(1.0, 1.0),
                              end: const Offset(1.03, 1.03),
                              duration: 2.seconds,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          const SizedBox(height: Spacing.lg),
                          _animateIfReal(
                            Text(
                              'Social Study',
                              style: context.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: context.colorScheme.onSurface,
                                letterSpacing: -0.8,
                              ),
                            ),
                            animation: (w) => w.animate().fade(delay: 100.ms).slideY(begin: 0.1),
                          ),
                          const SizedBox(height: Spacing.sm),
                          _animateIfReal(
                            Text(
                              'AI-powered adaptive learning\nfor families and schools',
                              textAlign: TextAlign.center,
                              style: context.textTheme.bodyLarge?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                            animation: (w) => w.animate().fade(delay: 200.ms).slideY(begin: 0.1),
                          ),
                          const SizedBox(height: Spacing.xl),
                          
                          // Sign In Portals
                          _animateIfReal(
                            _MicrosoftSignInButton(onPressed: onMicrosoftSignIn),
                            animation: (w) => w.animate().fade(delay: 350.ms).slideY(begin: 0.15),
                          ),
                          const SizedBox(height: Spacing.md),
                          _animateIfReal(
                            _GoogleSignInButton(onPressed: onGoogleSignIn),
                            animation: (w) => w.animate().fade(delay: 450.ms).slideY(begin: 0.15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xl * 1.5),
                    _animateIfReal(
                      Text(
                        'Social Study App v0.1.0-demo',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      animation: (w) => w.animate().fade(delay: 600.ms),
                    ),
                    const SizedBox(height: Spacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicrosoftSignInButton extends StatelessWidget {
  const _MicrosoftSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.microsoftBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        onPressed: onPressed,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MicrosoftLogoIcon(),
            SizedBox(width: Spacing.md),
            Text('Sign in with Microsoft'),
          ],
        ),
      ),
    );
  }
}

class _MicrosoftLogoIcon extends StatelessWidget {
  const _MicrosoftLogoIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.zero,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ColoredBox(color: Color(0xFFF25022)),
          ColoredBox(color: Color(0xFF7FBA00)),
          ColoredBox(color: Color(0xFF00A4EF)),
          ColoredBox(color: Color(0xFFFFB900)),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
          elevation: 0,
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        onPressed: onPressed,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleLogoIcon(),
            SizedBox(width: Spacing.md),
            Text('Sign in with Google'),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoIcon extends StatelessWidget {
  const _GoogleLogoIcon();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale);

    // Red Segment
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final Path redPath = Path()
      ..moveTo(12.0, 5.04)
      ..cubicTo(13.94, 5.04, 15.68, 5.71, 17.05, 7.01)
      ..lineTo(20.82, 3.25)
      ..cubicTo(18.25, 0.85, 14.88, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.32, 2.68, 1.4, 6.6)
      ..lineTo(5.56, 9.82)
      ..cubicTo(6.54, 6.95, 9.17, 5.04, 12.0, 5.04);
    canvas.drawPath(redPath, redPaint);

    // Yellow Segment
    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final Path yellowPath = Path()
      ..moveTo(5.56, 14.18)
      ..cubicTo(5.3, 13.4, 5.16, 12.57, 5.16, 11.7)
      ..cubicTo(5.16, 10.83, 5.3, 10.0, 5.56, 9.22)
      ..lineTo(1.4, 6.0)
      ..cubicTo(0.5, 7.82, 0.0, 9.83, 0.0, 11.7)
      ..cubicTo(0.0, 13.57, 0.5, 15.58, 1.4, 17.4)
      ..lineTo(5.56, 14.18);
    canvas.drawPath(yellowPath, yellowPaint);

    // Green Segment
    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final Path greenPath = Path()
      ..moveTo(12.0, 18.96)
      ..cubicTo(9.17, 18.96, 6.54, 17.05, 5.56, 14.18)
      ..lineTo(1.4, 17.4)
      ..cubicTo(3.32, 21.32, 7.33, 24.0, 12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.97, 22.93, 19.96, 21.09)
      ..lineTo(16.08, 18.07)
      ..cubicTo(14.99, 18.8, 13.59, 18.96, 12.0, 18.96);
    canvas.drawPath(greenPath, greenPaint);

    // Blue Segment
    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final Path bluePath = Path()
      ..moveTo(24.0, 11.7)
      ..cubicTo(24.0, 10.87, 23.93, 10.07, 23.79, 9.3)
      ..lineTo(12.0, 9.3)
      ..lineTo(12.0, 13.85)
      ..lineTo(18.72, 13.85)
      ..cubicTo(18.43, 15.39, 17.56, 16.7, 16.26, 17.58)
      ..lineTo(20.14, 20.6)
      ..cubicTo(22.41, 18.5, 24.0, 15.4, 24.0, 11.7);
    canvas.drawPath(bluePath, bluePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
