# Windows GitHub Actions Runners on Azure VMSS

Terraform module for Windows GitHub Actions self-hosted runners on Azure VMSS.

**Sibling to**:
- [`Azure/avm-ptn-cicd-agents-and-runners`](https://github.com/Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners) (Linux ACA upstream)
- [`martinopedal/terraform-azurerm-github-runners-alz-corp`](https://github.com/martinopedal/terraform-azurerm-github-runners-alz-corp) (Linux ACA corp)

**Covers the Windows-on-VMSS gap** for personal infrastructure requiring:
- Windows Server OS with specific dependencies
- Spot instance cost optimization (~70% savings on burst capacity)
- VM-level isolation and compliance requirements
- DSC-based service self-heal

## Features

- ✅ **Spot bursting** (1 Regular base + N Spot instances via `priority_mix`)
- ✅ **DSC-based service self-heal** (PowerShell Desired State Configuration enforces runner service state every 15min)
- ✅ **3-layer resilience**: DSC (15min) → VMSS auto-repair (30min) → Spot eviction recovery (1-5min)
- ✅ **GitHub App OIDC authentication** (via Key Vault + User-Assigned Managed Identity)
- ✅ **Application Health extension** + automatic instance repair
- ✅ **Multi-zone Spot placement** (zones 1,2,3 for capacity resilience)
- ✅ **AzAPI-first** (follows IaC discipline 2026-05-25)

## Usage

```hcl
module "windows_runners" {
  source = "git::https://github.com/martinopedal/terraform-azurerm-vmss-github-runners-windows.git?ref=<commit-sha>"

  location            = "swedencentral"
  resource_group_name = "rg-pool-w-personal-swedencentral-001"
  subnet_id           = data.azurerm_subnet.runner_subnet.id

  vmss_name     = "vmss-pool-w-personal"
  vmss_sku      = "Standard_D8ds_v6"
  vmss_capacity = 1

  key_vault_name   = "kv-pool-w-personal-xyz"
  github_owner     = "martinopedal"
  github_repo_list = ["personal-runners-infra", "azure-analyzer"]
  runner_labels    = ["self-hosted", "personal", "windows", "x64"]

  enable_telemetry = true

  tags = {
    environment = "personal"
    managed-by  = "terraform"
  }
}
```

## Pre-requisites

1. **Resource Group** (must exist before module)
2. **Subnet** with NAT Gateway or hub peering for egress
3. **GitHub App** created and private key uploaded to Key Vault as secret `github-app-private-key`
4. **Bootstrap script** hosted in accessible location (see note below)

### Bootstrap Script Hosting

The `scripts/register-windows-runner.ps1` script must be accessible to VMSS instances during CSE execution. Options:

1. **Private Storage Account** (recommended):
   - Upload script to blob storage
   - Generate SAS token with read permissions
   - Update `main.vmss.tf` `fileUris` to point to blob URL + SAS

2. **Public GitHub Release** (simpler for personal use):
   - Create a release in this repo
   - Attach `register-windows-runner.ps1` as asset
   - Update `fileUris` to GitHub release asset URL

## Architecture

### 3-Layer Self-Heal

| Layer | Mechanism | Scope | Recovery Time |
|---|---|---|---|
| **Layer 1: DSC** | PowerShell DSC extension with LCM | Service-level (process crash, manual stop) | 15 minutes |
| **Layer 2: VMSS Auto-Repair** | ApplicationHealthWindows + automatic_instance_repair | VM-level (VM unhealthy, DSC can't recover) | 30 minutes |
| **Layer 3: Spot Eviction** | Priority Mix + multi-zone | Capacity-level (Azure evicts Spot VM) | 1-5 minutes |

### DSC Configuration

**Purpose**: Continuously enforce `actions.runner.*` Windows service is **Running** + **Automatic** startup.

**LCM Settings**:
- `ConfigurationMode = 'ApplyAndAutoCorrect'` (re-enforce on drift)
- `ConfigurationModeFrequencyMins = 15`
- `RebootNodeIfNeeded = $false` (Spot-friendly, no spontaneous reboot)

### Priority Mix (Spot Bursting)

- **1 Regular instance** (always on, guaranteed capacity)
- **All scale-out uses Spot** (70% cost savings on burst capacity)
- **`max_bid_price = -1`** (pay up to on-demand, never evicted on price)
- **`eviction_policy = "Delete"`** (clean removal on capacity eviction)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| azapi | ~> 2.8 |
| azurerm | ~> 4.20 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location | Azure region where the VMSS should be deployed | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| subnet_id | ID of the subnet where VMSS instances will be deployed | `string` | n/a | yes |
| vmss_name | Name of the Virtual Machine Scale Set | `string` | n/a | yes |
| key_vault_name | Name of the Key Vault for GitHub App private key storage | `string` | n/a | yes |
| github_owner | GitHub owner (org or user) | `string` | n/a | yes |
| github_repo_list | List of repositories for runner registration | `list(string)` | n/a | yes |
| runner_labels | Labels for the GitHub runner | `list(string)` | `["self-hosted", "windows", "x64"]` | no |
| vmss_sku | VM SKU for the VMSS instances | `string` | `"Standard_D8ds_v6"` | no |
| vmss_capacity | Initial capacity for the VMSS | `number` | `1` | no |
| vmss_zones | Availability zones for the VMSS | `list(string)` | `["1", "2", "3"]` | no |
| enable_telemetry | Enable telemetry for the module | `bool` | `true` | no |

See [variables.tf](variables.tf) for full list.

## Outputs

| Name | Description |
|------|-------------|
| vmss_id | Resource ID of the Virtual Machine Scale Set |
| uami_principal_id | Principal ID of the User-Assigned Managed Identity |
| key_vault_name | Name of the Key Vault |
| vmss_name | Name of the Virtual Machine Scale Set |

## Examples

See [examples/personal-runners/](examples/personal-runners/) for a complete example.

## Why Not AVM?

This module exists because the official AVM CI/CD pattern module ([`Azure/avm-ptn-cicd-agents-and-runners`](https://github.com/Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners)) is **container-based** (Azure Container Apps + Azure Container Instances) and does not support Virtual Machine Scale Sets.

**VMSS-based runners** are a different pattern with different tradeoffs:
- **ACA/ACI**: Ephemeral, stateless, auto-scaling via KEDA, OS-agnostic containers
- **VMSS**: Persistent VMs, stateful (DSC), manual scaling + Spot bursting, Windows Server OS

Microsoft recommends ACA for CI/CD workloads, but VMSS remains viable for Windows-specific dependencies, GPU workloads, or compliance requirements.

An upstream feature request has been filed: [Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners#TBD]

## License

MIT

## Contributing

Contributions welcome! This module follows the AVM conventions where applicable (telemetry, variable naming) but is not an official AVM module.

## Features

### Priority Mix (Spot Bursting)

- **1 Regular instance** (always on, guaranteed capacity)
- **All scale-out uses Spot** (70% cost savings on burst capacity)
- **`max_bid_price = -1`** (pay up to on-demand, never evicted on price)
- **`eviction_policy = "Delete"`** (clean removal on capacity eviction)

### DSC Self-Heal

DSC continuously enforces runner service state every 15 minutes:

- **Service exists**: `actions.runner.martinopedal-*`
- **Service state**: Running
- **Startup type**: Automatic

**LCM configuration**:
- `ConfigurationMode = 'ApplyAndAutoCorrect'` (re-enforce on drift)
- `ConfigurationModeFrequencyMins = 15`
- `RebootNodeIfNeeded = $false` (Spot-friendly)

### 3-Layer Self-Heal

| Layer | Scope | Recovery Time |
|---|---|---|
| DSC | Service-level (process crash, manual stop) | 15 minutes |
| VMSS Auto-Repair | VM-level (DSC can't recover) | 30 minutes |
| Spot Eviction | Capacity-level (Azure evicts Spot) | 1-5 minutes |

## Inputs

See [variables.tf](variables.tf) for full list.

## Outputs

- `vmss_id` - VMSS resource ID
- `uami_principal_id` - UAMI principal ID (for additional RBAC)
- `key_vault_name` - Key Vault name

## Bootstrap Script

The CSE bootstrap script `scripts/register-windows-runner.ps1` handles:
1. GitHub App authentication (fetch PEM from KV via UAMI + IMDS)
2. Runner registration with ephemeral token
3. Watchdog scheduled task (60-second health check)

DSC takes over after initial registration to enforce service state.

## Upstream Contribution

This submodule is intended for eventual contribution to `Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners` as a VMSS-based runner pattern alongside the existing ACA/ACI patterns.

See upstream issue: [Azure/terraform-azurerm-avm-ptn-cicd-agents-and-runners#TBD]
