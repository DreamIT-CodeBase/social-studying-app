param location string
param environment string
param tags object

var redisName = 'redis-socialstudyapp-${environment}'

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
  }
}

output redisHostname string = redisCache.properties.hostName
output redisPort int = redisCache.properties.sslPort
