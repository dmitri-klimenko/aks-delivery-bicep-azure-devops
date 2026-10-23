param location string
param federatedIssuer string = ''
param federatedSubject string = ''

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-aks-delivery-infra'
  location: location
  tags: resourceGroup().tags
}

resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = if (!empty(federatedIssuer) && !empty(federatedSubject)) {
  parent: identity
  name: 'azure-devops'
  properties: {
    issuer: federatedIssuer
    subject: federatedSubject
    audiences: ['api://AzureADTokenExchange']
  }
}

// Infrastructure can manage resources and their role assignments only within
// this project's resource group, not throughout the subscription.
var deploymentRoles = [
  'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
  'f58310d9-a9f6-439a-9e8d-f62e7b41a168' // Role Based Access Control Administrator
]

resource roles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleId in deploymentRoles: {
  name: guid(resourceGroup().id, identity.id, roleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
