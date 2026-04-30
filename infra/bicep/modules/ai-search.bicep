// Azure AI Search — chunked document embeddings with metadata filters.
// Admin key stored in Key Vault.
param location string
param environment string
param tags object
param keyVaultName string

var searchName = 'search-socialstudyapp-${environment}'

resource aiSearch 'Microsoft.Search/searchServices@2024-03-01-preview' = {
  name: searchName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'standard' : 'basic'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    semanticSearch: 'free'
    publicNetworkAccess: 'enabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource searchKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ai-search-key'
  properties: {
    value: aiSearch.listAdminKeys().primaryKey
  }
}

output searchEndpoint string = 'https://${aiSearch.name}.search.windows.net'
output searchName string = aiSearch.name
output searchKeySecretUri string = searchKeySecret.properties.secretUriWithVersion
