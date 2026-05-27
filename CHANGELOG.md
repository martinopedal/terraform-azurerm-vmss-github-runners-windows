# Changelog

## 1.0.0

- Prepared the Windows VMSS runner module for first stable registry release.
- Added GitHub Actions validation for `terraform fmt`, `terraform validate`, and TFLint.
- Added a runnable personal runner example and generated terraform-docs README content.
- Replaced placeholder bootstrap wiring with an explicit `bootstrap_script_url` input.
- Removed hardcoded VMSS admin credentials and now generates a password unless `admin_password` is supplied.
- Made role assignment and telemetry resource names stable across Terraform plans.