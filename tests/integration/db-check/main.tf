# Helper for the integration test: reads the server, the database, the private endpoint and the secret names (not the values).
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "server_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "database_name" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "private_endpoint_name" {
  type = string
}

data "azurerm_mssql_server" "this" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
}

data "azurerm_mssql_database" "this" {
  name      = var.database_name
  server_id = data.azurerm_mssql_server.this.id
}

data "azurerm_private_endpoint_connection" "this" {
  name                = var.private_endpoint_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secrets" "this" {
  key_vault_id = var.key_vault_id
}

output "private_endpoint_status" {
  value = data.azurerm_private_endpoint_connection.this.private_service_connection[0].status
}

output "fqdn" {
  value = data.azurerm_mssql_server.this.fully_qualified_domain_name
}

output "database_id" {
  value = data.azurerm_mssql_database.this.id
}

output "secret_names" {
  value = data.azurerm_key_vault_secrets.this.names
}
