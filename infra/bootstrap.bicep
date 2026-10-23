targetScope = 'subscription'

// One-time trust bootstrap. Routine deployments use main.bicep in the pipeline.
param resourceGroupName string = 'rg-aks-delivery-bicep-dev'
param location string = 'northeurope'
param federatedIssuer string = ''
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

module deploymentIdentity './deployment-identity.bicep' = {
  name: 'deployment-identity'
  scope: projectGroup
  params: {
    location: location
    federatedIssuer: federatedIssuer
    federatedSubject: federatedSubject
  }
}

output clientId string = deploymentIdentity.outputs.clientId
output principalId string = deploymentIdentity.outputs.principalId
