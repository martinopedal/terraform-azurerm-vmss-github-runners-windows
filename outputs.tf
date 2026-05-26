output "vmss_id" {
  description = "Resource ID of the Virtual Machine Scale Set"
  value       = azapi_resource.vmss_windows.id
}

output "uami_principal_id" {
  description = "Principal ID of the User-Assigned Managed Identity"
  value       = azapi_resource.uami_vmss_windows.identity[0].principal_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azapi_resource.key_vault_vmss_windows.name
}

output "key_vault_id" {
  description = "Resource ID of the Key Vault"
  value       = azapi_resource.key_vault_vmss_windows.id
}

output "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  value       = azapi_resource.vmss_windows.name
}
