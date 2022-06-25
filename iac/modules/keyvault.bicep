param keyVaultName string
param location string

var tenantId = tenant().tenantId

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  location: location
  name: keyVaultName
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

output name string = kv.name
