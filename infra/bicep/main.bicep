// Social Study App — Azure infrastructure entry point
// Deploy: az deployment sub create --location eastus --template-file main.bicep --parameters @environments/dev/params.json

targetScope = 'subscription'

@description('Environment name (dev, staging, prod)')
param environment string

@description('Azure region for all resources')
param location string = 'eastus'

@description('Tenant short name — used in resource names')
param tenantName string = 'socialstudyapp'

var resourceGroupName = 'rg-${tenantName}-${environment}'
var tags = {
  app: 'social-study-app'
  environment: environment
  managedBy: 'bicep'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module cosmos 'modules/cosmos-db.bicep' = {
  name: 'cosmos'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
  }
}

module aiSearch 'modules/ai-search.bicep' = {
  name: 'ai-search'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
  }
}

module containerApp 'modules/container-apps.bicep' = {
  name: 'container-apps'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
  }
}

module redis 'modules/redis.bicep' = {
  name: 'redis'
  scope: rg
  params: {
    location: location
    environment: environment
    tags: tags
  }
}
