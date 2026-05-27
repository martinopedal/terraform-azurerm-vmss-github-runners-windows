# Windows GitHub Actions runners on Azure VMSS

This module deploys personal Windows GitHub Actions runners on Azure Virtual Machine Scale Sets with Spot scale-out, DSC service repair, and VMSS automatic instance repair.

It fills the Windows VMSS gap beside the two Linux ACA runner modules in the locked runner architecture:

- Personal Linux ACA: `Azure/avm-ptn-cicd-agents-and-runners/azurerm`
- Org Linux ACA: `martinopedal/terraform-azurerm-github-runners-alz-corp`
- Personal Windows VMSS: this module

## ALZ placement

Use this module only for the personal Windows runner pool on sub-5. Sub-5 is outside the network governance plane and inside the security plane. Do not use it for org Windows runners. Pool W-org is archived and the org runner path is Linux ACA.

## What the module creates

- A Windows VMSS through AzAPI
- A user-assigned managed identity for the VMSS
- A Key Vault for the GitHub App private key
- Key Vault Secrets User RBAC for the VMSS identity
- VMSS Custom Script, DSC, and Application Health extensions
- Optional AVM telemetry deployment

The module does not create the resource group, VNet, subnet, NAT Gateway, GitHub App, or GitHub repository permissions. Those stay in the consuming runner estate.

## Usage

Pin consumers to the release tag so VMSS bootstrap behavior is reproducible:

```hcl
module "windows_runners" {
  source = "github.com/martinopedal/terraform-azurerm-vmss-github-runners-windows?ref=v0.1.0"

  location             = "swedencentral"
  resource_group_name  = "rg-pool-w-personal-swedencentral-001"
  subnet_id            = data.azurerm_subnet.runner_subnet.id
  vmss_name            = "vmss-pool-w-personal"
  key_vault_name       = "kv-pool-w-personal-001"
  github_owner         = "martinopedal"
  github_repo_list     = ["personal-runners-infra"]
  bootstrap_script_url = "https://raw.githubusercontent.com/martinopedal/terraform-azurerm-vmss-github-runners-windows/v0.1.0/scripts/register-windows-runner.ps1"
  runner_labels        = ["self-hosted", "personal", "windows", "x64", "vmss"]

  enable_telemetry = true

  tags = {
    environment = "personal"
    managed-by  = "terraform"
  }
}
```

## Example

See `examples/personal-runners` for a complete sub-5 personal example that reads an existing NAT Gateway backed runner subnet and deploys a single VMSS with priorityMixPolicy spot and regular mix into it. Firewall audit requirements are documented in `docs/FIREWALL-REQUIREMENTS.md`.

## Bootstrap script

The Custom Script Extension downloads `scripts/register-windows-runner.ps1` from `bootstrap_script_url`. Pin the URL to a release tag in real consumers so a later `main` branch change cannot alter VMSS bootstrap behavior.

## Authentication model

The module expects a GitHub App private key in Key Vault as `github-app-private-key`. The VMSS identity reads that secret at bootstrap time, requests a GitHub runner registration token, and registers each Windows runner with the labels in `runner_labels`.

## Registry status

