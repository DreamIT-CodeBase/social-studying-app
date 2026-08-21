import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:social_study_app/core/config/environment.dart';

/// Owns the provider tokens that keep an installed account signed in.
///
/// Tokens remain in Android/iOS secure storage. The in-memory copy avoids a
/// secure-storage platform call on every API request, while [_refreshInFlight]
/// makes simultaneous requests share one provider refresh operation.
class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance = AuthSessionService._();

  static const tokenKey = 'auth_token';
  static const refreshTokenKey = 'auth_refresh_token';
  static const providerKey = 'auth_provider';
  static const userKey = 'auth_user';

  static const _microsoftProvider = 'microsoft';
  static const _googleProvider = 'google';
  static const _storage = FlutterSecureStorage();
  static const _appAuth = FlutterAppAuth();

  // iOS: google_sign_in v7 with Credential Manager (works perfectly on iOS)
  // Android: uses flutter_appauth PKCE browser flow instead (see authenticateWithGoogle)
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  late final Future<void> _googleInitialization = _googleSignIn.initialize(
    serverClientId: Environment.googleWebClientId,
  );

  // Android uses AppAuth with the registered Google iOS OAuth client. Google
  // permits this public-client PKCE flow with the client's reverse-domain
  // redirect URI. It does not involve Play Services, so Play signing-key
  // mismatches cannot produce status 10 (DEVELOPER_ERROR).
  static const _googlePkceClientId =
      '140186450317-vbdvuerjbgqtt0eslqjvoeofc8p3ccgb.apps.googleusercontent.com';
  static const _googlePkceRedirectUri =
      'com.googleusercontent.apps.140186450317-vbdvuerjbgqtt0eslqjvoeofc8p3ccgb:/oauth2redirect';
  static const _googleAuthEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const _googleTokenEndpoint =
      'https://oauth2.googleapis.com/token';

  bool _loaded = false;
  Map<String, String> _storedValues = {};
  String? _token;
  String? _refreshToken;
  String? _provider;
  Future<String?>? _refreshInFlight;
  final Set<Future<void>> _profileWrites = {};
  int _sessionGeneration = 0;
  bool _isClearing = false;

  String get _microsoftDiscoveryUrl =>
      'https://${Environment.b2cTenantSubdomain}.ciamlogin.com/'
      '${Environment.b2cTenantId}/v2.0/.well-known/openid-configuration';

  List<String> get _microsoftScopes => [
        'openid',
        'profile',
        'offline_access',
        'api://${Environment.b2cClientId}/access_as_user',
      ];

  /// Loads all secure values in one platform call and primes the token cache.
  /// This is used at startup so restoring a user does not require separate
  /// reads for the token and profile.
  Future<Map<String, String>> loadStoredValues({bool force = false}) async {
    if (_loaded && !force) {
      return Map<String, String>.from(_storedValues);
    }

    final generation = _sessionGeneration;
    final values = await _storage.readAll();
    if (generation != _sessionGeneration || _isClearing) return {};
    _prime(values);
    return values;
  }

  Future<void> persistMicrosoftSession(
    AuthorizationTokenResponse result,
  ) async {
    final idToken = result.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Microsoft did not return an ID token.');
    }

    await _beginSessionReplacement();
    await _writeSession(
      token: idToken,
      refreshToken: result.refreshToken,
      provider: _microsoftProvider,
    );
  }

  Future<void> persistGoogleSession(String idToken) async {
    await _beginSessionReplacement();
    await _writeSession(
      token: idToken,
      refreshToken: null,
      provider: _googleProvider,
    );
  }

  /// Authenticates with Google and returns the ID token.
  ///
  /// - Android: Uses OAuth 2.0 Authorization Code + PKCE in a browser tab.
  ///   This bypasses Play Services and Credential Manager certificate checks.
  /// - iOS: Uses native google_sign_in v7 (unchanged, working 100% on iPhone).
  Future<String> authenticateWithGoogle() async {
    if (Platform.isAndroid) {
      return _authenticateWithGoogleAndroid();
    } else {
      return _authenticateWithGoogleIOS();
    }
  }

  /// Android: OAuth 2.0 PKCE via Chrome Custom Tabs.
  Future<String> _authenticateWithGoogleAndroid() async {
    final result = await _appAuth
        .authorizeAndExchangeCode(
          AuthorizationTokenRequest(
            _googlePkceClientId,
            _googlePkceRedirectUri,
            serviceConfiguration: const AuthorizationServiceConfiguration(
              authorizationEndpoint: _googleAuthEndpoint,
              tokenEndpoint: _googleTokenEndpoint,
            ),
            scopes: const ['openid', 'email', 'profile'],
            promptValues: const ['select_account'],
          ),
        )
        .timeout(
          const Duration(seconds: 75),
          onTimeout: () => throw TimeoutException(
            'Google sign-in did not finish after returning from the browser.',
          ),
        );

    final idToken = result.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign in failed: no ID token returned.');
    }
    return idToken;
  }

  /// iOS: google_sign_in v7 — unchanged, works perfectly on iPhone.
  Future<String> _authenticateWithGoogleIOS() =>
      _authenticateWithGooglePlugin();

  Future<String> _authenticateWithGooglePlugin() async {
    await _googleInitialization;
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError('Google sign-in not supported on this platform.');
    }
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign in failed: no ID token returned.');
    }
    return idToken;
  }

  Future<void> writeUser(String userJson) async {
    if (_isClearing || _token == null) return;
    final write = _storage.write(key: userKey, value: userJson);
    _profileWrites.add(write);
    try {
      await write;
      if (!_isClearing && _token != null) {
        _storedValues[userKey] = userJson;
      }
    } finally {
      _profileWrites.remove(write);
    }
  }

  /// Returns a usable token, refreshing it shortly before expiry.
  ///
  /// A provider/network failure keeps the last token and cached account. This
  /// prevents an offline launch or a brief connection loss from logging the
  /// student out. The API may still reject a genuinely revoked session.
  Future<String?> getValidToken({bool forceRefresh = false}) async {
    await _ensureLoaded();
    final token = _token;
    if (token == null || token.isEmpty) return null;

    if (!forceRefresh && !_expiresSoon(token)) return token;

    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _refreshTokenFromProvider(_sessionGeneration);
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> clear() async {
    _sessionGeneration += 1;
    _isClearing = true;
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) {
      try {
        await activeRefresh;
      } catch (_) {
        // Secure deletion still runs if the provider refresh failed.
      }
    }
    if (_profileWrites.isNotEmpty) {
      await Future.wait(_profileWrites.toList());
    }

    _loaded = true;
    _token = null;
    _refreshToken = null;
    _provider = null;
    _refreshInFlight = null;
    _storedValues = {};

    await Future.wait([
      _storage.delete(key: tokenKey),
      _storage.delete(key: refreshTokenKey),
      _storage.delete(key: providerKey),
      _storage.delete(key: userKey),
    ]);

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Local secure state is already cleared; provider cleanup is best effort.
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded || _isClearing) return;
    final generation = _sessionGeneration;
    final values = await _storage.readAll();
    if (generation == _sessionGeneration && !_isClearing) {
      _prime(values);
    }
  }

  void _prime(Map<String, String> values) {
    _storedValues = Map<String, String>.from(values);
    _token = values[tokenKey];
    _refreshToken = values[refreshTokenKey];
    _provider = values[providerKey] ?? _inferProvider(_token);
    _loaded = true;

    // Existing installs predate provider metadata. Persist the inferred value
    // asynchronously on the next successful refresh/write; no migration prompt
    // or forced logout is needed.
  }

  Future<String?> _refreshTokenFromProvider(int generation) async {
    final oldToken = _token;
    if (oldToken == null) return null;

    try {
      return switch (_provider ?? _inferProvider(oldToken)) {
        _microsoftProvider => await _refreshMicrosoft(oldToken, generation),
        _googleProvider => await _refreshGoogle(oldToken, generation),
        _ => generation == _sessionGeneration ? oldToken : null,
      };
    } catch (_) {
      // Never erase a valid local account because the device is temporarily
      // offline or the identity provider is unavailable.
      return generation == _sessionGeneration ? oldToken : null;
    }
  }

  Future<String?> _refreshMicrosoft(String oldToken, int generation) async {
    final storedRefreshToken = _refreshToken;
    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      // A legacy install has no refresh token. Keep its cached account; the
      // next explicit Microsoft sign-in stores the new long-lived session.
      return generation == _sessionGeneration ? oldToken : null;
    }

    final result = await _appAuth.token(
      TokenRequest(
        Environment.b2cClientId,
        Environment.b2cRedirectUri,
        discoveryUrl: _microsoftDiscoveryUrl,
        refreshToken: storedRefreshToken,
        scopes: _microsoftScopes,
      ),
    );
    final refreshedIdToken = result.idToken;
    if (refreshedIdToken == null || refreshedIdToken.isEmpty) {
      return generation == _sessionGeneration ? oldToken : null;
    }
    if (generation != _sessionGeneration) return null;

    await _writeSession(
      token: refreshedIdToken,
      refreshToken: result.refreshToken ?? storedRefreshToken,
      provider: _microsoftProvider,
    );
    return refreshedIdToken;
  }

  Future<String?> _refreshGoogle(String oldToken, int generation) async {
    // Android: we can't silently refresh via AppAuth without user interaction.
    // Return the existing token and let the next explicit sign-in refresh it.
    if (Platform.isAndroid) {
      return generation == _sessionGeneration ? oldToken : null;
    }

    // iOS: use google_sign_in v7 lightweight (silent) authentication.
    await _googleInitialization;
    final lightweight = _googleSignIn.attemptLightweightAuthentication();
    final account = lightweight == null ? null : await lightweight;
    if (account == null) {
      return generation == _sessionGeneration ? oldToken : null;
    }
    final auth = await account.authentication;
    final refreshedIdToken = auth.idToken;
    if (refreshedIdToken == null || refreshedIdToken.isEmpty) {
      return generation == _sessionGeneration ? oldToken : null;
    }
    if (generation != _sessionGeneration) return null;

    await _writeSession(
      token: refreshedIdToken,
      refreshToken: null,
      provider: _googleProvider,
    );
    return refreshedIdToken;
  }

  Future<void> _beginSessionReplacement() async {
    _sessionGeneration += 1;
    _isClearing = true;
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) {
      try {
        await activeRefresh;
      } catch (_) {
        // The explicit sign-in will replace any failed previous refresh.
      }
    }
    if (_profileWrites.isNotEmpty) {
      await Future.wait(_profileWrites.toList());
    }
    _isClearing = false;
  }

  Future<void> _writeSession({
    required String token,
    required String? refreshToken,
    required String provider,
  }) async {
    await Future.wait([
      _storage.write(key: tokenKey, value: token),
      _storage.write(key: providerKey, value: provider),
      if (refreshToken == null)
        _storage.delete(key: refreshTokenKey)
      else
        _storage.write(key: refreshTokenKey, value: refreshToken),
    ]);

    _token = token;
    _refreshToken = refreshToken;
    _provider = provider;
    _loaded = true;
    _storedValues[tokenKey] = token;
    _storedValues[providerKey] = provider;
    if (refreshToken == null) {
      _storedValues.remove(refreshTokenKey);
    } else {
      _storedValues[refreshTokenKey] = refreshToken;
    }
  }

  bool _expiresSoon(String token) {
    final claims = _parseJwt(token);
    final exp = claims?['exp'];
    if (exp is! num) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
    return expiry
        .isBefore(DateTime.now().toUtc().add(const Duration(minutes: 5)));
  }

  String? _inferProvider(String? token) {
    if (token == null) return null;
    final issuer = _parseJwt(token)?['iss']?.toString().toLowerCase();
    if (issuer == null) return null;
    if (issuer.contains('accounts.google.com')) return _googleProvider;
    if (issuer.contains('microsoftonline.com') ||
        issuer.contains('ciamlogin.com')) {
      return _microsoftProvider;
    }
    return null;
  }

  Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
