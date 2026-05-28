# Effective resource IDs after BYO resolution.
# When user_assigned_managed_identity_resource_id / key_vault_resource_id are
# null, the module-created resources are used. Otherwise the externally-supplied
# IDs flow through into the VMSS identity block and RBAC scope.
locals {
  byo_uami = var.user_assigned_managed_identity_resource_id != null
  byo_kv   = var.key_vault_resource_id != null

  uami_id           = local.byo_uami ? var.user_assigned_managed_identity_resource_id : azapi_resource.uami_vmss_windows[0].id
  uami_principal_id = local.byo_uami ? data.azapi_resource.byo_uami[0].output.properties.principalId : azapi_resource.uami_vmss_windows[0].identity[0].principal_id

  kv_id   = local.byo_kv ? var.key_vault_resource_id : azapi_resource.key_vault_vmss_windows[0].id
  kv_name = local.byo_kv ? element(split("/", var.key_vault_resource_id), length(split("/", var.key_vault_resource_id)) - 1) : azapi_resource.key_vault_vmss_windows[0].name

  use_inline_bootstrap = var.bootstrap_script_inline_base64 != null

  # CSE command. Two modes:
  # - url    : download register-windows-runner.ps1 via fileUris (HTTPS), execute by name.
  # - inline : decode base64 userData (delivered via VMSS userData), write to disk, execute.
  cse_command_url = "powershell.exe -ExecutionPolicy Unrestricted -File register-windows-runner.ps1 -KeyVaultName ${local.kv_name} -GithubOwner ${var.github_owner} -GithubRepoList \"${join(",", var.github_repo_list)}\" -RunnerLabels \"${join(",", var.runner_labels)}\" -RunnerVersion ${var.runner_version}"

  cse_command_inline = "powershell.exe -ExecutionPolicy Unrestricted -Command \"$ud=[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((Invoke-RestMethod -Headers @{Metadata='true'} -Uri 'http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text'))); Set-Content -Path C:\\register-windows-runner.ps1 -Value $ud -Encoding UTF8; & C:\\register-windows-runner.ps1 -KeyVaultName ${local.kv_name} -GithubOwner ${var.github_owner} -GithubRepoList '${join(",", var.github_repo_list)}' -RunnerLabels '${join(",", var.runner_labels)}' -RunnerVersion ${var.runner_version}\""

  cse_protected_settings = local.use_inline_bootstrap ? {
    fileUris         = []
    commandToExecute = local.cse_command_inline
    } : {
    fileUris         = [var.bootstrap_script_url]
    commandToExecute = local.cse_command_url
  }

  hotpatching_compatible_sku_substrings = ["2025-datacenter-azure-edition"]
  hotpatching_sku_ok                    = anytrue([for s in local.hotpatching_compatible_sku_substrings : strcontains(var.windows_image_sku, s)])
}
