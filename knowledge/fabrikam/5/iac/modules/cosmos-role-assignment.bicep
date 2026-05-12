// Cosmos SQL data-plane role assignment.

param cosmosAccountName string
param principalId string
@description('Built-in: 00000000-0000-0000-0000-000000000001 Reader; 00000000-0000-0000-0000-000000000002 Contributor.')
param roleDefinitionId string = '00000000-0000-0000-0000-000000000002'

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosAccountName
}

resource assignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: account
  name: guid(account.id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: resourceId('Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions', account.name, roleDefinitionId)
    scope: account.id
  }
}
