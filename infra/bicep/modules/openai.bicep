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

var accountName = 'oai-ssa-${environment}-ddjopeut37ed2'
var hasQuota = gpt4oCapacity > 0

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
