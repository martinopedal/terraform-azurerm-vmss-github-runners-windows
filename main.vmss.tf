# Virtual Machine Scale Set for Windows GitHub Runners
resource "azapi_resource" "vmss_windows" {
  type      = "Microsoft.Compute/virtualMachineScaleSets@2024-07-01"
  name      = var.vmss_name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  identity {
    type = "UserAssigned"
    identity_ids = [
      azapi_resource.uami_vmss_windows.id
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
          adminUsername      = "azureuser"
          adminPassword      = "P@ssw0rd1234!" # Placeholder - not used (managed by AAD)
          windowsConfiguration = {
            provisionVMAgent       = true
            enableAutomaticUpdates = true
            timeZone               = "UTC"
          }
        }

        storageProfile = {
          imageReference = {
            publisher = "MicrosoftWindowsServer"
            offer     = "WindowsServer"
            sku       = "2022-datacenter-azure-edition"
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
                protectedSettings = {
                  fileUris = [
                    "https://raw.githubusercontent.com/actions/runner/main/README.md" # Placeholder URL
                  ]
                  commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File register-windows-runner.ps1 -KeyVaultName ${var.key_vault_name} -GithubOwner ${var.github_owner} -GithubRepoList \"${join(",", var.github_repo_list)}\" -RunnerLabels \"${join(",", var.runner_labels)}\" -RunnerVersion ${var.runner_version}"
                }
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
    azapi_resource.rbac_kv_secrets_user
  ]
}
