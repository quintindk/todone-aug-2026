// Storage account hardened for managed-identity-only access.

param location string
param tags object
@minLength(3)
@maxLength(24)
param name string
param allowSharedKeyAccess bool = false
param blobContainers array = []
param logAnalyticsWorkspaceId string = ''

resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: allowSharedKeyAccess
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = if (!empty(blobContainers)) {
  parent: st
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for c in blobContainers: {
  parent: blobService
  name: c
  properties: {
    publicAccess: 'None'
  }
}]

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'to-law'
  scope: st
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

output id string = st.id
output name string = st.name
output blobEndpoint string = st.properties.primaryEndpoints.blob
