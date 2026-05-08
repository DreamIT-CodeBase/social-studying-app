// Azure AI Document Intelligence (formerly Form Recognizer) — extracts text and OCR
// from uploaded study materials (PDF, DOCX, images). Used by the Sprint 2.3 ingestion
// worker via the prebuilt-read model.
//
// API key stored in Key Vault, consumed by Container Apps via secret reference.
param location string
param environment string
param tags object
param keyVaultName string

var accountName = 'di-ssa-${environment}-ddjopeut37ed2'

resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: accountName
  location: location
  tags: tags
  // The Azure resource kind is still 'FormRecognizer' even though the product
  // was rebranded to Document Intelligence. The new SDK
  // (azure-ai-documentintelligence) targets the same accounts.
  kind: 'FormRecognizer'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource documentIntelligenceKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'document-intelligence-key'
  properties: {
    value: documentIntelligence.listKeys().key1
  }
}

output documentIntelligenceEndpoint string = documentIntelligence.properties.endpoint
output documentIntelligenceKeySecretUri string = documentIntelligenceKeySecret.properties.secretUriWithVersion
