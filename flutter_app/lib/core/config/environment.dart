abstract final class Environment {
  // Deployed Azure Container Apps URL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ca-api-dev.salmonmushroom-d5e027eb.centralus.azurecontainerapps.io',
  );

  // Microsoft Entra External ID (CIAM) Configuration
  static const String tenantId = 'cbf2e3d3-af81-40dd-a396-aae11d2c6b3f';
  static const String clientId = '93e3ce50-a29e-462b-8956-85674a34d167';
  static const String tenantSubdomain = 'socialstudyingapp';

  static const String authority = 'https://$tenantSubdomain.ciamlogin.com/$tenantId/v2.0';
  static const String discoveryUrl = '$authority/.well-known/openid-configuration';
  static const String redirectUri = 'msauth://com.socialstudyapp.social_study_app/jykf64iAkgA74TNoFizFZlLnNPI1Y_C8el5RxYcCKCk';

  // Direct Endpoints for speed (CIAM)
  static const String authorizationEndpoint = 'https://$tenantSubdomain.ciamlogin.com/$tenantId/oauth2/v2.0/authorize';
  static const String tokenEndpoint = 'https://$tenantSubdomain.ciamlogin.com/$tenantId/oauth2/v2.0/token';
  static const String endSessionEndpoint = 'https://$tenantSubdomain.ciamlogin.com/$tenantId/oauth2/v2.0/logout';

  static const List<String> scopes = [
    'openid',
    'profile',
    'offline_access',
    'api://$clientId/access_as_user',
  ];
}
