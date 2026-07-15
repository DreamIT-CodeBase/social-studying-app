import 'dart:convert';

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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: Environment.googleWebClientId,
    scopes: const ['email', 'profile'],
  );

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
    final account = await _googleSignIn.signInSilently(
      suppressErrors: true,
      reAuthenticate: true,
    );
    if (account == null) {
      return generation == _sessionGeneration ? oldToken : null;
    }

    final refreshedIdToken = (await account.authentication).idToken;
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
