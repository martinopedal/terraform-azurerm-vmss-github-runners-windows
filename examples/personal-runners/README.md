# Personal Windows runners on VMSS

Working example that consumes this module for a personal runner pool. Mirrors the layout used in `martinopedal/personal-runners-infra`.

## Prerequisites

1. Resource group `rg-pool-w-personal-swedencentral-001`.
2. Virtual network with a subnet for runner NICs. NAT Gateway or hub peering for egress.
3. Key Vault holding the GitHub App private key as a secret named `github-app-private-key`. The Key Vault is provisioned by the module if you let it create one, or referenced by name if you bring your own.
4. GitHub App with `actions:write` and `metadata:read`. No webhook is needed for self-hosted runners.

## Run it

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and fill in subscription_id + key_vault_name + github_repo_list
terraform init
terraform plan
terraform apply
```

## What you get

One VMSS with Flexible orchestration and a priority mix:
- One Regular VM (always on).
- Scale-out beyond the base is all Spot, spread across zones 1, 2, 3.

Three layers of self-heal, in order of how often they fire:
1. DSC LCM in ApplyAndAutoCorrect, checking every 15 minutes. Restarts the runner service if it stops.
2. ApplicationHealthWindows + VMSS auto-repair. Deletes and recreates an instance whose health probe stays down past the grace period.
3. Spot eviction recovery. VMSS provisions a replacement in another zone within a few minutes.

## Verifying self-heal

After apply, you can prove each layer:

1. DSC layer: RDP into an instance, run `Stop-Service -Name 'actions.runner.*'`, wait 15 minutes. DSC restarts it.
2. Auto-repair layer: block the health probe port at the instance NSG, wait past the grace period. VMSS deletes and recreates.
3. Spot layer: trigger an eviction from the portal. A replacement appears in another zone.

## Cost

Single-instance Regular base + two Spot scale-out in Sweden Central (Standard_D8ds_v6, list prices, May 2026):
- Regular: about 230 USD per month.
- Each Spot: about 70 USD per month.
- Total for one Regular + two Spot: about 370 USD per month.

## Labels

The default is the canonical 2-label compound: `["self-hosted", "personal-windows"]`. Consumer workflows pin to this scheme via:

```yaml
runs-on: [self-hosted, personal-windows]
```

Do not use the legacy 4-label form `[self-hosted, personal, windows, x64]`. The lock ADR (`coordinator-runner-module-architecture-lock-2026-05-27`) makes the 2-label compound canonical for all personal runners.
