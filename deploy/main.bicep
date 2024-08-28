// Global parameters
targetScope = 'subscription'

@description('GUID for Resource Naming')
param guid string = newGuid()

@description('Deployment Location')
param location string = 'uksouth'

@description('Azure Cloud Enviroment')
param azureCloud string = 'AZURE_PUBLIC'

@description('Flag to Deploy Private Container Registry')
param privateAcr bool = false

@description('Flag to Deploy IPAM as a Function')
param deployAsFunc bool = false

@description('Flag to Deploy IPAM as a Container')
param deployAsContainer bool = false

@description('IPAM-UI App Registration Client/App ID')
param uiAppId string = '00000000-0000-0000-0000-000000000000'

@description('IPAM-Engine App Registration Client/App ID')
param engineAppId string

@secure()
param engineAppSecret string

@description('Tags')
param tags object = {}

@maxLength(7)
@description('Prefix for Resource Naming')
param namePrefix string = 'ipam'

@description('IPAM Resource Names')
var resourceNames = {
  functionName: 'func-cps-ipam-prod'
  appServiceName: 'as-cps-ipam-prod'
  functionPlanName: 'funcpn-cps-ipam-prod'
  appServicePlanName: 'asp-cps-ipam-prod'
  cosmosAccountName: 'cosmos-acc-cps-ipam-prod'
  cosmosContainerName: 'cosmos-ctr-cps-ipam-prod'
  cosmosDatabaseName: 'cosmos-db-cps-ipam-prod'
  keyVaultName: 'pv-cps-ipam-x1qa'
  workspaceName: 'log-cps-ipam-prod'
  managedIdentityName: 'mi-cps-${namePrefix}-${uniqueString(guid)}'
  resourceGroupName: 'rg-cps-ipam-app'
  storageAccountName: 'st-cps-ipam-prod'
  containerRegistryName: 'crcpsipamdevuksouth001'
}

param subId string
param vnetResourceGroup string
param vnetName string
param subnetName string
param keyVaultUri string

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  location: location
  #disable-next-line use-stable-resource-identifiers
  name: resourceNames.resourceGroupName
  tags: tags
}

// Log Analytics Workspace
module logAnalyticsWorkspace './modules/logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspaceModule'
  scope: resourceGroup
  params: {
    location: location
    workspaceName: resourceNames.workspaceName
  }
}

// Managed Identity for Secure Access to KeyVault
module managedIdentity './modules/managedIdentity.bicep' = {
  name: 'managedIdentityModule'
  scope: resourceGroup
  params: {
    location: location
    managedIdentityName: resourceNames.managedIdentityName
  }
}

// KeyVault for Secure Values
module keyVault './modules/keyVault.bicep' = {
  name: 'keyVaultModule'
  scope: resourceGroup

  params: {
    //location: location
    keyVaultName: resourceNames.keyVaultName
    identityPrincipalId: managedIdentity.outputs.principalId
    identityClientId: managedIdentity.outputs.clientId
    uiAppId: uiAppId
    engineAppId: engineAppId
    engineAppSecret: engineAppSecret
    workspaceId: logAnalyticsWorkspace.outputs.workspaceId
  }
}

// module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.7.0' = {
//   name: 'privateEndpointDeployment'
//   scope: resourceGroup
//   params: {
//     // Required parameters
//     name: 'KEYVAULT-PE-NAME'
//     subnetResourceId: '/subscriptions/${subId}/resourceGroups/${vnetResourceGroup}/providers/Microsoft.Network/virtualNetworks/${vnetName}/subnets/${subnetName}'
//     // Non-required parameters
//     customNetworkInterfaceName: 'KEYVAULT-PE-NIC'
//     ipConfigurations: [
//       {
//         name: 'myIPconfig'
//         properties: {
//           groupId: 'vault'
//           memberName: 'default'
//           privateIPAddress: 'PRIVATE_IP_ADDRESS'
//         }
//       }
//     ]
//     location: location
//     lock: {
//       kind: 'CanNotDelete'
//       name: 'myCustomLockName'
//     }
//     privateDnsZoneGroup: {
//       privateDnsZoneGroupConfigs: [
//         {
//           privateDnsZoneResourceId: '/subscriptions/${subId}/resourceGroups/RESOURCEGROUP/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
//         }
//       ]
//     }
//     privateLinkServiceConnections: [
//       {
//         name: 'KEYVAULT-PE-CONNECTION'
//         properties: {
//           groupIds: [
//             'vault'
//           ]
//           privateLinkServiceId: '/subscriptions/${subId}/resourceGroups/RESOURCEGROUP/providers/Microsoft.KeyVault/vaults/KEYVAULTNAME'
//         }
//       }
//     ]
//     tags: {
//       Environment: 'Non-Prod'
//       'hidden-title': 'This is visible in the resource name'
//       Role: 'DeploymentValidation'
//     }
//   }
//   dependsOn: [
//     keyVault
//   ]
// }

// Cosmos DB for IPAM Database
module cosmos './modules/cosmos.bicep' = {
  name: 'cosmosModule'
  scope: resourceGroup
  params: {
    location: location
    cosmosAccountName: resourceNames.cosmosAccountName
    cosmosContainerName: resourceNames.cosmosContainerName
    cosmosDatabaseName: resourceNames.cosmosDatabaseName
    keyVaultName: resourceNames.keyVaultName
    workspaceId: logAnalyticsWorkspace.outputs.workspaceId
    principalId: managedIdentity.outputs.principalId
  }
}

