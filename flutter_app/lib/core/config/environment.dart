abstract final class Environment {
  // Replace with actual Azure Container Apps URL after deployment
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
