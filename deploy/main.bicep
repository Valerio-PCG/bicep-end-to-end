@description('The location into which your Azure resources should be deployed.')
param location string = resourceGroup().location

@description('Select the type of environment you want to provision. Allowed values are Production and Test.')
@allowed([
  'Production'
  'Test'
])
param environmentType string

@description('A unique suffix to add to resource names that need to be globally unique.')
@maxLength(13)
param resourceNameSuffix string = uniqueString(resourceGroup().id)

@description('The URL to the product review API.')
param reviewApiUrl string

@secure()
@description('The API key to use when accessing the product review API.')
param reviewApiKey string

@secure()
param sqlServerAdminLogin string

@secure()
param sqlServerAdminLoginPassword string

// Define the names for resources.
var appServiceAppName = 'toy-website-${resourceNameSuffix}'
var appServicePlanName = 'toy-website'
var logAnalyticsWorkspaceName = 'workspace-${resourceNameSuffix}'
var applicationInsightsName = 'toywebsite'
var storageAccountName = 'mystorage${resourceNameSuffix}'
var storageAccountImagesBlobContainerName = 'toyimages'

var sqlServerName = 'toy-website-${resourceNameSuffix}'
var sqlDatabaseName = 'Toys'
var sqlDatabaseConnectionString = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Persist Security Info=False;User ID=${sqlServerAdminLogin};Password=${sqlServerAdminLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

// Define the SKUs for each component based on the environment type.
var environmentConfigurationMap = {
  Production: {
    appServicePlan: {
      sku: {
        name: 'D1'
        capacity: 1
      }
    }
    storageAccount: {
      sku: {
        name: 'Standard_LRS'
      }
    }
    sqlDatabase: {
      sku: {
        name: 'Standard'
        tier: 'Standard'
      }
    }
  }
  Test: {
    appServicePlan: {
      sku: {
        name: 'F1'
      }
    }
    storageAccount: {
      sku: {
        name: 'Standard_LRS'
      }
    }
    sqlDatabase: {
      sku: {
        name: 'Standard'
        tier: 'Standard'
      }
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: environmentConfigurationMap[environmentType].appServicePlan.sku
}

resource appServiceApp 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v6.0'
      connectionStrings: [
        {
          connectionString: sqlDatabaseConnectionString
          name: 'SqlDatabaseConnectionString'
          type: 'SQLServer'
        }
      ]
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'ReviewApiUrl'
          value: reviewApiUrl
        }
        {
          name: 'ReviewApiKey'
          value: reviewApiKey
        }
        {
          name: 'StorageAccountName'
          value: storageAccount.name
        }
        {
          name: 'StorageAccountBlobEndpoint'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'StorageAccountImagesContainerName'
          value: storageAccount::blobServices::storageAccountImagesBlobContainer.name
        }
        {
          name: 'SqlDatabaseConnectionString'
          value: sqlDatabaseConnectionString
        }
      ]
    }
  }
}

resource appServiceConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appServiceApp
  name: 'metadata'
  properties: {
    CURRENT_STACK: 'dotnetcore'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    Flow_Type: 'Bluefield'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: environmentConfigurationMap[environmentType].storageAccount.sku

  resource blobServices 'blobServices' = {
    name: 'default'

    resource storageAccountImagesBlobContainer 'containers' = {
      name: storageAccountImagesBlobContainerName

      properties: {
        publicAccess: 'Blob'
      }
    }
  }
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlServerAdminLogin
    administratorLoginPassword: sqlServerAdminLoginPassword
  }
}

resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: environmentConfigurationMap[environmentType].sqlDatabase.sku
}

output appServiceAppName string = appServiceApp.name
output appServiceAppHostName string = appServiceApp.properties.defaultHostName

output storageAccountName string = storageAccount.name
output storageAccountImagesBlobContainerName string = storageAccount::blobServices::storageAccountImagesBlobContainer.name

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name
