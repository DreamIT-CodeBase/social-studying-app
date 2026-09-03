import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/core/theme/app_colors.dart';
import 'package:social_study_app/features/screen_time/providers/screen_time_providers.dart';
import 'package:social_study_app/features/screen_time/models/student_device_status.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
import 'package:social_study_app/features/admin/moderation/presentation/moderation_screen.dart';
import 'package:social_study_app/features/admin/moderation/presentation/moderation_notifier.dart';
import 'package:social_study_app/features/screen_time/widgets/accessibility_disclosure_dialog.dart';

class ScreenTimeSettingsScreen extends ConsumerStatefulWidget {
  const ScreenTimeSettingsScreen({super.key});

  @override
  ConsumerState<ScreenTimeSettingsScreen> createState() =>
      _ScreenTimeSettingsScreenState();
}

class _ScreenTimeSettingsScreenState
    extends ConsumerState<ScreenTimeSettingsScreen>
    with WidgetsBindingObserver {
  bool _isAccessibilityEnabled = false;
  bool _isLoadingAccessibility = true;

  final Map<String, (String name, IconData icon)> _availableApps = {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccessibilityStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityStatus();
      // Also refresh the wallet in case minutes were consumed while app was in background
      ref.read(screenTimeNotifierProvider.notifier).refreshWallet();
    }
  }

  Future<void> _checkAccessibilityStatus() async {
    if (!Platform.isAndroid) {
      setState(() {
        _isAccessibilityEnabled = false;
        _isLoadingAccessibility = false;
      });
      return;
    }
    setState(() => _isLoadingAccessibility = true);
    final enabled = await ref
        .read(screenTimeNotifierProvider.notifier)
        .isAccessibilityServiceEnabled();
    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = enabled;
        _isLoadingAccessibility = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(screenTimeNotifierProvider);
    final ratioAsync = ref.watch(xpToMinuteRatioProvider);
    final enableBlockingAsync = ref.watch(enableBlockingProvider);
    final blockedPackagesAsync = ref.watch(blockedPackagesProvider);

    final isEditable = currentFlavor == AppFlavor.admin;
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    final AsyncValue<List<StudentDeviceStatus>>? deviceStatusesAsync =
        isEditable && workspaceId != null
            ? ref.watch(studentDeviceStatusesProvider(workspaceId))
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Screen Time Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: walletAsync.when(
        data: (wallet) {
          final ratio = ratioAsync.valueOrNull ?? 10;
          final enableBlocking = enableBlockingAsync.valueOrNull ?? true;
          final blockedPackages = blockedPackagesAsync.valueOrNull ?? [];

          return ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              _buildParentMessage(),
              const SizedBox(height: Spacing.lg),

              if (isEditable &&
                  workspaceId != null &&
                  deviceStatusesAsync != null) ...[
                _buildSectionTitle('Student Device Health'),
                const SizedBox(height: Spacing.sm),
                _buildDeviceHealthCard(
                  workspaceId,
                  deviceStatusesAsync,
                ),
                const SizedBox(height: Spacing.lg),
              ],
              if (Platform.isAndroid && currentFlavor == AppFlavor.student) ...[
                _buildAccessibilityStatusCard(),
                const SizedBox(height: Spacing.lg),
              ],
              _buildSectionTitle('App Blocking Controls'),
              const SizedBox(height: Spacing.sm),
              _buildBlockingControlCard(enableBlocking, isEditable),
              const SizedBox(height: Spacing.lg),
              if (enableBlocking) ...[
                _buildSectionTitle('Apps to Control'),
                const SizedBox(height: Spacing.sm),
                _buildAppSelectorCard(blockedPackages, isEditable),
                const SizedBox(height: Spacing.lg),
              ],
              _buildSectionTitle('Social Media Question Rules & Reoccurring Timeframe'),
              const SizedBox(height: Spacing.sm),
              _buildSocialQuestionsCard(isEditable),
              const SizedBox(height: Spacing.lg),
              if (isEditable && workspaceId != null) ...[
                _buildSectionTitle('Flagged Uploads & Content Controls'),
                const SizedBox(height: Spacing.sm),
                _buildFlaggedUploadsCard(workspaceId),
                const SizedBox(height: Spacing.lg),
              ],
              _buildSectionTitle('Rules & Conversion'),
              const SizedBox(height: Spacing.sm),
              _buildConversionCard(ratio, isEditable),
              const SizedBox(height: Spacing.lg),
              if (isEditable) ...[
                _buildResetCard(),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error loading settings: $err')),
      ),
    );
  }

  Widget _buildParentMessage() {
    return Card(
      elevation: 0,
      color: AppColors.primaryContainer.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primaryContainer),
      ),
      child: const Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            Icon(Icons.family_restroom_rounded,
                color: AppColors.primary, size: 28),
            SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Earn Digital Freedom',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Connect study progress directly with screen time. Study questions to unlock access to social media apps.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onPrimaryContainer,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: Spacing.xs),
      child: Text(
        title.toUpperCase(),
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: context.colorScheme.onSurface.withValues(alpha: 0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDeviceHealthCard(
    String workspaceId,
    AsyncValue<List<StudentDeviceStatus>> statusesAsync,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: statusesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: Spacing.md),
              Text('Checking student devices…'),
            ],
          ),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Device health unavailable',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Spacing.xs),
              Text('$error'),
              const SizedBox(height: Spacing.sm),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(studentDeviceStatusesProvider(workspaceId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (statuses) {
          if (statuses.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: Text(
                'No students are enrolled in this workspace yet.',
              ),
            );
          }

          final readyCount = statuses.where((status) => status.blockingReady).length;
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  readyCount == statuses.length
                      ? Icons.verified_user_rounded
                      : Icons.warning_amber_rounded,
                  color: readyCount == statuses.length
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text(
                  '$readyCount of ${statuses.length} devices ready',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Blocking requires Accessibility and Usage Access.',
                ),
                trailing: IconButton(
                  tooltip: 'Refresh device health',
                  onPressed: () =>
                      ref.invalidate(studentDeviceStatusesProvider(workspaceId)),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const Divider(height: 1),
              ...statuses.map(
                (status) => ListTile(
                  leading: Icon(
                    status.blockingReady
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: status.blockingReady ? Colors.green : Colors.red,
                  ),
                  title: Text(status.displayName),
                  subtitle: Text(
                    status.blockingReady
                        ? 'Blocking active • ${_formatLastReported(status.lastReportedAt)}'
                        : 'Permission action required • ${_formatLastReported(status.lastReportedAt)}',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatLastReported(DateTime? timestamp) {
    if (timestamp == null) return 'never reported';
    final local = timestamp.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return 'last checked ${local.month}/${local.day} ${local.hour}:$minute';
  }

  Future<bool> _runPolicyUpdate(Future<void> Function() update) async {
    try {
      await update();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update the student policy. Check your connection and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Widget _buildAccessibilityStatusCard() {
    final statusColor = _isAccessibilityEnabled ? Colors.green : Colors.orange;
    final statusText = _isAccessibilityEnabled ? 'Active' : 'Disabled';
    final statusIcon = _isAccessibilityEnabled
        ? Icons.check_circle
        : Icons.warning_amber_rounded;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Android App Blocking Service',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Status: $statusText',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isLoadingAccessibility)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            const Text(
              'To automatically block social media apps when screen time expires, you must enable the "Social Study App" in Android Accessibility settings.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                backgroundColor:
                    _isAccessibilityEnabled ? Colors.grey : AppColors.primary,
              ),
              onPressed: () {
                showAccessibilityProminentDisclosureDialog(
                  context,
                  onAccept: () {
                    ref
                        .read(screenTimeNotifierProvider.notifier)
                        .openAccessibilitySettings();
                  },
                );
              },
              icon: const Icon(Icons.settings_power_rounded),
              label: Text(_isAccessibilityEnabled
                  ? 'Configure Settings'
                  : 'Enable Service'),
            ),
            const SizedBox(height: Spacing.xs),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  showAccessibilityProminentDisclosureDialog(
                    context,
                    onAccept: () {
                      ref
                          .read(screenTimeNotifierProvider.notifier)
                          .openAccessibilitySettings();
                    },
                  );
                },
                icon: const Icon(Icons.info_outline_rounded, size: 16),
                label: const Text(
                  'View Prominent Disclosure & Privacy Policy',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockingControlCard(bool enableBlocking, bool isAdmin) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: const Text(
          'Enable App Blocking',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isAdmin
              ? 'Block targeted apps when screen time is exhausted'
              : 'App blocking is managed by your parent or university',
        ),
        value: enableBlocking,
        activeColor: AppColors.primary,
        onChanged: isAdmin
            ? (value) async {
                final updated = await _runPolicyUpdate(
                  () => ref
                      .read(screenTimeNotifierProvider.notifier)
                      .updateEnableBlocking(value),
                );
                if (updated) ref.invalidate(enableBlockingProvider);
              }
            : null,
      ),
    );
  }

  Widget _buildAppSelectorCard(List<String> blockedPackages, bool isAdmin) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: _availableApps.entries.map((entry) {
          final pkg = entry.key;
          final (name, icon) = entry.value;
          final isBlocked = blockedPackages.contains(pkg);

          return CheckboxListTile(
            title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            secondary:
                Icon(icon, color: isBlocked ? AppColors.primary : Colors.grey),
            value: isBlocked,
            activeColor: AppColors.primary,
            onChanged: isAdmin
                ? (bool? checked) async {
                    final newList = List<String>.from(blockedPackages);
                    if (checked == true) {
                      newList.add(pkg);
                    } else {
                      newList.remove(pkg);
                    }
                    final updated = await _runPolicyUpdate(
                      () => ref
                          .read(screenTimeNotifierProvider.notifier)
                          .updateBlockedPackages(newList),
                    );
                    if (updated) ref.invalidate(blockedPackagesProvider);
                  }
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConversionCard(int ratio, bool isAdmin) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'XP to Minutes Conversion',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Currently set to: $ratio XP = 1 Minute of screen time.\n(For example, 100 XP gives 10 minutes).',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.md),
            DropdownButtonFormField<int>(
              value: ratio,
              decoration: InputDecoration(
                labelText: 'Conversion Rate',
                filled: true,
                fillColor: context.colorScheme.surfaceContainer,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(
                    value: 5, child: Text('5 XP = 1 Minute (Generous)')),
                DropdownMenuItem(
                    value: 10, child: Text('10 XP = 1 Minute (Standard)')),
                DropdownMenuItem(
                    value: 20, child: Text('20 XP = 1 Minute (Moderate)')),
                DropdownMenuItem(
                    value: 50, child: Text('50 XP = 1 Minute (Strict)')),
              ],
              onChanged: isAdmin
                  ? (value) async {
                      if (value != null) {
                        final updated = await _runPolicyUpdate(
                          () => ref
                              .read(screenTimeNotifierProvider.notifier)
                              .updateXpToMinuteRatio(value),
                        );
                        if (updated) ref.invalidate(xpToMinuteRatioProvider);
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: const Text(
          'Reset Today\'s Screen Time Stats',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        subtitle: const Text(
            'Resets today\'s usage timer to 0 without affecting your earned balance.'),
        trailing: const Icon(Icons.refresh_rounded, color: Colors.orange),
        onTap: () async {
          await ref
              .read(screenTimeNotifierProvider.notifier)
              .resetConsumedToday();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Daily usage stats reset successfully.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSocialQuestionsCard(bool isAdmin) {
    final enableSocialAsync = ref.watch(enableSocialQuestionsProvider);
    final intervalAsync = ref.watch(recurringQuestionsIntervalProvider);
    final promptCountAsync = ref.watch(questionsPerPromptProvider);
    final targetSubjectAsync = ref.watch(socialQuestionsSubjectProvider);

    final enableSocial = enableSocialAsync.valueOrNull ?? true;
    final interval = intervalAsync.valueOrNull ?? 15;
    final promptCount = promptCountAsync.valueOrNull ?? 1;
    final targetSubject = targetSubjectAsync.valueOrNull;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Require Questions for Social Media',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isAdmin
                    ? 'Learner must answer study questions to open or continue using social media'
                    : 'Configured by parent to reinforce study habits',
              ),
              value: enableSocial,
              activeColor: AppColors.primary,
              onChanged: isAdmin
                  ? (value) async {
                      await ref
                          .read(screenTimeNotifierProvider.notifier)
                          .updateEnableSocialQuestions(value);
                    }
                  : null,
            ),
            if (enableSocial) ...[
              const Divider(height: 24),
              const Text(
                'Recurring Question Interval (Timeframe)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Frequency of recurring study questions while browsing social apps:',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.sm),
              DropdownButtonFormField<int>(
                value: interval,
                decoration: InputDecoration(
                  labelText: 'Recurring Interval',
                  filled: true,
                  fillColor: context.colorScheme.surfaceContainer,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('On App Launch Only')),
                  DropdownMenuItem(value: 15, child: Text('Every 15 Minutes (Recommended)')),
                  DropdownMenuItem(value: 30, child: Text('Every 30 Minutes')),
                  DropdownMenuItem(value: 45, child: Text('Every 45 Minutes')),
                  DropdownMenuItem(value: 60, child: Text('Every 1 Hour')),
                ],
                onChanged: isAdmin
                    ? (value) async {
                        if (value != null) {
                          await ref
                              .read(screenTimeNotifierProvider.notifier)
                              .updateRecurringQuestionsInterval(value);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: Spacing.md),
              const Text(
                'Questions per Recurring Prompt',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: Spacing.sm),
              DropdownButtonFormField<int>(
                value: promptCount,
                decoration: InputDecoration(
                  labelText: 'Question Count',
                  filled: true,
                  fillColor: context.colorScheme.surfaceContainer,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 Question (Quick Recall)')),
                  DropdownMenuItem(value: 2, child: Text('2 Questions (Balanced)')),
                  DropdownMenuItem(value: 3, child: Text('3 Questions (Deep Practice)')),
                ],
                onChanged: isAdmin
                    ? (value) async {
                        if (value != null) {
                          await ref
                              .read(screenTimeNotifierProvider.notifier)
                              .updateQuestionsPerPrompt(value);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: Spacing.md),
              const Text(
                'Target Study Subject Focus',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: Spacing.sm),
              DropdownButtonFormField<String?>(
                value: targetSubject,
                decoration: InputDecoration(
                  labelText: 'Subject Focus',
                  filled: true,
                  fillColor: context.colorScheme.surfaceContainer,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Subjects (Rotational)')),
                  DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry Focus 🧪')),
                  DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics Focus 📐')),
                  DropdownMenuItem(value: 'Physics', child: Text('Physics Focus ⚡')),
                  DropdownMenuItem(value: 'Biology', child: Text('Biology Focus 🧬')),
                ],
                onChanged: isAdmin
                    ? (value) async {
                        await ref
                            .read(screenTimeNotifierProvider.notifier)
                            .updateSocialQuestionsSubject(value);
                      }
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlaggedUploadsCard(String workspaceId) {
    final queueAsync = ref.watch(moderationQueueProvider(workspaceId));
    final flaggedCount = queueAsync.valueOrNull?.length ?? 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (flaggedCount > 0 ? Colors.orange : Colors.green)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  flaggedCount > 0
                      ? Icons.flag_rounded
                      : Icons.verified_user_rounded,
                  color: flaggedCount > 0 ? Colors.orange : Colors.green,
                  size: 22,
                ),
              ),
              title: Text(
                flaggedCount > 0
                    ? '$flaggedCount Flagged Upload(s) Awaiting Review'
                    : 'All Uploads Approved & Safe',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                flaggedCount > 0
                    ? 'Review study materials before questions are generated'
                    : 'AI content safety filter is active and protecting uploads',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ModerationScreen(workspaceId: workspaceId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
