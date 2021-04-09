param Prefix string = resourceGroup().name
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

var saname = '${toLower(replace(replace(Prefix,'_',''),'-',''))}diag'

resource sa 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: saname
  location: Location
  kind:'StorageV2'
  sku:{
    name: DiagnosticStorageSku
    tier:'Standard'
  }
  properties:{
    allowBlobPublicAccess: false    
    minimumTlsVersion:'TLS1_2'
    supportsHttpsTrafficOnly:true
    networkAcls:{
      bypass:'AzureServices'
      defaultAction: PublicNetworkAccessForQuery ? 'Allow' : 'Deny'
      virtualNetworkRules:[for subnet in AllowedSubnetResourceId:{
          action:'Allow'
          id: subnet
        }]
    }
  }
}

resource saBlobs 'Microsoft.Storage/storageAccounts/blobServices@2021-01-01' = {
  parent: sa
  name: 'default'
  properties:{
    lastAccessTimeTrackingPolicy: {
      enable: true
    }
  }
}

resource archivePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2021-01-01' = {
  parent: sa
  name: 'default'
  properties:{
    policy:{
      rules:[
        {
          name: 'MigrateToCold'
          enabled: true
          type: 'Lifecycle'
          definition:{
            filters:{
              blobTypes:[
                'blockBlob'
              ]
              prefixMatch:[
                '/'
              ]
            }
            actions:{
              baseBlob:{                
                enableAutoTierToHotFromCool:true
                tierToCool:{
                  daysAfterLastAccessTimeGreaterThan: LogWorkspaceRetentionDays
                }
              }
            }
          }
        }
        {
          name: 'Delete'
          enabled: true
          type: 'Lifecycle'
          definition:{
            filters:{
              blobTypes:[
                'blockBlob'
              ]
              prefixMatch:[
                '/'
              ]
            }
            actions:{
              snapshot:{
                delete:{
                  daysAfterCreationGreaterThan: DiagnosticStorageRetentionDays
                }
              }
              version:{
                delete:{
                  daysAfterCreationGreaterThan: DiagnosticStorageRetentionDays
                }
              }
              baseBlob:{
                delete:{
                  daysAfterModificationGreaterThan: DiagnosticStorageRetentionDays
                }
              }
            }
          }
        }
      ]
    }
  }
}

resource logworkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: Prefix
  location: Location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: LogWorkspaceRetentionDays
    publicNetworkAccessForIngestion: PublicNetworkAccessForIngestion ? 'Enabled' : 'Disabled'
    publicNetworkAccessForQuery: PublicNetworkAccessForQuery ? 'Enabled' : 'Disabled'
  }
}

resource logWorkspaceSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for solution in Solutions: {
  name: '${solution}(${Prefix})'
  location: Location
  plan:{
    name:'VMInsights(${Prefix})'
    product: 'OMSGallery/${solution}'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  properties:{
    workspaceResourceId: logworkspace.id
  }
}]

resource logworkspaceIISLogs 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: logworkspace
  name: 'default'
  kind:'IISLogs'
  properties: {
    state: 'OnPremiseEnabled'     
  }
}

resource logworkspaceEventsSystem 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: logworkspace
  name: 'WindowsEventsSystem'
  kind:'WindowsEvent'
  properties: {
    eventLogName: 'System'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  } 
}

resource logworkspaceEventsApplication 'Microsoft.OperationalInsights/workspaces/dataSources@2020-08-01' = {
  parent: logworkspace
  name: 'WindowsEventsApplication'
  kind:'WindowsEvent'
  properties: {
    eventLogName: 'Application'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
      {
        eventType: 'Information'
      }
    ]
  } 
}

/* Might be for customer-managed encryption only? Seems like it has side effects!
// see: https://docs.microsoft.com/en-us/azure/azure-monitor/logs/private-storage
var sa_link_names = [
  'Alerts'
  'AzureWatson'
  'Query'
  'CustomLogs'
]

resource logworkspaceStorageLink 'Microsoft.OperationalInsights/workspaces/linkedStorageAccounts@2020-08-01' = [for Link in sa_link_names: {
  name: any('${Prefix}/${Link}')
  dependsOn:[
    logworkspace
  ]
  properties:{
    storageAccountIds:[
      sa.id
    ]
  }
}]
*/

output StorageAccountName string = saname
output StorageAccountResourceId string = sa.id
output LogWorkspaceResourceId string = logworkspace.id
output LogWorkspaceId string = logworkspace.properties.customerId
