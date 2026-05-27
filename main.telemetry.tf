# AVM telemetry compliance
resource "azapi_resource" "telemetry" {
  count = var.enable_telemetry ? 1 : 0

  type      = "Microsoft.Resources/deployments@2021-04-01"
  name      = "46d3xgtm.ptn-cicd-vmss-windows"
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  body = {
    properties = {
      mode = "Incremental"
      template = {
        "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
        contentVersion = "1.0.0.0"
        resources      = []
        outputs = {
          telemetry = {
            type  = "String"
            value = "For more information, see https://aka.ms/avm/TelemetryInfo"
          }
        }
      }
    }
  }
}
