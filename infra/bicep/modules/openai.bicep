// Azure OpenAI (AI Foundry) — GPT-4o deployment for question generation.
// API key stored in Key Vault.
//
// GPT-4o quota: new subscriptions start at 0 TPM. Set gpt4oCapacity = 0 to
// create the account without a model deployment. Request quota at:
// https://aka.ms/oai/quotaincrease — then redeploy with capacity > 0.
param location string
param environment string
param tags object
param keyVaultName string

@description('Tokens-per-minute capacity for GPT-4o (in thousands). 0 = skip model deployment (no quota yet).')
param gpt4oCapacity int = 0

@description('Tokens-per-minute capacity for text-embedding-3-small (in thousands). 0 = skip deployment.')
param embeddingCapacity int = 0

var uniqueSuffix = uniqueString(subscription().id, resourceGroup().id)

var accountName = 'oai-ssa-${environment}-${uniqueSuffix}'
var hasQuota = gpt4oCapacity > 0
var hasEmbeddingQuota = embeddingCapacity > 0

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: accountName
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

// Only deployed when quota has been granted — set gpt4oCapacity > 0 in params.json
resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = if (hasQuota) {
  parent: openAiAccount
  name: 'gpt-4o'
  sku: {
    name: 'Standard'
    capacity: gpt4oCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
  }
}

// Sprint 2.9 — text-embedding-3-small. 1536 dimensions, 5x cheaper than -large
// while still handling our K-12 retrieval workload. Deployed under the same
// account as GPT-4o so the existing key + endpoint cover both. Conditional on
// embeddingCapacity so a fresh subscription without embedding quota can still
// deploy the rest of the infra.
//
// SKU is GlobalStandard (not Standard) because new subscriptions ship with
// 1000 TPM of quota under GlobalStandard.text-embedding-3-small and zero
// under regional Standard. Using Standard fails the deployment with a
// SKU-not-available error. GlobalStandard is region-agnostic; the
// embedding endpoint we hit is the same.
//
// Sequenced after gpt4oDeployment via dependsOn — Azure rejects parallel
// deployment ops on the same Cognitive Services account.
resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = if (hasEmbeddingQuota) {
  parent: openAiAccount
  name: 'text-embedding-3-small'
  sku: {
    name: 'GlobalStandard'
    capacity: embeddingCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-small'
      version: '1'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
  }
  dependsOn: [
    gpt4oDeployment
  ]
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource openAiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-openai-key'
  properties: {
    value: openAiAccount.listKeys().key1
  }
}

output openAiEndpoint string = openAiAccount.properties.endpoint
output openAiKeySecretUri string = openAiKeySecret.properties.secretUriWithVersion
// Empty string when no deployment exists — Container App env var will be blank until quota is granted
output deploymentName string = hasQuota ? gpt4oDeployment.name : ''
output embeddingDeploymentName string = hasEmbeddingQuota ? embeddingDeployment.name : ''
