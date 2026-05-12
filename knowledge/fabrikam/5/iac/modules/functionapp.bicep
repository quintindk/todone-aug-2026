// Consumption (Y1) Linux Function App running .NET 8 isolated.

param location string
param tags object
param planName string
param functionAppName string
param appInsightsConnectionString string
param logAnalyticsWorkspaceId string
param runtimeStorageAccountName string
param archiveStorageAccountName string
param archiveContainerName string
param cosmosAccountName string
param cosmosDatabaseName string
param cosmosContainerName string
param keyVaultName string

resource plan 'Microsoft.Web/serverFarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource func 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    clientCertEnabled: false
    reserved: true
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      functionAppScaleLimit: 200
      use32BitWorkerProcess: false
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        // Identity-based AzureWebJobsStorage. Requires Storage Blob Data Owner
        // on the runtime account (granted in main.bicep).
        {
          name: 'AzureWebJobsStorage__accountName'
          value: runtimeStorageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'COSMOS_ENDPOINT'
          value: 'https://${cosmosAccountName}.documents.azure.com:443/'
        }
        {
          name: 'COSMOS_DATABASE'
          value: cosmosDatabaseName
        }
        {
          name: 'COSMOS_CONTAINER'
          value: cosmosContainerName
        }
        {
          name: 'KEY_VAULT_NAME'
          value: keyVaultName
        }
        {
          name: 'PAYLOAD_ARCHIVE_ACCOUNT'
          value: archiveStorageAccountName
        }
        {
          name: 'PAYLOAD_ARCHIVE_CONTAINER'
          value: archiveContainerName
        }
      ]
    }
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-law'
  scope: func
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output id string = func.id
output name string = func.name
output principalId string = func.identity.principalId
output defaultHostname string = func.properties.defaultHostName
