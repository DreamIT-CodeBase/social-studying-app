import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:social_study_app/core/config/environment.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/services/dio_client.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<User> signIn();
  Future<void> signOut();
  Future<void> deleteAccount(String userId);
  Future<User?> getStoredUser();
  Future<String?> getValidAccessToken();
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  return RealAuthRepository(
    dio: ref.read(dioClientProvider).dio,
    secureStorage: const FlutterSecureStorage(),
    appAuth: const FlutterAppAuth(),
  );
}

class RealAuthRepository implements AuthRepository {
  RealAuthRepository({
    required Dio dio,
    required FlutterSecureStorage secureStorage,
    required FlutterAppAuth appAuth,
  })  : _dio = dio,
        _storage = secureStorage,
        _appAuth = appAuth;

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final FlutterAppAuth _appAuth;

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userKey = 'auth_user_json';

  @override
  Future<User> signIn() async {
    try {
      debugPrint('AuthRepository: Starting interactive sign in...');

      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          Environment.clientId,
          Environment.redirectUri,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: Environment.authorizationEndpoint,
            tokenEndpoint: Environment.tokenEndpoint,
            endSessionEndpoint: Environment.endSessionEndpoint,
          ),
          scopes: Environment.scopes,
          promptValues: ['login'],
          preferEphemeralSession: true,
        ),
      );

      if (result == null || result.accessToken == null) {
        debugPrint('AuthRepository: No access token returned');
        throw Exception('Authentication failed: No access token returned');
      }

      debugPrint('AuthRepository: Login successful, received access token');

      await _storage.write(key: _refreshTokenKey, value: result.refreshToken);
      final token = result.accessToken!;
      await _storage.write(key: _tokenKey, value: token);

      debugPrint('AuthRepository: Fetching user profile from backend...');
      try {
        final response = await _dio.get(
          '/api/v1/users/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final user = User.fromJson(response.data);
        await _storage.write(key: _userKey, value: jsonEncode(response.data));
        debugPrint('AuthRepository: User profile loaded: ${user.displayName}');
        return user;
      } catch (e) {
        debugPrint('AuthRepository: Profile fetch failed - $e');
        if (e is DioException && e.response?.statusCode == 401) {
          await signOut();
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('AuthRepository: signIn failed - $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    debugPrint('AuthRepository: Signing out...');
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);

    try {
      await _appAuth.endSession(EndSessionRequest(
        idTokenHint: null,
        postLogoutRedirectUrl: Environment.redirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: Environment.authorizationEndpoint,
          tokenEndpoint: Environment.tokenEndpoint,
          endSessionEndpoint: Environment.endSessionEndpoint,
        ),
      ));
    } catch (e) {
      debugPrint('AuthRepository: endSession best-effort failed - $e');
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    debugPrint('AuthRepository: Deleting account $userId...');
    await _dio.delete('/api/v1/users/$userId');
    await signOut();
  }

  @override
  Future<User?> getStoredUser() async {
    final token = await getValidAccessToken();
    if (token == null) return null;

    try {
      final response = await _dio.get('/api/v1/users/me');
      return User.fromJson(response.data);
    } catch (_) {
      final cachedUserJson = await _storage.read(key: _userKey);
      if (cachedUserJson != null) {
        try {
          return User.fromJson(jsonDecode(cachedUserJson));
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  @override
  Future<String?> getValidAccessToken() async {
    final accessToken = await _storage.read(key: _tokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);

    if (accessToken == null && refreshToken == null) return null;

    bool isExpired = false;
    if (accessToken != null) {
      try {
        isExpired = JwtDecoder.isExpired(accessToken);
      } catch (_) {
        isExpired = true;
      }
    } else {
      isExpired = true;
    }

    if (!isExpired) {
      return accessToken;
    }

    if (refreshToken != null) {
      debugPrint('AuthRepository: Access token expired, attempting silent refresh...');
      try {
        final result = await _appAuth.token(TokenRequest(
          Environment.clientId,
          Environment.redirectUri,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: Environment.authorizationEndpoint,
            tokenEndpoint: Environment.tokenEndpoint,
            endSessionEndpoint: Environment.endSessionEndpoint,
          ),
          refreshToken: refreshToken,
          scopes: Environment.scopes,
        ));

        if (result != null && result.accessToken != null) {
          debugPrint('AuthRepository: Silent refresh successful');
          await _storage.write(key: _tokenKey, value: result.accessToken);
          if (result.refreshToken != null) {
            await _storage.write(key: _refreshTokenKey, value: result.refreshToken);
          }
          return result.accessToken;
        }
      } catch (e) {
        debugPrint('AuthRepository: Silent refresh failed - $e');
      }
    }

    return accessToken;
  }
}

class _MockAuthRepository implements AuthRepository {
  @override
  Future<User> signIn() async => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount(String userId) async {}
  @override
  Future<User?> getStoredUser() async => null;
  @override
  Future<String?> getValidAccessToken() async => null;
}
