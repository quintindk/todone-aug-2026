// RBAC-only Key Vault. No access policies; consumers get a role assignment.

param location string
param tags object
param name string
param enablePurgeProtection bool = true
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
param operatorObjectIds array = []
param logAnalyticsWorkspaceId string = ''

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    // purgeProtection is one-way; only enable when explicitly requested (prod).
    enablePurgeProtection: enablePurgeProtection ? true : null
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Operator role assignment: Key Vault Secrets Officer
resource operatorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in operatorObjectIds: {
  name: guid(kv.id, principalId, 'kv-secrets-officer')
  scope: kv
  properties: {
    principalId: principalId
    principalType: 'User'
    // Key Vault Secrets Officer
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  }
}]

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'to-law'
  scope: kv
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
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

output id string = kv.id
output name string = kv.name
output uri string = kv.properties.vaultUri
