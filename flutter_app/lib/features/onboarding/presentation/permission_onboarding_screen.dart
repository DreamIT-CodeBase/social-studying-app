import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/routing/routes.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
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

  int _currentStep = 0; // 0 = Permissions, 1 = Choose Your Distraction Apps
  bool _hasIOSSelectedApps = false;
  Set<String> _selectedAndroidPackages = {};

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

  static const Map<String, (String name, IconData icon)> _availableAndroidApps = {
    'com.instagram.android': ('Instagram', Icons.camera_alt_outlined),
    'com.instagram.barcelona': ('Threads', Icons.alternate_email_rounded),
    'com.zhiliaoapp.musically': ('TikTok', Icons.music_note_outlined),
    'com.google.android.youtube': ('YouTube', Icons.play_circle_outline),
    'com.facebook.katana': ('Facebook', Icons.facebook_outlined),
    'com.twitter.android': ('X (Twitter)', Icons.alternate_email_outlined),
    'com.snapchat.android': ('Snapchat', Icons.chat_bubble_outline),
    'com.reddit.frontpage': ('Reddit', Icons.forum_outlined),
    'com.pinterest': ('Pinterest', Icons.push_pin_outlined),
  };

  List<_PermissionKind> get _permissionOrder {
    if (Platform.isIOS) {
      return const [
        _PermissionKind.notifications,
        _PermissionKind.screenTime,
      ];
    }
    return const [
      _PermissionKind.notifications,
      _PermissionKind.accessibility,
      _PermissionKind.usageAccess,
      _PermissionKind.overlay,
      _PermissionKind.battery,
    ];
  }

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
    final hasIOSApps = Platform.isIOS
        ? await _screenTimeService.hasSelectedBlockedApps()
        : false;
    final blockedAndroid = Platform.isAndroid
        ? await _screenTimeService.getBlockedPackages()
        : <String>[];

    if (!mounted) return;
    setState(() {
      _status = status;
      _hasIOSSelectedApps = hasIOSApps;
      if (_selectedAndroidPackages.isEmpty && blockedAndroid.isNotEmpty) {
        _selectedAndroidPackages = blockedAndroid.toSet();
      }
      _isChecking = false;
    });
  }

  void _scheduleNextDialog() {
    if (!mounted || !_sequenceActive || _isDialogOpen || _isSubmitting) return;

    if (_currentStep != 0) return;

    final next = _permissionOrder.cast<_PermissionKind?>().firstWhere(
          (permission) =>
              permission != null &&
              !_isGranted(permission) &&
              !_attempted.contains(permission),
          orElse: () => null,
        );

    if (next == null) {
      _sequenceActive = false;
      if (mounted) {
        setState(() {
          _currentStep = 1; // Advance seamlessly to Choose Your Distraction Apps
        });
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
    if (Platform.isIOS) {
      try {
        switch (permission) {
          case _PermissionKind.notifications:
            await _screenTimeService.requestNotificationPermission();
            break;
          case _PermissionKind.screenTime:
            await _screenTimeService.requestScreenTimeAuthorization();
            break;
          case _PermissionKind.selectApps:
            await _pickIOSApps();
            break;
          default:
            break;
        }
      } catch (_) {}
      await _refreshStatus();
      _scheduleNextDialog();
      return;
    }

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
        case _PermissionKind.screenTime:
        case _PermissionKind.selectApps:
          break;
      }

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

  Future<void> _pickIOSApps() async {
    try {
      if (!_status.iosScreenTimeAuthorized) {
        final result =
            await _screenTimeService.requestScreenTimeAuthorization();
        if (!result.approved) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please authorize Apple Screen Time first to choose apps.'),
              ),
            );
          }
          return;
        }
      }
      await _screenTimeService.presentFamilyActivityPicker();
      final hasApps = await _screenTimeService.hasSelectedBlockedApps();
      if (mounted) {
        setState(() {
          _hasIOSSelectedApps = hasApps;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAndroidAppsAndFinish() async {
    try {
      await _screenTimeService
          .saveBlockedPackages(_selectedAndroidPackages.toList());
      final authState = ref.read(authNotifierProvider).valueOrNull;
      final user =
          authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
      if (user != null) {
        final memberships = effectiveStudentMemberships(user);
        if (memberships.isNotEmpty) {
          final workspaceId = memberships.first.workspaceId;
          try {
            await ref.read(screenTimeRepositoryProvider).updateSettings(
                  workspaceId: workspaceId,
                  blockedPackages: _selectedAndroidPackages.toList(),
                );
          } catch (_) {}
        }
      }
    } catch (_) {}
    await _finishOnboarding(force: true);
  }

  Future<void> _skipAppSelection() async {
    // Crucial: ensure zero apps are blocked when skipping
    if (Platform.isAndroid) {
      try {
        await _screenTimeService.saveBlockedPackages([]);
      } catch (_) {}
    }
    await _finishOnboarding(force: true);
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
      _PermissionKind.screenTime => _status.iosScreenTimeAuthorized,
      _PermissionKind.selectApps => _hasIOSSelectedApps,
    };
  }

  Future<void> _finishOnboarding({bool force = false}) async {
    if (_isSubmitting) return;
    await _refreshStatus();
    if (!mounted) return;
    if (!force && !_status.requiredPermissionsGranted) {
      _restartSequence();
      return;
    }

    var authState = ref.read(authNotifierProvider).valueOrNull;
    var user = authState?.maybeWhen(
      authenticated: (authenticatedUser) => authenticatedUser,
      orElse: () => null,
    );
    user ??= await ref.read(authRepositoryProvider).getStoredUser();

    if (user != null) {
      setState(() => _isSubmitting = true);
      try {
        await SessionPersistenceService.instance.setPermissionSetupComplete(
          user.id,
          complete: true,
        );
      } catch (_) {}
      try {
        final currentWallet = await _screenTimeService.loadWallet(user.id);
        if (currentWallet.availableMinutes == 0 && currentWallet.totalEarnedMinutes == 0) {
          await _screenTimeService.saveWallet(
            currentWallet.copyWith(
              availableMinutes: 30,
              totalEarnedMinutes: 30,
            ),
            user.id,
          );
        }
      } catch (_) {}
      unawaited(_reportPermissionStatus());
    }

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
    if (_currentStep == 1) {
      return _buildDistractionAppsStep();
    }
    return _buildPermissionsStep();
  }

  Widget _buildPermissionsStep() {
    final requiredReady = _status.requiredPermissionsGranted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('App permissions'),
        actions: [
          TextButton(
            onPressed:
                _isSubmitting ? null : () => setState(() => _currentStep = 1),
            child: const Text('Next'),
          ),
        ],
      ),
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
                    'Set up study protection',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    Platform.isIOS
                        ? 'Apple Screen Time keeps you focused by shielding selected social apps when study minutes run out.'
                        : 'Android will show its permission controls. Return to Social Studying after enabling each switch.',
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
                      Platform.isIOS
                          ? 'Screen Time permission is required for social app shielding.'
                          : 'Accessibility and Usage Access are required for automatic blocking.',
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
              child: Column(
                children: [
                  FilledButton.icon(
                    onPressed: _isChecking || _isSubmitting || _sequenceActive
                        ? null
                        : () => setState(() => _currentStep = 1),
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
                          ? (Platform.isIOS
                              ? 'Complete the prompt'
                              : 'Complete the Android prompt')
                          : 'Continue to Choose Apps',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _currentStep = 1),
                    child: const Text('Skip permissions and choose apps'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The dedicated "Choose Your Distraction Apps" screen requested by user
  Widget _buildDistractionAppsStep() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Permissions',
          onPressed: () => setState(() => _currentStep = 0),
        ),
        title: const Text(
          'Focus Setup',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _skipAppSelection,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Spacing.lg),
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'STEP 2 OF 2 • APP SHIELDING',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Choose Your Distraction Apps',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Earn social media time by completing study questions. Select which apps you want to pause when study time runs out.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: Spacing.xl),

                  // ── iOS Native Experience ───────────────────────────────────
                  if (Platform.isIOS) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _hasIOSSelectedApps
                              ? Colors.green.withValues(alpha: 0.4)
                              : Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                      color: _hasIOSSelectedApps
                          ? Colors.green.withValues(alpha: 0.05)
                          : Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _hasIOSSelectedApps
                                      ? Icons.check_circle_rounded
                                      : Icons.apps_rounded,
                                  color: _hasIOSSelectedApps
                                      ? Colors.green
                                      : AppColors.primary,
                                  size: 26,
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _hasIOSSelectedApps
                                            ? 'Distraction Apps Configured'
                                            : 'No Apps Shielded Yet',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _hasIOSSelectedApps
                                            ? 'Apple Screen Time will pause only your chosen apps when study time expires.'
                                            : 'Tap below to select Instagram, TikTok, YouTube, or categories.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_hasIOSSelectedApps) ...[
                              const SizedBox(height: Spacing.md),
                              OutlinedButton.icon(
                                onPressed: _pickIOSApps,
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                label: const Text('Change Selected Apps'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Container(
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 18, color: Color(0xFF3674FF)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Essential App Safety: Select specific distraction apps (e.g. Instagram, TikTok, YouTube). Do not select whole categories so alarms, home security, and system utilities stay active.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E3A8A),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Android Experience ─────────────────────────────────────
                  if (Platform.isAndroid || (!Platform.isIOS && !Platform.isAndroid)) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Select apps to pause:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedAndroidPackages.length ==
                                          _availableAndroidApps.length) {
                                        _selectedAndroidPackages.clear();
                                      } else {
                                        _selectedAndroidPackages =
                                            _availableAndroidApps.keys.toSet();
                                      }
                                    });
                                  },
                                  child: Text(
                                    _selectedAndroidPackages.length ==
                                            _availableAndroidApps.length
                                        ? 'Deselect All'
                                        : 'Select All',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 1),
                            ..._availableAndroidApps.entries.map((entry) {
                              final pkg = entry.key;
                              final (name, icon) = entry.value;
                              final isSelected =
                                  _selectedAndroidPackages.contains(pkg);
                              return CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                activeColor: AppColors.primary,
                                secondary: Icon(
                                  icon,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedAndroidPackages.add(pkg);
                                    } else {
                                      _selectedAndroidPackages.remove(pkg);
                                    }
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Primary & Crucial Secondary Buttons ─────────────────────────
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                children: [
                  // Primary Action Button
                  if (Platform.isIOS) ...[
                    if (!_hasIOSSelectedApps)
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _pickIOSApps,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        icon: const Icon(Icons.touch_app_rounded),
                        label: const Text(
                          'Choose Apps to Shield',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : () => _finishOnboarding(force: true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          'Continue to Study App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : (_selectedAndroidPackages.isNotEmpty
                              ? _saveAndroidAppsAndFinish
                              : () {
                                  // Pre-select top distraction apps if user clicks without checking
                                  setState(() {
                                    _selectedAndroidPackages.addAll([
                                      'com.instagram.android',
                                      'com.zhiliaoapp.musically',
                                      'com.google.android.youtube',
                                    ]);
                                  });
                                }),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      icon: const Icon(Icons.touch_app_rounded),
                      label: Text(
                        _selectedAndroidPackages.isNotEmpty
                            ? 'Save Shielded Apps (${_selectedAndroidPackages.length})'
                            : 'Choose Apps to Shield',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Crucial Secondary Button (Skip for Now / Set Up Later)
                  TextButton(
                    onPressed: _isSubmitting ? null : _skipAppSelection,
                    child: const Text(
                      'Skip for Now / Set Up Later',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zero apps are blocked if skipped. You can always configure apps in the Profile tab.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
  battery,
  screenTime,
  selectApps;

  bool get isRequired {
    if (Platform.isIOS) {
      return this == _PermissionKind.screenTime;
    }
    return this == _PermissionKind.accessibility ||
        this == _PermissionKind.usageAccess;
  }

  String get shortTitle => switch (this) {
        _PermissionKind.notifications => 'Notifications',
        _PermissionKind.accessibility => 'App blocking service',
        _PermissionKind.usageAccess => 'Usage Access',
        _PermissionKind.overlay => 'Display over apps',
        _PermissionKind.battery => 'Battery optimization',
        _PermissionKind.screenTime => 'Screen Time permission',
        _PermissionKind.selectApps => 'Select apps to shield',
      };

  String get title => switch (this) {
        _PermissionKind.notifications => 'Allow Social Studying notifications?',
        _PermissionKind.accessibility => 'Turn on app blocking?',
        _PermissionKind.usageAccess => 'Allow Usage Access?',
        _PermissionKind.overlay => 'Allow display over other apps?',
        _PermissionKind.battery => 'Keep app blocking responsive?',
        _PermissionKind.screenTime => 'Allow Screen Time access?',
        _PermissionKind.selectApps => 'Choose apps to shield',
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
        _PermissionKind.screenTime =>
          'Apple Screen Time allows Social Studying to securely shield social media apps when earned study minutes run out.',
        _PermissionKind.selectApps =>
          'Pick the social media apps, categories, or websites you want Social Studying to shield during study sessions.',
      };

  String get actionLabel => switch (this) {
        _PermissionKind.notifications => 'Allow',
        _PermissionKind.accessibility => 'Open Android settings',
        _PermissionKind.usageAccess => 'Open Android settings',
        _PermissionKind.overlay => 'Open Android settings',
        _PermissionKind.battery => 'Continue',
        _PermissionKind.screenTime => 'Allow',
        _PermissionKind.selectApps => 'Select apps',
      };

  IconData get icon => switch (this) {
        _PermissionKind.notifications => Icons.notifications_rounded,
        _PermissionKind.accessibility => Icons.accessibility_new_rounded,
        _PermissionKind.usageAccess => Icons.insights_rounded,
        _PermissionKind.overlay => Icons.layers_rounded,
        _PermissionKind.battery => Icons.battery_saver_rounded,
        _PermissionKind.screenTime => Icons.hourglass_top_rounded,
        _PermissionKind.selectApps => Icons.app_blocking_rounded,
      };
}
