// Azure Cosmos DB for MongoDB API — shared throughput for dynamic tenants.
// Primary connection string stored in Key Vault.
param location string
param environment string
param tags object
param keyVaultName string

var uniqueSuffix = uniqueString(subscription().id, resourceGroup().id)

var accountName = 'cosmos-ssa-${environment}-${uniqueSuffix}'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  tags: tags
  kind: 'MongoDB'
  properties: {
    apiProperties: {
      serverVersion: '7.0'
    }
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    // Disable public network access in prod; use private endpoints
    publicNetworkAccess: environment == 'prod' ? 'Disabled' : 'Enabled'
  }
}

// Platform database — stores the tenants collection (not per-tenant data)
resource platformDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: 'platform'
  properties: {
    resource: {
      id: 'platform'
    }
    options: {
      throughput: 400
    }
  }
}

resource tenantsCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2024-05-15' = {
  parent: platformDatabase
  name: 'tenants'
  properties: {
    resource: {
      id: 'tenants'
      indexes: [
        {
          key: { keys: ['_id'] }
        }
        {
          key: { keys: ['admin_email'] }
        }
      ]
    }
  }
}

// Dynamic tenant domain collections all consume this one database-level
// throughput pool, preventing every signup or component from allocating
// another dedicated 400 RU/s. Every collection is sharded by tenant_id.
resource tenantDataDatabase 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: 'tenant_data_shared'
  properties: {
    resource: {
      id: 'tenant_data_shared'
    }
    options: {
      throughput: 400
    }
  }
}

var tenantCollectionNames = [
  'users'
  'workspaces'
  'documents'
  'chunks'
  'knowledge_states'
  'interactions'
  'gamification'
  'moderation_log'
  'question_queue'
  'flashcards'
  'flashcard_ratings'
  'adaptive_sessions'
  'xp_events'
  'notification_tokens'
  'notification_dispatches'
  'screen_time_settings'
  'screen_time_wallets'
  'device_usage_logs'
  'app_usage_logs'
  'screen_time_logs'
  'app_restrictions'
  'parental_controls'
  'permission_status'
  'db_stats'
  'rag_evaluations'
]

resource tenantCollections 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2024-05-15' = [for collectionName in tenantCollectionNames: {
  parent: tenantDataDatabase
  name: collectionName
  properties: {
    resource: {
      id: collectionName
      shardKey: {
        tenant_id: 'Hash'
      }
      indexes: [
        {
          key: { keys: ['_id'] }
        }
        {
          key: { keys: ['tenant_id'] }
        }
      ]
    }
  }
}]

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource cosmosConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'cosmos-connection-string'
  properties: {
    // Primary MongoDB connection string
    value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
  }
}

output cosmosAccountName string = cosmosAccount.name
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosConnectionSecretUri string = cosmosConnectionSecret.properties.secretUriWithVersion
