// Log Analytics workspace + App Insights linked to it.

@description('Region.')
param location string

@description('Tags.')
param tags object

@description('Log Analytics workspace name.')
param logAnalyticsName string

@description('Application Insights component name.')
param appInsightsName string

@description('Retention in days for the workspace.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: law.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output logAnalyticsWorkspaceId string = law.id
output appInsightsId string = appi.id
output appInsightsConnectionString string = appi.properties.ConnectionString
