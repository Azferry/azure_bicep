
@description('Location for all resources except Application Insights.')
param location string = resourceGroup().location

@description('Location for Application Insights.')
param appInsightsLocation string = 'eastus2'

@description('The runtime language in the function app.')
@allowed([
  'node'
  'dotnet'
  'java'
])
param runtime string = 'node'

// @description('The name of the function app that you wish to create.')
// param appName string = 'fnapp${uniqueString(resourceGroup().id)}'

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
])
param storageAccountType string = 'Standard_LRS'

@description('The name of the virtual network to be created.')
param vnetName string = 'vnet-demo-wus2-001'

@description('The name of the subnet to be created within the virtual network.')
param subnetName string = 'snet-functionapp'

var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/26'
var functionAppName = 'func-demo-wus2-demo-001'
var hostingPlanName = 'plan-demo-wus2-demo-001'
var storageAccountName = 'stdemowus2demo001'
var functionWorkerRuntime = runtime

var AppInsightName = 'appi-demo-wus2-demo-001'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}
// 2018-05-01-preview
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: AppInsightName
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource serverFarm 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
  properties: {
    maximumElasticWorkerCount: 20
  }
}

resource function 'Microsoft.Web/sites@2020-06-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: serverFarm.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix= ${environment().suffixes.storage};AccountKey=${listkeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listkeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~12'
        }
      ]
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource networkConfig 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  parent: function
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: subnet.id
    swiftSupported: true
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: virtualNetwork
  name: subnetName
}
