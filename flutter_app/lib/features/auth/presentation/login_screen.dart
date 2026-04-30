import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/shared/widgets/error_view.dart';
import 'package:social_study_app/shared/widgets/loading_indicator.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: authAsync.when(
          data: (_) => _LoginBody(
            onSignIn: () => ref.read(authNotifierProvider.notifier).signIn(),
          ),
          loading: () => const LoadingIndicator(message: 'Signing you in…'),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.read(authNotifierProvider.notifier).signIn(),
            retryLabel: 'Try Again',
          ),
        ),
      ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          _AppLogo(),
          const SizedBox(height: Spacing.xl),
          Text(
            'Social Study',
            style: context.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'AI-powered adaptive learning\nfor families and schools',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
          _MicrosoftSignInButton(onPressed: onSignIn),
          const SizedBox(height: Spacing.lg),
          _DemoButton(onPressed: onSignIn),
          const Spacer(),
          Text(
            'Social Study App v0.1.0-demo',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(77),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_stories_rounded,
        size: 48,
        color: Colors.white,
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
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
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

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: context.colorScheme.outline),
        ),
        onPressed: onPressed,
        child: Text(
          'Continue with Demo Account',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
