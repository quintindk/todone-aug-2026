// Azure RBAC role assignment scoped to a storage account.

param storageAccountName string
param principalId string
@description('Role definition GUID. Storage Blob Data Contributor: ba92f5b4-2d11-453d-a403-e96b0029c9fe; Storage Blob Data Owner: b7e6dc6d-f1e8-4753-8033-0f276bb0955b.')
param roleDefinitionId string

resource st 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(st.id, principalId, roleDefinitionId)
  scope: st
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}
