// Azure Container Apps — hosts the FastAPI backend.
// Managed identity pulls image from ACR and reads secrets from Key Vault.
param location string
param environment string
param tags object

param managedIdentityId string
param managedIdentityClientId string

// Secret URIs (with version) from Key Vault — pinned so rotations don't break live traffic
param cosmosConnectionSecretUri string
param redisConnectionSecretUri string
param serviceBusConnectionSecretUri string
param openAiKeySecretUri string
param searchKeySecretUri string
param contentSafetyKeySecretUri string
param storageConnectionSecretUri string

// Plain-text configuration values
param openAiEndpoint string
param openAiDeploymentName string
param searchEndpoint string
param contentSafetyEndpoint string
param storageEndpoint string

// Azure AD B2C — set after B2C tenant is provisioned (Task 1.5)
param b2cTenantId string = ''
param b2cClientId string = ''
param b2cPolicyName string = 'B2C_1_signupsignin'

// Image to run — set to placeholder on first deploy; updated via push-image.sh
param apiImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

param registryLoginServer string

var envName = 'cae-socialstudyapp-${environment}'
var appName = 'ca-api-${environment}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-socialstudyapp-${environment}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: environment == 'prod' ? 90 : 30
  }
}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource apiApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerAppEnv.id
    configuration: {
      // Pull image from ACR using managed identity — no registry credentials stored
      registries: [
        {
          server: registryLoginServer
          identity: managedIdentityId
        }
      ]
      // Secrets are pulled from Key Vault at container startup using managed identity
      secrets: [
        {
          name: 'cosmos-connection-string'
          keyVaultUrl: cosmosConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'redis-connection-string'
          keyVaultUrl: redisConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'service-bus-connection-string'
          keyVaultUrl: serviceBusConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'azure-openai-key'
          keyVaultUrl: openAiKeySecretUri
          identity: managedIdentityId
        }
        {
          name: 'ai-search-key'
          keyVaultUrl: searchKeySecretUri
          identity: managedIdentityId
        }
        {
          name: 'content-safety-key'
          keyVaultUrl: contentSafetyKeySecretUri
          identity: managedIdentityId
        }
        {
          name: 'storage-connection-string'
          keyVaultUrl: storageConnectionSecretUri
          identity: managedIdentityId
        }
      ]
      ingress: {
        external: true
        targetPort: 8000
        transport: 'http'
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
    }
    template: {
      containers: [
        {
          name: 'api'
          image: apiImage
          resources: {
            cpu: json(environment == 'prod' ? '1.0' : '0.5')
            memory: environment == 'prod' ? '2Gi' : '1Gi'
          }
          env: [
            {
              name: 'ENVIRONMENT'
              value: environment
            }
            {
              name: 'COSMOS_CONNECTION_STRING'
              secretRef: 'cosmos-connection-string'
            }
            {
              name: 'REDIS_URL'
              secretRef: 'redis-connection-string'
            }
            {
              name: 'SERVICE_BUS_CONNECTION'
              secretRef: 'service-bus-connection-string'
            }
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: openAiEndpoint
            }
            {
              name: 'AZURE_OPENAI_KEY'
              secretRef: 'azure-openai-key'
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT'
              value: openAiDeploymentName
            }
            {
              name: 'SEARCH_ENDPOINT'
              value: searchEndpoint
            }
            {
              name: 'SEARCH_KEY'
              secretRef: 'ai-search-key'
            }
            {
              name: 'CONTENT_SAFETY_ENDPOINT'
              value: contentSafetyEndpoint
            }
            {
              name: 'CONTENT_SAFETY_KEY'
              secretRef: 'content-safety-key'
            }
            {
              name: 'STORAGE_CONNECTION_STRING'
              secretRef: 'storage-connection-string'
            }
            {
              name: 'STORAGE_ENDPOINT'
              value: storageEndpoint
            }
            {
              name: 'B2C_TENANT_ID'
              value: b2cTenantId
            }
            {
              name: 'B2C_CLIENT_ID'
              value: b2cClientId
            }
            {
              name: 'B2C_POLICY_NAME'
              value: b2cPolicyName
            }
            {
              name: 'MANAGED_IDENTITY_CLIENT_ID'
              value: managedIdentityClientId
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8000
              }
              initialDelaySeconds: 10
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8000
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: environment == 'prod' ? 1 : 0
        maxReplicas: environment == 'prod' ? 10 : 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

output apiUrl string = 'https://${apiApp.properties.configuration.ingress.fqdn}'
output containerAppName string = apiApp.name
output containerAppEnvName string = containerAppEnv.name
