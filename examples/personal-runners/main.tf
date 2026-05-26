# Example: Personal Windows GitHub Runners on VMSS

terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
  }
}

provider "azurerm" {
  features {}
}

# Reference existing subnet
data "azurerm_subnet" "runner_subnet" {
  name                 = "subnet-pool-w-personal"
  virtual_network_name = "vnet-pool-w-personal-swedencentral"
  resource_group_name  = "rg-network-pool-w-personal-swedencentral"
}

# Windows VMSS Runners module
module "windows_runners" {
  source = "git::https://github.com/martinopedal/terraform-azurerm-vmss-github-runners-windows.git?ref=v0.1.0"

  location            = "swedencentral"
  resource_group_name = "rg-pool-w-personal-swedencentral-001"
  subnet_id           = data.azurerm_subnet.runner_subnet.id

  vmss_name     = "vmss-pool-w-personal"
  vmss_sku      = "Standard_D8ds_v6"
  vmss_capacity = 1

  # GitHub configuration
  key_vault_name   = "kv-pool-w-personal-xyz"
  github_owner     = "martinopedal"
  github_repo_list = ["personal-runners-infra", "azure-analyzer"]
  runner_labels    = ["self-hosted", "personal", "windows", "x64"]

  # Priority Mix: 1 Regular base, all scale-out uses Spot
  priority_mix_base_regular_count   = 1
  priority_mix_regular_percent_base = 0

  # DSC self-heal frequency
  dsc_configuration_mode_frequency_mins = 15

  # VMSS auto-repair grace period
  auto_repair_grace_period = "PT30M"

  # Multi-zone Spot placement
  vmss_zones = ["1", "2", "3"]

  enable_telemetry = true

  tags = {
    environment = "personal"
    managed-by  = "terraform"
    lifecycle   = "permanent"
    owner       = "martinopedal"
  }
}

# Outputs
output "vmss_id" {
  description = "Resource ID of the VMSS"
  value       = module.windows_runners.vmss_id
}

output "vmss_name" {
  description = "Name of the VMSS"
  value       = module.windows_runners.vmss_name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.windows_runners.key_vault_name
}
