# User-Assigned Managed Identity for VMSS
resource "azapi_resource" "uami_vmss_windows" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  name      = "uami-${var.vmss_name}"
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  body = {}

  tags = var.tags
}

# Data source for current client config
data "azurerm_client_config" "current" {}

# Data source for UAMI identity (needed for outputs)
data "azurerm_user_assigned_identity" "vmss_windows" {
  name                = azapi_resource.uami_vmss_windows.name
  resource_group_name = var.resource_group_name

  depends_on = [azapi_resource.uami_vmss_windows]
}
