// Fabrikam payments webhook handler - infrastructure
//
// Reverse-engineered from rg-fabrikam-dev-webhook (subscription quintindekok-demo).
// Parameterised so the same template ships dev, test, prod.
//
// Targets:
//   az deployment group create -g <rg> -f main.bicep -p main.parameters.<env>.json

targetScope = 'resourceGroup'

@description('Environment short name: dev | test | prod.')
@allowed([
  'dev'
  'test'
  'prod'
])
param env string

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Short suffix for global-unique resource names (5-8 lowercase alphanumerics).')
@minLength(5)
@maxLength(8)
param nameSuffix string

@description('Object IDs of human operators who need data-plane access (Key Vault Secrets Officer, Cosmos Data Contributor).')
param operatorObjectIds array = []

@description('Tag map applied to every resource.')
param tags object = {
  workload: 'fabrikam-payments-webhook'
  environment: env
  managedBy: 'bicep'
  costCenter: 'payments-platform'
}

// --- Computed names ----------------------------------------------------------

var workloadShort = 'fabrkwh'
var workloadLong = 'fabrikam-webhook'

var planName     = 'plan-${workloadLong}-${env}-${nameSuffix}'
var funcName     = 'func-${workloadLong}-${env}-${nameSuffix}'
var cosmosName   = 'cosmos-${workloadLong}-${env}-${nameSuffix}'
var kvName       = 'kv-${workloadShort}-${env}-${nameSuffix}'
var logName      = 'log-${workloadLong}-${env}-${nameSuffix}'
var appiName     = 'appi-${workloadLong}-${env}-${nameSuffix}'
// Storage accounts: max 24 chars, lowercase alphanumeric only.
var stRuntimeName = toLower('st${workloadShort}rt${env}${nameSuffix}')
var stArchiveName = toLower('st${workloadShort}ar${env}${nameSuffix}')

// --- Modules ----------------------------------------------------------------

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: logName
    appInsightsName: appiName
    retentionInDays: env == 'prod' ? 90 : 30
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    tags: tags
    name: kvName
    enablePurgeProtection: env == 'prod'
    softDeleteRetentionInDays: env == 'prod' ? 90 : 7
    publicNetworkAccess: 'Enabled'
    operatorObjectIds: operatorObjectIds
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module stRuntime 'modules/storage.bicep' = {
  name: 'st-runtime'
  params: {
    location: location
    tags: tags
    name: stRuntimeName
    allowSharedKeyAccess: false
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module stArchive 'modules/storage.bicep' = {
  name: 'st-archive'
  params: {
    location: location
    tags: tags
    name: stArchiveName
    allowSharedKeyAccess: false
    blobContainers: [
      'payload-archive'
    ]
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module cosmos 'modules/cosmos.bicep' = {
  name: 'cosmos'
  params: {
    location: location
    tags: tags
    name: cosmosName
    databaseName: 'webhook'
    containerName: 'events'
    partitionKeyPath: '/merchantId'
    defaultTtlSeconds: 2592000 // 30 days
    enableContinuousBackup: env == 'prod'
    operatorObjectIds: operatorObjectIds
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module functionApp 'modules/functionapp.bicep' = {
  name: 'function'
  params: {
    location: location
    tags: tags
    planName: planName
    functionAppName: funcName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    runtimeStorageAccountName: stRuntime.outputs.name
    archiveStorageAccountName: stArchive.outputs.name
    archiveContainerName: 'payload-archive'
    cosmosAccountName: cosmos.outputs.name
    cosmosDatabaseName: cosmos.outputs.databaseName
    cosmosContainerName: cosmos.outputs.containerName
    keyVaultName: keyvault.outputs.name
  }
}

// --- Role assignments: wire the Function App MI to data planes --------------

module funcCosmosRole 'modules/cosmos-role-assignment.bicep' = {
  name: 'role-func-cosmos'
  params: {
    cosmosAccountName: cosmos.outputs.name
    principalId: functionApp.outputs.principalId
    // 00000000-0000-0000-0000-000000000002 = Cosmos DB Built-in Data Contributor
    roleDefinitionId: '00000000-0000-0000-0000-000000000002'
  }
}

module funcArchiveRole 'modules/storage-role-assignment.bicep' = {
  name: 'role-func-archive'
  params: {
    storageAccountName: stArchive.outputs.name
    principalId: functionApp.outputs.principalId
    // Storage Blob Data Contributor
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
}

module funcRuntimeRole 'modules/storage-role-assignment.bicep' = {
  name: 'role-func-runtime'
  params: {
    storageAccountName: stRuntime.outputs.name
    principalId: functionApp.outputs.principalId
    // Storage Blob Data Owner - required for AzureWebJobsStorage identity-based access
    roleDefinitionId: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  }
}

module funcKvRole 'modules/keyvault-role-assignment.bicep' = {
  name: 'role-func-kv'
  params: {
    keyVaultName: keyvault.outputs.name
    principalId: functionApp.outputs.principalId
    // Key Vault Secrets User
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

output functionAppName string = functionApp.outputs.name
output functionAppHostname string = functionApp.outputs.defaultHostname
output cosmosEndpoint string = cosmos.outputs.endpoint
output keyVaultName string = keyvault.outputs.name
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
