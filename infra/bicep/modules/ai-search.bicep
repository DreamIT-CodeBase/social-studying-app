param location string
param environment string
param tags object

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
  }
}

output searchEndpoint string = 'https://${aiSearch.name}.search.windows.net'
output searchName string = aiSearch.name
