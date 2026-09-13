import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/shared/models/gamification.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';
import 'package:social_study_app/features/screen_time/services/screen_time_service.dart';
import 'package:social_study_app/features/screen_time/data/screen_time_repository.dart';
import 'package:social_study_app/features/screen_time/models/student_device_status.dart';

part 'screen_time_providers.g.dart';

final studentDeviceStatusesProvider = FutureProvider.autoDispose
    .family<List<StudentDeviceStatus>, String>((ref, workspaceId) {
  return ref
      .watch(screenTimeRepositoryProvider)
      .fetchDeviceStatuses(workspaceId: workspaceId);
});

@Riverpod(keepAlive: true)
class ScreenTimeNotifier extends _$ScreenTimeNotifier {
  late final ScreenTimeService _service = ScreenTimeService();

  // ── Notification throttle ─────────────────────────────────────────────────
  // Only fire a notification once per 5 minutes, accumulating earned minutes
  // across multiple syncXp() calls so the user doesn't get one every minute.
  static const Duration _notifCooldown = Duration(minutes: 5);
  DateTime? _lastNotificationTime;
  int _pendingNotifMinutes = 0;

  @override
  Future<ScreenTimeWallet> build() async {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    final memberships = effectiveStudentMemberships(user);
    if (user == null || memberships.isEmpty) {
      await _service.setCurrentUserId(null);
      return ScreenTimeWallet.initial();
    }

    final workspaceId =
        ref.watch(activeWorkspaceIdProvider) ?? memberships.first.workspaceId;
    final key = (workspaceId: workspaceId, userId: user.id);

    await _service.setCurrentUserId(user.id);

    // Listen to gamification profile updates to trigger auto-sync
    ref.listen<AsyncValue<GamificationProfile>>(
      gamificationProfileProvider(key),
      (prev, next) {
        final profile = next.valueOrNull;
        if (profile != null) {
          syncXp();
        }
      },
    );

    final wallet = await _syncWalletAndSettings(user.id, workspaceId);
    await _service.setEnforcementReady(true);

    // iOS: start a periodic timer to keep shields active even while the
    // main app is running in the foreground.
    if (Platform.isIOS) {
      _startPeriodicShieldSync();
    }

    return wallet;
  }

  Timer? _shieldSyncTimer;

