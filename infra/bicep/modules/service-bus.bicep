// Azure Service Bus — async queues for document ingestion and status recalc.
// Connection string stored in Key Vault.
param location string
param environment string
param tags object
param keyVaultName string

var uniqueSuffix = uniqueString(subscription().id, resourceGroup().id)

var namespaceName = 'sb-ssa-${environment}-${uniqueSuffix}'

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

// Sprint 2.5 — topic extraction. lockDuration=PT5M is the Service Bus
// hard cap (all SKUs). GPT-4o topic extraction normally finishes in
// 5–30s; if a pathologically long doc exceeds 5 min, SB redelivers and
// the worker's status-machine idempotency handles the retry. maxDelivery=3
// (not 5) — model calls are expensive and a doc that fails three times
// almost certainly has a structural issue, not a transient one.
resource topicExtractionQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: namespace
  name: 'topic-extraction'
  properties: {
    lockDuration: 'PT5M'
    maxDeliveryCount: 3
    defaultMessageTimeToLive: 'P1D'
    deadLetteringOnMessageExpiration: true
  }
}

// Sprint 2.8 — chunking. Deterministic CPU work (no AI call), runs in
// seconds even for textbook-size docs. 5-min lock matches document
// ingestion; maxDelivery=5 because transient Cosmos writes deserve more
// retries than expensive model calls.
resource chunkingQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: namespace
  name: 'chunking'
  properties: {
    lockDuration: 'PT5M'
    maxDeliveryCount: 5
    defaultMessageTimeToLive: 'P1D'
    deadLetteringOnMessageExpiration: true
  }
}

// Sprint 2.9 — vectorization. text-embedding-3-small calls finish in 1–3s
// per batch even for full documents (16 inputs/batch), and AI Search
// upsert tops out at a few seconds. PT5M is the Service Bus hard cap;
// if a redeliver fires the worker's delete-then-upsert keeps the index
// state correct. maxDelivery=3 — embeddings are cheap but not free, and
// a doc that fails three times has a structural issue.
resource vectorizationQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: namespace
  name: 'vectorization'
  properties: {
    lockDuration: 'PT5M'
    maxDeliveryCount: 3
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
