// Azure RBAC role assignment scoped to a Key Vault.

param keyVaultName string
param principalId string
@description('Role definition GUID. Key Vault Secrets User: 4633458b-17de-408a-b874-0445c86b69e6.')
param roleDefinitionId string

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, principalId, roleDefinitionId)
  scope: kv
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}
