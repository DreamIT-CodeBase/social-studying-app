import 'package:flutter/foundation.dart';
import 'package:social_study_app/core/config/app_flavor.dart';

abstract final class Environment {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kReleaseMode) {
      return 'https://ca-api-dev.ambitiouswave-1e406ff3.centralus.azurecontainerapps.io';
    }
    // Dynamic local testing: connect to localhost (or 10.0.2.2 on Android emulator)
    if (kIsWeb) return 'http://localhost:8000';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  // When true, all repository providers route through Dio → real backend.
  // When false, demo/offline repositories are used for users matching the
  // demo-user heuristic.
  static const bool useRealBackend = bool.fromEnvironment(
    'USE_REAL_BACKEND',
    defaultValue: true,
  );

  // ── Microsoft Entra ID (Azure AD B2C / CIAM) Config ──────────────────────
  static const String b2cTenantId = String.fromEnvironment(
    'B2C_TENANT_ID',
    defaultValue: 'cbf2e3d3-af81-40dd-a396-aae11d2c6b3f',
  );

  static const String b2cClientId = String.fromEnvironment(
    'B2C_CLIENT_ID',
    defaultValue: '93e3ce50-a29e-462b-8956-85674a34d167',
  );

  static const String b2cTenantSubdomain = String.fromEnvironment(
    'B2C_TENANT_SUBDOMAIN',
    defaultValue: 'socialstudyingapp',
  );

  static const String b2cPolicyName = String.fromEnvironment(
    'B2C_POLICY_NAME',
    defaultValue: 'B2C_1_signupsignin',
  );

  static const String _b2cRedirectUri = String.fromEnvironment(
    'B2C_REDIRECT_URI',
    defaultValue: 'msauth://com.socialstudyapp.app/callback',
  );

  static const String _b2cStudentIosRedirectUri = String.fromEnvironment(
    'B2C_STUDENT_IOS_REDIRECT_URI',
    defaultValue: 'msauth.ai.socialstudying.app://auth',
  );

  static const String _b2cAdminIosRedirectUri = String.fromEnvironment(
    'B2C_ADMIN_IOS_REDIRECT_URI',
    defaultValue: 'msauth.ai.socialstudying.app.admin://auth',
  );

  static String get b2cIosRedirectUri => currentFlavor == AppFlavor.admin
      ? _b2cAdminIosRedirectUri
      : _b2cStudentIosRedirectUri;

  static String get b2cRedirectUri =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? b2cIosRedirectUri
          : _b2cRedirectUri;

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '140186450317-6d8qopjlvvmlad2847o3i8nru0saclv9.apps.googleusercontent.com',
  );
}