  void _startPeriodicShieldSync() {
    _shieldSyncTimer?.cancel();
    // Sync every 60 seconds so the used-time meter updates minute-by-minute.
    _shieldSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      _service.reapplyShields();
      // Re-read wallet from native side to pick up consumption changes
      // made by the DeviceActivity extension in the background.
      await _refreshWalletFromNative();
    });
    ref.onDispose(() => _shieldSyncTimer?.cancel());
  }

  /// Reads the latest wallet from native iOS (shared UserDefaults) and
  /// updates the Flutter state so the used-time meter reflects actual usage.
  Future<void> _refreshWalletFromNative() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;
    try {
      final wallet = await _service.loadWallet(user.id);
      final current = state.valueOrNull;
      // Only update if consumption actually changed to avoid unnecessary rebuilds
      if (current == null ||
          current.availableMinutes != wallet.availableMinutes ||
          current.consumedToday != wallet.consumedToday) {
        state = AsyncData(wallet);
      }
    } catch (_) {
      // Swallowed: best effort refresh
    }
  }

  Future<ScreenTimeWallet> _syncWalletAndSettings(
      String userId, String workspaceId) async {
    final repo = ref.read(screenTimeRepositoryProvider);

    // 1. Sync Settings from Backend to local SharedPreferences
    try {
      final settings = await repo.fetchSettings(workspaceId: workspaceId);
      await _service.saveEnableBlocking(settings.enableBlocking);
      await _service.saveBlockedPackages(settings.blockedPackages);
      await _service.saveXpToMinuteRatio(settings.xpToMinuteRatio);
    } catch (e) {
      // Swallowed: offline / fallback to local prefs
    }

    // 2. Read local wallet (might contain background changes from Accessibility service)
    final localWallet = await _service.loadWallet(userId);

    // Calculate local consumption delta
    final prefs = await SharedPreferences.getInstance();
    final syncedConsumed = prefs.getInt('synced_consumed_minutes_$userId') ??
        localWallet.consumedMinutes;
    final deltaMinutes = localWallet.consumedMinutes - syncedConsumed;

    ScreenTimeWallet serverWallet;
    try {
      if (deltaMinutes > 0) {
        // Sync local background consumption to server
        serverWallet = await repo.consumeMinutes(
            workspaceId: workspaceId, minutes: deltaMinutes);
      } else {
        // Just fetch latest wallet from server
        serverWallet = await repo.fetchWallet(workspaceId: workspaceId);
      }

      // Update local wallet with server response
      await _service.saveWallet(serverWallet, userId);
      await prefs.setInt(
          'synced_consumed_minutes_$userId', serverWallet.consumedMinutes);
      return serverWallet;
    } catch (e) {
      // Offline / fallback: use local wallet
      return localWallet;
    }
  }

  Future<void> refreshWallet() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final memberships = effectiveStudentMemberships(user);
    if (memberships.isEmpty) return;
    final workspaceId =
        ref.read(activeWorkspaceIdProvider) ?? memberships.first.workspaceId;

    state = await AsyncValue.guard(() async {
      final wallet = await _syncWalletAndSettings(user.id, workspaceId);
      await _service.setEnforcementReady(true);
      return wallet;
    });
  }

  Future<void> syncXp() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final memberships = effectiveStudentMemberships(user);
    if (memberships.isEmpty) return;
    final workspaceId =
        ref.read(activeWorkspaceIdProvider) ?? memberships.first.workspaceId;
    final currentWallet = state.valueOrNull;

    try {
      final serverWallet = await ref
          .read(screenTimeRepositoryProvider)
          .syncXp(workspaceId: workspaceId);

      if (currentWallet != null) {
        final deltaMinutes =
            serverWallet.availableMinutes - currentWallet.availableMinutes;
        if (deltaMinutes > 0) {
          _pendingNotifMinutes += deltaMinutes;
          final now = DateTime.now();
          final lastNotif = _lastNotificationTime;
          // Only fire if accumulated minutes is at least 30, and cooldown has passed
          if (_pendingNotifMinutes >= 30 &&
              (lastNotif == null ||
                  now.difference(lastNotif) >= _notifCooldown)) {
            await _service.showNotification(_pendingNotifMinutes);
            _lastNotificationTime = now;
            _pendingNotifMinutes = 0;
          }
          // else: silently accumulate — will fire once the threshold and cooldown are met
        }
      }

      await _service.saveWallet(serverWallet, user.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'synced_consumed_minutes_${user.id}', serverWallet.consumedMinutes);

      state = AsyncData(serverWallet);
    } catch (e) {
      // Offline: keep local state
    }
  }

  Future<void> updateXpToMinuteRatio(int ratio) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final memberships = effectiveStudentMemberships(user);
    if (memberships.isEmpty) return;
    final workspaceId =
        ref.read(activeWorkspaceIdProvider) ?? memberships.first.workspaceId;

    try {
      final updatedSettings =
          await ref.read(screenTimeRepositoryProvider).updateSettings(
                workspaceId: workspaceId,
                xpToMinuteRatio: ratio,
              );
      await _service.saveXpToMinuteRatio(updatedSettings.xpToMinuteRatio);

      // Auto-trigger sync-xp on the backend to adjust based on the new ratio
      await syncXp();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updateEnableBlocking(bool enable) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final memberships = effectiveStudentMemberships(user);
    if (memberships.isEmpty) return;
    final workspaceId =
        ref.read(activeWorkspaceIdProvider) ?? memberships.first.workspaceId;

    try {
      final updatedSettings =
          await ref.read(screenTimeRepositoryProvider).updateSettings(
                workspaceId: workspaceId,
                enableBlocking: enable,
              );
      await _service.saveEnableBlocking(updatedSettings.enableBlocking);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updateBlockedPackages(List<String> packages) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final memberships = effectiveStudentMemberships(user);
    if (memberships.isEmpty) return;
    final workspaceId =
        ref.read(activeWorkspaceIdProvider) ?? memberships.first.workspaceId;

    try {
      final updatedSettings =
          await ref.read(screenTimeRepositoryProvider).updateSettings(
                workspaceId: workspaceId,
                blockedPackages: packages,
              );
      await _service.saveBlockedPackages(updatedSettings.blockedPackages);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> consumeMinutes(int minutes) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final memberships = effectiveStudentMemberships(user);
    if (memberships.isEmpty) return;
    final workspaceId =
        ref.read(activeWorkspaceIdProvider) ?? memberships.first.workspaceId;

    try {
      final serverWallet =
          await ref.read(screenTimeRepositoryProvider).consumeMinutes(
                workspaceId: workspaceId,
                minutes: minutes,
              );
      await _service.saveWallet(serverWallet, user.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'synced_consumed_minutes_${user.id}', serverWallet.consumedMinutes);

      state = AsyncData(serverWallet);
    } catch (e) {
      // Local fallback
      final currentWallet = state.valueOrNull;
      if (currentWallet != null) {
        final updated = currentWallet.copyWith(
          availableMinutes: (currentWallet.availableMinutes - minutes)
              .clamp(0, double.maxFinite.toInt()),
          consumedMinutes: currentWallet.consumedMinutes + minutes,
          consumedToday: currentWallet.consumedToday + minutes,
          lastSyncTime: DateTime.now(),
        );
        await _service.saveWallet(updated, user.id);
        state = AsyncData(updated);
      }
    }
  }

  Future<void> resetConsumedToday() async {
    final currentWallet = state.valueOrNull;
    if (currentWallet == null) return;

    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);

    final updated = currentWallet.copyWith(
      consumedToday: 0,
      lastSyncTime: DateTime.now(),
    );

    await _service.saveWallet(updated, user?.id);
    state = AsyncData(updated);
  }

  /// Sets available screen time to 0 minutes and immediately reapplies shields so testers can verify blocking.
  Future<void> simulateZeroMinutesForTesting() async {
    final currentWallet = state.valueOrNull;
    if (currentWallet == null) return;
    final available = currentWallet.availableMinutes;
    if (available > 0) {
      await consumeMinutes(available);
    }
    await reapplyShields();
  }

  /// Grants test minutes so testers can quickly verify unblocking.
  Future<void> addTestMinutes(int minutes) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user =
        authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    final currentWallet = state.valueOrNull;
    if (currentWallet != null) {
      final updated = currentWallet.copyWith(
        availableMinutes: currentWallet.availableMinutes + minutes,
        lastSyncTime: DateTime.now(),
      );
      await _service.saveWallet(updated, user?.id);
      state = AsyncData(updated);
      await reapplyShields();
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    return _service.isAccessibilityServiceEnabled();
  }

  Future<void> openAccessibilitySettings() async {
    await _service.openAccessibilitySettings();
  }

  Future<bool> isScreenTimeAuthorized() async {
    return _service.isScreenTimeAuthorized();
  }

  Future<bool> requestScreenTimeAuthorization() async {
    final result = await _service.requestScreenTimeAuthorization();
    return result.approved;
  }

  Future<bool> presentFamilyActivityPicker() async {
    final result = await _service.presentFamilyActivityPicker();
    await refreshWallet();
    return result;
  }

  Future<bool> hasSelectedBlockedApps() async {
    return _service.hasSelectedBlockedApps();
  }

  Future<void> reapplyShields() async {
    await _service.reapplyShields();
  }

  Future<void> updateEnableSocialQuestions(bool enable) async {
    await _service.saveEnableSocialQuestions(enable);
    ref.invalidate(enableSocialQuestionsProvider);
  }

  Future<void> updateRecurringQuestionsInterval(int minutes) async {
    await _service.saveRecurringQuestionsInterval(minutes);
    ref.invalidate(recurringQuestionsIntervalProvider);
  }

  Future<void> updateQuestionsPerPrompt(int count) async {
    await _service.saveQuestionsPerPrompt(count);
    ref.invalidate(questionsPerPromptProvider);
  }

  Future<void> updateSocialQuestionsSubject(String? subject) async {
    await _service.saveSocialQuestionsSubject(subject);
    ref.invalidate(socialQuestionsSubjectProvider);
  }
}

