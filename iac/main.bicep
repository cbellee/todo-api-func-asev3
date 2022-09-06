param location string
param appName string
param environment string
param containerImageName string
param acrName string
param shareName string = 'myshare'
param mountPath string = '/mnt'

@description('App service plan sku.')
param sku string = 'IsolatedV2'

@description('App service plan sku code.')
param skuCode string = 'I1V2'

var affix = uniqueString(resourceGroup().id)
var funcAppName = '${affix}-${environment}-${appName}'
var funcStorageAccountName = '${affix}stor'
var hostingPlanName = 'asp-${affix}'
var appInsightsName = 'ai-${affix}'
var kvName = 'kv-app-${affix}'
var vnetName = '${affix}-vnet'
var tenantId = tenant().tenantId
var aseName = 'asev3-${affix}'

var tags = {
  environment: environment
  costCenter: '1234567890'
}

resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: acrName
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aseSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: [
            {
              name: 'Microsoft.Web.hostingEnvironments'
              properties: {
                serviceName: 'Microsoft.Web/hostingEnvironments'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'privateLinkSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource keyvault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  location: location
  name: kvName
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    accessPolicies: []
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
  }
}

resource funcStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: funcStorageAccountName
  kind: 'StorageV2'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

resource storageBlobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'storage-blob-private-endpoint'
  location: location
  properties: {
    subnet: {
      id: vnet.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-blob-plink'
        properties: {
          privateLinkServiceId: funcStorageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource storageFilePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'storage-file-private-endpoint'
  location: location
  properties: {
    subnet: {
      id: vnet.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-file-plink'
        properties: {
          privateLinkServiceId: funcStorageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

resource storageTablePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'storage-table-private-endpoint'
  location: location
  properties: {
    subnet: {
      id: vnet.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-table-plink'
        properties: {
          privateLinkServiceId: funcStorageAccount.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }
}

resource aseConfig 'Microsoft.Web/hostingEnvironments/configurations@2021-01-15' existing = {
  name: '${aseName}/networking'
}

resource storageBlobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource storageFilePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
}

resource storageTablePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.table.core.windows.net'
  location: 'global'
}

resource asev3PrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${aseName}.appserviceenvironment.net'
  location: 'global'
}

resource webRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: asev3PrivateDnsZone
  name: '*'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: asev3.outputs.privateIpAddress
      }
    ]
  }
}

resource scmRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: asev3PrivateDnsZone
  name: '*.scm'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: asev3.outputs.privateIpAddress
      }
    ]
  }
}

resource aRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: asev3PrivateDnsZone
  name: '@'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: asev3.outputs.privateIpAddress
      }
    ]
  }
}

resource storageBlobPrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  name: '${storageBlobPrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob-storage'
        properties: {
          privateDnsZoneId: storageBlobPrivateDnsZone.id
        }
      }
    ]
  }
}

resource storageFilePrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  name: '${storageFilePrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-file-storage'
        properties: {
          privateDnsZoneId: storageFilePrivateDnsZone.id
        }
      }
    ]
  }
}

resource storageTablePrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  name: '${storageTablePrivateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-table-storage'
        properties: {
          privateDnsZoneId: storageTablePrivateDnsZone.id
        }
      }
    ]
  }
}

resource storageBlobPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'blob-storage-dns-zone-link'
  parent: storageBlobPrivateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource storageFilePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'file-storage-dns-zone-link'
  parent: storageFilePrivateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource storageTablePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'table-storage-dns-zone-link'
  parent: storageTablePrivateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource asev3PrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'asev3-dns-zone-link'
  parent: asev3PrivateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

/* resource hostingPlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
  properties: {
    reserved: true
    maximumElasticWorkerCount: 20
  }
  dependsOn: [
    storageBlobPrivateDnsZoneLink
    storageFilePrivateDnsZoneLink
    storageTablePrivateDnsZoneLink
  ]
} */

module asev3 'modules/ase.bicep' = {
  name: 'ase-deployment'
  params: {
    name: 'asev3'
    location: location
    subnetId: vnet.properties.subnets[0].id
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: hostingPlanName
  location: location
  sku: {
    tier: sku
    name: skuCode
  }
  properties: {
    hostingEnvironmentProfile: {
      id: resourceId('Microsoft.Web/hostingEnvironments', asev3.outputs.aseName)
    }
  }
}

resource funcApp 'Microsoft.Web/sites@2021-01-01' = {
  dependsOn: [
    appInsights
    asev3
  ]
  name: funcAppName
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'functionapp,linux'
  location: location
  tags: {}
  properties: {
    siteConfig: {
      vnetRouteAllEnabled: true
      linuxFxVersion: 'DOCKER|${containerImageName}'
      appSettings: [
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16'
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'custom'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference('microsoft.insights/components/${appInsightsName}', '2015-05-01').InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};AccountKey=${listKeys(funcStorageAccount.id, '2019-06-01').keys[0].value};'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};AccountKey=${listKeys(funcStorageAccount.id, '2019-06-01').keys[0].value};'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acr.listCredentials().passwords[0].value
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: acr.properties.loginServer
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acr.name
        }
      ]
      use32BitWorkerProcess: false
    }
    serverFarmId: '/subscriptions/${subscription().subscriptionId}/resourcegroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/${hostingPlanName}'
    clientAffinityEnabled: false
  }
}

resource storageSetting 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${funcAppName}/azurestorageaccounts'
  properties: {
    '${shareName}': {
      type: 'AzureFiles'
      shareName: shareName
      mountPath: mountPath
      accountName: funcStorageAccount.name
      accessKey: listKeys(funcStorageAccount.id, funcStorageAccount.apiVersion).keys[0].value
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  kind: 'web'
  location: location
  tags: {}
  properties: {
    Application_Type: 'web'
  }
}

output functionName string = funcApp.name
