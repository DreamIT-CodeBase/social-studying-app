import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/icons/loginpagebgimage.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          // Subtle Dark Layer for Contrast
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ),
          // Scrollable Layout
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Spacing to push main box downward
                    const SizedBox(height: 120),
                    // Floating White Overlay Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(38),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App Logo square card
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/branding/app_logo.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [Color(0xFF00F2FE), Color(0xFF4FACFE), Color(0xFFF355DA)],
                                        ).createShader(bounds),
                                        child: const Text(
                                          'S',
                                          style: TextStyle(
                                            fontSize: 38,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        'Studying AI',
                                        style: TextStyle(
                                          fontSize: 7,
                                          color: Colors.white60,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Title text
                          const Text(
                            'Welcome to',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF7C5CFC), Color(0xFF2563EB)],
                            ).createShader(bounds),
                            child: const Text(
                              'Social Studying AI',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'AI-powered adaptive learning\nfor families and schools',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Features Row
                          const Row(
                            children: [
                              _FeatureItem(
                                icon: Icons.track_changes_rounded,
                                iconColor: Color(0xFF7C5CFC),
                                title: 'Smart Learning',
                                desc: 'Adaptive quizzes\njust for you',
                              ),
                              _FeatureDivider(),
                              _FeatureItem(
                                icon: Icons.bar_chart_rounded,
                                iconColor: Color(0xFF3B82F6),
                                title: 'Track Progress',
                                desc: 'See your growth\nand insights',
                              ),
                              _FeatureDivider(),
                              _FeatureItem(
                                icon: Icons.emoji_events_rounded,
                                iconColor: Color(0xFF10B981),
                                title: 'Earn & Achieve',
                                desc: 'Earn XP and\nunlock new levels',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Microsoft Button
                          _MicrosoftSignInButton(onPressed: onMicrosoftSignIn),
                          const SizedBox(height: 12),
                          // Google Button
                          _GoogleSignInButton(onPressed: onGoogleSignIn),

                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Terms footer
                    const Text(
                      'By continuing, you agree to our',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Terms of Service',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        Text(
                          ' and ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
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

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: const Color(0xFFE2E8F0),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}



class _MicrosoftSignInButton extends StatelessWidget {
  const _MicrosoftSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C5CFC), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const _MicrosoftLogoIcon(),
                ),
                const Spacer(),
                const Text(
                  'Sign in with Microsoft',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF2563EB),
                    size: 16,
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
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const _GoogleLogoIcon(),
                ),
                const Spacer(),
                const Text(
                  'Sign in with Google',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF7C5CFC),
                    size: 16,
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