// Helpers to expose settings as simpler read/write providers
@riverpod
Future<int> xpToMinuteRatio(XpToMinuteRatioRef ref) async {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  final user =
      authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
  if (user != null) {
    final memberships = effectiveStudentMemberships(user);
    final workspaceId = ref.watch(activeWorkspaceIdProvider) ??
        (memberships.isNotEmpty ? memberships.first.workspaceId : null);
    if (workspaceId != null) {
      try {
        final settings = await ref
            .watch(screenTimeRepositoryProvider)
            .fetchSettings(workspaceId: workspaceId);
        return settings.xpToMinuteRatio;
      } catch (_) {
        // fallback
      }
    }
  }
  return ScreenTimeService().getXpToMinuteRatio();
}

@riverpod
Future<bool> enableBlocking(EnableBlockingRef ref) async {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  final user =
      authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
  if (user != null) {
    final memberships = effectiveStudentMemberships(user);
    final workspaceId = ref.watch(activeWorkspaceIdProvider) ??
        (memberships.isNotEmpty ? memberships.first.workspaceId : null);
    if (workspaceId != null) {
      try {
        final settings = await ref
            .watch(screenTimeRepositoryProvider)
            .fetchSettings(workspaceId: workspaceId);
        return settings.enableBlocking;
      } catch (_) {
        // fallback
      }
    }
  }
  return ScreenTimeService().getEnableBlocking();
}

@riverpod
Future<List<String>> blockedPackages(BlockedPackagesRef ref) async {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  final user =
      authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
  if (user != null) {
    final memberships = effectiveStudentMemberships(user);
    final workspaceId = ref.watch(activeWorkspaceIdProvider) ??
        (memberships.isNotEmpty ? memberships.first.workspaceId : null);
    if (workspaceId != null) {
      try {
        final settings = await ref
            .watch(screenTimeRepositoryProvider)
            .fetchSettings(workspaceId: workspaceId);
        return settings.blockedPackages;
      } catch (_) {
        // fallback
      }
    }
  }
  return ScreenTimeService().getBlockedPackages();
}

final enableSocialQuestionsProvider = FutureProvider<bool>((ref) async {
  return ScreenTimeService().getEnableSocialQuestions();
});

final recurringQuestionsIntervalProvider = FutureProvider<int>((ref) async {
  return ScreenTimeService().getRecurringQuestionsInterval();
});

final questionsPerPromptProvider = FutureProvider<int>((ref) async {
  return ScreenTimeService().getQuestionsPerPrompt();
});

final socialQuestionsSubjectProvider = FutureProvider<String?>((ref) async {
  return ScreenTimeService().getSocialQuestionsSubject();
});
