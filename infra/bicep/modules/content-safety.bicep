// Azure AI Content Safety — moderates uploaded documents and generated questions.
// API key stored in Key Vault.
param location string
param environment string
param tags object
param keyVaultName string

var accountName = 'cs-socialstudyapp-${environment}'

resource contentSafety 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: accountName
  location: location
  tags: tags
  kind: 'ContentSafety'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource contentSafetyKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'content-safety-key'
  properties: {
    value: contentSafety.listKeys().key1
  }
}

output contentSafetyEndpoint string = contentSafety.properties.endpoint
output contentSafetyKeySecretUri string = contentSafetyKeySecret.properties.secretUriWithVersion
