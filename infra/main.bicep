targetScope = 'resourceGroup'

param location string = 'northeurope'

@description('Enable for the AKS milestone. Disabling does not delete an existing cluster.')
param enableAks bool = false

@description('Object ID of the federated infrastructure pipeline identity; never a personal user ID.')
param pipelinePrincipalId string = ''

param aksNodeVmSize string = 'Standard_D4s_v6'

@description('AKS may use another region when the registry region has compute restrictions.')
param aksLocation string = location

@description('Copy exactly from the draft Azure DevOps workload identity service connection. Leave empty for initial bootstrap.')
param federatedIssuer string = ''

@description('Copy exactly from Azure DevOps; do not construct this value yourself.')
param federatedSubject string = ''

module registry './registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    federatedIssuer: federatedIssuer
    federatedSubject: federatedSubject
  }
}

module aks './aks.bicep' = if (enableAks) {
  name: 'aks'
  params: {
    location: aksLocation
    registryName: registry.outputs.registryName
    pipelinePrincipalId: pipelinePrincipalId
    nodeVmSize: aksNodeVmSize
  }
}

output aksClusterName string = enableAks ? aks!.outputs.clusterName : ''
output aksNodeResourceGroup string = enableAks ? aks!.outputs.nodeResourceGroup : ''
output resourceGroupName string = resourceGroup().name
output registryName string = registry.outputs.registryName
output registryId string = registry.outputs.registryId
output loginServer string = registry.outputs.loginServer
output identityClientId string = registry.outputs.identityClientId
output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
