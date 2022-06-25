param location string
param appName string
param environment string
param sqlAdminUserName string = 'sqladmin'
param sqlAdminUserPassword string
param adminObjectId string
param sqlDbName string = 'todosDb'

var prefix = uniqueString(resourceGroup().id)
var funcAppName = '${prefix}-${environment}-${appName}'
var funcStorageAccountName = '${prefix}stor'
var hostingPlanName = '${prefix}-asp'
var appInsightsName = '${prefix}-ai'
var sqlServerName = '${prefix}-sql-server'
var kvName = '${prefix}-kv'
var tenantId = tenant().tenantId
var dbCxnString = 'server=${sqlServer.properties.fullyQualifiedDomainName};user id=${sqlAdminUserName};password=${sqlAdminUserPassword};port=1433;database=${sqlDbName}'

var tags = {
  environment: environment
  costCenter: '1234567890'
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUserName
    administratorLoginPassword: sqlAdminUserPassword
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  location: location
  name: sqlDbName
  parent: sqlServer
  sku: {
    name: 'Free'
  }
  tags: tags
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'deployKeyVault'
  params: {
    location: location
    keyVaultName: kvName
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

resource hostingPlan 'Microsoft.Web/serverfarms@2020-06-01' = {
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
}

resource funcApp 'Microsoft.Web/sites@2021-01-01' = {
  dependsOn: [
    appInsights
    hostingPlan
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
      appSettings: [
        {
          name: 'DB_CXN'
          value: '@Microsoft.KeyVault(SecretUri=${secret.properties.secretUri})'
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
      ]
      use32BitWorkerProcess: false
    }
    serverFarmId: '/subscriptions/${subscription().subscriptionId}/resourcegroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/${hostingPlanName}'
    clientAffinityEnabled: false
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: '${kvName}/dbCxnString'
  properties: {
    value: dbCxnString
  }
}

/* resource funcAppConfig 'Microsoft.Web/sites/config@2021-03-01' = {
  parent: funcApp
  name: 'appsettings'
  properties: {
    'DB_CXN': '@Microsoft.KeyVault(SecretUri=${secret.properties.secretUri})'
    'FUNCTIONS_EXTENSION_VERSION': '~3'
    'FUNCTIONS_WORKER_RUNTIME': 'custom'
    'APPINSIGHTS_INSTRUMENTATIONKEY': reference('microsoft.insights/components/${appInsightsName}', '2015-05-01').InstrumentationKey
    'AzureWebJobsStorage': 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};AccountKey=${listKeys(funcStorageAccount.id, '2019-06-01').keys[0].value};'
    'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING': 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};AccountKey=${listKeys(funcStorageAccount.id, '2019-06-01').keys[0].value};'
    'WEBSITE_DNS_SERVER': '168.63.129.16'
  }
} */

module keyvaultPolicies 'modules/keyvault_policy.bicep' = {
  name: 'deployKeyVaultPolicies'
  dependsOn: [
    keyvault
  ]
  params: {
    accessPolicies: [
      {
        permissions: {
          keys: [
            'all'
          ]
          secrets: [
            'all'
          ]
          certificates: [
            'all'
          ]
        }
        tenantId: tenantId
        objectId: adminObjectId
      }
      {
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          keys: []
          certificates: []
        }
        tenantId: tenantId
        objectId: funcApp.identity.principalId
      }
    ]
    keyVaultName: keyvault.outputs.name
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
output dbName string = sqlDb.name
