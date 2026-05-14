// Social Study App — Azure infrastructure entry point
// Deploy: az deployment sub create --location eastus --template-file main.bicep --parameters @environments/dev/params.json
//
// Deployment order (handled automatically by Bicep dependency graph):
//   1. managed-identity
//   2. key-vault + container-registry  (parallel, both need identity)
//   3. cosmos-db, redis, ai-search, storage, service-bus, openai, content-safety
//      (parallel, all need key-vault)
//   4. container-apps  (needs everything above)

targetScope = 'subscription'

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region for all resources')
param location string = 'eastus'

@description('Tenant short name — used in resource names')
param tenantName string = 'socialstudyapp'

@description('Object ID of the user/SP running this deployment — granted Key Vault Secrets Officer')
param deployerObjectId string

@description('Azure AD B2C tenant ID — set after B2C is provisioned (Task 1.5)')
param b2cTenantId string = ''

@description('Azure AD B2C app client ID — set after B2C is provisioned')
param b2cClientId string = ''

@description('Azure AD B2C sign-up/sign-in policy name')
param b2cPolicyName string = 'B2C_1_signupsignin'

@description('GPT-4o tokens-per-minute capacity (thousands). 10 = 10K TPM.')
param gpt4oCapacity int = 10

var resourceGroupName = 'rg-${tenantName}-${environment}'
var tags = {
  app: 'social-study-app'
  environment: environment
  managedBy: 'bicep'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ── Step 1: Identity ──────────────────────────────────────────────────────────

module identity 'modules/managed-identity.bicep' = {
  name: 'managed-identity'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
  }
}

// ── Step 2: Key Vault + Container Registry (parallel) ─────────────────────────

module keyVault 'modules/key-vault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    deployerObjectId: deployerObjectId
    managedIdentityPrincipalId: identity.outputs.identityPrincipalId
  }
}

module acr 'modules/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    managedIdentityPrincipalId: identity.outputs.identityPrincipalId
  }
}

// ── Step 3: Data + AI services (parallel, all need Key Vault) ─────────────────

module cosmos 'modules/cosmos-db.bicep' = {
  name: 'cosmos'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

module redis 'modules/redis.bicep' = {
  name: 'redis'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

module aiSearch 'modules/ai-search.bicep' = {
  name: 'ai-search'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
    managedIdentityPrincipalId: identity.outputs.identityPrincipalId
  }
}

module serviceBus 'modules/service-bus.bicep' = {
  name: 'service-bus'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

module openAi 'modules/openai.bicep' = {
  name: 'openai'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
    gpt4oCapacity: gpt4oCapacity
  }
}

module contentSafety 'modules/content-safety.bicep' = {
  name: 'content-safety'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

module documentIntelligence 'modules/document-intelligence.bicep' = {
  name: 'document-intelligence'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// ── Step 4: Container Apps (needs all of the above) ───────────────────────────

module containerApp 'modules/container-apps.bicep' = {
  name: 'container-apps'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
    managedIdentityId: identity.outputs.identityId
    managedIdentityClientId: identity.outputs.identityClientId
    cosmosConnectionSecretUri: cosmos.outputs.cosmosConnectionSecretUri
    redisConnectionSecretUri: redis.outputs.redisConnectionSecretUri
    serviceBusConnectionSecretUri: serviceBus.outputs.serviceBusConnectionSecretUri
    openAiKeySecretUri: openAi.outputs.openAiKeySecretUri
    searchKeySecretUri: aiSearch.outputs.searchKeySecretUri
    contentSafetyKeySecretUri: contentSafety.outputs.contentSafetyKeySecretUri
    storageConnectionSecretUri: storage.outputs.storageConnectionSecretUri
    documentIntelligenceKeySecretUri: documentIntelligence.outputs.documentIntelligenceKeySecretUri
    openAiEndpoint: openAi.outputs.openAiEndpoint
    openAiDeploymentName: openAi.outputs.deploymentName
    searchEndpoint: aiSearch.outputs.searchEndpoint
    contentSafetyEndpoint: contentSafety.outputs.contentSafetyEndpoint
    storageEndpoint: storage.outputs.storageEndpoint
    documentIntelligenceEndpoint: documentIntelligence.outputs.documentIntelligenceEndpoint
    b2cTenantId: b2cTenantId
    b2cClientId: b2cClientId
    b2cPolicyName: b2cPolicyName
    registryLoginServer: acr.outputs.registryLoginServer
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

output resourceGroupName string = resourceGroupName
output apiUrl string = containerApp.outputs.apiUrl
output containerAppName string = containerApp.outputs.containerAppName
output workerAppName string = containerApp.outputs.workerAppName
output topicWorkerAppName string = containerApp.outputs.topicWorkerAppName
output registryLoginServer string = acr.outputs.registryLoginServer
output registryName string = acr.outputs.registryName
output keyVaultName string = keyVault.outputs.keyVaultName
output cosmosAccountName string = cosmos.outputs.cosmosAccountName
output searchEndpoint string = aiSearch.outputs.searchEndpoint
output openAiEndpoint string = openAi.outputs.openAiEndpoint
output storageEndpoint string = storage.outputs.storageEndpoint
output contentSafetyEndpoint string = contentSafety.outputs.contentSafetyEndpoint
output documentIntelligenceEndpoint string = documentIntelligence.outputs.documentIntelligenceEndpoint
