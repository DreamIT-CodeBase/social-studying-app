import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/user.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<User> signIn();
  Future<void> signOut();
  Future<User?> getStoredUser();
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) => _MockAuthRepository();

// Mock implementation — replace with MSAL B2C SDK in Sprint 1 task 1.11
class _MockAuthRepository implements AuthRepository {
  static const _storage = FlutterSecureStorage();
  static const _loggedInKey = 'demo_user_logged_in';

  // Key the Dio auth interceptor reads (see shared/services/dio_client.dart).
  // In a real-backend build we stash the dev-auth sentinel here on sign-in so
  // every request carries it; the backend resolves it to the seeded demo user.
  static const _tokenKey = 'auth_token';

  @override
  Future<User> signIn() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    await _storage.write(key: _loggedInKey, value: 'true');
    if (Environment.useRealBackend) {
      await _storage.write(key: _tokenKey, value: Environment.devAuthToken);
    }
    return _demoUser;
  }

  @override
  Future<void> signOut() async {
    await _storage.delete(key: _loggedInKey);
    await _storage.delete(key: _tokenKey);
  }

  @override
  Future<User?> getStoredUser() async {
    final value = await _storage.read(key: _loggedInKey);
    if (value != 'true') return null;
    // Self-heal the bearer token on resume: a session persisted by a demo
    // build (or before this flag existed) won't have written one, which
    // would 401 every real-backend call until the next sign-in.
    if (Environment.useRealBackend) {
      await _storage.write(key: _tokenKey, value: Environment.devAuthToken);
    }
    return _demoUser;
  }

  static final _demoUser = User(
    id: 'usr_demo_001',
    email: 'demo@socialstudyapp.com',
    displayName: 'Alex Rivera',
    tenantId: 'ten_demo_001',
    role: UserRole.tenantAdmin,
    workspaceMemberships: [
      const WorkspaceMembership(
        workspaceId: 'wsp_demo_001',
        workspaceName: 'Demo Classroom',
        role: UserRole.workspaceAdmin,
      ),
    ],
    createdAt: DateTime(2026, 4, 30),
    lastLogin: DateTime.now(),
  );
}
