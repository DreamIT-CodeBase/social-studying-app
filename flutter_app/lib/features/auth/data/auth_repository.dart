import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

  @override
  Future<User> signIn() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    await _storage.write(key: _loggedInKey, value: 'true');
    return _demoUser;
  }

  @override
  Future<void> signOut() async {
    await _storage.delete(key: _loggedInKey);
  }

  @override
  Future<User?> getStoredUser() async {
    final value = await _storage.read(key: _loggedInKey);
    return value == 'true' ? _demoUser : null;
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
