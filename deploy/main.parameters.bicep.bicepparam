using 'main.bicep' /*TODO: Provide a path to a bicep template*/

param tags = {
  Application: 'IPAM'
  Environment: 'Production'
}

param uiAppId = 'UI_APP_ID'
param engineAppId = '5b2ad51b-42fd-45fa-b9eb-90422c5a63ae'
param engineAppSecret = 'ENGINE_APP_SECRET'
param deployAsFunc = false
param deployAsContainer = true
param privateAcr = false
param subId = '41388b2c-b356-465b-ad2b-441351d5cc79'
param vnetResourceGroup = 'rg-cps-ipam-net'
param vnetName = 'vnet-cps-ipam-prod'
param subnetName = 'snet-cps-ipam-01'
param keyVaultUri = 'https://pv-cps-ipam-x1qa.vault.azure.net/'
