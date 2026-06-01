# Key Vault for GitHub App private key storage.
# When var.key_vault_resource_id is null, module creates the KV using var.key_vault_name.
# Otherwise the existing KV is consumed via locals.kv_id / locals.kv_name.
resource "azapi_resource" "key_vault_vmss_windows" {
  count = local.byo_kv ? 0 : 1

  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  name      = var.key_vault_name
  location  = var.location
  parent_id = "/subscriptions/${local.subscription_id}/resourceGroups/${var.resource_group_name}"

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
      enablePurgeProtection     = var.key_vault_purge_protection_enabled
      publicNetworkAccess       = "Disabled"
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Deny"
        ipRules       = [for ip in var.key_vault_allowed_ip_ranges : { value = ip }]
      }
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.key_vault_name != null
      error_message = "key_vault_name is required when key_vault_resource_id is null (module is creating the Key Vault)."
    }
    # ipRules are managed out-of-band by the consumer (e.g. bridge runner IP grants)
    # because the deploy SP often runs from a public IP that must be allowlisted after KV create.
    ignore_changes = [
      body.properties.networkAcls.ipRules,
      body.properties.networkAcls.virtualNetworkRules,
      body.properties.publicNetworkAccess,
    ]
  }
}

# RBAC: Grant UAMI Key Vault Secrets User on the effective Key Vault (BYO or module-created).
# Always applied so the runner can read its registration secret. When BYO KV is used, the
# caller's identity needs Microsoft.Authorization/roleAssignments/write on the BYO KV.
resource "azapi_resource" "rbac_kv_secrets_user" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${local.kv_id}/${local.uami_principal_id}/4633458b-17de-408a-b874-0445c86b69e6")
  parent_id = local.kv_id

  body = {
    properties = {
      roleDefinitionId = "/subscriptions/${local.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
      principalId      = local.uami_principal_id
      principalType    = "ServicePrincipal"
    }
  }

  depends_on = [
    azapi_resource.key_vault_vmss_windows,
    azapi_resource.uami_vmss_windows,
    data.azapi_resource.byo_uami,
  ]
}

# State migration for existing consumers: the count-ified resources change addresses.
moved {
  from = azapi_resource.key_vault_vmss_windows
  to   = azapi_resource.key_vault_vmss_windows[0]
}

moved {
  from = azapi_resource.uami_vmss_windows
  to   = azapi_resource.uami_vmss_windows[0]
}
