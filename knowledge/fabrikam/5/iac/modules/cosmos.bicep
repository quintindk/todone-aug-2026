// Cosmos DB SQL API, serverless, MI-only auth (disableLocalAuth=true).

param location string
param tags object
param name string
param databaseName string = 'webhook'
param containerName string = 'events'
param partitionKeyPath string = '/merchantId'
@description('Default TTL on the container in seconds. -1 disables, 0 omits, > 0 sets.')
param defaultTtlSeconds int = 2592000
param enableContinuousBackup bool = false
param operatorObjectIds array = []
param logAnalyticsWorkspaceId string = ''

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: name
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    minimalTlsVersion: 'Tls12'
    backupPolicy: enableContinuousBackup ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous7Days'
      }
    } : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Local'
      }
    }
  }
}

resource db 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: account
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: db
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          partitionKeyPath
        ]
        kind: 'Hash'
      }
      defaultTtl: defaultTtlSeconds
      indexingPolicy: {
        indexingMode: 'consistent'
      }
    }
  }
}

// Operator data-plane access: Cosmos DB Built-in Data Contributor.
resource operatorRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = [for principalId in operatorObjectIds: {
  parent: account
  name: guid(account.id, principalId, 'cosmos-data-contributor')
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions', account.name, '00000000-0000-0000-0000-000000000002')
    scope: account.id
  }
}]

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'to-law'
  scope: account
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
        category: 'Requests'
        enabled: true
      }
    ]
  }
}

output id string = account.id
output name string = account.name
output endpoint string = account.properties.documentEndpoint
output databaseName string = db.name
output containerName string = container.name
