import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/screen_time/services/screen_time_service.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final iosPermissionSetupProvider =
    StateNotifierProvider.autoDispose<IOSPermissionSetupNotifier, IOSPermissionSetupState>(
  (ref) => IOSPermissionSetupNotifier(),
);

class IOSPermissionSetupState {
  const IOSPermissionSetupState({
    this.step = 0,
    this.isLoading = false,
    this.screenTimeStatus = 'notDetermined',
    this.hasSelectedApps = false,
    this.notificationsGranted = false,
    this.errorMessage,
  });

  final int step;
  final bool isLoading;
  final String screenTimeStatus; // 'notDetermined' | 'approved' | 'denied'
  final bool hasSelectedApps;
  final bool notificationsGranted;
  final String? errorMessage;

  bool get screenTimeApproved => screenTimeStatus == 'approved';
  bool get allDone => screenTimeApproved && hasSelectedApps;

  IOSPermissionSetupState copyWith({
    int? step,
    bool? isLoading,
    String? screenTimeStatus,
    bool? hasSelectedApps,
    bool? notificationsGranted,
    String? errorMessage,
    bool clearError = false,
  }) =>
      IOSPermissionSetupState(
        step: step ?? this.step,
        isLoading: isLoading ?? this.isLoading,
        screenTimeStatus: screenTimeStatus ?? this.screenTimeStatus,
        hasSelectedApps: hasSelectedApps ?? this.hasSelectedApps,
        notificationsGranted: notificationsGranted ?? this.notificationsGranted,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

class IOSPermissionSetupNotifier extends StateNotifier<IOSPermissionSetupState> {
  IOSPermissionSetupNotifier() : super(const IOSPermissionSetupState()) {
    _refresh();
  }

  final _service = ScreenTimeService();

  Future<void> _refresh() async {
    if (!Platform.isIOS) return;
    state = state.copyWith(isLoading: true);
    final status = await _service.getIOSAuthorizationStatus();
    final hasApps = await _service.hasSelectedBlockedApps();
    final perm = await _service.getPermissionStatus();
    state = state.copyWith(
      isLoading: false,
      screenTimeStatus: status,
      hasSelectedApps: hasApps,
      notificationsGranted: perm.notifications,
    );
  }

  Future<void> requestScreenTime() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _service.requestScreenTimeAuthorization();
    if (result.approved) {
      state = state.copyWith(
        isLoading: false,
        screenTimeStatus: 'approved',
        step: state.step + 1,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        screenTimeStatus: 'denied',
        errorMessage: result.errorMessage,
      );
    }
  }

  Future<void> openScreenTimeSettings() async {
    await _service.openScreenTimeSettings();
    // Delay a little then re-check (user might have enabled in Settings)
    await Future.delayed(const Duration(seconds: 3));
    await _refresh();
  }

  Future<void> openAppPicker() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final success = await _service.presentFamilyActivityPicker();
    final hasApps = await _service.hasSelectedBlockedApps();
    state = state.copyWith(
      isLoading: false,
      hasSelectedApps: hasApps,
      step: success && hasApps ? state.step + 1 : state.step,
    );
  }

  Future<void> requestNotifications() async {
    state = state.copyWith(isLoading: true);
    final granted = await _service.requestNotificationPermissionIOS();
    state = state.copyWith(isLoading: false, notificationsGranted: granted);
  }

  void nextStep() => state = state.copyWith(step: state.step + 1);
  void prevStep() => state = state.copyWith(step: (state.step - 1).clamp(0, 10));
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full-page permission onboarding for iOS — matches the Android setup flow.
/// Shown automatically when the user is authenticated but Screen Time
/// authorization has not been granted.
class IOSPermissionSetupScreen extends ConsumerWidget {
  const IOSPermissionSetupScreen({super.key, this.onComplete});

  /// Called when all required permissions are granted.
  final VoidCallback? onComplete;

