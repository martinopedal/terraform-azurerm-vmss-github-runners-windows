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

variable "subscription_id" {
  description = "Subscription ID used to compose resource parent_id values. When set to a non-empty value it is used directly so parent_id is known at plan time. This avoids a spurious azapi ForceNew (VMSS/UAMI replacement) when the azurerm provider defers data.azurerm_client_config to apply — e.g. under OIDC auth on CI runners, where object_id resolution makes the whole data source known-after-apply. Defaults to the provider's client_config subscription for backward compatibility."
  type        = string
  default     = ""
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
  description = "Optional resource ID of an existing Key Vault to use instead of creating one. When set, the module skips KV creation and only assigns the UAMI the Key Vault Secrets User role on this vault. If this references a resource created in the same apply (unknown at plan time), you MUST also set create_key_vault = false."
  type        = string
  default     = null
}

variable "create_key_vault" {
  description = "Whether the module should create the Key Vault. Defaults to null which auto-detects from key_vault_resource_id (null => create). Set explicitly to false when key_vault_resource_id is an unknown-at-plan-time reference (e.g. azurerm_key_vault.x.id created in the same root)."
  type        = bool
  default     = null
}

variable "key_vault_purge_protection_enabled" {
  description = "Whether to enable purge protection on the module-created Key Vault. Ignored when a BYO Key Vault is supplied. Defaults to true for production hardening; set to false in ephemeral/test environments where vaults need to be hard-deleted."
  type        = bool
  default     = true
}

variable "user_assigned_managed_identity_resource_id" {
  description = "Optional resource ID of an existing User-Assigned Managed Identity. When set, the module skips UAMI creation and attaches this identity to the VMSS instead, looking up its principalId for RBAC. If this references a resource created in the same apply (unknown at plan time), you MUST also set create_user_assigned_managed_identity = false."
  type        = string
  default     = null
}

