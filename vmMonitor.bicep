param Location string = resourceGroup().location
param VMName string
param StorageAccountResourceId string
param LogWorkspaceResourceId string
param ApplicationInsightsInstrumentationKey string
param UseProxyServer bool = false

resource vm 'Microsoft.Compute/virtualMachines@2020-12-01' existing = {
  name: VMName  
}

var logworkspace = reference(LogWorkspaceResourceId,'2020-03-01-preview')
var sa           = reference(StorageAccountResourceId,'2019-06-01')
var saname       = split(StorageAccountResourceId,'/')[8]

// TIP: http://azure.github.io/azure-diagnostics-tools/config-builder/#
resource vmWAD 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: vm
  location: Location
  name: 'Microsoft.Insights.VMDiagnosticsSettings'
  properties:{
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Diagnostics'
    type: 'IaaSDiagnostics'
    typeHandlerVersion:'1.5'
    settings: {
      StorageAccount: saname
      WadCfg: {
        StorageAccount: saname
        DiagnosticMonitorConfiguration: {
          overallQuotaInMB: 4096
          useProxyServer: UseProxyServer
          eventVolume: 'Small'
          Metrics: {
            resourceId: vm.id
            MetricAggregation: [
              {
                scheduledTransferPeriod: 'PT1H'
              }
              {
                scheduledTransferPeriod: 'PT1M'
              }
            ]
          }
          PerformanceCounters: {
            scheduledTransferPeriod: 'PT1M'
            PerformanceCounterConfiguration: PerformanceCounterConfiguration
            sinks: 'AzureMonitor'
          }
          DiagnosticInfrastructureLogs: {
            scheduledTransferLogLevelFilter: 'Warning'
            scheduledTransferPeriod: 'PT1M'
          }
          Directories: {
            scheduledTransferPeriod: 'PT1M'
          }
          WindowsEventLog: {
            scheduledTransferPeriod: 'PT1M'
            DataSource: [
              {
                name: 'Application!*[System[(Level=1 or Level=2 or Level=3)]]'
              }
              {
                name: 'System!*[System[(Level=1 or Level=2 or Level=3)]]'
              }
              {
                name: 'Security!*[System[(band(Keywords,4503599627370496))]]'
              }
            ]
          }
          CrashDumps: {
            CrashDumpConfiguration: [
              {
                processName: 'w3wp'
              }
            ]
            ContainerName: 'crashdumps'
            DumpType: 'Full'
          }
          Logs: {
            scheduledTransferLogLevelFilter: 'Undefined'
            scheduledTransferPeriod: 'PT1M'
          }
          sinks: 'applicationInsights'
        }
        SinksConfig: {
          Sink: [
            {
              name: 'applicationInsights'
              ApplicationInsights: ApplicationInsightsInstrumentationKey
            }
            {
              name: 'applicationInsightsProfiler'
              ApplicationInsightsProfiler: ApplicationInsightsInstrumentationKey
            }
            {
              AzureMonitor: {}
              name: 'AzureMonitor'
            }
          ]
        }
      }     
    }
    protectedSettings:{
      storageAccountName: saname
      storageAccountKey: listKeys(StorageAccountResourceId, '2015-05-01-preview').key1
      storageAccountEndPoint: 'https://core.windows.net'
    }
  }
}

resource vmMMA 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: vm
  location: Location
  name: 'MicrosoftMonitoringAgent'
  properties:{
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: logworkspace.customerId
    }
    protectedSettings: {
      workspaceKey: listKeys(LogWorkspaceResourceId, '2015-03-20').primarySharedKey
    }
  }
}

resource vmDependency 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: vm
  location: Location
  name: 'DAExtension'
  properties:{
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentWindows'
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
}

resource vmAppInsights 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: vm
  location: Location
  name: 'ApplicationMonitoring'
  properties:{
    publisher: 'Microsoft.Azure.Diagnostics'
    type: 'ApplicationMonitoringWindows'
    typeHandlerVersion: '2.8'
    autoUpgradeMinorVersion: true
    settings: {
      redfieldConfiguration: {
        instrumentationKeyMap: {
          filters: [
            {
              appFilter: '.*'
              machineFilter: '.*'
              virtualPathFilter: '.*'
              instrumentationSettings: {
                connectionString: 'InstrumentationKey=${ApplicationInsightsInstrumentationKey}'
              }
            }
          ]
        }
      }
    }
  }
}

