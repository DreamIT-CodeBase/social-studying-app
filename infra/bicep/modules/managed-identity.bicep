// User-assigned managed identity — attached to the Container App so it can
// authenticate to Key Vault, ACR, Service Bus, and Storage without secrets.
param location string
param environment string
param tags object

var identityName = 'id-socialstudyapp-${environment}'

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

output identityId string = identity.id
output identityClientId string = identity.properties.clientId
output identityPrincipalId string = identity.properties.principalId
