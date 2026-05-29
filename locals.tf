# Effective resource IDs after BYO resolution.
# When user_assigned_managed_identity_resource_id / key_vault_resource_id are
# null, the module-created resources are used. Otherwise the externally-supplied
# IDs flow through into the VMSS identity block and RBAC scope.
locals {
  byo_uami = var.user_assigned_managed_identity_resource_id != null
  byo_kv   = var.key_vault_resource_id != null

  uami_id           = local.byo_uami ? var.user_assigned_managed_identity_resource_id : azapi_resource.uami_vmss_windows[0].id
  uami_principal_id = local.byo_uami ? data.azapi_resource.byo_uami[0].output.properties.principalId : azapi_resource.uami_vmss_windows[0].output.properties.principalId

  kv_id   = local.byo_kv ? var.key_vault_resource_id : azapi_resource.key_vault_vmss_windows[0].id
  kv_name = local.byo_kv ? element(split("/", var.key_vault_resource_id), length(split("/", var.key_vault_resource_id)) - 1) : azapi_resource.key_vault_vmss_windows[0].name

  use_inline_bootstrap   = var.bootstrap_script_inline_base64 != null
  use_override_bootstrap = var.bootstrap_script_override_url != null

  # Auth-method-specific args appended to the CSE command line for the
  # module-shipped script. Override scripts get the base arg set only -
  # consumers who supply bootstrap_script_override_url own their auth wiring.
  app_private_key_path          = "C:\\github-app-private-key.pem"
  app_private_key_write_command = var.github_app_private_key_pem == null ? "" : "$pk=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(coalesce(var.github_app_private_key_pem, ""))}')); Set-Content -Path ${local.app_private_key_path} -Value $pk -Encoding ascii; "
  app_id_arg                    = var.github_app_id == null ? "UNSET" : tostring(var.github_app_id)
  installation_id_arg           = var.github_app_installation_id == null ? "UNSET" : tostring(var.github_app_installation_id)

  auth_args_app = var.github_app_private_key_pem == null ? "-AuthMethod app -AppId ${local.app_id_arg} -InstallationId ${local.installation_id_arg} -AppPrivateKeySecretName ${var.app_private_key_secret_name}" : "-AuthMethod app -AppId ${local.app_id_arg} -InstallationId ${local.installation_id_arg} -PrivateKeyPath ${local.app_private_key_path}"
  auth_args_pat = "-AuthMethod pat -PatSecretName ${var.pat_secret_name}"
  auth_args     = var.auth_method == "app" ? local.auth_args_app : local.auth_args_pat

  base_args = "-KeyVaultName ${local.kv_name} -GithubOwner ${var.github_owner} -GithubRepoList \"${join(",", var.github_repo_list)}\" -RunnerLabels \"${join(",", var.runner_labels)}\" -RunnerVersion ${var.runner_version}"

  # Module-shipped script gets full base + auth args.
  module_script_args = "${local.base_args} ${local.auth_args}"

  # Override script gets base args only.
  override_script_args = local.base_args

  # CSE command. Three modes:
  # - url      : download register-windows-runner.ps1 via fileUris (HTTPS), execute by name.
  # - inline   : decode base64 userData (delivered via VMSS userData), write to disk, execute.
  # - override : download consumer-supplied script via fileUris, execute.
  cse_command_url      = "powershell.exe -ExecutionPolicy Unrestricted -Command \"${local.app_private_key_write_command}& .\\register-windows-runner.ps1 ${local.module_script_args}\""
  cse_command_override = "powershell.exe -ExecutionPolicy Unrestricted -File ${reverse(split("/", coalesce(var.bootstrap_script_override_url, "x/x.ps1")))[0]} ${local.override_script_args}"
  cse_command_inline   = "powershell.exe -ExecutionPolicy Unrestricted -Command \"${local.app_private_key_write_command}$ud=[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((Invoke-RestMethod -Headers @{Metadata='true'} -Uri 'http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text'))); Set-Content -Path C:\\register-windows-runner.ps1 -Value $ud -Encoding UTF8; & C:\\register-windows-runner.ps1 ${local.module_script_args}\""

  cse_protected_settings = local.use_inline_bootstrap ? {
    fileUris         = []
    commandToExecute = local.cse_command_inline
    } : local.use_override_bootstrap ? {
    fileUris         = [var.bootstrap_script_override_url]
    commandToExecute = local.cse_command_override
    } : {
    fileUris         = [var.bootstrap_script_url]
    commandToExecute = local.cse_command_url
  }

  hotpatching_compatible_sku_substrings = ["2025-datacenter-azure-edition"]
  hotpatching_sku_ok                    = anytrue([for s in local.hotpatching_compatible_sku_substrings : strcontains(var.windows_image_sku, s)])

  # Flexible orchestration mode constrains certain properties (upgradePolicy
  # is rejected, automatic OS upgrade extensions are not applicable, etc.).
  is_flexible = var.orchestration_mode == "Flexible"

  # Application health probe settings - either tcp/0 (v1.1.0 default) or
  # http/https with a request path.
  app_health_settings = var.app_health_protocol == "tcp" ? {
    protocol    = "tcp"
    port        = var.app_health_port
    requestPath = ""
    } : {
    protocol    = var.app_health_protocol
    port        = var.app_health_port
    requestPath = var.app_health_request_path
  }

  # Canonical tag set: auto-injected Module/ModuleVersion/OS + consumer-supplied
  # canonical_tags + freeform var.tags merged on top (last wins).
  module_canonical_tags = {
    Module        = "terraform-azurerm-vmss-github-runners-windows"
    ModuleVersion = "1.3.1"
    OS            = "windows"
  }
  consumer_canonical_tags = merge(
    var.canonical_tags.owner == null ? {} : { Owner = var.canonical_tags.owner },
    var.canonical_tags.workload == null ? {} : { Workload = var.canonical_tags.workload },
    var.canonical_tags.pool == null ? {} : { Pool = var.canonical_tags.pool },
    var.canonical_tags.trust == null ? {} : { Trust = var.canonical_tags.trust },
    var.canonical_tags.cost_center == null ? {} : { CostCenter = var.canonical_tags.cost_center },
  )
  effective_tags = merge(local.module_canonical_tags, local.consumer_canonical_tags, var.tags)

  # DSC extension - omitted from the extensionProfile list when disabled.
  # When enabled, points at a consumer-hosted blob (zip) produced by
  # alz-avm-tf-demo/dsc-configs Build-DscPackage.ps1.
  dsc_extension = var.dsc_enabled ? [{
    name = "DSC"
    properties = {
      publisher               = "Microsoft.Powershell"
      type                    = "DSC"
      typeHandlerVersion      = "2.83"
      autoUpgradeMinorVersion = true
      settings = {
        wmfVersion = "latest"
        configuration = {
          url      = var.dsc_config_url
          script   = var.dsc_configuration_script
          function = var.dsc_configuration_function
        }
        configurationArguments = merge(
          var.dsc_configuration_arguments,
          { ConfigurationModeFrequencyMins = var.dsc_configuration_mode_frequency_mins }
        )
        advancedOptions = { forcePullAndApply = true }
      }
      protectedSettings = {
        configurationUrlSasToken = var.dsc_config_sas_token
      }
    }
  }] : []
}