variable "create_user_assigned_managed_identity" {
  description = "Whether the module should create the UAMI. Defaults to null which auto-detects from user_assigned_managed_identity_resource_id (null => create). Set explicitly to false when the supplied resource id is unknown at plan time."
  type        = bool
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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "orchestration_mode" {
  description = "VMSS orchestration mode. 'Uniform' (default) is the classic mode and matches v1.1.0 behavior. 'Flexible' uses individual VMs underneath, supports mixing fault domains, and is required by some consumer scenarios (e.g. personal pool-w-pub). Immutable after VMSS creation - changing this value triggers destroy/recreate."
  type        = string
  default     = "Uniform"
  validation {
    condition     = contains(["Uniform", "Flexible"], var.orchestration_mode)
    error_message = "orchestration_mode must be either 'Uniform' or 'Flexible'."
  }
}

variable "auth_method" {
  description = "Runner registration authentication method. 'app' uses a GitHub App private key stored in Key Vault to mint installation + registration tokens at boot. 'pat' uses a Personal Access Token stored in Key Vault as the registration credential. App auth is preferred for org-scoped pools; PAT is simpler for personal repo pools."
  type        = string
  default     = "app"
  validation {
    condition     = contains(["app", "pat"], var.auth_method)
    error_message = "auth_method must be either 'app' or 'pat'."
  }
}

variable "github_app_id" {
  description = "GitHub App ID. Required when auth_method = 'app'. The App must be installed on github_owner and have Actions:read+write + Administration:read+write permissions on github_repo_list."
  type        = number
  default     = null
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID for github_owner. Required when auth_method = 'app'. Find via: GET /users/{owner}/installation or /orgs/{owner}/installation."
  type        = number
  default     = null
}

variable "github_app_private_key_pem" {
  description = "Optional GitHub App PEM private key. When set with github_app_id and github_app_installation_id, the module writes it from CSE protectedSettings to a transient file and passes -PrivateKeyPath to register-windows-runner.ps1. If null, App auth falls back to app_private_key_secret_name in Key Vault."
  type        = string
  default     = null
  sensitive   = true
}

variable "app_private_key_secret_name" {
  description = "Name of the Key Vault secret holding the GitHub App PEM private key. Ignored when auth_method = 'pat'."
  type        = string
  default     = "github-app-private-key"
}

variable "pat_secret_name" {
  description = "Name of the Key Vault secret holding the GitHub PAT (classic, repo+admin:repo_hook scopes). Ignored when auth_method = 'app'."
  type        = string
  default     = "github-runner-pat"
}

variable "bootstrap_script_override_url" {
  description = "Optional HTTPS URL to a consumer-owned bootstrap script that fully replaces the module-shipped register-windows-runner.ps1. When set, the module passes only -KeyVaultName, -GithubOwner, -GithubRepoList, -RunnerLabels, -RunnerVersion to the override script - auth-method-specific args are NOT passed (the override script owns its own param surface). Mutually exclusive with bootstrap_script_url and bootstrap_script_inline_base64."
  type        = string
  default     = null
}

variable "app_health_protocol" {
  description = "Protocol used by the ApplicationHealthWindows extension to probe runner health. 'tcp' (default, matches v1.1.0) opens a TCP connect; 'http' / 'https' issue GET against app_health_request_path on app_health_port."
  type        = string
  default     = "tcp"
  validation {
    condition     = contains(["tcp", "http", "https"], var.app_health_protocol)
    error_message = "app_health_protocol must be one of 'tcp', 'http', or 'https'."
  }
}

variable "app_health_port" {
  description = "Port probed by the ApplicationHealthWindows extension. Defaults to 0 (matches v1.1.0 - effectively disabled for TCP). Set to 80 with protocol='http' to probe a runner-side HTTP health endpoint."
  type        = number
  default     = 0
}

variable "app_health_request_path" {
  description = "HTTP/HTTPS request path probed by the ApplicationHealthWindows extension. Only applies when app_health_protocol is 'http' or 'https'."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# DSC extension (Layer 4 of the 5-layer auto-heal model)
# ---------------------------------------------------------------------------
# The DSC configuration itself lives in alz-avm-tf-demo/dsc-configs and is
# published as a release-asset zip (e.g. runner-supervisor/v0.1.0). The
# consumer is responsible for fetching that zip and hosting it on a private
# blob with a read-only SAS, then passing url + sas + script + function to
# this module. See dsc-configs/docs/consuming.md for the canonical pattern.
# ---------------------------------------------------------------------------

variable "dsc_enabled" {
  description = "Whether to provision the Microsoft.Powershell.DSC extension on the VMSS. When true, dsc_config_url and dsc_config_sas_token are required. Set to false for environments that rely only on Layers 1-3 + 5 (e.g. short-lived test pools)."
  type        = bool
  default     = true
}

variable "dsc_config_url" {
  description = "HTTPS URL of the DSC configuration zip (produced by alz-avm-tf-demo/dsc-configs/scripts/Build-DscPackage.ps1 and hosted on a private blob). Required when dsc_enabled = true. Pin to a semver release tag (e.g. runner-supervisor/v0.1.0)."
  type        = string
  default     = null
}

variable "dsc_config_sas_token" {
  description = "SAS token granting read access to dsc_config_url. Required when dsc_enabled = true and the blob is private (the standard case). Should be issued with permissions = 'r' only."
  type        = string
  default     = null
  sensitive   = true
}

variable "dsc_configuration_script" {
  description = "Script filename inside the DSC zip (relative to the zip root). Defaults to RunnerSupervisor.ps1 which matches the dsc-configs RunnerSupervisor config."
  type        = string
  default     = "RunnerSupervisor.ps1"
}

variable "dsc_configuration_function" {
  description = "Name of the Configuration function inside the DSC script. Defaults to RunnerSupervisor which matches the dsc-configs RunnerSupervisor config."
  type        = string
  default     = "RunnerSupervisor"
}

variable "dsc_configuration_arguments" {
  description = "Hashtable of arguments passed to the DSC configuration function. Forwarded as-is into the extension's configurationArguments protectedSetting. Default values match dsc-configs RunnerSupervisor signature."
  type        = map(string)
  default = {
    WatchdogLogPath   = "C:\\runner-watchdog.log"
    SupervisorLogPath = "C:\\runner-supervisor.log"
  }
}

variable "dsc_configuration_mode_frequency_mins" {
  description = "DSC LCM consistency check frequency in minutes. 15 matches the dsc-configs architecture doc and is the canonical default."
  type        = number
  default     = 15
}

# ---------------------------------------------------------------------------
# Canonical tag taxonomy
# ---------------------------------------------------------------------------
# Every runner resource SHOULD carry these tags so the estate is uniformly
# discoverable across M1 (Windows VMSS) and M2/M3/M4 (Linux ACA). The module
# automatically injects Module + ModuleVersion + OS=windows; the consumer
# supplies the rest via canonical_tags. Anything in var.tags merges on top.
# ---------------------------------------------------------------------------

variable "canonical_tags" {
  description = "Canonical tag taxonomy applied to all runner resources. Set the keys you want; module injects Module = 'terraform-azurerm-vmss-github-runners-windows', ModuleVersion = (current release), OS = 'windows'. Anything in var.tags merges on top of the canonical set."
  type = object({
    owner       = optional(string)
    workload    = optional(string)
    pool        = optional(string)
    trust       = optional(string) # private | public | org
    cost_center = optional(string)
  })
  default  = {}
  nullable = false
  validation {
    condition     = var.canonical_tags.trust == null || contains(["private", "public", "org"], var.canonical_tags.trust)
    error_message = "canonical_tags.trust must be one of 'private', 'public', or 'org'."
  }
}

variable "key_vault_allowed_ip_ranges" {
  type        = list(string)
  default     = []
  description = "Additional public IPv4 CIDRs to allow on the module-created Key Vault firewall (e.g. bridge runner IP). Ignored when key_vault_resource_id is provided (BYO KV)."
}
