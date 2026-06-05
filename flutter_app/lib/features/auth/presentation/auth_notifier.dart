import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/features/auth/domain/auth_state.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthState> build() async {
    final storedUser = await ref.read(authRepositoryProvider).getStoredUser();
    if (storedUser != null) {
      return AuthState.authenticated(user: storedUser);
    }
    return const AuthState.unauthenticated();
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).signIn();
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
      final user = await ref.read(authRepositoryProvider).getStoredUser();
      if (user == null) {
        state = const AsyncData(AuthState.unauthenticated());
      } else {
        state = AsyncData(AuthState.authenticated(user: user));
      }
    } catch (_) {
      // Swallow — refresh is a hint, not a contract.
    }
  }
}
