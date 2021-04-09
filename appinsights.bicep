param Location string = resourceGroup().location
param Prefix string = resourceGroup().name
param Suffix string
param LogWorkspaceResourceId string
param PublicNetworkAccessForQuery bool = true
param PublicNetworkAccessForIngestion bool = true

resource appinsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: '${Prefix}-${Suffix}'
  location: Location
  kind: 'web'
  properties:{
    Application_Type: 'web'
    WorkspaceResourceId: LogWorkspaceResourceId
    publicNetworkAccessForIngestion: PublicNetworkAccessForIngestion ? 'Enabled' : 'Disabled'
    publicNetworkAccessForQuery: PublicNetworkAccessForQuery ? 'Enabled' : 'Disabled'
  }
}

output AppInsightsConnectionString string = appinsights.properties.ConnectionString
output AppInsightsInstrumentationKey string = appinsights.properties.InstrumentationKey
