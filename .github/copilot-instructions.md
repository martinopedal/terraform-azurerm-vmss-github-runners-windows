---
description: 'Self-hosted Windows GitHub Actions runners on Azure VMSS - Terraform module'
applyTo: '**/*.tf, **/*.tfvars, **/*.md, **/*.ps1'
---

# Copilot instructions - terraform-azurerm-vmss-github-runners-windows

## What this module is

A Terraform module that deploys self-hosted Windows GitHub Actions runners on Azure Virtual Machine Scale Sets (VMSS) through AzAPI, with Spot scale-out, DSC-based service repair, and VMSS automatic instance repair. It complements Linux Azure Container Apps runner modules by covering the Windows VMSS path.

## What the module owns

- The Windows VMSS and its extensions (Custom Script, DSC, Application Health)
- A user-assigned managed identity for the VMSS
- A Key Vault for the GitHub App private key (or a bring-your-own Key Vault)
- Key Vault Secrets User RBAC for the VMSS identity
- Optional AVM telemetry

It does not create the resource group, VNet, subnet, NAT Gateway, GitHub App, or repository permissions. Those stay in the consuming configuration.

## Rules for modifying this repo

- Keep both authentication paths working: GitHub App (`auth_method = "app"`) and PAT (`auth_method = "pat"`). Test both when changing `scripts/register-windows-runner.ps1` or the Custom Script Extension wiring.
- Keep the three bootstrap delivery modes mutually exclusive: `bootstrap_script_url`, `bootstrap_script_inline_base64`, `bootstrap_script_override_url`.
- DSC configuration content is consumer-hosted (a zip on a private blob, referenced by `dsc_config_url` and `dsc_config_sas_token`). Do not vendor a DSC configuration into this module.
- Treat `orchestration_mode` as immutable: changing it forces VMSS recreate.

## Validation before committing

```bash
terraform fmt -recursive
terraform validate
```

## Security rules

- No secrets in code; use Key Vault and GitHub Secrets.
- SHA-pin all GitHub Actions to commit SHAs.
- Generate VMSS admin credentials; do not hardcode them.
- CodeQL enabled for code scanning.

## README conventions

- No AI-generated language patterns.
- The `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` markers are for terraform-docs auto-generation. Edit input/output descriptions in the `.tf` source, then regenerate.

## GitHub-first principle

Validate changes in GitHub Actions, not locally. Push, trigger the workflow, check logs, iterate.
