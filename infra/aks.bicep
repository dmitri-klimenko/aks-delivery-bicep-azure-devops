param location string
param registryName string
@minLength(36)
param pipelinePrincipalId string
param nodeVmSize string = 'Standard_D4s_v6'

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: registryName
}

resource cluster 'Microsoft.ContainerService/managedClusters@2025-02-01' = {
  name: 'aks-delivery-bicep-dev'
  location: location
  tags: resourceGroup().tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  properties: {
    dnsPrefix: 'aks-delivery-${uniqueString(resourceGroup().id)}'
    nodeResourceGroup: '${resourceGroup().name}-nodes'
    enableRBAC: true
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      tenantID: tenant().tenantId
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: 2
        vmSize: nodeVmSize
        osType: 'Linux'
        osSKU: 'Ubuntu'
        osDiskType: 'Managed'
        osDiskSizeGB: 64
        type: 'VirtualMachineScaleSets'
        maxPods: 30
        enableAutoScaling: false
        upgradeSettings: {
          maxSurge: '1'
        }
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      podCidr: '10.244.0.0/16'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
  }
}

var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource pullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, cluster.id, acrPullRoleId)
  scope: registry
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: cluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

var clusterAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')

resource pipelineAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(cluster.id, pipelinePrincipalId, clusterAdminRoleId)
  scope: cluster
  properties: {
    roleDefinitionId: clusterAdminRoleId
    principalId: pipelinePrincipalId
    principalType: 'ServicePrincipal'
  }
}

output clusterName string = cluster.name
output nodeResourceGroup string = cluster.properties.nodeResourceGroup
output kubeletPrincipalId string = cluster.properties.identityProfile.kubeletidentity.objectId
