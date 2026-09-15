import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const _nativeEntraChannel =
      MethodChannel('com.socialstudyapp.app/entra_auth');
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
      final AuthorizationTokenResponse result;
      if (!kIsWeb && Platform.isIOS) {
        result = await _signInWithMicrosoftIos();
      } else {
        result = await _appAuth
            .authorizeAndExchangeCode(
              AuthorizationTokenRequest(
                Environment.b2cClientId,
                Environment.b2cRedirectUri,
                discoveryUrl: discoveryUrl,
                promptValues: ['login'],
                responseMode: 'query',
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
                'Microsoft sign-in did not finish after returning from the browser.',
              ),
            );
      }

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
    } catch (e, stackTrace) {
      debugPrint('Microsoft sign-in failed: $e\n$stackTrace');
      throw Exception(_friendlyMicrosoftSignInMessage(e));
    }
  }

  String _friendlyMicrosoftSignInMessage(Object error) {
    final details = error.toString().toLowerCase();
    final cancelled = details.contains('cancel') ||
        details.contains('user_cancelled') ||
        details.contains('code: -3') ||
        details.contains('code=-3');
    if (cancelled) {
      return 'Sign-in was not completed. Tap Microsoft sign-in again and keep the browser open until it returns to Social Studying.';
    }
    if (error is TimeoutException) {
      return 'Sign-in took too long. Check your internet connection, close the sign-in browser, then try again.';
    }
    if (!kIsWeb && Platform.isIOS) {
      return 'Microsoft sign-in could not finish on this iPhone. Close the sign-in browser, make sure Safari allows cookies, return to Social Studying, and try again. If it continues, restart the app and try on a stable connection.';
    }
    return 'Microsoft sign-in could not finish. Check your connection, close any open sign-in window, and try again.';
  }

  Future<AuthorizationTokenResponse> _signInWithMicrosoftIos() async {
    final scopes = <String>[
      'openid',
      'profile',
      'offline_access',
      'api://${Environment.b2cClientId}/access_as_user',
    ];
    try {
      final payload = await _nativeEntraChannel
          .invokeMapMethod<String, dynamic>('signInWithMicrosoft', {
        'clientId': Environment.b2cClientId,
        'tenantId': Environment.b2cTenantId,
        'tenantSubdomain': Environment.b2cTenantSubdomain,
        'redirectUri': Environment.b2cIosRedirectUri,
        'scopes': scopes,
      }).timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw TimeoutException(
          'Microsoft sign-in did not return to the app within two minutes.',
        ),
      );
      if (payload == null) {
        throw StateError('Microsoft returned no token data.');
      }
      final idToken = payload['idToken'] as String?;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Microsoft returned no ID token.');
      }
      final expiresAtMilliseconds = payload['expiresAtMilliseconds'] as int?;
      final returnedScopes = (payload['scopes'] as List<dynamic>?)
          ?.map((scope) => scope.toString())
          .toList();
      return AuthorizationTokenResponse(
        payload['accessToken'] as String?,
        (payload['refreshToken'] as String?)?.nullIfEmpty,
        expiresAtMilliseconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                expiresAtMilliseconds,
                isUtc: true,
              ),
        idToken,
        payload['tokenType'] as String?,
        returnedScopes ?? scopes,
        const <String, dynamic>{},
        const <String, dynamic>{},
      );
    } on PlatformException catch (error) {
      if (error.code == 'entra_sign_in_cancelled') {
        throw Exception('Microsoft sign-in was cancelled. Please try again.');
      }
      throw Exception(error.message ?? 'Microsoft sign-in failed on iPhone.');
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    try {
      debugPrint('Google Sign-in: starting authentication...');
      final idToken =
          await AuthSessionService.instance.authenticateWithGoogle();
      debugPrint('Google Sign-in: received ID token, persisting session...');

      await AuthSessionService.instance.persistGoogleSession(idToken);
      debugPrint('Google Sign-in: session persisted, fetching profile...');

      // Fetch the real user profile from the backend.
      // Retry once on transient failure — the token is already persisted,
      // so losing the profile fetch shouldn't strand the user on login.
      final dio = _ref.read(dioClientProvider).dio;
      User? backendUser;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          if (attempt > 0) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
          final response = await dio.get('/api/v1/users/me');
          backendUser = User.fromJson(response.data as Map<String, dynamic>);
          break;
        } catch (e) {
          debugPrint(
            'Google Sign-in: profile fetch attempt ${attempt + 1} failed: $e',
          );
          if (attempt == 1) rethrow;
        }
      }

      debugPrint('Google Sign-in: user profile loaded (${backendUser!.email})');

      await AuthSessionService.instance
          .writeUser(jsonEncode(backendUser.toJson()));
      debugPrint('Google Sign-in: complete, returning user');

      return backendUser;
    } catch (e, st) {
      debugPrint('Google Sign-in failed with error: $e\n$st');
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

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
