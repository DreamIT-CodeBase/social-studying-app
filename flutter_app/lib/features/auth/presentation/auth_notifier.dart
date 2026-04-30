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
}
