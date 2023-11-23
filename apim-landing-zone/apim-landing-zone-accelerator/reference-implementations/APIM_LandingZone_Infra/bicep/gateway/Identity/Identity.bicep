param appGatewayName string
param location string = resourceGroup().location

var appGatewayIdentityId = 'identity-${appGatewayName}'

resource appGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name:     appGatewayIdentityId
  location: location
}
output appGatewayIdentity object = appGatewayIdentity
output appGatewayIdentityId string = appGatewayIdentity.id





