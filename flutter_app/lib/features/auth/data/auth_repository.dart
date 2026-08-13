import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/auth_session_service.dart';
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
  static const _userKey = AuthSessionService.userKey;
  final _appAuth = const FlutterAppAuth();

  @override
  Future<User> signInWithMicrosoft() async {
    try {
      const discoveryUrl =
          'https://${Environment.b2cTenantSubdomain}.ciamlogin.com/'
          '${Environment.b2cTenantId}/v2.0/.well-known/openid-configuration';

      debugPrint(
        'Microsoft sign-in: opening Entra with redirect URI '
        '${Environment.b2cRedirectUri}',
      );
      final result = await _appAuth
          .authorizeAndExchangeCode(
            AuthorizationTokenRequest(
              Environment.b2cClientId,
              Environment.b2cRedirectUri,
              discoveryUrl: discoveryUrl,
              promptValues: ['login'],
              // A custom iOS URI callback cannot receive a browser form POST.
              // Require Entra to return the authorization code in the callback
              // URL so AppAuth can resume the authorization flow.
              responseMode: 'query',
              // On iOS, use AppAuth's dedicated authentication-session
              // implementation. It completes inside ASWebAuthenticationSession
              // rather than relying on a UIApplication/UIScene URL callback.
              externalUserAgent:
                  ExternalUserAgent.ephemeralAsWebAuthenticationSession,
              scopes: [
                'openid',
                'profile',
                'offline_access',
                'api://${Environment.b2cClientId}/access_as_user',
              ],
            ),
          )
          .timeout(
            const Duration(seconds: 75),
            onTimeout: () => throw TimeoutException(
              'Microsoft sign-in did not finish after returning from Safari. '
              'Check the Entra iOS redirect URI and the device connection.',
            ),
          );

      if (result.idToken == null) {
        throw Exception('Authentication returned empty result');
      }

      debugPrint('Microsoft sign-in: Entra returned tokens.');
      await AuthSessionService.instance.persistMicrosoftSession(result);
      debugPrint('Microsoft sign-in: session saved; loading account.');

      // Fetch the real user profile from the backend
      final dio = _ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/users/me');
      final backendUser = User.fromJson(response.data as Map<String, dynamic>);

      await AuthSessionService.instance
          .writeUser(jsonEncode(backendUser.toJson()));
      debugPrint('Microsoft sign-in: account loaded.');

      return backendUser;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    try {
      final idToken =
          await AuthSessionService.instance.authenticateWithGoogle();

      await AuthSessionService.instance.persistGoogleSession(idToken);

      // Fetch the real user profile from the backend
      final dio = _ref.read(dioClientProvider).dio;
      final response = await dio.get('/api/v1/users/me');
      final backendUser = User.fromJson(response.data as Map<String, dynamic>);

      await AuthSessionService.instance
          .writeUser(jsonEncode(backendUser.toJson()));

      return backendUser;
    } catch (e) {
      throw Exception('Google Sign in failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await AuthSessionService.instance.clear();
  }

  @override
  Future<User?> getStoredUser() async {
    final values = await AuthSessionService.instance.loadStoredValues();
    final token = values[AuthSessionService.tokenKey];
    final userJson = values[_userKey];
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
    await AuthSessionService.instance.writeUser(jsonEncode(user.toJson()));
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
}
