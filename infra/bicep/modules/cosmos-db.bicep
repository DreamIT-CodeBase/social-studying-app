// Azure Cosmos DB for MongoDB API — one database per tenant, one collection per domain.
// Primary connection string stored in Key Vault.
param location string
param environment string
param tags object
param keyVaultName string

var accountName = 'cosmos-ssa-${environment}-ddjopeut37ed2'

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
