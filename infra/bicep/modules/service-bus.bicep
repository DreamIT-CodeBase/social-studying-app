// Azure Service Bus — async queues for document ingestion and status recalc.
// Connection string stored in Key Vault.
param location string
param environment string
param tags object
param keyVaultName string

var namespaceName = 'sb-socialstudyapp-${environment}'

resource namespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'Standard' : 'Basic'
    tier: environment == 'prod' ? 'Standard' : 'Basic'
  }
  properties: {
    minimumTlsVersion: '1.2'
  }
}

resource documentIngestionQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: namespace
  name: 'document-ingestion'
  properties: {
    lockDuration: 'PT5M'
    maxDeliveryCount: 5
    defaultMessageTimeToLive: 'P1D'
    deadLetteringOnMessageExpiration: true
  }
}

resource knowledgeStateQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: namespace
  name: 'knowledge-state-recalc'
  properties: {
    lockDuration: 'PT1M'
    maxDeliveryCount: 3
    defaultMessageTimeToLive: 'PT1H'
    deadLetteringOnMessageExpiration: true
  }
}

// RootManageSharedAccessKey has Send + Listen — use for the API in dev;
// scope per-queue policies in production
resource sendListenRule 'Microsoft.ServiceBus/namespaces/authorizationRules@2022-10-01-preview' existing = {
  parent: namespace
  name: 'RootManageSharedAccessKey'
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource serviceBusConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'service-bus-connection-string'
  properties: {
    value: sendListenRule.listKeys().primaryConnectionString
  }
}

output namespaceName string = namespace.name
output serviceBusConnectionSecretUri string = serviceBusConnectionSecret.properties.secretUriWithVersion
