import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<User> signInWithMicrosoft();
  Future<User> signInWithGoogle();
  Future<void> signOut();
  Future<User?> getStoredUser();
  Future<void> updateStoredUser(User user);
  Future<User> redeemInviteCode(String code);
  Future<void> deleteAccount(String userId);
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) => RealAuthRepository(ref);

class RealAuthRepository implements AuthRepository {
  RealAuthRepository(this._ref);

  final AuthRepositoryRef _ref;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  final _appAuth = const FlutterAppAuth();
  final _googleSignIn = GoogleSignIn(
    serverClientId: Environment.googleWebClientId,
    scopes: ['email', 'profile'],
  );

  @override
  Future<User> signInWithMicrosoft() async {
    try {
      final discoveryUrl = 'https://${Environment.b2cTenantSubdomain}.ciamlogin.com/'
          '${Environment.b2cTenantId}/v2.0/.well-known/openid-configuration';

      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          Environment.b2cClientId,
          Environment.b2cRedirectUri,
          discoveryUrl: discoveryUrl,
          promptValues: ['login'],
          scopes: [
            'openid',
            'profile',
            'offline_access',
            'api://${Environment.b2cClientId}/access_as_user',
          ],
        ),
      );

      if (result == null || result.idToken == null) {
        throw Exception('Authentication returned empty result');
      }

      await _storage.write(key: _tokenKey, value: result.idToken);

      // Fetch the real user profile from the backend
      final dio = _ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/users/me');
      final backendUser = User.fromJson(response.data as Map<String, dynamic>);
      
      await _storage.write(key: _userKey, value: jsonEncode(backendUser.toJson()));

      return backendUser;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in cancelled by user');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google sign in failed: no ID token returned');
      }

      await _storage.write(key: _tokenKey, value: idToken);

      // Fetch the real user profile from the backend
      final dio = _ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/users/me');
      final backendUser = User.fromJson(response.data as Map<String, dynamic>);
      
      await _storage.write(key: _userKey, value: jsonEncode(backendUser.toJson()));

      return backendUser;
    } catch (e) {
      throw Exception('Google Sign in failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  @override
  Future<User?> getStoredUser() async {
    final token = await _storage.read(key: _tokenKey);
    final userJson = await _storage.read(key: _userKey);
    if (token == null || userJson == null) {
      return null;
    }
    try {
      return User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateStoredUser(User user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  @override
  Future<User> redeemInviteCode(String code) async {
    try {
      final dio = _ref.read(dioClientProvider).dio;
      final response = await dio.post(
        '/api/v1/users/join',
        data: {'code': code},
      );
      final updatedUser = User.fromJson(response.data as Map<String, dynamic>);
      await updateStoredUser(updatedUser);
      return updatedUser;
    } catch (e) {
      throw Exception('Redeem invite code failed: $e');
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    try {
      final dio = _ref.read(dioClientProvider).dio;
      await dio.delete('/api/v1/users/$userId');
      await signOut();
    } catch (e) {
      throw Exception('Delete account failed: $e');
    }
  }

  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid token');
    }
    final payload = parts[1];
    var normalized = base64Url.normalize(payload);
    final resp = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(resp) as Map<String, dynamic>;
  }
}
