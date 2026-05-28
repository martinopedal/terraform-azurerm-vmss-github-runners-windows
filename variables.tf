variable "enable_telemetry" {
  description = "This variable controls whether or not telemetry is enabled for the module. For more information see https://aka.ms/avm/telemetryinfo. If it is set to false, then no telemetry will be collected."
  type        = bool
  default     = true
}

variable "location" {
  description = "Azure region where the VMSS should be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where VMSS instances will be deployed"
  type        = string
}

variable "bootstrap_script_url" {
  description = "HTTPS URL for scripts/register-windows-runner.ps1. Pin this to a release tag in consumers. Mutually exclusive with bootstrap_script_inline_base64; one of the two must be set."
  type        = string
  default     = null
}

variable "bootstrap_script_inline_base64" {
  description = "Optional inline bootstrap script (base64-encoded UTF-8 of register-windows-runner.ps1). When set, the script is delivered via VMSS userData and decoded by the CSE at boot, avoiding any HTTPS fetch. Mutually exclusive with bootstrap_script_url."
  type        = string
  default     = null
}

variable "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  type        = string
}

variable "vmss_sku" {
  description = "VM SKU for the VMSS instances (e.g., Standard_D8ds_v6)"
  type        = string
  default     = "Standard_D8ds_v6"
}

variable "vmss_capacity" {
  description = "Initial capacity for the VMSS"
  type        = number
  default     = 1
}

variable "vmss_zones" {
  description = "Availability zones for the VMSS (for Spot capacity resilience)"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "key_vault_name" {
  description = "Name of the Key Vault to create for GitHub App private key storage. Required when key_vault_resource_id is null. Ignored when BYO Key Vault is supplied."
  type        = string
  default     = null
}

variable "key_vault_resource_id" {
  description = "Optional resource ID of an existing Key Vault to use instead of creating one. When set, the module skips KV creation and only assigns the UAMI the Key Vault Secrets User role on this vault."
  type        = string
  default     = null
}

variable "key_vault_purge_protection_enabled" {
  description = "Whether to enable purge protection on the module-created Key Vault. Ignored when a BYO Key Vault is supplied. Defaults to true for production hardening; set to false in ephemeral/test environments where vaults need to be hard-deleted."
  type        = bool
  default     = true
}

variable "user_assigned_managed_identity_resource_id" {
  description = "Optional resource ID of an existing User-Assigned Managed Identity. When set, the module skips UAMI creation and attaches this identity to the VMSS instead, looking up its principalId for RBAC."
  type        = string
  default     = null
}

variable "windows_image_sku" {
  description = "Windows Server image SKU. Use '2025-datacenter-azure-edition' when enable_hotpatching = true."
  type        = string
  default     = "2022-datacenter-azure-edition"
}

variable "enable_hotpatching" {
  description = "Enable Windows Server hotpatching. Requires windows_image_sku to include '2025-datacenter-azure-edition'. When true, patchMode is set to AutomaticByPlatform and hotpatching is enabled on the VMSS patchSettings."
  type        = bool
  default     = false
}

variable "github_owner" {
  description = "GitHub owner (org or user)"
  type        = string
}

variable "github_repo_list" {
  description = "List of repositories for runner registration (comma-separated in CSE)"
  type        = list(string)
}

variable "runner_labels" {
  description = "Labels for the GitHub runner"
  type        = list(string)
  default     = ["self-hosted", "windows", "x64"]
}

variable "runner_version" {
  description = "GitHub Actions runner version"
  type        = string
  default     = "2.319.1"
}

variable "admin_username" {
  description = "Local administrator username for VMSS provisioning. Password authentication should remain inaccessible from the network."
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Optional local administrator password. If null, the module generates one."
  type        = string
  default     = null
  sensitive   = true
}

variable "priority_mix_base_regular_count" {
  description = "Number of Regular (non-Spot) instances in the base capacity"
  type        = number
  default     = 1
}

variable "priority_mix_regular_percentage_above_base" {
  description = "Percentage of Regular instances above base (0 = all Spot)"
  type        = number
  default     = 0
}

variable "eviction_policy" {
  description = "Eviction policy for Spot instances (Delete or Deallocate)"
  type        = string
  default     = "Delete"
}

variable "max_bid_price" {
  description = "Maximum price for Spot instances (-1 = pay up to on-demand)"
  type        = number
  default     = -1
}

variable "disk_controller_type" {
  description = "Disk controller type (SCSI or NVMe)"
  type        = string
  default     = "NVMe"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "os_disk_storage_account_type" {
  description = "OS disk storage type (StandardSSD_LRS, Premium_LRS, etc.)"
  type        = string
  default     = "StandardSSD_LRS"
}

variable "automatic_instance_repair_grace_period" {
  description = "Grace period for automatic instance repair (ISO 8601 duration)"
  type        = string
  default     = "PT30M"
}

variable "dsc_configuration_mode_frequency_mins" {
  description = "DSC LCM consistency check frequency in minutes"
  type        = number
  default     = 15
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
