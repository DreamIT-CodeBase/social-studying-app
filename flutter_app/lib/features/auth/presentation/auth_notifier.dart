import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/domain/auth_state.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
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
    try {
      await refresh();
    } catch (_) {}
  }

  Future<void> signInWithMicrosoft() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).signInWithMicrosoft();
      return AuthState.authenticated(user: user);
    });
  }

  Future<void> redeemInviteCode(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).redeemInviteCode(code);
      return AuthState.authenticated(user: user);
    });
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> deleteAccount() async {
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
    try {
      final dio = ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/users/me');
      final updatedUser = User.fromJson(response.data as Map<String, dynamic>);
      
      await ref.read(authRepositoryProvider).updateStoredUser(updatedUser);
      state = AsyncData(AuthState.authenticated(user: updatedUser));
    } catch (_) {
      // Fallback to local storage if network fails
      final user = await ref.read(authRepositoryProvider).getStoredUser();
      if (user == null) {
        state = const AsyncData(AuthState.unauthenticated());
      } else {
        state = AsyncData(AuthState.authenticated(user: user));
      }
    }
  }
}
