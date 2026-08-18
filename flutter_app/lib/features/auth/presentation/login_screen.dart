import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/features/auth/domain/auth_state.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';
import 'package:social_study_app/shared/widgets/app_logo.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (_, next) {
      next.whenData((state) {
        state.whenOrNull(
          authenticated: (user) {
            try {
              if (currentFlavor == AppFlavor.student) {
                context.go(AppRoutes.studentHome);
              } else {
                context.go(AppRoutes.adminDashboard);
              }
            } catch (_) {}
          },
        );
      });
    });

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
        error: (error, _) => _LoginBody(
          errorMessage: error.toString().replaceFirst('Exception: ', ''),
          onMicrosoftSignIn: () => ref
              .read(authNotifierProvider.notifier)
              .signInWithMicrosoft(),
          onGoogleSignIn: () => ref
              .read(authNotifierProvider.notifier)
              .signInWithGoogle(),
        ),
      ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.onMicrosoftSignIn,
    required this.onGoogleSignIn,
    this.errorMessage,
  });

  final VoidCallback onMicrosoftSignIn;
  final VoidCallback onGoogleSignIn;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                  Center(
                    child: AppLogo(
                      size: 80,
                      shadows: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x66000000)
                              : const Color(0x260F172A),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome to Social Studying',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: titleColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue learning.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: subtitleColor),
                  ),
                  if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _MicrosoftSignInButton(onPressed: onMicrosoftSignIn),
                  const SizedBox(height: 12),
                  _GoogleSignInButton(onPressed: onGoogleSignIn),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _LegalFooter(
                  onTermsTap: () => context.push(AppRoutes.terms),
                  onPrivacyTap: () => context.push(AppRoutes.privacy),
                  isDark: isDark,
                ),
                ],
              ),
            ),
          ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.onTermsTap, required this.onPrivacyTap, required this.isDark});

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            'By continuing, you agree to our',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: onTermsTap,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Terms & Conditions'),
              ),
              Text('and', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280))),
              TextButton(
                onPressed: onPrivacyTap,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Privacy Policy'),
              ),
            ],
          ),
        ],
      );
}



class _MicrosoftSignInButton extends StatelessWidget {
  const _MicrosoftSignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.email_outlined, color: Colors.white, size: 22),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Sign in / Sign up with Email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 22),
              ],
            ),
          ),
        ),
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
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF1E40AF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331E40AF),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const _GoogleLogoIcon(),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Sign in with Google',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 28),
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
