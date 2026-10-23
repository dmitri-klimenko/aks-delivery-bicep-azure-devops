using './main.bicep'

// Public federation identifiers for the current TEST deployment.
// Recreate the connection and replace these values for another project/tenant.
param location = 'northeurope'
param pipelinePrincipalId = '65266025-bfd7-46db-a186-fa37bd30fc2b'
param enableAks = true
param aksLocation = 'swedencentral'
param aksNodeVmSize = 'Standard_D4s_v6'
param federatedIssuer = 'https://login.microsoftonline.com/cf91a88a-1e10-4224-9b97-ed7564b4d4e3/v2.0'
param federatedSubject = '/eid1/c/pub/t/iqiRzxAeJEKbl-11ZLTU4w/a/rISbSSETf0KqFyZ8ppdXmA/sc/7992b5f3-b6d1-4b38-81d4-a4ae769f168f/f57fa2ce-28de-4a41-8aa0-1376513c3187'
