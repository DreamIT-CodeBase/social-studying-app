import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/features/auth/presentation/auth_notifier.dart';
import 'package:social_study_app/features/home/providers/workspace_providers.dart';
import 'package:social_study_app/features/gamification/presentation/gamification_notifier.dart';
import 'package:social_study_app/shared/models/gamification.dart';
import 'package:social_study_app/features/screen_time/models/screen_time_wallet.dart';
import 'package:social_study_app/features/screen_time/services/screen_time_service.dart';
import 'package:social_study_app/features/screen_time/data/screen_time_repository.dart';

part 'screen_time_providers.g.dart';

@Riverpod(keepAlive: true)
class ScreenTimeNotifier extends _$ScreenTimeNotifier {
  late final ScreenTimeService _service = ScreenTimeService();

  @override
  Future<ScreenTimeWallet> build() async {
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null || user.workspaceMemberships.isEmpty) {
      await _service.setCurrentUserId(null);
      return ScreenTimeWallet.initial();
    }

    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId == null) {
      await _service.setCurrentUserId(null);
      return ScreenTimeWallet.initial();
    }
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

    return _syncWalletAndSettings(user.id, workspaceId);
  }

  Future<ScreenTimeWallet> _syncWalletAndSettings(String userId, String workspaceId) async {
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
    final syncedConsumed = prefs.getInt('synced_consumed_minutes_$userId') ?? localWallet.consumedMinutes;
    final deltaMinutes = localWallet.consumedMinutes - syncedConsumed;

    ScreenTimeWallet serverWallet;
    try {
      if (deltaMinutes > 0) {
        // Sync local background consumption to server
        serverWallet = await repo.consumeMinutes(workspaceId: workspaceId, minutes: deltaMinutes);
      } else {
        // Just fetch latest wallet from server
        serverWallet = await repo.fetchWallet(workspaceId: workspaceId);
      }

      // Update local wallet with server response
      await _service.saveWallet(serverWallet, userId);
      await prefs.setInt('synced_consumed_minutes_$userId', serverWallet.consumedMinutes);
      return serverWallet;
    } catch (e) {
      // Offline / fallback: use local wallet
      return localWallet;
    }
  }

  Future<void> refreshWallet() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await _syncWalletAndSettings(user.id, workspaceId);
    });
  }

  Future<void> syncXp() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null) return;
    final currentWallet = state.valueOrNull;

    try {
      final serverWallet = await ref.read(screenTimeRepositoryProvider).syncXp(workspaceId: workspaceId);

      if (currentWallet != null) {
        final deltaMinutes = serverWallet.availableMinutes - currentWallet.availableMinutes;
        if (deltaMinutes > 0) {
          await _service.showNotification(deltaMinutes);
        }
      }

      await _service.saveWallet(serverWallet, user.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('synced_consumed_minutes_${user.id}', serverWallet.consumedMinutes);

      state = AsyncData(serverWallet);
    } catch (e) {
      // Offline: keep local state
    }
  }

  Future<void> updateXpToMinuteRatio(int ratio) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null) return;

    try {
      final updatedSettings = await ref.read(screenTimeRepositoryProvider).updateSettings(
        workspaceId: workspaceId,
        xpToMinuteRatio: ratio,
      );
      await _service.saveXpToMinuteRatio(updatedSettings.xpToMinuteRatio);

      // Auto-trigger sync-xp on the backend to adjust based on the new ratio
      await syncXp();
    } catch (e) {
      // Fallback to local update if offline
      await _service.saveXpToMinuteRatio(ratio);
    }
  }

  Future<void> updateEnableBlocking(bool enable) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null) return;

    try {
      final updatedSettings = await ref.read(screenTimeRepositoryProvider).updateSettings(
        workspaceId: workspaceId,
        enableBlocking: enable,
      );
      await _service.saveEnableBlocking(updatedSettings.enableBlocking);
    } catch (e) {
      await _service.saveEnableBlocking(enable);
    }
  }

  Future<void> updateBlockedPackages(List<String> packages) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null) return;

    try {
      final updatedSettings = await ref.read(screenTimeRepositoryProvider).updateSettings(
        workspaceId: workspaceId,
        blockedPackages: packages,
      );
      await _service.saveBlockedPackages(updatedSettings.blockedPackages);
    } catch (e) {
      await _service.saveBlockedPackages(packages);
    }
  }

  Future<void> consumeMinutes(int minutes) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
    if (user == null) return;

    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null) return;

    try {
      final serverWallet = await ref.read(screenTimeRepositoryProvider).consumeMinutes(
        workspaceId: workspaceId,
        minutes: minutes,
      );
      await _service.saveWallet(serverWallet, user.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('synced_consumed_minutes_${user.id}', serverWallet.consumedMinutes);

      state = AsyncData(serverWallet);
    } catch (e) {
      // Local fallback
      final currentWallet = state.valueOrNull;
      if (currentWallet != null) {
        final updated = currentWallet.copyWith(
          availableMinutes: (currentWallet.availableMinutes - minutes).clamp(0, double.maxFinite.toInt()),
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
    final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);

    final updated = currentWallet.copyWith(
      consumedToday: 0,
      lastSyncTime: DateTime.now(),
    );

    await _service.saveWallet(updated, user?.id);
    state = AsyncData(updated);
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    return _service.isAccessibilityServiceEnabled();
  }

  Future<void> openAccessibilitySettings() async {
    await _service.openAccessibilitySettings();
  }
}

// Helpers to expose settings as simpler read/write providers
@riverpod
Future<int> xpToMinuteRatio(XpToMinuteRatioRef ref) async {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
  if (user != null) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId != null) {
      try {
        final settings = await ref.watch(screenTimeRepositoryProvider).fetchSettings(workspaceId: workspaceId);
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
  final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
  if (user != null) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId != null) {
      try {
        final settings = await ref.watch(screenTimeRepositoryProvider).fetchSettings(workspaceId: workspaceId);
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
  final user = authState?.maybeWhen(authenticated: (u) => u, orElse: () => null);
  if (user != null) {
    final workspaceId = ref.watch(activeWorkspaceIdProvider);
    if (workspaceId != null) {
      try {
        final settings = await ref.watch(screenTimeRepositoryProvider).fetchSettings(workspaceId: workspaceId);
        return settings.blockedPackages;
      } catch (_) {
        // fallback
      }
    }
  }
  return ScreenTimeService().getBlockedPackages();
}
