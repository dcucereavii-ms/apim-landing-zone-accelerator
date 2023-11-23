@allowed([
  'new'
  'existing'
])
param newOrExistingKeyVault   string = 'existing'
param existingKvName          string 
param existingSecretName      string 
param existingKvResourceGroup string 
param newKeyVaultName         string 
param managedIdentity         object      
param managedIdentityId       string      
param location                string
param appGatewayFQDN          string


@description('Set to selfsigned if self signed certificates should be used for the Application Gateway. Set to custom and copy the pfx file to deployment/bicep/gateway/certs/appgw.pfx if custom certificates are to be used')
@allowed([
  'selfsigned'
  'custom'
])
param appGatewayCertType string = 'custom'
param scope string = newOrExistingKeyVault== 'new' ? resourceGroup().name : existingKvResourceGroup

var kvName = newOrExistingKeyVault == 'new' ? newKeyVaultName : existingKvName
var secretName = newOrExistingKeyVault == 'new'? replace(appGatewayFQDN,'.', '-') : existingSecretName
var subjectName='CN=${appGatewayFQDN}'

param subscriptionId string = subscription().subscriptionId
param resourceGroupName string



module grantAccessPolicy '../../keyvault/accessPolicy.bicep'= {
  name: 'grantAccessPolicy'
  scope: resourceGroup(scope)
  params:{
    kvName: kvName
    managedIdentity: managedIdentity
  }
}


resource appGatewayCertificate 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (newOrExistingKeyVault == 'new') {
  name: '${secretName}-certificate'
  dependsOn: [
    grantAccessPolicy
  ]
  location: location 
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '6.6'
    arguments: ' -vaultName ${newKeyVaultName} -certificateName ${secretName} -subjectName ${subjectName} -certType ${appGatewayCertType}'
    scriptContent: '''
      param(
      [string] [Parameter(Mandatory=$true)] $vaultName,
      [string] [Parameter(Mandatory=$true)] $certificateName,
      [string] [Parameter(Mandatory=$true)] $subjectName,
      [string] [Parameter(Mandatory=$true)] $certType
      )

      $ErrorActionPreference = 'Stop'
      $DeploymentScriptOutputs = @{}
      if ($certType -eq 'selfsigned') {
        $policy = New-AzKeyVaultCertificatePolicy -SubjectName $subjectName -IssuerName Self -ValidityInMonths 12 -Verbose
        
        # private key is added as a secret that can be retrieved in the ARM template
        Add-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName -CertificatePolicy $policy -Verbose
        
        $newCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name $certificateName

        # it takes a few seconds for KeyVault to finish
        $tries = 0
        do {
          Write-Host 'Waiting for certificate creation completion...'
          Start-Sleep -Seconds 10
          $operation = Get-AzKeyVaultCertificateOperation -VaultName $vaultName -Name $certificateName
          $tries++

          if ($operation.Status -eq 'failed')
          {
          throw 'Creating certificate $certificateName in vault $vaultName failed with error $($operation.ErrorMessage)'
          }

          if ($tries -gt 120)
          {
          throw 'Timed out waiting for creation of certificate $certificateName in vault $vaultName'
          }
        } while ($operation.Status -ne 'completed')		
      }
      '''
    retentionInterval: 'P1D'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/${managedIdentity.resourceId}': {}
    }
  }
}

module appGatewaySecretsUriFromNewKv 'certificateSecret.bicep' = if(newOrExistingKeyVault == 'new'){
  name: '${secretName}-certificate'
  scope: resourceGroup(scope)
  dependsOn: [
    appGatewayCertificate
  ]
  params: {
    resourceGroupName: scope
    keyVaultName: kvName
    secretName: secretName
  }
}

module appGatewaySecretsUriFromExistingKv 'certificateSecret.bicep' = if(newOrExistingKeyVault == 'existing'){
  name: secretName
  scope: resourceGroup(scope)
  params: {
    resourceGroupName: scope
    keyVaultName: kvName
    secretName: secretName
  }
}

output secretUri string = newOrExistingKeyVault == 'existing'? appGatewaySecretsUriFromExistingKv.outputs.secretUri : appGatewaySecretsUriFromNewKv.outputs.secretUri

