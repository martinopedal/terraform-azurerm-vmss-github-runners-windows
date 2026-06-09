# Windows GitHub Actions runners on Azure VMSS

This module deploys self-hosted Windows GitHub Actions runners on Azure Virtual Machine Scale Sets with Spot scale-out, DSC service repair, and VMSS automatic instance repair.

It complements Linux Azure Container Apps (ACA) runner modules by covering the Windows VMSS path, which ACA does not serve.


## Network egress requirements

Force-tunneled landing-zone spokes must allow the runner dependencies documented in [EGRESS.md](./EGRESS.md) at the hub Azure Firewall before deployment. Runners that egress through a NAT Gateway instead of a hub firewall do not need these openings, but the same dependency list applies.

## Placement

This module deploys the Windows VMSS and its directly attached resources only. Use it where a Windows runner pool is required; the Linux runner path is covered by ACA runner modules.

## What the module creates

- A Windows VMSS through AzAPI
- A user-assigned managed identity for the VMSS
- A Key Vault for the GitHub App private key
- Key Vault Secrets User RBAC for the VMSS identity
- VMSS Custom Script, DSC, and Application Health extensions
- Optional AVM telemetry deployment

The module does not create the resource group, VNet, subnet, NAT Gateway, GitHub App, or GitHub repository permissions. Those stay in the consuming configuration.

The `subnet_id` you pass in must already exist and comply with your landing-zone policies. Many landing zones enforce an Azure Policy that requires every subnet to have a Network Security Group attached, so ensure the subnet you supply has one.

## Windows VMSS hardening checks

Common Windows VMSS runner hardening checks this module accounts for:

| Pattern | Module status | Consumer implication |
| --- | --- | --- |
| Key Vault secret expiration | Not applicable: this module creates the Key Vault, but no `azurerm_key_vault_secret` resources. | Secret creation remains consumer-owned; any consumer-created secret should set a policy-safe expiration, such as 180 days. |
| DSC storage blob upload RBAC | Not applicable: this module creates no storage account and uploads no `azurerm_storage_blob` DSC artifact. | If a consumer adds DSC artifacts in Storage, configure the provider with `storage_use_azuread = true` and grant the Terraform principal `Storage Blob Data Contributor` on that storage account. |
| Windows DCR schema | Not applicable: this module creates no DCR through `azurerm_monitor_data_collection_rule` or AzAPI `dataCollectionRules`. | DCRs stay consumer-owned; Windows DCRs must use `kind = "Windows"` and valid `windowsEventLogs`, `performanceCounters`, and `dataFlow` arrays. |

## Usage

```hcl
module "windows_runners" {
  source  = "martinopedal/vmss-github-runners-windows/azurerm"
  version = "1.3.0"

  location             = "swedencentral"
  resource_group_name  = "rg-runners-windows-example"
  subnet_id            = data.azurerm_subnet.runner_subnet.id
  vmss_name            = "vmss-runners-windows"
  key_vault_name       = "kv-runners-win-example"
  github_owner         = "my-github-org"
  github_repo_list     = ["my-repo"]
  bootstrap_script_url = "https://raw.githubusercontent.com/martinopedal/terraform-azurerm-vmss-github-runners-windows/v1.3.0/scripts/register-windows-runner.ps1"
  runner_labels        = ["self-hosted", "windows"]

  enable_telemetry = true

  tags = {
    environment = "example"
    managed-by  = "terraform"
  }
}
```

## Example

See `examples/personal-runners` for a complete example that reads an existing runner subnet and deploys the module into it.

## Bootstrap script

The Custom Script Extension downloads `scripts/register-windows-runner.ps1` from `bootstrap_script_url`. Pin the URL to a release tag in real consumers so a later `main` branch change cannot alter VMSS bootstrap behavior.

## Authentication model

