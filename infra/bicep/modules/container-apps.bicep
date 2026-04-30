param location string
param environment string
param tags object

var envName = 'cae-socialstudyapp-${environment}'
var appName = 'ca-api-${environment}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-socialstudyapp-${environment}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
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
  properties: {
    environmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'http'
      }
    }
    template: {
      containers: [
        {
          name: 'api'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: environment == 'prod' ? 1 : 0
        maxReplicas: environment == 'prod' ? 10 : 3
      }
    }
  }
}

output apiUrl string = 'https://${apiApp.properties.configuration.ingress.fqdn}'
