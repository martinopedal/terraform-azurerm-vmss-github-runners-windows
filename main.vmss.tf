resource "random_password" "admin_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Virtual Machine Scale Set for Windows GitHub Runners
resource "azapi_resource" "vmss_windows" {
  type      = "Microsoft.Compute/virtualMachineScaleSets@2024-07-01"
  name      = var.vmss_name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  identity {
    type = "UserAssigned"
    identity_ids = [
      local.uami_id
    ]
  }

  body = {
    sku = {
      name     = var.vmss_sku
      capacity = var.vmss_capacity
      tier     = "Standard"
    }

    properties = merge({
      orchestrationMode = var.orchestration_mode
      # overprovision is only valid for Uniform orchestration; Flexible rejects it.
      overprovision            = var.orchestration_mode == "Uniform" ? false : null
      singlePlacementGroup     = false
      platformFaultDomainCount = 1

      # Priority Mix: 1 Regular base + N Spot burst
      priorityMixPolicy = {
        baseRegularPriorityCount           = var.priority_mix_base_regular_count
        regularPriorityPercentageAboveBase = var.priority_mix_regular_percentage_above_base
      }

      # Spot configuration
      virtualMachineProfile = {
        priority       = "Spot"
        evictionPolicy = var.eviction_policy
        billingProfile = {
          maxPrice = var.max_bid_price
        }

        # Azure Hybrid Benefit: when license_type is set (e.g. "Windows_Server"),
        # AHUB is applied. azapi (v2) omits this key when var.license_type is null,
        # preserving pay-as-you-go behaviour by default.
        licenseType = var.license_type

        osProfile = {
          computerNamePrefix = substr(var.vmss_name, 0, 9)
          adminUsername      = var.admin_username
          adminPassword      = coalesce(var.admin_password, random_password.admin_password.result)
          windowsConfiguration = merge(
            {
              provisionVMAgent       = true
              enableAutomaticUpdates = true
              timeZone               = "UTC"
            },
            var.enable_hotpatching ? {
              patchSettings = {
                patchMode         = "AutomaticByPlatform"
                enableHotpatching = true
                automaticByPlatformSettings = {
                  rebootSetting = "IfRequired"
                }
              }
            } : {}
          )
        }

        # Optional inline bootstrap: base64-encoded register-windows-runner.ps1 is
        # surfaced to the instance via VMSS userData and decoded by the CSE at boot.
        userData = local.use_inline_bootstrap ? var.bootstrap_script_inline_base64 : null

        storageProfile = {
          diskControllerType = var.disk_controller_type

          imageReference = {
            publisher = "MicrosoftWindowsServer"
            offer     = "WindowsServer"
            sku       = var.windows_image_sku
            version   = "latest"
          }
          osDisk = {
            createOption = "FromImage"
            caching      = "ReadWrite"
            diskSizeGB   = var.os_disk_size_gb
            managedDisk = {
              storageAccountType = var.os_disk_storage_account_type
            }
          }
        }

        networkProfile = {
          networkApiVersion = "2022-11-01"
          networkInterfaceConfigurations = [
            {
              name = "${var.vmss_name}-nic"
              properties = {
                primary                     = true
                enableAcceleratedNetworking = true
                ipConfigurations = [
                  {
                    name = "ipconfig1"
                    properties = {
                      subnet = {
                        id = var.subnet_id
                      }
                      primary                 = true
                      privateIPAddressVersion = "IPv4"
                    }
                  }
                ]
              }
            }
          ]
        }

        # Extensions are defined inline
        extensionProfile = {
          extensions = concat([
            {
              name = "CustomScriptExtension"
              properties = {
                publisher               = "Microsoft.Compute"
                type                    = "CustomScriptExtension"
                typeHandlerVersion      = "1.10"
                autoUpgradeMinorVersion = true
                protectedSettings       = local.cse_protected_settings
              }
            }
            ],
            local.dsc_extension,
            [
              {
                name = "ApplicationHealthWindows"
                properties = {
                  publisher               = "Microsoft.ManagedServices"
                  type                    = "ApplicationHealthWindows"
                  typeHandlerVersion      = "1.0"
                  autoUpgradeMinorVersion = true
                  settings                = local.app_health_settings
                }
              }
          ])
        }
      }

      # Automatic instance repair
      automaticRepairsPolicy = {
        enabled     = true
        gracePeriod = var.automatic_instance_repair_grace_period
      }
      },
      # upgradePolicy is rejected by ARM for Flexible orchestration mode -
      # include it only for Uniform.
      local.is_flexible ? {} : {
        upgradePolicy = {
          mode = "Manual"
        }
      }
    )

    zones = var.vmss_zones
  }

  tags = local.effective_tags

  depends_on = [
    azapi_resource.uami_vmss_windows,
    azapi_resource.key_vault_vmss_windows,
    azapi_resource.rbac_kv_secrets_user,
    data.azapi_resource.byo_uami,
  ]

  lifecycle {
    precondition {
      condition = length([
        for v in [var.bootstrap_script_url, var.bootstrap_script_inline_base64, var.bootstrap_script_override_url] : v if v != null
      ]) == 1
      error_message = "Exactly one of bootstrap_script_url, bootstrap_script_inline_base64, or bootstrap_script_override_url must be set."
    }
    precondition {
      condition     = !var.enable_hotpatching || local.hotpatching_sku_ok
      error_message = "enable_hotpatching = true requires windows_image_sku to include '2025-datacenter-azure-edition' (got '${var.windows_image_sku}')."
    }
    precondition {
      condition     = var.auth_method != "app" || (var.github_app_id != null && var.github_app_installation_id != null)
      error_message = "auth_method = 'app' requires both github_app_id and github_app_installation_id to be set."
    }
    precondition {
      condition     = !var.dsc_enabled || (var.dsc_config_url != null && var.dsc_config_sas_token != null)
      error_message = "dsc_enabled = true requires both dsc_config_url and dsc_config_sas_token (see dsc-configs/docs/consuming.md for the canonical fetch-zip + blob + SAS pattern)."
    }
  }
}
