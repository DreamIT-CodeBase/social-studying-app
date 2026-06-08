abstract final class Environment {
  // Replace with actual Azure Container Apps URL after deployment
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // ── Dev-auth (real backend, demo creds) ──────────────────────────────────
  //
  // When true, the still-mocked demo login (auth_repository.dart) drives the
  // *real* backend instead of the in-process Demo* repositories: it writes
  // [devAuthToken] as the bearer token and every repository provider routes
  // through Dio. The backend accepts that sentinel token only in non-prod and
  // resolves it to the seeded demo user (see backend/app/core/auth.py).
  //
  // Off by default, so a plain `flutter run` stays a fully offline demo. Turn
  // it on for dogfooding against rg-ssa2-dev:
  //
  //   flutter run --flavor admin -t lib/main_admin.dart \
  //     --dart-define=USE_REAL_BACKEND=true \
  //     --dart-define=API_BASE_URL=https://ca-api-dev.salmonmushroom-d5e027eb.centralus.azurecontainerapps.io
  //
  // DEV_AUTH_TOKEN defaults to the value provisioned on ca-api-dev; override
  // via --dart-define if the backend token is rotated.
  static const bool useRealBackend = bool.fromEnvironment(
    'USE_REAL_BACKEND',
    defaultValue: false,
  );

  static const String devAuthToken = String.fromEnvironment(
    'DEV_AUTH_TOKEN',
    defaultValue: 'devauth-ssa2-2c9f8a1b7e4d6035',
  );
}
