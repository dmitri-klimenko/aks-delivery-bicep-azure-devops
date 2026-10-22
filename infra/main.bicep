targetScope = 'subscription'

@description('Dedicated to Bicep + Azure DevOps. Never reuse for the Terraform project.')
param resourceGroupName string = 'rg-aks-delivery-bicep-dev'

param location string = 'northeurope'

@description('Copy exactly from the draft Azure DevOps workload identity service connection. Leave empty for initial bootstrap.')
param federatedIssuer string = ''

@description('Copy exactly from Azure DevOps; do not construct this value yourself.')
param federatedSubject string = ''

resource projectGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    project: 'aks-delivery-bicep-azure-devops'
    environment: 'dev'
    managedBy: 'bicep'
  }
}

module registry './registry.bicep' = {
  name: 'registry'
  scope: projectGroup
  params: {
    location: location
    federatedIssuer: federatedIssuer
    federatedSubject: federatedSubject
  }
}

output resourceGroupName string = projectGroup.name
output registryName string = registry.outputs.registryName
output registryId string = registry.outputs.registryId
output loginServer string = registry.outputs.loginServer
output identityClientId string = registry.outputs.identityClientId
output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
