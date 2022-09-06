param location string
param name string
param dedicatedHostCount int = 0
param subnetId string
param zoneRedundant bool = false
@allowed([
  'None'
  'Web'
  'Publishing'
  'Web, Publishing'
])
param internalLoadBalancingMode string = 'Web, Publishing'

var affix = uniqueString(resourceGroup().id)
var aseName = '${name}-${affix}'

resource ase 'Microsoft.Web/hostingEnvironments@2022-03-01' = {
  name: aseName
  location: location
  kind: 'ASEV3'
  properties: {
    dedicatedHostCount: dedicatedHostCount
    zoneRedundant: zoneRedundant
    internalLoadBalancingMode: internalLoadBalancingMode
    virtualNetwork: {
      id: subnetId
    }
  }
}

output aseName string = ase.name
output privateIpAddress string = ase.properties.networkingConfiguration.properties.internalInboundIpAddresses[0]
