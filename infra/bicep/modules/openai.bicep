// Azure OpenAI (AI Foundry) — GPT-4o deployment for question generation.
// API key stored in Key Vault.
param location string
param environment string
param tags object
param keyVaultName string

@description('Tokens-per-minute capacity for GPT-4o (in thousands). 10 = 10K TPM.')
param gpt4oCapacity int = environment == 'prod' ? 40 : 10

var accountName = 'oai-socialstudyapp-${environment}'

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

resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
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
output deploymentName string = gpt4oDeployment.name
