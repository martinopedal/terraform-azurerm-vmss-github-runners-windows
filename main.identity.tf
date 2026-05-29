# User-Assigned Managed Identity for VMSS.
# When var.user_assigned_managed_identity_resource_id is null, module creates the UAMI.
# Otherwise the existing identity is looked up and its principalId is consumed via locals.
resource "azapi_resource" "uami_vmss_windows" {
  count = local.byo_uami ? 0 : 1

  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = "uami-${var.vmss_name}"
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  body = {}

  response_export_values = ["properties.principalId", "properties.clientId"]

  tags = var.tags
}

# Lookup for BYO UAMI - needed to resolve principalId for RBAC + VMSS identity reference.
data "azapi_resource" "byo_uami" {
  count = local.byo_uami ? 1 : 0

  type        = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  resource_id = var.user_assigned_managed_identity_resource_id

  response_export_values = ["properties.principalId", "properties.clientId"]
}

# Data source for current client config
data "azurerm_client_config" "current" {}
