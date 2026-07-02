abstract final class Environment {
  // Default points at the host machine from the Android emulator (10.0.2.2).
  // Override for production deploys:
  //   --dart-define=API_BASE_URL=https://ca-api-dev.salmonmushroom-d5e027eb.centralus.azurecontainerapps.io
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

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

  static const String b2cRedirectUri = String.fromEnvironment(
    'B2C_REDIRECT_URI',
    defaultValue: 'msauth://com.socialstudyapp.app/callback',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '140186450317-6d8qopjlvvmlad2847o3i8nru0saclv9.apps.googleusercontent.com',
  );
}
