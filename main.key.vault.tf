# Key Vault for GitHub App private key storage
resource "azapi_resource" "key_vault_vmss_windows" {
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = var.key_vault_name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  body = {
    properties = {
      sku = {
        family = "A"
        name   = "standard"
      }
      tenantId                  = data.azurerm_client_config.current.tenant_id
      enableRbacAuthorization   = true
      enableSoftDelete          = true
      softDeleteRetentionInDays = 7
      enablePurgeProtection     = false
      publicNetworkAccess       = "Disabled"
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Deny"
      }
    }
  }

  tags = var.tags

  depends_on = [azapi_resource.uami_vmss_windows]
}

# RBAC: Grant UAMI Key Vault Secrets User on the Key Vault
resource "azapi_resource" "rbac_kv_secrets_user" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${azapi_resource.key_vault_vmss_windows.id}/${azapi_resource.uami_vmss_windows.identity[0].principal_id}/4633458b-17de-408a-b874-0445c86b69e6")
  parent_id = azapi_resource.key_vault_vmss_windows.id

  body = {
    properties = {
      roleDefinitionId = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
      principalId      = azapi_resource.uami_vmss_windows.identity[0].principal_id
      principalType    = "ServicePrincipal"
    }
  }

  depends_on = [
    azapi_resource.key_vault_vmss_windows,
    azapi_resource.uami_vmss_windows
  ]
}
