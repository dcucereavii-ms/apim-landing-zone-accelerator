param existingSecretName string 
param existingKvName string 
param existingKvResourceGroup string
param newKvName string
param appGwManagedIdentity object
param appGatewayFQDN string
param appGatewayCertType string 
param location string 

param newOrExisting string 
param identityResourceGroupName string

var secretName = replace(appGatewayFQDN,'.', '-')

resource key_vault_existing 'Microsoft.KeyVault/vaults@2019-09-01' existing  ={
  name: existingKvName
  scope: resourceGroup(existingKvResourceGroup)
}

module kvCertificate '../gateway/modules/certificate.bicep'={
  name: existingSecretName
  params: {
    existingSecretName: existingSecretName
    existingKvName: existingKvName
    existingKvResourceGroup: existingKvResourceGroup
    appGatewayCertType: appGatewayCertType
    appGatewayFQDN: appGatewayFQDN
    managedIdentity: appGwManagedIdentity
    location: location
    newOrExistingKeyVault: newOrExisting
    newKeyVaultName: newKvName
    resourceGroupName: identityResourceGroupName
    managedIdentityId: appGwManagedIdentity.id
  }
  dependsOn: [
    key_vault_existing
  ]
}