The repository name follows the Terraform Registry naming convention for `martinopedal/vmss-github-runners-windows/azurerm`. If it is not visible in the registry after release, Martin needs to sign in to registry.terraform.io, choose Publish module, select this GitHub repository, and publish from the `v0.1.0` tag.

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
| <a name="input_bootstrap_script_url"></a> [bootstrap\_script\_url](#input\_bootstrap\_script\_url) | HTTPS URL for scripts/register-windows-runner.ps1. Pin this to a release tag in consumers. | `string` | n/a | yes |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub owner (org or user) | `string` | n/a | yes |
| <a name="input_github_repo_list"></a> [github\_repo\_list](#input\_github\_repo\_list) | List of repositories for runner registration (comma-separated in CSE) | `list(string)` | n/a | yes |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault for GitHub App private key storage | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the VMSS should be deployed | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | ID of the subnet where VMSS instances will be deployed | `string` | n/a | yes |
| <a name="input_vmss_name"></a> [vmss\_name](#input\_vmss\_name) | Name of the Virtual Machine Scale Set | `string` | n/a | yes |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | Optional local administrator password. If null, the module generates one. | `string` | `null` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Local administrator username for VMSS provisioning. Password authentication should remain inaccessible from the network. | `string` | `"azureuser"` | no |
| <a name="input_automatic_instance_repair_grace_period"></a> [automatic\_instance\_repair\_grace\_period](#input\_automatic\_instance\_repair\_grace\_period) | Grace period for automatic instance repair (ISO 8601 duration) | `string` | `"PT30M"` | no |
| <a name="input_disk_controller_type"></a> [disk\_controller\_type](#input\_disk\_controller\_type) | Disk controller type (SCSI or NVMe) | `string` | `"NVMe"` | no |
| <a name="input_dsc_configuration_mode_frequency_mins"></a> [dsc\_configuration\_mode\_frequency\_mins](#input\_dsc\_configuration\_mode\_frequency\_mins) | DSC LCM consistency check frequency in minutes | `number` | `15` | no |
| <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry) | This variable controls whether or not telemetry is enabled for the module. For more information see https://aka.ms/avm/telemetryinfo. If it is set to false, then no telemetry will be collected. | `bool` | `true` | no |
| <a name="input_eviction_policy"></a> [eviction\_policy](#input\_eviction\_policy) | Eviction policy for Spot instances (Delete or Deallocate) | `string` | `"Delete"` | no |
| <a name="input_max_bid_price"></a> [max\_bid\_price](#input\_max\_bid\_price) | Maximum price for Spot instances (-1 = pay up to on-demand) | `number` | `-1` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size in GB | `number` | `128` | no |
| <a name="input_os_disk_storage_account_type"></a> [os\_disk\_storage\_account\_type](#input\_os\_disk\_storage\_account\_type) | OS disk storage type (StandardSSD\_LRS, Premium\_LRS, etc.) | `string` | `"StandardSSD_LRS"` | no |
| <a name="input_priority_mix_base_regular_count"></a> [priority\_mix\_base\_regular\_count](#input\_priority\_mix\_base\_regular\_count) | Number of Regular (non-Spot) instances in the base capacity | `number` | `1` | no |
| <a name="input_priority_mix_regular_percentage_above_base"></a> [priority\_mix\_regular\_percentage\_above\_base](#input\_priority\_mix\_regular\_percentage\_above\_base) | Percentage of Regular instances above base (0 = all Spot) | `number` | `0` | no |
| <a name="input_runner_labels"></a> [runner\_labels](#input\_runner\_labels) | Labels for the GitHub runner | `list(string)` | <pre>[<br/>  "self-hosted",<br/>  "windows",<br/>  "x64"<br/>]</pre> | no |
| <a name="input_runner_version"></a> [runner\_version](#input\_runner\_version) | GitHub Actions runner version | `string` | `"2.319.1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vmss_capacity"></a> [vmss\_capacity](#input\_vmss\_capacity) | Initial capacity for the VMSS | `number` | `1` | no |
| <a name="input_vmss_sku"></a> [vmss\_sku](#input\_vmss\_sku) | VM SKU for the VMSS instances (e.g., Standard\_D8ds\_v6) | `string` | `"Standard_D8ds_v6"` | no |
| <a name="input_vmss_zones"></a> [vmss\_zones](#input\_vmss\_zones) | Availability zones for the VMSS (for Spot capacity resilience) | `list(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | Resource ID of the Key Vault |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Name of the Key Vault |
| <a name="output_uami_principal_id"></a> [uami\_principal\_id](#output\_uami\_principal\_id) | Principal ID of the User-Assigned Managed Identity |
| <a name="output_vmss_id"></a> [vmss\_id](#output\_vmss\_id) | Resource ID of the Virtual Machine Scale Set |
| <a name="output_vmss_name"></a> [vmss\_name](#output\_vmss\_name) | Name of the Virtual Machine Scale Set |
<!-- END_TF_DOCS -->

## License

MIT