The preferred path is GitHub App auth. Supply `github_app_id`, `github_app_installation_id`, and `github_app_private_key_pem`; the module passes the PEM through VMSS CSE `protectedSettings`, writes it to a transient local file, and the bootstrap script mints an RS256 JWT before requesting a short-lived runner registration token. If `github_app_private_key_pem` is null, the script keeps the v1.2.0 Key Vault secret fallback via `app_private_key_secret_name`. If App args are absent, the script falls back to PAT auth via `pat_secret_name` or a direct `-Pat` value for back-compat.

```hcl
module "windows_runners" {
  source  = "martinopedal/vmss-github-runners-windows/azurerm"
  version = "1.3.0"

  location             = "swedencentral"
  resource_group_name  = "rg-runners-windows-example"
  subnet_id            = data.azurerm_subnet.runner_subnet.id
  vmss_name            = "vmss-runners-windows"
  key_vault_name       = "kv-runners-win-example"
  github_owner         = "my-github-org"
  github_repo_list     = ["my-repo"]
  bootstrap_script_url = "https://raw.githubusercontent.com/martinopedal/terraform-azurerm-vmss-github-runners-windows/v1.3.0/scripts/register-windows-runner.ps1"
  runner_labels        = ["self-hosted", "windows"]
  orchestration_mode   = "Flexible"

  github_app_id              = 123456
  github_app_installation_id = 987654321
  github_app_private_key_pem = var.github_app_private_key_pem

  enable_telemetry = true
}
```

### Public-facing pool example

Deploy a public-facing runner pool for public or untrusted workflow scenarios:

```hcl
module "windows_runners_pub" {
  source  = "martinopedal/vmss-github-runners-windows/azurerm"
  version = "1.3.0"

  location             = "swedencentral"
  resource_group_name  = "rg-runners-windows-pub-example"
  subnet_id            = data.azurerm_subnet.pub_subnet.id
  vmss_name            = "vmss-runners-windows-pub"
  key_vault_name       = "kv-runners-win-pub-example"
  github_owner         = "my-github-org"
  github_repo_list     = ["my-public-repo"]
  bootstrap_script_url = "https://raw.githubusercontent.com/martinopedal/terraform-azurerm-vmss-github-runners-windows/v1.3.0/scripts/register-windows-runner.ps1"
  runner_labels        = ["self-hosted", "windows", "pub"]

  github_app_id              = 123456
  github_app_installation_id = 987654321
  github_app_private_key_pem = var.github_app_private_key_pem

  enable_telemetry = true

  tags = {
    environment = "example"
    managed-by  = "terraform"
  }
}
```

## Registry status

The repository name follows the Terraform Registry naming convention for `martinopedal/vmss-github-runners-windows/azurerm`. If it is not visible in the registry after release, publish it from registry.terraform.io (Publish module) against this GitHub repository and the `v1.3.0` tag.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | ~> 2.8 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.20 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | ~> 2.8 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.20 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.7 |

## Resources

