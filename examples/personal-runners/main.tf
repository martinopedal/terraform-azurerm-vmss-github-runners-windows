data "azurerm_subnet" "runner_subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

module "windows_runners" {
  source = "../../"
  # In real consumers, pin to a tag instead of the relative path:
  # source = "git::https://github.com/martinopedal/terraform-azurerm-vmss-github-runners-windows.git?ref=v0.1.0"

  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = data.azurerm_subnet.runner_subnet.id

  vmss_name     = var.vmss_name
  vmss_sku      = var.vmss_sku
  vmss_capacity = var.vmss_capacity
  vmss_zones    = var.vmss_zones

  key_vault_name   = var.key_vault_name
  github_owner     = var.github_owner
  github_repo_list = var.github_repo_list
  runner_labels    = var.runner_labels

  priority_mix_base_regular_count   = var.priority_mix_base_regular_count
  priority_mix_regular_percent_base = var.priority_mix_regular_percent_base

  dsc_configuration_mode_frequency_mins = var.dsc_configuration_mode_frequency_mins
  auto_repair_grace_period              = var.auto_repair_grace_period

  enable_telemetry = var.enable_telemetry
  tags             = var.tags
}
