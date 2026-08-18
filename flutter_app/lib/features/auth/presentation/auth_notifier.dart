import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/domain/auth_state.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';
import 'package:social_study_app/shared/services/session_persistence_service.dart';

part 'auth_notifier.g.dart';

final dailyLoginRewardProvider = StateProvider<int?>((ref) => null);

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  int _authGeneration = 0;

  @override
  Future<AuthState> build() async {
    final storedUser = await ref.read(authRepositoryProvider).getStoredUser();
    if (storedUser != null) {
      _refreshBackground();
      return AuthState.authenticated(user: storedUser);
    }
    return const AuthState.unauthenticated();
  }

  void _refreshBackground() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
      try {
        await refresh();
        final user = state.valueOrNull?.maybeWhen(
          authenticated: (value) => value,
          orElse: () => null,
        );
        if (user != null &&
            user.workspaceMemberships.any(
              (membership) =>
                  membership.workspaceId == 'wsp_self_${user.id}',
            )) {
          return;
        }
      } catch (_) {
        // The next bounded attempt retries with the cached session intact.
      }
    }
  }

  Future<void> signInWithMicrosoft() async {
    _authGeneration += 1;
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).signInWithMicrosoft();
      await SessionPersistenceService.instance.setPermissionSetupComplete(
        user.id,
        complete: true,
      );
      state = AsyncData(AuthState.authenticated(user: user));
      unawaited(_claimDailyLogin(user));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> signInWithGoogle() async {
    _authGeneration += 1;
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      await SessionPersistenceService.instance.setPermissionSetupComplete(
        user.id,
        complete: true,
      );
      state = AsyncData(AuthState.authenticated(user: user));
      unawaited(_claimDailyLogin(user));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> redeemInviteCode(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user =
          await ref.read(authRepositoryProvider).redeemInviteCode(code);
      return AuthState.authenticated(user: user);
    });
  }

  Future<void> signOut() async {
    _authGeneration += 1;
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> deleteAccount() async {
    _authGeneration += 1;
    final currentUser = state.valueOrNull?.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );
    if (currentUser == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).deleteAccount(currentUser.id);
      return const AuthState.unauthenticated();
    });
  }

  /// Re-fetch the stored User and update auth state.
  Future<void> refresh() async {
    final generation = _authGeneration;
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/users/me');
      if (generation != _authGeneration) return;

      final updatedUser = User.fromJson(response.data as Map<String, dynamic>);
      await ref.read(authRepositoryProvider).updateStoredUser(updatedUser);
      if (generation != _authGeneration) return;

      state = AsyncData(AuthState.authenticated(user: updatedUser));
      await _claimDailyLogin(updatedUser);
    } catch (_) {
      if (generation != _authGeneration) return;

      // A temporary network/provider failure preserves the installed account.
      final user = await ref.read(authRepositoryProvider).getStoredUser();
      if (generation != _authGeneration) return;
      if (user == null) {
        state = const AsyncData(AuthState.unauthenticated());
      } else {
        state = AsyncData(AuthState.authenticated(user: user));
      }
    }
  }

  Future<void> _claimDailyLogin(User user) async {
    for (final membership in user.workspaceMemberships) {
      try {
        final response =
            await ref.read(dioClientProvider).dio.post<Map<String, dynamic>>(
                  '/api/v1/workspaces/${membership.workspaceId}/users/me/gamification/daily-login',
                );
        final data = response.data;
        if (data?['awarded'] == true) {
          ref.read(dailyLoginRewardProvider.notifier).state =
              (data?['xp_earned'] as num?)?.toInt() ?? 2;
        }
      } catch (_) {
        // A later refresh safely retries; the backend claim is idempotent.
      }
    }
  }
}
