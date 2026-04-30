param location string
param environment string
param tags object

var accountName = 'cosmos-socialstudyapp-${environment}'

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
  }
}

output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosAccountName string = cosmosAccount.name
