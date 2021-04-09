param Prefix string = resourceGroup().name
param Suffix string
param Location string = resourceGroup().location
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
param DiagnosticStorageSku string = 'Standard_LRS'
param DiagnosticStorageRetentionDays int = 365
param LogWorkspaceRetentionDays int = 30
param PublicNetworkAccessForQuery bool = true
param PublicNetworkAccessForIngestion bool = true
param AllowedSubnetResourceId array = []
// Typical entries are: VMInsights, SecurityCenterFree, and ServiceMap
// Refer to: https://docs.microsoft.com/en-us/powershell/module/az.monitoringsolutions/new-azmonitorloganalyticssolution?view=azps-5.7.0#examples
param Solutions array = [
  'VMInsights'
]

module logs 'logworkspace.bicep' = {
  name: 'logworkspace'
  params:{
    Prefix: Prefix
    Location: Location
    DiagnosticStorageSku: DiagnosticStorageSku
    DiagnosticStorageRetentionDays: DiagnosticStorageRetentionDays
    LogWorkspaceRetentionDays: LogWorkspaceRetentionDays
    PublicNetworkAccessForQuery: PublicNetworkAccessForQuery
    PublicNetworkAccessForIngestion: PublicNetworkAccessForIngestion
    AllowedSubnetResourceId: AllowedSubnetResourceId
    Solutions: Solutions
  }
}

module appinsights 'appinsights.bicep' = {
  name: 'appinsights'
  params:{
    Prefix: Prefix
    Suffix: Suffix        
    Location: Location
    LogWorkspaceResourceId: logs.outputs.LogWorkspaceResourceId
    PublicNetworkAccessForQuery: PublicNetworkAccessForQuery
    PublicNetworkAccessForIngestion: PublicNetworkAccessForIngestion
  }
}

output StorageAccountName string = logs.outputs.StorageAccountName
output StorageAccountResourceId string = logs.outputs.StorageAccountResourceId
output LogWorkspaceResourceId string = logs.outputs.LogWorkspaceResourceId
output LogWorkspaceId string = logs.outputs.LogWorkspaceId
output AppInsightsConnectionString string = appinsights.outputs.AppInsightsConnectionString
output AppInsightsInstrumentationKey string = appinsights.outputs.AppInsightsInstrumentationKey
