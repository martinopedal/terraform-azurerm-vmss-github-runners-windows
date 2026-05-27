data "azurerm_subnet" "runner_subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

module "windows_runners" {
  source = "../../"
  # In real consumers, pin to a tag instead of the relative path:
  # source = "git::https://github.com/martinopedal/terraform-azurerm-vmss-github-runners-windows.git?ref=v1.0.0"

  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = data.azurerm_subnet.runner_subnet.id

  vmss_name     = var.vmss_name
  vmss_sku      = var.vmss_sku
  vmss_capacity = var.vmss_capacity
  vmss_zones    = var.vmss_zones

  key_vault_name       = var.key_vault_name
  github_owner         = var.github_owner
  github_repo_list     = var.github_repo_list
  bootstrap_script_url = var.bootstrap_script_url
  runner_labels        = var.runner_labels

  priority_mix_base_regular_count            = var.priority_mix_base_regular_count
  priority_mix_regular_percentage_above_base = var.priority_mix_regular_percentage_above_base

  dsc_configuration_mode_frequency_mins  = var.dsc_configuration_mode_frequency_mins
  automatic_instance_repair_grace_period = var.automatic_instance_repair_grace_period

  enable_telemetry = var.enable_telemetry
  tags             = var.tags
}

