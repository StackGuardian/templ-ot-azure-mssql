output "server_fqdn" {
  description = "FQDN of the server. Resolves to the private endpoint inside the VNet."
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "server_name" {
  description = "Name of the server"
  value       = azurerm_mssql_server.this.name
}

output "database_name" {
  description = "Name of the database"
  value       = azurerm_mssql_database.this.name
}

output "administrator_login" {
  description = "Admin user name"
  value       = azurerm_mssql_server.this.administrator_login
}

output "key_vault_id" {
  description = "ID of the Key Vault with the admin password"
  value       = azurerm_key_vault.this.id
}

output "admin_password_secret_name" {
  description = "Name of the Key Vault secret with the admin password"
  value       = azurerm_key_vault_secret.admin_password.name
}

output "private_endpoint_ip" {
  description = "Private IP address of the server in the VNet"
  value       = azurerm_private_endpoint.sql.private_service_connection[0].private_ip_address
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "ID of the VNet, for clients that need to reach the server"
  value       = azurerm_virtual_network.this.id
}
