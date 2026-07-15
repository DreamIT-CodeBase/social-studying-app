import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/screen_time/data/screen_time_repository.dart';
import 'package:social_study_app/features/screen_time/services/screen_time_service.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen>
    with WidgetsBindingObserver {
  final ScreenTimeService _screenTimeService = ScreenTimeService();
  final Set<_PermissionKind> _attempted = {};

  DevicePermissionStatus _status = const DevicePermissionStatus(
    usageAccess: false,
    overlay: false,
    notifications: false,
    accessibility: false,
    batteryExempt: false,
  );
  bool _isChecking = true;
  bool _isDialogOpen = false;
  bool _isSubmitting = false;
  bool _sequenceActive = true;
  bool _waitingForAndroidSettings = false;

  static const _permissionOrder = <_PermissionKind>[
    _PermissionKind.notifications,
    _PermissionKind.accessibility,
    _PermissionKind.usageAccess,
    _PermissionKind.overlay,
    _PermissionKind.battery,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshStatus();
      _scheduleNextDialog();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_waitingForAndroidSettings) {
      return;
    }
    _waitingForAndroidSettings = false;
    unawaited(_continueAfterAndroidSettings());
  }

  Future<void> _continueAfterAndroidSettings() async {
    // Give the OEM Settings app a moment to persist its switch before reading it.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _refreshStatus();
    _scheduleNextDialog();
  }

  Future<void> _refreshStatus() async {
    final status = await _screenTimeService.getPermissionStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _isChecking = false;
    });
  }

  void _scheduleNextDialog() {
    if (!mounted || !_sequenceActive || _isDialogOpen || _isSubmitting) return;

    final next = _permissionOrder.cast<_PermissionKind?>().firstWhere(
          (permission) =>
              permission != null &&
              !_isGranted(permission) &&
              !_attempted.contains(permission),
          orElse: () => null,
        );

    if (next == null) {
      _sequenceActive = false;
      if (_status.requiredPermissionsGranted) {
        unawaited(_finishOnboarding());
      } else if (mounted) {
        setState(() {});
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showPermissionDialog(next));
    });
  }

  Future<void> _showPermissionDialog(_PermissionKind permission) async {
    if (!mounted || _isDialogOpen) return;
    setState(() => _isDialogOpen = true);

    final shouldOpen = await showDialog<bool>(
      context: context,
      barrierDismissible: !permission.isRequired,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(permission.icon, color: AppColors.primary, size: 32),
        title: Text(permission.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(permission.description),
            if (permission == _PermissionKind.accessibility) ...[
              const SizedBox(height: Spacing.md),
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Social Studying detects only the foreground app so it can block selected social apps when earned time reaches zero. It does not read screen content, passwords, or messages.',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!permission.isRequired)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(permission.actionLabel),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _isDialogOpen = false);
    _attempted.add(permission);

    if (shouldOpen != true) {
      _scheduleNextDialog();
      return;
    }

    await _requestPermission(permission);
  }

  Future<void> _requestPermission(_PermissionKind permission) async {
    if (!Platform.isAndroid) {
      await _refreshStatus();
      _scheduleNextDialog();
      return;
    }

    try {
      switch (permission) {
        case _PermissionKind.notifications:
          await _screenTimeService.requestNotificationPermission();
          await _refreshStatus();
          _scheduleNextDialog();
          return;
        case _PermissionKind.accessibility:
          _waitingForAndroidSettings = true;
          await _screenTimeService.openAccessibilitySettings();
          break;
        case _PermissionKind.usageAccess:
          _waitingForAndroidSettings = true;
          await _screenTimeService.openUsageAccessSettings();
          break;
        case _PermissionKind.overlay:
          _waitingForAndroidSettings = true;
          await _screenTimeService.openOverlaySettings();
          break;
        case _PermissionKind.battery:
          _waitingForAndroidSettings = true;
          await _screenTimeService.openBatteryOptimizationSettings();
          break;
      }

      // Some OEM settings panels behave like dialogs and do not emit a full
      // paused/resumed lifecycle pair. Continue when that happens.
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (!mounted || !_waitingForAndroidSettings) return;
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          _waitingForAndroidSettings = false;
          unawaited(_continueAfterAndroidSettings());
        }
      });
    } catch (_) {
      _waitingForAndroidSettings = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Android could not open that permission control.'),
          ),
        );
      }
      _scheduleNextDialog();
    }
  }

  void _restartSequence([_PermissionKind? only]) {
    setState(() {
      if (only == null) {
        _attempted.removeWhere((permission) => !_isGranted(permission));
      } else {
        _attempted.remove(only);
      }
      _sequenceActive = true;
    });
    _scheduleNextDialog();
  }

  bool _isGranted(_PermissionKind permission) {
    return switch (permission) {
      _PermissionKind.notifications => _status.notifications,
      _PermissionKind.accessibility => _status.accessibility,
      _PermissionKind.usageAccess => _status.usageAccess,
      _PermissionKind.overlay => _status.overlay,
      _PermissionKind.battery => _status.batteryExempt,
    };
  }

  Future<void> _finishOnboarding() async {
    if (_isSubmitting) return;
    await _refreshStatus();
    if (!mounted) return;
    if (!_status.requiredPermissionsGranted) {
      _restartSequence();
      return;
    }

    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(
      authenticated: (authenticatedUser) => authenticatedUser,
      orElse: () => null,
    );
    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SessionPersistenceService.instance.setPermissionSetupComplete(
        user.id,
        complete: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save permission setup. Please try again.'),
        ),
      );
      return;
    }

    unawaited(_reportPermissionStatus());
    if (mounted) {
      context.go(AppRoutes.studentHome);
    }
  }

  Future<void> _reportPermissionStatus() async {
    try {
      await ref.read(screenTimeRepositoryProvider).reportPermissionStatus(
            overlayPermission: _status.overlay,
            usageAccessPermission: _status.usageAccess,
            notificationAccess: _status.notifications,
            accessibilityService: _status.accessibility,
            batteryOptimizationExempt: _status.batteryExempt,
            deviceAdministrator: false,
          );
    } catch (_) {
      // Local enforcement is already active; cloud health retries on resume.
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiredReady = _status.requiredPermissionsGranted;
    return Scaffold(
      appBar: AppBar(title: const Text('App permissions')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Spacing.lg),
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Set up social app blocking',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Android will show its own permission controls one at a time. Return to Social Studying after enabling each switch.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.xl),
                  Card(
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < _permissionOrder.length;
                            index++) ...[
                          _PermissionTile(
                            permission: _permissionOrder[index],
                            granted: _isGranted(_permissionOrder[index]),
                            onTap: () =>
                                _restartSequence(_permissionOrder[index]),
                          ),
                          if (index < _permissionOrder.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                  if (!requiredReady && !_sequenceActive) ...[
                    const SizedBox(height: Spacing.md),
                    Text(
                      'Accessibility and Usage Access are required for automatic blocking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: FilledButton.icon(
                onPressed: _isChecking || _isSubmitting || _sequenceActive
                    ? null
                    : requiredReady
                        ? _finishOnboarding
                        : _restartSequence,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                icon: _isChecking || _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _sequenceActive
                      ? 'Complete the Android prompt'
                      : requiredReady
                          ? 'Finish setup'
                          : 'Continue permission setup',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.granted,
    required this.onTap,
  });

  final _PermissionKind permission;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: granted ? null : onTap,
      leading: Icon(
        granted ? Icons.check_circle_rounded : permission.icon,
        color: granted
            ? Colors.green
            : permission.isRequired
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        permission.shortTitle,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(permission.isRequired ? 'Required' : 'Recommended'),
      trailing: Text(
        granted ? 'Allowed' : 'Set up',
        style: TextStyle(
          color: granted ? Colors.green : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _PermissionKind {
  notifications,
  accessibility,
  usageAccess,
  overlay,
  battery;

  bool get isRequired =>
      this == _PermissionKind.accessibility ||
      this == _PermissionKind.usageAccess;

  String get shortTitle => switch (this) {
        _PermissionKind.notifications => 'Notifications',
        _PermissionKind.accessibility => 'App blocking service',
        _PermissionKind.usageAccess => 'Usage Access',
        _PermissionKind.overlay => 'Display over apps',
        _PermissionKind.battery => 'Battery optimization',
      };

  String get title => switch (this) {
        _PermissionKind.notifications => 'Allow Social Studying notifications?',
        _PermissionKind.accessibility => 'Turn on app blocking?',
        _PermissionKind.usageAccess => 'Allow Usage Access?',
        _PermissionKind.overlay => 'Allow display over other apps?',
        _PermissionKind.battery => 'Keep app blocking responsive?',
      };

  String get description => switch (this) {
        _PermissionKind.notifications =>
          'Get earned-time awards, policy updates, and study-session reminders.',
        _PermissionKind.accessibility =>
          'Android requires an Accessibility service to detect selected social apps and display the study lock.',
        _PermissionKind.usageAccess =>
          'Usage Access provides a reliable second signal for detecting the foreground social app and measuring elapsed time.',
        _PermissionKind.overlay =>
          'This optional fallback lets the study lock remain visible on phones with stricter window behavior.',
        _PermissionKind.battery =>
          'This optional setting helps Android keep the blocking service responsive when the phone is idle.',
      };

  String get actionLabel => switch (this) {
        _PermissionKind.notifications => 'Allow',
        _PermissionKind.accessibility => 'Open Android settings',
        _PermissionKind.usageAccess => 'Open Android settings',
        _PermissionKind.overlay => 'Open Android settings',
        _PermissionKind.battery => 'Continue',
      };

  IconData get icon => switch (this) {
        _PermissionKind.notifications => Icons.notifications_rounded,
        _PermissionKind.accessibility => Icons.accessibility_new_rounded,
        _PermissionKind.usageAccess => Icons.insights_rounded,
        _PermissionKind.overlay => Icons.layers_rounded,
        _PermissionKind.battery => Icons.battery_saver_rounded,
      };
}
