targetScope='resourceGroup'
// Parameters
@description('Azure location to which the resources are to be deployed')
param location string

@description('Standardized suffix text to be added to resource names')
param resourceSuffix string

// Variables
var logAnalyticsWorkspaceName = 'log-${resourceSuffix}'

// Resources
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}


