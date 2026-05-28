# Changelog

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