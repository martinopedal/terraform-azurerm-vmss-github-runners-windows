variable "subscription_id" {
  description = "Azure subscription ID where the runner VMSS will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Resource group that will host the VMSS."
  type        = string
  default     = "rg-pool-w-personal-swedencentral-001"
}

variable "subnet_name" {
  description = "Existing subnet for runner NICs."
  type        = string
  default     = "subnet-pool-w-personal"
}

variable "vnet_name" {
  description = "Existing virtual network containing the runner subnet."
  type        = string
  default     = "vnet-pool-w-personal-swedencentral"
}

variable "vnet_resource_group_name" {
  description = "Resource group containing the runner subnet's virtual network."
  type        = string
  default     = "rg-network-pool-w-personal-swedencentral"
}

variable "vmss_name" {
  description = "Name of the VMSS."
  type        = string
  default     = "vmss-pool-w-personal"
}

variable "vmss_sku" {
  description = "Azure VM SKU for runner instances."
  type        = string
  default     = "Standard_D8ds_v6"
}

variable "vmss_capacity" {
  description = "Initial number of runner instances."
  type        = number
  default     = 1
}

variable "vmss_zones" {
  description = "Availability zones for VMSS placement."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "key_vault_name" {
  description = "Existing Key Vault holding the GitHub App private key (secret name: github-app-private-key)."
  type        = string
}

variable "github_owner" {
  description = "GitHub owner (org or user) the runners register against."
  type        = string
  default     = "martinopedal"
}

variable "github_repo_list" {
  description = "Repositories the runners register against."
  type        = list(string)
}

variable "runner_labels" {
  description = "Runner labels. Canonical personal Windows scheme is the 2-label compound [self-hosted, personal-windows]."
  type        = list(string)
  default     = ["self-hosted", "personal-windows"]
}

variable "priority_mix_base_regular_count" {
  description = "Number of always-on Regular VMs. Spot fills the rest."
  type        = number
  default     = 1
}

variable "priority_mix_regular_percent_base" {
  description = "Percent of scale-out capacity that is Regular (0 = all Spot beyond the base)."
  type        = number
  default     = 0
}

variable "dsc_configuration_mode_frequency_mins" {
  description = "DSC LCM consistency-check interval (minutes)."
  type        = number
  default     = 15
}

variable "auto_repair_grace_period" {
  description = "VMSS auto-repair grace period (ISO 8601 duration)."
  type        = string
  default     = "PT30M"
}

variable "enable_telemetry" {
  description = "AVM telemetry flag — leave true unless your org policy disallows it."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    environment = "personal"
    managed-by  = "terraform"
    lifecycle   = "permanent"
    owner       = "martinopedal"
  }
}
