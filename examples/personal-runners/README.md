# Example: Personal Windows Runners on VMSS

Complete example showing how to consume the Windows VMSS runners module for a personal runner pool.

## Pre-requisites

1. **Resource Group** created (`rg-pool-w-personal-swedencentral-001`)
2. **Virtual Network + Subnet** with NAT Gateway or hub peering for egress
3. **Key Vault** created (`kv-pool-w-personal-xyz`) with GitHub App private key stored as secret `github-app-private-key`
4. **GitHub App** configured with:
   - Permissions: `actions:write`, `metadata:read`
   - Webhook: None required for self-hosted runners
   - Private key generated and uploaded to Key Vault

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Migration from Inline VMSS

If migrating from inline azapi VMSS resources in `personal-runners-infra`, follow these steps:

1. **Remove inline azapi resources** from your Terraform state:
   ```bash
   terraform state rm 'azapi_resource.vmss_pool_w_personal'
   terraform state rm 'azapi_resource.uami_pool_w_personal'
   terraform state rm 'azurerm_key_vault.pool_w_personal'
   ```

2. **Import existing resources** into the module:
   ```bash
   terraform import 'module.windows_runners.azapi_resource.vmss' '/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachineScaleSets/{vmss-name}'
   terraform import 'module.windows_runners.azapi_resource.uami' '/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{uami-name}'
   terraform import 'module.windows_runners.azurerm_key_vault.this' '/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{kv-name}'
   ```

3. **Apply configuration**:
   ```bash
   terraform plan  # Should show minimal changes
   terraform apply
   ```

## Verification

### Verify 3-Layer Self-Heal

1. **Layer 1 (DSC)**:
   - RDP into a VMSS instance
   - Stop the runner service: `Stop-Service -Name 'actions.runner.*'`
   - Wait 15 minutes → DSC should restart it

2. **Layer 2 (Auto-Repair)**:
   - Disable the ApplicationHealthWindows extension probe port
   - Wait 30 minutes → VMSS should delete and recreate the instance

3. **Layer 3 (Spot Eviction)**:
   - Simulate Spot eviction via Azure Portal (or wait for real eviction)
   - VMSS should provision a replacement instance in another zone within 1-5 minutes

## Cost Optimization

With `priority_mix`:
- **1 Regular instance**: ~$230/month (Standard_D8ds_v6, Sweden Central)
- **Each Spot instance**: ~$70/month (~70% savings)

Total for 1 Regular + 2 Spot = $230 + 2*$70 = **$370/month** for 3-instance pool.
