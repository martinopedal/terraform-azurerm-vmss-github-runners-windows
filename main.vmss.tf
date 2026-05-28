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

    properties = {
      overprovision            = false
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
                assessmentMode    = "AutomaticByPlatform"
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
          extensions = [
            {
              name = "CustomScriptExtension"
              properties = {
                publisher               = "Microsoft.Compute"
                type                    = "CustomScriptExtension"
                typeHandlerVersion      = "1.10"
                autoUpgradeMinorVersion = true
                protectedSettings       = local.cse_protected_settings
              }
            },
            {
              name = "DSC"
              properties = {
                publisher               = "Microsoft.Powershell"
                type                    = "DSC"
                typeHandlerVersion      = "2.80"
                autoUpgradeMinorVersion = true
                protectedSettings = {
                  configurationArguments = {
                    ConfigurationModeFrequencyMins = var.dsc_configuration_mode_frequency_mins
                  }
                }
              }
            },
            {
              name = "ApplicationHealthWindows"
              properties = {
                publisher               = "Microsoft.ManagedServices"
                type                    = "ApplicationHealthWindows"
                typeHandlerVersion      = "1.0"
                autoUpgradeMinorVersion = true
                settings = {
                  protocol    = "tcp"
                  port        = 0
                  requestPath = ""
                }
              }
            }
          ]
        }
      }

      # Automatic instance repair
      automaticRepairsPolicy = {
        enabled     = true
        gracePeriod = var.automatic_instance_repair_grace_period
      }

      # Upgrade policy
      upgradePolicy = {
        mode = "Manual"
      }
    }

    zones = var.vmss_zones
  }

  tags = var.tags

  depends_on = [
    azapi_resource.uami_vmss_windows,
    azapi_resource.key_vault_vmss_windows,
    azapi_resource.rbac_kv_secrets_user,
    data.azapi_resource.byo_uami,
  ]

  lifecycle {
    precondition {
      condition     = (var.bootstrap_script_url != null) != (var.bootstrap_script_inline_base64 != null)
      error_message = "Exactly one of bootstrap_script_url or bootstrap_script_inline_base64 must be set."
    }
    precondition {
      condition     = !var.enable_hotpatching || local.hotpatching_sku_ok
      error_message = "enable_hotpatching = true requires windows_image_sku to include '2025-datacenter-azure-edition' (got '${var.windows_image_sku}')."
    }
  }
}
