import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/screen_time/data/screen_time_repository.dart';

class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen> {
  static const _channel = MethodChannel('com.socialstudyapp.app/screen_time');
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSubmitting = false;

  // Track granted statuses for each of the 5 steps
  bool _usageGranted = false;
  bool _overlayGranted = false;
  bool _notificationGranted = false;
  bool _accessibilityGranted = false;
  bool _batteryExempt = false;

  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkAllStatuses();
    // Start periodic check to automatically update when user comes back from settings
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkAllStatuses();
    });
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkAllStatuses() async {
    if (!Platform.isAndroid) {
      // Mock true for non-Android platforms
      if (mounted) {
        setState(() {
          _usageGranted = true;
          _overlayGranted = true;
          _notificationGranted = true;
          _accessibilityGranted = true;
          _batteryExempt = true;
        });
      }
      return;
    }

    try {
      final usage = await _channel.invokeMethod<bool>('isUsageAccessGranted') ?? false;
      final overlay = await _channel.invokeMethod<bool>('isOverlayGranted') ?? false;
      final notification = await _channel.invokeMethod<bool>('isNotificationGranted') ?? false;
      final accessibility = await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      final battery = await _channel.invokeMethod<bool>('isBatteryOptimizationExempt') ?? false;

      if (mounted) {
        setState(() {
          _usageGranted = usage;
          _overlayGranted = overlay;
          _notificationGranted = notification;
          _accessibilityGranted = accessibility;
          _batteryExempt = battery;
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<void> _grantPermission(int stepIndex) async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mocking grant on non-Android platform.')),
      );
      return;
    }

    try {
      switch (stepIndex) {
        case 0:
          await _channel.invokeMethod<void>('openUsageAccessSettings');
          break;
        case 1:
          await _channel.invokeMethod<void>('openOverlaySettings');
          break;
        case 2:
          await _channel.invokeMethod<void>('openNotificationSettings');
          break;
        case 3:
          await _channel.invokeMethod<void>('openAccessibilitySettings');
          break;
        case 4:
          await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching settings: $e')),
      );
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(screenTimeRepositoryProvider);
      await repo.reportPermissionStatus(
        overlayPermission: _overlayGranted,
        usageAccessPermission: _usageGranted,
        notificationAccess: _notificationGranted,
        accessibilityService: _accessibilityGranted,
        batteryOptimizationExempt: _batteryExempt,
        deviceAdministrator: false, // fallback/optional
      );

      if (mounted) {
        context.go(AppRoutes.studentHome);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync statuses: $e. Proceeding to home...'),
            duration: const Duration(seconds: 3),
          ),
        );
        context.go(AppRoutes.studentHome);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _PermissionStepData(
        title: 'Usage Access',
        description:
            'Allows the app to track which apps you use, so we can calculate your screen time and reward you for study milestones.',
        icon: Icons.insights_rounded,
        isGranted: _usageGranted,
        gradientColors: [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
      ),
      _PermissionStepData(
        title: 'System Overlay',
        description:
            'Allows the app to show a blocking overlay when you try to open social media during restricted study hours.',
        icon: Icons.layers_rounded,
        isGranted: _overlayGranted,
        gradientColors: [const Color(0xFFEC4899), const Color(0xFFF472B6)],
      ),
      _PermissionStepData(
        title: 'Notifications Access',
        description:
            'Ensures you receive screen time awards and study session warnings instantly.',
        icon: Icons.notifications_rounded,
        isGranted: _notificationGranted,
        gradientColors: [const Color(0xFF10B981), const Color(0xFF34D399)],
      ),
      _PermissionStepData(
        title: 'Accessibility Service',
        description:
            'Monitors active apps in the background to automatically restrict apps when study schedules are active.',
        icon: Icons.accessibility_new_rounded,
        isGranted: _accessibilityGranted,
        gradientColors: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      ),
      _PermissionStepData(
        title: 'Battery Saver Exemption',
        description:
            'Allows the screen time monitoring service to run continuously in the background without being suspended by Android.',
        icon: Icons.battery_charging_full_rounded,
        isGranted: _batteryExempt,
        gradientColors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      ),
    ];

    final currentStep = steps[_currentPage];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xl,
                  vertical: Spacing.md,
                ),
                child: Row(
                  children: [
                    Text(
                      'Permissions Setup',
                      style: context.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_currentPage + 1} of ${steps.length}',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: Spacing.md),
                          // Premium Gradient Card with Icon
                          Container(
                            height: 160,
                            width: 160,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: step.gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: step.gradientColors.first.withOpacity(0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              step.icon,
                              size: 72,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),

                          // Text Info
                          Text(
                            step.title,
                            style: context.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                            child: Text(
                              step.description,
                              textAlign: TextAlign.center,
                              style: context.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.xl,
                              vertical: Spacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: step.isGranted
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF7F1D1D),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: step.isGranted
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  step.isGranted
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.error_outline_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: Spacing.sm),
                                Text(
                                  step.isGranted ? 'GRANTED' : 'MISSING',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!Platform.isAndroid) ...[
                            const SizedBox(height: Spacing.md),
                            Text(
                              'Platform not supported — Mocked as Granted',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Step Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  steps.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, 0, Spacing.xl, Spacing.xl,
                ),
                child: Column(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: currentStep.isGranted
                            ? const Color(0xFF1E293B)
                            : AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _grantPermission(_currentPage),
                      child: Text(
                        currentStep.isGranted
                            ? 'Already Granted'
                            : 'Grant Permission',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: currentStep.isGranted
                              ? Colors.white60
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      children: [
                        if (_currentPage > 0)
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 56),
                                side: const BorderSide(color: Color(0xFF334155)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                setState(() => _currentPage--);
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: const Text(
                                'Back',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (_currentPage > 0) const SizedBox(width: Spacing.md),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 56),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    if (_currentPage < steps.length - 1) {
                                      setState(() => _currentPage++);
                                      _pageController.nextPage(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                      );
                                    } else {
                                      await _finishOnboarding();
                                    }
                                  },
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  )
                                : Text(
                                    _currentPage == steps.length - 1
                                        ? 'Finish Setup'
                                        : 'Next',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStepData {
  const _PermissionStepData({
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
    required this.gradientColors,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isGranted;
  final List<Color> gradientColors;
}
