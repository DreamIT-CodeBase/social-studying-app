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
param documentIntelligenceKeySecretUri string

// Plain-text configuration values
param openAiEndpoint string
param openAiDeploymentName string
param searchEndpoint string
param contentSafetyEndpoint string
param storageEndpoint string
param documentIntelligenceEndpoint string

// Azure AD B2C — set after B2C tenant is provisioned (Task 1.5)
param b2cTenantId string = ''
param b2cClientId string = ''
param b2cPolicyName string = 'B2C_1_signupsignin'

// Image to run — set to placeholder on first deploy; updated via push-image.sh
param apiImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

param registryLoginServer string

var envName = 'cae-socialstudyapp-${environment}'
var appName = 'ca-api-${environment}'
var workerAppName = 'ca-worker-${environment}'
var topicWorkerAppName = 'ca-topic-extractor-${environment}'
var chunkerAppName = 'ca-chunker-${environment}'

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
        {
          name: 'document-intelligence-key'
          keyVaultUrl: documentIntelligenceKeySecretUri
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
              name: 'DOCUMENT_INTELLIGENCE_ENDPOINT'
              value: documentIntelligenceEndpoint
            }
            {
              name: 'DOCUMENT_INTELLIGENCE_KEY'
              secretRef: 'document-intelligence-key'
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

// ── Worker Container App (Sprint 2.3) ─────────────────────────────────────────
// Same image as the API, different entrypoint: `python -m app.workers.document_ingestion`.
// No ingress — workers consume from Service Bus, not HTTP. Scales 0→N on queue
// depth via the KEDA azure-servicebus trigger.
//
// Scaling auth uses the connection string (matches the project's worker-auth
// decision in memory/sprint_2_3_decisions.md). KEDA does NOT support managed
// identity for the azure-servicebus trigger as of api-version 2024-03-01.

resource workerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: workerAppName
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
      registries: [
        {
          server: registryLoginServer
          identity: managedIdentityId
        }
      ]
      // Same Key Vault secrets as the API — worker reads connection strings
      // directly per the Sprint 2.3 auth decision. KEDA scaler also reads
      // 'service-bus-connection-string' to query queue depth.
      secrets: [
        {
          name: 'cosmos-connection-string'
          keyVaultUrl: cosmosConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'service-bus-connection-string'
          keyVaultUrl: serviceBusConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'storage-connection-string'
          keyVaultUrl: storageConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'document-intelligence-key'
          keyVaultUrl: documentIntelligenceKeySecretUri
          identity: managedIdentityId
        }
        {
          name: 'content-safety-key'
          keyVaultUrl: contentSafetyKeySecretUri
          identity: managedIdentityId
        }
      ]
      // No ingress block — worker is not HTTP-reachable.
    }
    template: {
      containers: [
        {
          name: 'worker'
          image: apiImage
          // Override the API's uvicorn entrypoint; same image, different process.
          command: ['python']
          args: ['-m', 'app.workers.document_ingestion']
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
              name: 'SERVICE_BUS_CONNECTION'
              secretRef: 'service-bus-connection-string'
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
              name: 'DOCUMENT_INTELLIGENCE_ENDPOINT'
              value: documentIntelligenceEndpoint
            }
            {
              name: 'DOCUMENT_INTELLIGENCE_KEY'
              secretRef: 'document-intelligence-key'
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
              name: 'MANAGED_IDENTITY_CLIENT_ID'
              value: managedIdentityClientId
            }
          ]
          // No HTTP probes for a worker process. Container Apps will restart
          // the container if the python process exits, which is the right
          // signal for a long-running asyncio loop.
        }
      ]
      scale: {
        // Scale-to-zero in dev keeps costs near zero between uploads.
        // Prod keeps min=1 so the first message after idle isn't slow.
        minReplicas: environment == 'prod' ? 1 : 0
        maxReplicas: environment == 'prod' ? 10 : 3
        rules: [
          {
            name: 'queue-depth'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                queueName: 'document-ingestion'
                messageCount: '5'
              }
              auth: [
                {
                  secretRef: 'service-bus-connection-string'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

// ── Topic Extractor Container App (Sprint 2.5) ────────────────────────────────
// Second worker. Consumes the `topic-extraction` queue, runs GPT-4o over the
// extracted text, and writes per-document topic tags. Scales independently of
// the text extractor: topic mining is slow (10–30s/doc on GPT-4o) and we don't
// want a backlog here to starve text extraction or vice versa.
//
// Same image as the API/worker — entrypoint is `python -m app.workers.topic_extraction`.

resource topicWorkerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: topicWorkerAppName
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
      registries: [
        {
          server: registryLoginServer
          identity: managedIdentityId
        }
      ]
      secrets: [
        {
          name: 'cosmos-connection-string'
          keyVaultUrl: cosmosConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'service-bus-connection-string'
          keyVaultUrl: serviceBusConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'storage-connection-string'
          keyVaultUrl: storageConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'azure-openai-key'
          keyVaultUrl: openAiKeySecretUri
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'topic-extractor'
          image: apiImage
          command: ['python']
          args: ['-m', 'app.workers.topic_extraction']
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
              name: 'SERVICE_BUS_CONNECTION'
              secretRef: 'service-bus-connection-string'
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
              name: 'MANAGED_IDENTITY_CLIENT_ID'
              value: managedIdentityClientId
            }
          ]
        }
      ]
      scale: {
        // Topic mining is slower per message — keep maxReplicas low to avoid
        // hammering the GPT-4o deployment's TPM budget in parallel.
        minReplicas: environment == 'prod' ? 1 : 0
        maxReplicas: environment == 'prod' ? 5 : 2
        rules: [
          {
            name: 'topic-queue-depth'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                queueName: 'topic-extraction'
                messageCount: '3'
              }
              auth: [
                {
                  secretRef: 'service-bus-connection-string'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

// ── Chunker Container App (Sprint 2.8) ────────────────────────────────────────
// Third worker. Consumes the `chunking` queue, splits each document's
// extracted text into ~500-token overlapping chunks, and writes them to the
// `chunks` Cosmos collection. Pure CPU — no AI call — so it scales tighter
// than the topic extractor and doesn't need an OpenAI secret.
//
// Same image; entrypoint is `python -m app.workers.chunking`.

resource chunkerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: chunkerAppName
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
      registries: [
        {
          server: registryLoginServer
          identity: managedIdentityId
        }
      ]
      secrets: [
        {
          name: 'cosmos-connection-string'
          keyVaultUrl: cosmosConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'service-bus-connection-string'
          keyVaultUrl: serviceBusConnectionSecretUri
          identity: managedIdentityId
        }
        {
          name: 'storage-connection-string'
          keyVaultUrl: storageConnectionSecretUri
          identity: managedIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'chunker'
          image: apiImage
          command: ['python']
          args: ['-m', 'app.workers.chunking']
          resources: {
            cpu: json(environment == 'prod' ? '0.5' : '0.25')
            memory: environment == 'prod' ? '1Gi' : '0.5Gi'
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
              name: 'SERVICE_BUS_CONNECTION'
              secretRef: 'service-bus-connection-string'
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
              name: 'MANAGED_IDENTITY_CLIENT_ID'
              value: managedIdentityClientId
            }
          ]
        }
      ]
      scale: {
        // Chunking is fast (sub-second per chunk write) — keep replicas low
        // to avoid Cosmos write contention on the same partition.
        minReplicas: environment == 'prod' ? 1 : 0
        maxReplicas: environment == 'prod' ? 3 : 2
        rules: [
          {
            name: 'chunk-queue-depth'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                queueName: 'chunking'
                messageCount: '5'
              }
              auth: [
                {
                  secretRef: 'service-bus-connection-string'
                  triggerParameter: 'connection'
                }
              ]
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
output workerAppName string = workerApp.name
output topicWorkerAppName string = topicWorkerApp.name
output chunkerAppName string = chunkerApp.name
