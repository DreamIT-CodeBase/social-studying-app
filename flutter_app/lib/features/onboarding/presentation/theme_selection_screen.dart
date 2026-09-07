import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/theme/theme_manager.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';

class ThemeSelectionScreen extends ConsumerStatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  ConsumerState<ThemeSelectionScreen> createState() =>
      _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  AppThemeMode _selectedMode = AppThemeMode.mature;

  @override
  void initState() {
    super.initState();
    // Pre-select the existing theme mode value if already initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentMode = ref.read(appThemeModeProvider);
      setState(() {
        _selectedMode = currentMode;
      });
    });
  }

  void _onContinue() async {
    // 1. Save chosen mode to state and SharedPreferences
    await ref.read(appThemeModeProvider.notifier).setThemeMode(_selectedMode);

    if (!mounted) return;

    // 2. Redirect to dashboard if already authenticated, otherwise go to login
    final auth = ref.read(authNotifierProvider).valueOrNull;
    final isAuthenticated = auth?.maybeWhen(
          authenticated: (_) => true,
          orElse: () => false,
        ) ??
        false;

    if (isAuthenticated) {
      if (currentFlavor == AppFlavor.admin) {
        context.go(AppRoutes.adminDashboard);
      } else {
        context.go(AppRoutes.studentHome);
      }
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFEEF2FF), const Color(0xFFFAFAFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xl, vertical: Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),

                // Sparkle Badge
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6)
                          .withOpacity(isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: Color(0xFF8B5CF6), size: 14),
                        SizedBox(width: 6),
                        Text(
                          'EXPERIENCE SELECTOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8B5CF6),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),

                // Greeting Title
                Text(
                  'Choose Your Style',
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Tailor the study environment to fit your age and focus goals.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),

                const Spacer(flex: 2),

                // Theme Card Options
                _buildThemeOptionCard(
                  context: context,
                  mode: AppThemeMode.kids,
                  title: 'Kids Mode',
                  subtitle: 'Playful & Colorful',
                  description:
                      'Learn with Bronto the dinosaur mascot! Gamified rewards, fun celebrations, and cheerful illustrations.',
                  icon: Icons.child_care_rounded,
                  iconColor: const Color(0xFF10B981),
                  cardBg: isDark
                      ? const Color(0xFF064E3B).withOpacity(0.1)
                      : const Color(0xFFECFDF5),
                  borderColor: const Color(0xFF10B981),
                ),
                const SizedBox(height: Spacing.lg),
                _buildThemeOptionCard(
                  context: context,
                  mode: AppThemeMode.mature,
                  title: 'Teen & College Mode',
                  subtitle: 'Matured & Productive',
                  description:
                      'Clean design focused purely on stats, streaks, and subject mastery. Subtle professional layout without mascots.',
                  icon: Icons.school_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  cardBg: isDark
                      ? const Color(0xFF2E1065).withOpacity(0.1)
                      : const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFF8B5CF6),
                ),

                const Spacer(flex: 3),

                // Continue Button
                FilledButton(
                  onPressed: _onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    elevation: 2,
                    shadowColor: const Color(0xFF8B5CF6).withOpacity(0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Get Started'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required BuildContext context,
    required AppThemeMode mode,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    final isSelected = _selectedMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? cardBg
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? borderColor
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: borderColor.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedMode = mode;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? iconColor.withOpacity(0.16)
                        : (isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: isSelected
                        ? iconColor
                        : (isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: Spacing.md),

                // Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E1B4B),
                            ),
                          ),
                          const Spacer(),
                          // Radio indicator
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? borderColor
                                    : (isDark
                                        ? const Color(0xFF475569)
                                        : const Color(0xFFCBD5E1)),
                                width: isSelected ? 6.5 : 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? iconColor
                              : (isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
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