| Name | Type |
| ---- | ---- |
| [azapi_resource.key_vault_vmss_windows](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.rbac_kv_secrets_user](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.telemetry](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.uami_vmss_windows](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.vmss_windows](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [random_password.admin_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub owner (org or user) | `string` | n/a | yes |
| <a name="input_github_repo_list"></a> [github\_repo\_list](#input\_github\_repo\_list) | List of repositories for runner registration (comma-separated in CSE) | `list(string)` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the VMSS should be deployed | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | ID of the subnet where VMSS instances will be deployed | `string` | n/a | yes |
| <a name="input_vmss_name"></a> [vmss\_name](#input\_vmss\_name) | Name of the Virtual Machine Scale Set | `string` | n/a | yes |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Optional local administrator password. If null, the module generates one. | `string` | `null` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Local administrator username for VMSS provisioning. Password authentication should remain inaccessible from the network. | `string` | `"azureuser"` | no |
| <a name="input_app_health_port"></a> [app\_health\_port](#input\_app\_health\_port) | Port probed by the ApplicationHealthWindows extension. Defaults to 0 (matches v1.1.0 - effectively disabled for TCP). Set to 80 with protocol='http' to probe a runner-side HTTP health endpoint. | `number` | `0` | no |
| <a name="input_app_health_protocol"></a> [app\_health\_protocol](#input\_app\_health\_protocol) | Protocol used by the ApplicationHealthWindows extension to probe runner health. 'tcp' (default, matches v1.1.0) opens a TCP connect; 'http' / 'https' issue GET against app\_health\_request\_path on app\_health\_port. | `string` | `"tcp"` | no |
| <a name="input_app_health_request_path"></a> [app\_health\_request\_path](#input\_app\_health\_request\_path) | HTTP/HTTPS request path probed by the ApplicationHealthWindows extension. Only applies when app\_health\_protocol is 'http' or 'https'. | `string` | `""` | no |
| <a name="input_app_private_key_secret_name"></a> [app\_private\_key\_secret\_name](#input\_app\_private\_key\_secret\_name) | Name of the Key Vault secret holding the GitHub App PEM private key. Ignored when auth\_method = 'pat'. | `string` | `"github-app-private-key"` | no |
| <a name="input_auth_method"></a> [auth\_method](#input\_auth\_method) | Runner registration authentication method. 'app' uses a GitHub App private key stored in Key Vault to mint installation + registration tokens at boot. 'pat' uses a Personal Access Token stored in Key Vault as the registration credential. App auth is preferred for org-scoped pools; PAT is simpler for personal repo pools. | `string` | `"app"` | no |
| <a name="input_automatic_instance_repair_grace_period"></a> [automatic\_instance\_repair\_grace\_period](#input\_automatic\_instance\_repair\_grace\_period) | Grace period for automatic instance repair (ISO 8601 duration) | `string` | `"PT30M"` | no |
| <a name="input_bootstrap_script_inline_base64"></a> [bootstrap\_script\_inline\_base64](#input\_bootstrap\_script\_inline\_base64) | Optional inline bootstrap script (base64-encoded UTF-8 of register-windows-runner.ps1). When set, the script is delivered via VMSS userData and decoded by the CSE at boot, avoiding any HTTPS fetch. Mutually exclusive with bootstrap\_script\_url. | `string` | `null` | no |
| <a name="input_bootstrap_script_override_url"></a> [bootstrap\_script\_override\_url](#input\_bootstrap\_script\_override\_url) | Optional HTTPS URL to a consumer-owned bootstrap script that fully replaces the module-shipped register-windows-runner.ps1. When set, the module passes only -KeyVaultName, -GithubOwner, -GithubRepoList, -RunnerLabels, -RunnerVersion to the override script - auth-method-specific args are NOT passed (the override script owns its own param surface). Mutually exclusive with bootstrap\_script\_url and bootstrap\_script\_inline\_base64. | `string` | `null` | no |
| <a name="input_bootstrap_script_url"></a> [bootstrap\_script\_url](#input\_bootstrap\_script\_url) | HTTPS URL for scripts/register-windows-runner.ps1. Pin this to a release tag in consumers. Mutually exclusive with bootstrap\_script\_inline\_base64; one of the two must be set. | `string` | `null` | no |
| <a name="input_canonical_tags"></a> [canonical\_tags](#input\_canonical\_tags) | Canonical tag taxonomy applied to all runner resources. Set the keys you want; module injects Module = 'terraform-azurerm-vmss-github-runners-windows', ModuleVersion = (current release), OS = 'windows'. Anything in var.tags merges on top of the canonical set. | <pre>object({<br/>    owner       = optional(string)<br/>    workload    = optional(string)<br/>    pool        = optional(string)<br/>    trust       = optional(string) # private | public | org<br/>    cost_center = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_create_key_vault"></a> [create\_key\_vault](#input\_create\_key\_vault) | Whether the module should create the Key Vault. Defaults to null which auto-detects from key\_vault\_resource\_id (null => create). Set explicitly to false when key\_vault\_resource\_id is an unknown-at-plan-time reference (e.g. azurerm\_key\_vault.x.id created in the same root). | `bool` | `null` | no |
| <a name="input_create_user_assigned_managed_identity"></a> [create\_user\_assigned\_managed\_identity](#input\_create\_user\_assigned\_managed\_identity) | Whether the module should create the UAMI. Defaults to null which auto-detects from user\_assigned\_managed\_identity\_resource\_id (null => create). Set explicitly to false when the supplied resource id is unknown at plan time. | `bool` | `null` | no |
| <a name="input_disk_controller_type"></a> [disk\_controller\_type](#input\_disk\_controller\_type) | Disk controller type (SCSI or NVMe) | `string` | `"NVMe"` | no |
| <a name="input_dsc_config_sas_token"></a> [dsc\_config\_sas\_token](#input\_dsc\_config\_sas\_token) | SAS token granting read access to dsc\_config\_url. Required when dsc\_enabled = true and the blob is private (the standard case). Should be issued with permissions = 'r' only. | `string` | `null` | no |
| <a name="input_dsc_config_url"></a> [dsc\_config\_url](#input\_dsc\_config\_url) | HTTPS URL of the DSC configuration zip (produced by your DSC packaging script, for example Build-DscPackage.ps1, and hosted on a private blob). Required when dsc\_enabled = true. Pin to a semver release tag (e.g. runner-supervisor/v0.1.0). | `string` | `null` | no |
| <a name="input_dsc_configuration_arguments"></a> [dsc\_configuration\_arguments](#input\_dsc\_configuration\_arguments) | Hashtable of arguments passed to the DSC configuration function. Forwarded as-is into the extension's configurationArguments protectedSetting. Default values match the RunnerSupervisor configuration signature. | `map(string)` | <pre>{<br/>  "SupervisorLogPath": "C:\\runner-supervisor.log",<br/>  "WatchdogLogPath": "C:\\runner-watchdog.log"<br/>}</pre> | no |
| <a name="input_dsc_configuration_function"></a> [dsc\_configuration\_function](#input\_dsc\_configuration\_function) | Name of the Configuration function inside the DSC script. Defaults to RunnerSupervisor, matching the RunnerSupervisor configuration. | `string` | `"RunnerSupervisor"` | no |
| <a name="input_dsc_configuration_mode_frequency_mins"></a> [dsc\_configuration\_mode\_frequency\_mins](#input\_dsc\_configuration\_mode\_frequency\_mins) | DSC LCM consistency check frequency in minutes. 15 is the canonical default for the RunnerSupervisor configuration. | `number` | `15` | no |
| <a name="input_dsc_configuration_script"></a> [dsc\_configuration\_script](#input\_dsc\_configuration\_script) | Script filename inside the DSC zip (relative to the zip root). Defaults to RunnerSupervisor.ps1, matching the RunnerSupervisor configuration. | `string` | `"RunnerSupervisor.ps1"` | no |
| <a name="input_dsc_enabled"></a> [dsc\_enabled](#input\_dsc\_enabled) | Whether to provision the Microsoft.Powershell.DSC extension on the VMSS. When true, dsc\_config\_url and dsc\_config\_sas\_token are required. Set to false for environments that rely only on Layers 1-3 + 5 (e.g. short-lived test pools). | `bool` | `true` | no |
| <a name="input_enable_hotpatching"></a> [enable\_hotpatching](#input\_enable\_hotpatching) | Enable Windows Server hotpatching. Requires windows\_image\_sku to include '2025-datacenter-azure-edition'. When true, patchMode is set to AutomaticByPlatform and hotpatching is enabled on the VMSS patchSettings. | `bool` | `false` | no |
| <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry) | This variable controls whether or not telemetry is enabled for the module. For more information see https://aka.ms/avm/telemetryinfo. If it is set to false, then no telemetry will be collected. | `bool` | `true` | no |
| <a name="input_eviction_policy"></a> [eviction\_policy](#input\_eviction\_policy) | Eviction policy for Spot instances (Delete or Deallocate) | `string` | `"Delete"` | no |
| <a name="input_github_app_id"></a> [github\_app\_id](#input\_github\_app\_id) | GitHub App ID. Required when auth\_method = 'app'. The App must be installed on github\_owner and have Actions:read+write + Administration:read+write permissions on github\_repo\_list. | `number` | `null` | no |
| <a name="input_github_app_installation_id"></a> [github\_app\_installation\_id](#input\_github\_app\_installation\_id) | GitHub App installation ID for github\_owner. Required when auth\_method = 'app'. Find via: GET /users/{owner}/installation or /orgs/{owner}/installation. | `number` | `null` | no |
| <a name="input_github_app_private_key_pem"></a> [github\_app\_private\_key\_pem](#input\_github\_app\_private\_key\_pem) | Optional GitHub App PEM private key. When set with github\_app\_id and github\_app\_installation\_id, the module writes it from CSE protectedSettings to a transient file and passes -PrivateKeyPath to register-windows-runner.ps1. If null, App auth falls back to app\_private\_key\_secret\_name in Key Vault. | `string` | `null` | no |
| <a name="input_key_vault_allowed_ip_ranges"></a> [key\_vault\_allowed\_ip\_ranges](#input\_key\_vault\_allowed\_ip\_ranges) | Additional public IPv4 CIDRs to allow on the module-created Key Vault firewall (e.g. bridge runner IP). Ignored when key\_vault\_resource\_id is provided (BYO KV). | `list(string)` | `[]` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault to create for GitHub App private key storage. Required when key\_vault\_resource\_id is null. Ignored when BYO Key Vault is supplied. | `string` | `null` | no |
| <a name="input_key_vault_purge_protection_enabled"></a> [key\_vault\_purge\_protection\_enabled](#input\_key\_vault\_purge\_protection\_enabled) | Whether to enable purge protection on the module-created Key Vault. Ignored when a BYO Key Vault is supplied. Defaults to true for production hardening; set to false in ephemeral/test environments where vaults need to be hard-deleted. | `bool` | `true` | no |
| <a name="input_key_vault_resource_id"></a> [key\_vault\_resource\_id](#input\_key\_vault\_resource\_id) | Optional resource ID of an existing Key Vault to use instead of creating one. When set, the module skips KV creation and only assigns the UAMI the Key Vault Secrets User role on this vault. If this references a resource created in the same apply (unknown at plan time), you MUST also set create\_key\_vault = false. | `string` | `null` | no |
| <a name="input_license_type"></a> [license\_type](#input\_license\_type) | Azure Hybrid Benefit license type for Windows instances. Set to "Windows\_Server" to apply AHUB (saves the Windows Server license cost on regular and Spot instances). Leave null for pay-as-you-go licensing. | `string` | `null` | no |
| <a name="input_max_bid_price"></a> [max\_bid\_price](#input\_max\_bid\_price) | Maximum price for Spot instances (-1 = pay up to on-demand) | `number` | `-1` | no |
| <a name="input_orchestration_mode"></a> [orchestration\_mode](#input\_orchestration\_mode) | VMSS orchestration mode. 'Uniform' (default) is the classic mode and matches v1.1.0 behavior. 'Flexible' uses individual VMs underneath, supports mixing fault domains, and is required by some consumer scenarios (for example a public-facing pool). Immutable after VMSS creation - changing this value triggers destroy/recreate. | `string` | `"Uniform"` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size in GB | `number` | `128` | no |
| <a name="input_os_disk_storage_account_type"></a> [os\_disk\_storage\_account\_type](#input\_os\_disk\_storage\_account\_type) | OS disk storage type (StandardSSD\_LRS, Premium\_LRS, etc.) | `string` | `"StandardSSD_LRS"` | no |
| <a name="input_pat_secret_name"></a> [pat\_secret\_name](#input\_pat\_secret\_name) | Name of the Key Vault secret holding the GitHub PAT (classic, repo+admin:repo\_hook scopes). Ignored when auth\_method = 'app'. | `string` | `"github-runner-pat"` | no |
| <a name="input_priority_mix_base_regular_count"></a> [priority\_mix\_base\_regular\_count](#input\_priority\_mix\_base\_regular\_count) | Number of Regular (non-Spot) instances in the base capacity | `number` | `1` | no |
| <a name="input_priority_mix_regular_percentage_above_base"></a> [priority\_mix\_regular\_percentage\_above\_base](#input\_priority\_mix\_regular\_percentage\_above\_base) | Percentage of Regular instances above base (0 = all Spot) | `number` | `0` | no |
| <a name="input_runner_labels"></a> [runner\_labels](#input\_runner\_labels) | Labels for the GitHub runner | `list(string)` | <pre>[<br/>  "self-hosted",<br/>  "windows",<br/>  "x64"<br/>]</pre> | no |
| <a name="input_runner_version"></a> [runner\_version](#input\_runner\_version) | GitHub Actions runner version | `string` | `"2.319.1"` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | Subscription ID used to compose resource parent\_id values. When set to a non-empty value it is used directly so parent\_id is known at plan time. This avoids a spurious azapi ForceNew (VMSS/UAMI replacement) when the azurerm provider defers data.azurerm\_client\_config to apply, for example under OIDC auth on CI runners, where object\_id resolution makes the whole data source known-after-apply. Defaults to the provider's client\_config subscription for backward compatibility. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_user_assigned_managed_identity_resource_id"></a> [user\_assigned\_managed\_identity\_resource\_id](#input\_user\_assigned\_managed\_identity\_resource\_id) | Optional resource ID of an existing User-Assigned Managed Identity. When set, the module skips UAMI creation and attaches this identity to the VMSS instead, looking up its principalId for RBAC. If this references a resource created in the same apply (unknown at plan time), you MUST also set create\_user\_assigned\_managed\_identity = false. | `string` | `null` | no |
| <a name="input_vmss_capacity"></a> [vmss\_capacity](#input\_vmss\_capacity) | Initial capacity for the VMSS | `number` | `1` | no |
| <a name="input_vmss_sku"></a> [vmss\_sku](#input\_vmss\_sku) | VM SKU for the VMSS instances (e.g., Standard\_D8ds\_v6) | `string` | `"Standard_D8ds_v6"` | no |
| <a name="input_vmss_zones"></a> [vmss\_zones](#input\_vmss\_zones) | Availability zones for the VMSS (for Spot capacity resilience) | `list(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |
| <a name="input_windows_image_sku"></a> [windows\_image\_sku](#input\_windows\_image\_sku) | Windows Server image SKU. Use '2025-datacenter-azure-edition' when enable\_hotpatching = true. | `string` | `"2022-datacenter-azure-edition"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | Resource ID of the effective Key Vault (module-created or BYO). |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Name of the effective Key Vault (module-created or BYO). |
| <a name="output_uami_principal_id"></a> [uami\_principal\_id](#output\_uami\_principal\_id) | Principal ID of the effective User-Assigned Managed Identity (module-created or BYO). |
| <a name="output_uami_resource_id"></a> [uami\_resource\_id](#output\_uami\_resource\_id) | Resource ID of the effective User-Assigned Managed Identity (module-created or BYO). |
| <a name="output_vmss_id"></a> [vmss\_id](#output\_vmss\_id) | Resource ID of the Virtual Machine Scale Set |
| <a name="output_vmss_name"></a> [vmss\_name](#output\_vmss\_name) | Name of the Virtual Machine Scale Set |
<!-- END_TF_DOCS -->

## License

MIT