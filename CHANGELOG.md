# Changelog

## 1.3.0

- **Protected GitHub App private key path**: new sensitive `github_app_private_key_pem` input. When set with `github_app_id` and `github_app_installation_id`, the CSE protectedSettings command writes the PEM to a transient local file and calls `register-windows-runner.ps1` with `-PrivateKeyPath`.
- **CSE App/PAT fallback**: `register-windows-runner.ps1` now chooses App auth only when App ID, installation ID, and a private-key source are present. If App args are absent, it falls back to PAT registration (`-Pat` direct value or Key Vault `pat_secret_name`) for back-compat.
- **v1.2.0 behavior retained**: `orchestration_mode` remains `"Uniform"` by default with `"Flexible"` opt-in, and the Key Vault App private-key path still works when `github_app_private_key_pem` is null.

## 1.2.0

- **DSC extension wired end-to-end** (Layer 4 of the 5-layer auto-heal model). The v1.1.0 extension only set `ConfigurationModeFrequencyMins` with no `configuration` block - it was effectively a no-op. The new extension consumes a release-asset zip published by [alz-avm-tf-demo/dsc-configs](https://github.com/alz-avm-tf-demo/dsc-configs) (canonical home for runner DSC). New inputs: `dsc_enabled` (bool, default `true`), `dsc_config_url`, `dsc_config_sas_token` (sensitive), `dsc_configuration_script` (default `"RunnerSupervisor.ps1"`), `dsc_configuration_function` (default `"RunnerSupervisor"`), `dsc_configuration_arguments` (map). Consumers fetch the zip via `data.http`, push to a private blob, and pass URL + SAS - see [dsc-configs/docs/consuming.md](https://github.com/alz-avm-tf-demo/dsc-configs/blob/main/docs/consuming.md). The module-internal `runner-dsc-config.ps1` stub has been removed (was duplicating dsc-configs without the watchdog + supervisor enforcement).
- **Canonical tag taxonomy**: new `canonical_tags` input (object with optional `owner`, `workload`, `pool`, `trust`, `cost_center`). The module auto-injects `Module`, `ModuleVersion`, `OS = "windows"` and merges everything in `var.tags` on top. Standardizes tag keys across M1 (Windows) and M2/M3/M4 (Linux ACA) so the estate is uniformly discoverable.
- **Flexible orchestration mode**: new `orchestration_mode` input (default `"Uniform"` for v1.1.0 back-compat). Set to `"Flexible"` for VMSS-VMs orchestration (required by personal pool-w-pub). The module now omits `upgradePolicy` for Flexible (rejected by ARM otherwise). Immutable - changing this value triggers destroy/recreate of the VMSS. Closes #19.
- **GitHub App authentication wired end-to-end**: new `auth_method` input (`"app"` default | `"pat"`). When `auth_method = "app"`, the bootstrap script now actually mints an RS256 JWT from the App private key, exchanges it for an installation token, and exchanges that for a runner registration token. The previous v1.1.0 script fetched the App key from KV but called `config.cmd` without `--token`, which would have failed registration. New inputs: `github_app_id`, `github_app_installation_id`, `app_private_key_secret_name` (defaults to `"github-app-private-key"`). PAT mode adds `pat_secret_name` (defaults to `"github-runner-pat"`) as a thin escape hatch.
- **PowerShell 7 auto-install**: the bootstrap script now runs as a two-stage process. Stage 1 (Windows PowerShell 5.1, executed by CSE) installs PowerShell 7.4.6 via the official Microsoft MSI if absent, then re-executes Stage 2 under `pwsh.exe`. Stage 2 does all KV / GitHub API / runner-registration work using PS 7's `[System.Security.Cryptography.RSA]::ImportFromPem()` for clean RS256 signing.
- **Configurable App Health probe**: new `app_health_protocol` (`"tcp"` default | `"http"` | `"https"`), `app_health_port` (default `0`, set `80` for HTTP probe), `app_health_request_path`. v1.1.0 hardcoded tcp/0; consumers running an HTTP health endpoint can now wire it through.
- **Consumer-owned bootstrap escape hatch**: new `bootstrap_script_override_url` input as a third option alongside `bootstrap_script_url` and `bootstrap_script_inline_base64`. When set, the module passes only the base arg surface (`-KeyVaultName -GithubOwner -GithubRepoList -RunnerLabels -RunnerVersion`) to the override script - auth-method-specific args are NOT passed, so the consumer script owns its own auth wiring. For consumers with non-standard registration flows.
- **Lifecycle preconditions**: `auth_method = "app"` requires both `github_app_id` and `github_app_installation_id`; `dsc_enabled = true` requires both `dsc_config_url` and `dsc_config_sas_token`; mutual-exclusion precondition extended to cover all three bootstrap modes.
- Backward-compatible for VMSS plan shape: existing v1.1.0 consumers that don't set the new inputs get the same VMSS body (Uniform mode, hardcoded tcp/0 health, url-or-inline bootstrap). The bootstrap *script itself* is materially different - any consumer pinning the module-shipped script via `bootstrap_script_url` MUST repin to the v1.2.0 release URL so the new param surface is in place. The DSC extension default flips from no-op to active - consumers without a hosted DSC zip MUST either set `dsc_enabled = false` or follow the dsc-configs consuming pattern.
- Tracking issue #20 opened for v2.0.0 refactor to wrap `Azure/avm-res-compute-virtualmachinescaleset/azurerm` instead of hand-rolling VMSS via `azapi_resource` (per the canonical-modules directive).

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