module privateEndpointcosmos 'br/public:avm/res/network/private-endpoint:0.7.0' = {
  name: 'privateEndpointDeploymentcosmos'
  scope: resourceGroup
  params: {
    // Required parameters
    name: 'ipam-cosmos'
    subnetResourceId: '/subscriptions/${subId}/resourceGroups/${vnetResourceGroup}/providers/Microsoft.Network/virtualNetworks/${vnetName}/subnets/${subnetName}'
    location: location
    privateLinkServiceConnections: [
      {
        name: 'COSMOSDB-ENDPOINT-NAME'
        properties: {
          groupIds: [
            'Sql'
          ]
          privateLinkServiceId: '/subscriptions/${subId}/resourceGroups/RESOURCEGROUPNAME/providers/Microsoft.DocumentDB/databaseAccounts/COSMOS-DB-NAME'
        }
      }
    ]
  }
  dependsOn: [
    cosmos
  ]
}

// Storage Account for Nginx Config/Function Metadata
module storageAccount './modules/storageAccount.bicep' = if (deployAsFunc) {
  scope: resourceGroup
  name: 'storageAccountModule'
  params: {
    location: location
    storageAccountName: resourceNames.storageAccountName
    workspaceId: logAnalyticsWorkspace.outputs.workspaceId
  }
}

// Container Registry
module containerRegistry './modules/containerRegistry.bicep' = if (privateAcr) {
  scope: resourceGroup
  name: 'containerRegistryModule'
  params: {
    location: location
    containerRegistryName: resourceNames.containerRegistryName
    principalId: managedIdentity.outputs.principalId
  }
}

// App Service w/ Docker Compose + CI
module appService './modules/appService.bicep' = if (!deployAsFunc) {
  scope: resourceGroup
  name: 'appServiceModule'
  params: {
    location: location
    azureCloud: azureCloud
    appServiceName: resourceNames.appServiceName
    appServicePlanName: resourceNames.appServicePlanName
    keyVaultUri: keyVaultUri
    cosmosDbUri: cosmos.outputs.cosmosDocumentEndpoint
    databaseName: resourceNames.cosmosDatabaseName
    containerName: resourceNames.cosmosContainerName
    managedIdentityId: managedIdentity.outputs.id
    managedIdentityClientId: managedIdentity.outputs.clientId
    workspaceId: logAnalyticsWorkspace.outputs.workspaceId
    deployAsContainer: deployAsContainer
    privateAcr: privateAcr
    privateAcrUri: privateAcr ? containerRegistry.outputs.acrUri : ''
    //Subnetid: '/subscriptions/${subId}/resourceGroups/${vnetResourceGroup}/providers/Microsoft.Network/virtualNetworks/${vnetName}/subnets/${subnetName}'
  }
}

module privateEndpointappservice 'br/public:avm/res/network/private-endpoint:0.7.0' = {
  name: 'privateEndpointDeploymentappservice'
  scope: resourceGroup
  params: {
    // Required parameters
    name: 'ipam-appservice'
    subnetResourceId: '/subscriptions/${subId}/resourceGroups/${vnetResourceGroup}/providers/Microsoft.Network/virtualNetworks/${vnetName}/subnets/${subnetName}'
    location: location
    privateLinkServiceConnections: [
      {
        name: 'ipamappservice'
        properties: {
          groupIds: [
            'sites'
          ]
          privateLinkServiceId: '/subscriptions/${subId}/resourceGroups/RESOURCEGROUP/providers/Microsoft.Web/sites/APPSERVICE'
        }
      }
    ]
  }
  dependsOn: [
    appService
  ]
}

// Function App
module functionApp './modules/functionApp.bicep' = if (deployAsFunc) {
  scope: resourceGroup
  name: 'functionAppModule'
  params: {
    location: location
    azureCloud: azureCloud
    functionAppName: resourceNames.functionName
    functionPlanName: resourceNames.appServicePlanName
    keyVaultUri: keyVaultUri
    cosmosDbUri: cosmos.outputs.cosmosDocumentEndpoint
    databaseName: resourceNames.cosmosDatabaseName
    containerName: resourceNames.cosmosContainerName
    managedIdentityId: managedIdentity.outputs.id
    managedIdentityClientId: managedIdentity.outputs.clientId
    storageAccountName: resourceNames.storageAccountName
    workspaceId: logAnalyticsWorkspace.outputs.workspaceId
    deployAsContainer: deployAsContainer
    privateAcr: privateAcr
    privateAcrUri: privateAcr ? containerRegistry.outputs.acrUri : ''
  }
}

// Outputs
output suffix string = uniqueString(guid)
output subscriptionId string = subscription().subscriptionId
output resourceGroupName string = resourceGroup.name
output appServiceName string = deployAsFunc ? resourceNames.functionName : resourceNames.appServiceName
output appServiceHostName string = deployAsFunc
  ? functionApp.outputs.functionAppHostName
  : appService.outputs.appServiceHostName
output acrName string = privateAcr ? containerRegistry.outputs.acrName : ''
output acrUri string = privateAcr ? containerRegistry.outputs.acrUri : ''
output keyvaultId string = resourceNames.keyVaultName
