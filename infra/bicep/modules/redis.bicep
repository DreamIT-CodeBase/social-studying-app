// Azure Cache for Redis — user auth cache (5 min TTL), session data.
// TLS connection string stored in Key Vault.
param location string
param environment string
param tags object
param keyVaultName string

var redisName = 'redis-ssa-${environment}-ddjopeut37ed2'

resource redisCache 'Microsoft.Cache/redis@2024-03-01' = {
  name: redisName
  location: location
  tags: tags
  properties: {
    sku: {
      name: environment == 'prod' ? 'Standard' : 'Basic'
      family: 'C'
      capacity: environment == 'prod' ? 1 : 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource redisConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'redis-connection-string'
  // rediss:// = TLS; port 6380 is the SSL port for Azure Cache for Redis
  properties: {
    value: 'rediss://:${redisCache.listKeys().primaryKey}@${redisCache.properties.hostName}:${redisCache.properties.sslPort}'
  }
}

output redisHostname string = redisCache.properties.hostName
output redisSslPort int = redisCache.properties.sslPort
output redisConnectionSecretUri string = redisConnectionSecret.properties.secretUriWithVersion
