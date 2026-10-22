param location string
param federatedIssuer string = ''
param federatedSubject string = ''

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: 'acr${uniqueString(resourceGroup().id)}'
  location: location
  tags: resourceGroup().tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
    // AcrPush/AcrPull use registry RBAC, rather than repository ABAC roles.
    roleAssignmentMode: 'LegacyRegistryPermissions'
  }
}

resource pushIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-aks-delivery-acr-push'
  location: location
  tags: resourceGroup().tags
}

resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = if (!empty(federatedIssuer) && !empty(federatedSubject)) {
  parent: pushIdentity
  name: 'azure-devops'
  properties: {
    issuer: federatedIssuer
    subject: federatedSubject
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

var acrPushRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')

resource pushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, pushIdentity.id, acrPushRoleId)
  scope: registry
  properties: {
    roleDefinitionId: acrPushRoleId
    principalId: pushIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output registryName string = registry.name
output registryId string = registry.id
output loginServer string = registry.properties.loginServer
output identityClientId string = pushIdentity.properties.clientId
