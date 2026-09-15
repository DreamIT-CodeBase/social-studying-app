// Azure Notification Hubs — Sprint 5.6.
//
// Provisions one namespace + one hub for cross-platform push delivery.
// The DefaultFullSharedAccessSignature connection string is dropped
// into Key Vault and exposed via secretUri so the API + scheduler
// Container Apps can mount it as an env var.
//
// FCM (Firebase) wire-up is HUMAN-ONLY — the FCM server key has to be
// minted in the Firebase console and pasted into ANH's Google
// credentials blade (Settings → Google (GCM/FCM) → API key). Once the
// key is in place every native push goes through ANH → FCM → Android.
// iOS uses APNs the same way (Apple cert into ANH → Apple → iOS) but
// the project plan calls for FCM-only in MVP; APNs lands when the iOS
// build is ready for store submission.
//
// See ``docs/notifications-setup.md`` for the step-by-step Firebase
// console walkthrough that completes the wire-up.

param location string
param environment string
param tags object
param keyVaultName string

// Namespace name must be globally unique across Azure. Same naming
// convention as ``service-bus.bicep`` (sb-ssa-<env>-<seed>) — the seed
// is the pinned shared suffix from memory/infra_seed_and_rg_decisions.
var uniqueSuffix = uniqueString(subscription().id, resourceGroup().id)

var namespaceName = 'nh-ns-ssa-${environment}-${uniqueSuffix}'
var hubName = 'study-app-${environment}'

resource namespace 'Microsoft.NotificationHubs/namespaces@2023-09-01' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    // Free tier covers 1M pushes/month per namespace — plenty for
    // dev/staging. Production bumps to Basic when MAU * notifications-
    // per-MAU crosses the free cap.
    name: environment == 'prod' ? 'Basic' : 'Free'
  }
  properties: {}
}

resource hub 'Microsoft.NotificationHubs/namespaces/notificationHubs@2023-09-01' = {
  parent: namespace
  name: hubName
  location: location
  tags: tags
  // No properties set here — FCM / APNs credentials are configured
  // out-of-band through the Firebase console + Azure portal. Setting
  // them via Bicep would require committing the FCM server key to
  // source control, which we explicitly don't.
  properties: {}
}

// DefaultFullSharedAccessSignature has Manage + Send + Listen — the
// API needs Send (to dispatch pushes), the Flutter app gets a scoped
// Listen-only token through a separate registration endpoint
// (sprint 5.7).
resource fullAccessRule 'Microsoft.NotificationHubs/namespaces/notificationHubs/authorizationRules@2023-09-01' existing = {
  parent: hub
  name: 'DefaultFullSharedAccessSignature'
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource notificationHubConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'notification-hub-connection-string'
  properties: {
    value: fullAccessRule.listKeys().primaryConnectionString
  }
}

output namespaceName string = namespace.name
output hubName string = hub.name
output notificationHubConnectionSecretUri string = notificationHubConnectionSecret.properties.secretUriWithVersion