  static const _steps = [
    _StepData(
      icon: Icons.shield_rounded,
      iconColor: Color(0xFF3674FF),
      title: 'Welcome to\nSocial Studying',
      subtitle:
          'To enforce your study-first policy, the app needs a few one-time permissions on this iPhone.',
      primaryLabel: 'Get Started',
    ),
    _StepData(
      icon: Icons.family_restroom_rounded,
      iconColor: Color(0xFF7846F5),
      title: 'Enable\nScreen Time',
      subtitle:
          'Apple\'s Screen Time API lets Social Studying shield distracting apps when study minutes run out. Tap below and approve the dialog.',
      primaryLabel: 'Enable Screen Time',
      secondaryLabel: 'Open Settings Instead',
    ),
    _StepData(
      icon: Icons.app_blocking_rounded,
      iconColor: Color(0xFFEF4444),
      title: 'Choose Apps\nto Shield',
      subtitle:
          'Pick the social media apps (Instagram, TikTok, YouTube, etc.) that should be blocked when study time is exhausted.',
      primaryLabel: 'Choose Apps',
    ),
    _StepData(
      icon: Icons.notifications_active_rounded,
      iconColor: Color(0xFFF59E0B),
      title: 'Stay Informed',
      subtitle:
          'Allow notifications so we can alert you when you\'ve earned new screen-time minutes for completing study sessions.',
      primaryLabel: 'Allow Notifications',
      secondaryLabel: 'Skip for Now',
    ),
    _StepData(
      icon: Icons.check_circle_rounded,
      iconColor: Color(0xFF23E6A0),
      title: 'All Set!',
      subtitle:
          'Social Studying will now shield your selected apps whenever study minutes drop to zero. Complete a study session to unlock them.',
      primaryLabel: 'Go to App',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(iosPermissionSetupProvider);
    final notifier = ref.read(iosPermissionSetupProvider.notifier);

    // Auto-advance if Screen Time was already approved externally
    ref.listen(iosPermissionSetupProvider, (prev, next) {
      if (prev?.screenTimeStatus != 'approved' &&
          next.screenTimeStatus == 'approved' &&
          next.step == 1) {
        notifier.nextStep();
      }
      // Auto-complete if all done and on final step
      if (next.step >= _steps.length && onComplete != null) {
        onComplete!();
      }
    });

    final stepIndex = state.step.clamp(0, _steps.length - 1);
    final step = _steps[stepIndex];
    final isLastStep = stepIndex == _steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Progress dots ──────────────────────────────────────────────
              _ProgressDots(current: stepIndex, total: _steps.length),
              const Spacer(),

              // ── Icon ───────────────────────────────────────────────────────
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _StepIcon(
                    key: ValueKey(stepIndex),
                    icon: step.icon,
                    color: step.iconColor,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // ── Title ──────────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  step.title,
                  key: ValueKey('title_$stepIndex'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),

              // ── Subtitle ───────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  step.subtitle,
                  key: ValueKey('sub_$stepIndex'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),

              // ── Status badges ──────────────────────────────────────────────
              if (stepIndex == 1) ...[
                const SizedBox(height: Spacing.md),
                _StatusBadge(
                  label: 'Screen Time',
                  status: state.screenTimeStatus,
                ),
              ],
              if (stepIndex == 2) ...[
                const SizedBox(height: Spacing.md),
                _StatusBadge(
                  label: 'Apps Selected',
                  status: state.hasSelectedApps ? 'approved' : 'notDetermined',
                ),
              ],

              // ── Error message ──────────────────────────────────────────────
              if (state.errorMessage != null) ...[
                const SizedBox(height: Spacing.md),
                _ErrorCard(message: state.errorMessage!),
              ],

              const Spacer(),

              // ── Primary action ─────────────────────────────────────────────
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: step.iconColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: state.isLoading
                    ? null
                    : () => _handlePrimary(
                          context,
                          stepIndex,
                          notifier,
                          state,
                          isLastStep,
                        ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        step.primaryLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              // ── Secondary action ───────────────────────────────────────────
              if (step.secondaryLabel != null) ...[
                const SizedBox(height: Spacing.sm),
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => _handleSecondary(stepIndex, notifier),
                  child: Text(
                    step.secondaryLabel!,
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],

              // ── Back button (not on first or last step) ────────────────────
              if (stepIndex > 0 && !isLastStep) ...[
                const SizedBox(height: Spacing.xs),
                Center(
                  child: TextButton.icon(
                    onPressed: notifier.prevStep,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePrimary(
    BuildContext context,
    int stepIndex,
    IOSPermissionSetupNotifier notifier,
    IOSPermissionSetupState state,
    bool isLastStep,
  ) {
    if (isLastStep) {
      onComplete?.call();
      return;
    }
    switch (stepIndex) {
      case 0:
        notifier.nextStep();
      case 1:
        if (state.screenTimeStatus == 'denied') {
          notifier.openScreenTimeSettings();
        } else {
          notifier.requestScreenTime();
        }
      case 2:
        notifier.openAppPicker();
      case 3:
        notifier.requestNotifications();
        notifier.nextStep();
      default:
        notifier.nextStep();
    }
  }

  void _handleSecondary(int stepIndex, IOSPermissionSetupNotifier notifier) {
    switch (stepIndex) {
      case 1:
        notifier.openScreenTimeSettings();
      case 3:
        notifier.nextStep(); // Skip notifications
      default:
        notifier.nextStep();
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StepData {
  const _StepData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    this.secondaryLabel,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String? secondaryLabel;
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({super.key, required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 56, color: color),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.2),
          ),
        );
      }),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (status) {
      'approved' => (
          Colors.green,
          Icons.check_circle_rounded,
          'Enabled',
        ),
      'denied' => (
          Colors.red,
          Icons.cancel_rounded,
          'Denied — tap "Open Settings" below',
        ),
      _ => (
          Colors.orange,
          Icons.hourglass_empty_rounded,
          'Pending',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            '$label: $text',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.onErrorContainer,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