// Not verbose at all...
var PerformanceCounterConfiguration =  [
  {
    counterSpecifier: '\\Processor Information(_Total)\\% Processor Time'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Processor Information(_Total)\\% Privileged Time'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Processor Information(_Total)\\% User Time'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Processor Information(_Total)\\Processor Frequency'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\System\\Processes'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(_Total)\\Thread Count'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(_Total)\\Handle Count'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\System\\System Up Time'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\System\\Context Switches/sec'
    unit: 'CountPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\System\\Processor Queue Length'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Memory\\% Committed Bytes In Use'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Memory\\Available Bytes'
    unit: 'Bytes'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Memory\\Committed Bytes'
    unit: 'Bytes'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Memory\\Cache Bytes'
    unit: 'Bytes'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Memory\\Pool Paged Bytes'
    unit: 'Bytes'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Memory\\Pool Nonpaged Bytes'
    unit: 'Bytes'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Memory\\Pages/sec'
    unit: 'CountPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Memory\\Page Faults/sec'
    unit: 'CountPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(_Total)\\Working Set'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(_Total)\\Working Set - Private'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\% Disk Time'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\% Disk Read Time'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\% Disk Write Time'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\% Idle Time'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Disk Bytes/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Disk Read Bytes/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Disk Write Bytes/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Disk Transfers/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Disk Reads/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Disk Writes/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Avg. Disk sec/Transfer'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Avg. Disk sec/Read'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Avg. Disk sec/Write'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Avg. Disk Queue Length'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Avg. Disk Read Queue Length'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Avg. Disk Write Queue Length'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\% Free Space'
    unit: 'Percent'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\LogicalDisk(_Total)\\Free Megabytes'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Network Interface(*)\\Bytes Total/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Network Interface(*)\\Bytes Sent/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Network Interface(*)\\Bytes Received/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Network Interface(*)\\Packets/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Network Interface(*)\\Packets Sent/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Network Interface(*)\\Packets Received/sec'
    unit: 'BytesPerSecond'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Network Interface(*)\\Packets Outbound Errors'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Network Interface(*)\\Packets Received Errors'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Exceptions(w3wp)\\# of Exceps Thrown / sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Interop(w3wp)\\# of marshalling'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Jit(w3wp)\\% Time in Jit'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Loading(w3wp)\\Current appdomains'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Loading(w3wp)\\Current Assemblies'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Loading(w3wp)\\% Time Loading'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Loading(w3wp)\\Bytes in Loader Heap'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR LocksAndThreads(w3wp)\\Contention Rate / sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR LocksAndThreads(w3wp)\\Current Queue Length'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Memory(w3wp)\\# Gen 0 Collections'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Memory(w3wp)\\# Gen 1 Collections'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Memory(w3wp)\\# Gen 2 Collections'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Memory(w3wp)\\% Time in GC'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Memory(w3wp)\\# Bytes in all Heaps'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Networking(w3wp)\\Connections Established'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Networking 4.0.0.0(w3wp)\\Connections Established'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\.NET CLR Remoting(w3wp)\\Remote Calls/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Application Restarts'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Applications Running'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Requests Current'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Request Execution Time'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Requests Queued'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Requests Rejected'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Request Wait Time'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Requests Disconnected'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Worker Processes Running'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET\\Worker Process Restarts'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Application Restarts'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Applications Running'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Requests Current'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Request Execution Time'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Requests Queued'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Requests Rejected'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Request Wait Time'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Requests Disconnected'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Worker Processes Running'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET v4.0.30319\\Worker Process Restarts'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Anonymous Requests'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Anonymous Requests/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache Total Entries'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache Total Turnover Rate'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache Total Hits'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache Total Misses'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache Total Hit Ratio'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache API Entries'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache API Turnover Rate'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache API Hits'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache API Misses'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Cache API Hit Ratio'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Output Cache Entries'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Output Cache Turnover Rate'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Output Cache Hits'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Output Cache Misses'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Output Cache Hit Ratio'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Compilations Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Debugging Requests'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Errors During Preprocessing'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Errors During Compilation'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Errors During Execution'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Errors Unhandled During Execution'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Errors Unhandled During Execution/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Errors Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Errors Total/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Pipeline Instance Count'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Request Bytes In Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Request Bytes Out Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests Executing'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests Failed'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests Not Found'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests Not Authorized'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests In Application Queue'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests Timed Out'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests Succeeded'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Requests/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Sessions Active'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Sessions Abandoned'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Sessions Timed Out'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Sessions Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Transactions Aborted'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Transactions Committed'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Transactions Pending'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Transactions Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Applications(__Total__)\\Transactions/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Anonymous Requests'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Anonymous Requests/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache Total Entries'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache Total Turnover Rate'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache Total Hits'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache Total Misses'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache Total Hit Ratio'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache API Entries'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache API Turnover Rate'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache API Hits'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache API Misses'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Cache API Hit Ratio'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Output Cache Entries'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Output Cache Turnover Rate'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Output Cache Hits'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Output Cache Misses'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Output Cache Hit Ratio'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Compilations Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Debugging Requests'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Errors During Preprocessing'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Errors During Compilation'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Errors During Execution'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Errors Unhandled During Execution'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Errors Unhandled During Execution/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Errors Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Errors Total/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Pipeline Instance Count'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Request Bytes In Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Request Bytes Out Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests Executing'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests Failed'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests Not Found'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests Not Authorized'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests In Application Queue'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests Timed Out'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests Succeeded'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Requests/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Sessions Active'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Sessions Abandoned'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Sessions Timed Out'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Sessions Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Transactions Aborted'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Transactions Committed'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Transactions Pending'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Transactions Total'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\ASP.NET Apps v4.0.30319(__Total__)\\Transactions/Sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(w3wp)\\% Processor Time'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(w3wp)\\Virtual Bytes'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(w3wp)\\Private Bytes'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(w3wp)\\Thread Count'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Process(w3wp)\\Handle Count'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Web Service(_Total)\\Bytes Total/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Web Service(_Total)\\Current Connections'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Web Service(_Total)\\Total Method Requests/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\Web Service(_Total)\\ISAPI Extension Requests/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:Buffer Manager\\Page reads/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:Buffer Manager\\Page writes/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:Buffer Manager\\Checkpoint pages/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:Buffer Manager\\Lazy writes/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:Buffer Manager\\Buffer cache hit ratio'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:Buffer Manager\\Database pages'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:Memory Manager\\Total Server Memory (KB)'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:Memory Manager\\Memory Grants Pending'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:General Statistics\\User Connections'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:SQL Statistics\\Batch Requests/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:SQL Statistics\\SQL Compilations/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
  {
    counterSpecifier: '\\SQLServer:SQL Statistics\\SQL Re-Compilations/sec'
    unit: 'Count'
    sampleRate: 'PT60S'
  }
]
