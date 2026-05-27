output "vmss_id" {
  description = "Resource ID of the VMSS."
  value       = module.windows_runners.vmss_id
}

output "vmss_name" {
  description = "Name of the VMSS."
  value       = module.windows_runners.vmss_name
}

output "key_vault_name" {
  description = "Key Vault holding the GitHub App private key."
  value       = module.windows_runners.key_vault_name
}
