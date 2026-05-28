# Changelog

## 1.1.0

- **BYO User-Assigned Managed Identity**: new `user_assigned_managed_identity_resource_id` input. When set, the module skips UAMI creation and attaches the existing identity to the VMSS, looking up its principalId via a data source for RBAC. Closes #13.
- **BYO Key Vault**: new `key_vault_resource_id` input. When set, the module skips Key Vault creation and only assigns the UAMI the Key Vault Secrets User role on the existing vault. `key_vault_name` is now optional (required only when the module creates the vault). Closes #12.
- **Key Vault purge protection**: new `key_vault_purge_protection_enabled` input (default `true`) replaces the hardcoded `enablePurgeProtection = false`. Production hardening by default; set to `false` in ephemeral/test environments. Closes #16.
- **Inline bootstrap mode**: new `bootstrap_script_inline_base64` input as a mutually-exclusive alternative to `bootstrap_script_url`. The base64-encoded `register-windows-runner.ps1` is delivered via VMSS `userData` and decoded by the CSE at boot, avoiding any HTTPS fetch (useful in egress-restricted networks). Exactly one of the two must be set; enforced via lifecycle precondition. Closes #15.
- **Hotpatching**: new `enable_hotpatching` and `windows_image_sku` inputs. When `enable_hotpatching = true`, the module wires `patchSettings` with `patchMode = AutomaticByPlatform` and `enableHotpatching = true`. A precondition validates that `windows_image_sku` includes `2025-datacenter-azure-edition`. Closes #14.
- State migration: `moved {}` blocks added for `azapi_resource.uami_vmss_windows` and `azapi_resource.key_vault_vmss_windows` so existing v1.0.x consumers transition to the count-indexed addresses without recreate.
- Backward-compatible: all new inputs default to `null`/`false`/existing behavior. Consumers that don't opt into BYO or hotpatching get exactly the same plan as v1.0.1 (modulo the `enablePurgeProtection` default flip - set `key_vault_purge_protection_enabled = false` to preserve the v1.0.x default).

## 1.0.1

- Documented the ALZ hardening audit for Key Vault secret expiry, DSC storage blob RBAC, and Windows DCR schema risks.
- Confirmed the module does not create Key Vault secrets, storage accounts/blobs, or Data Collection Rules; those resources remain consumer-owned if needed.
- Confirmed no upstream parent exists for this originally-authored repository, so no upstream PR is required.

## 1.0.0

- Prepared the Windows VMSS runner module for first stable registry release.
- Added GitHub Actions validation for `terraform fmt`, `terraform validate`, and TFLint.
- Added a runnable personal runner example and generated terraform-docs README content.
- Replaced placeholder bootstrap wiring with an explicit `bootstrap_script_url` input.
- Removed hardcoded VMSS admin credentials and now generates a password unless `admin_password` is supplied.
- Made role assignment and telemetry resource names stable across Terraform plans.