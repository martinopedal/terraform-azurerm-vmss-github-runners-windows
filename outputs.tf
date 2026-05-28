output "vmss_id" {
  description = "Resource ID of the Virtual Machine Scale Set"
  value       = azapi_resource.vmss_windows.id
}

output "uami_principal_id" {
  description = "Principal ID of the effective User-Assigned Managed Identity (module-created or BYO)."
  value       = local.uami_principal_id
}

output "uami_resource_id" {
  description = "Resource ID of the effective User-Assigned Managed Identity (module-created or BYO)."
  value       = local.uami_id
}

output "key_vault_name" {
  description = "Name of the effective Key Vault (module-created or BYO)."
  value       = local.kv_name
}

output "key_vault_id" {
  description = "Resource ID of the effective Key Vault (module-created or BYO)."
  value       = local.kv_id
}

output "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  value       = azapi_resource.vmss_windows.name
}
