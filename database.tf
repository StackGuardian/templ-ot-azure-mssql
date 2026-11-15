resource "azurerm_mssql_server" "this" {
  #checkov:skip=CKV2_AZURE_2:Vulnerability assessment needs Microsoft Defender for SQL, which is billed per server and out of scope for the demo
  #checkov:skip=CKV_AZURE_24:Audit logs go to Log Analytics, retention is configurable via advanced_settings.log_retention_days
  name                                    = "${var.name_prefix}-sql-${random_string.suffix.result}"
  location                                = azurerm_resource_group.this.location
  resource_group_name                     = azurerm_resource_group.this.name
  version                                 = "12.0"
  administrator_login                     = var.advanced_settings.administrator_login
  administrator_login_password_wo         = ephemeral.random_password.admin.result
  administrator_login_password_wo_version = var.advanced_settings.password_version
  minimum_tls_version                     = "1.2"
  public_network_access_enabled           = false
  tags                                    = local.tags

  # The identity running OpenTofu is the Entra ID admin. SQL logins stay enabled for the admin password.
  azuread_administrator {
    login_username              = "opentofu-deployer"
    object_id                   = data.azurerm_client_config.current.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = false
  }
}

locals {
  serverless = startswith(var.advanced_settings.sku_name, "GP_S_")
}

resource "azurerm_mssql_database" "this" {
  #checkov:skip=CKV_AZURE_224:Ledger is an application choice and cannot be turned off later, so it stays off in the demo
  #checkov:skip=CKV_AZURE_229:Zone redundancy is not available for Basic and Standard and is out of scope for the demo (cost)
  name        = var.advanced_settings.database_name
  server_id   = azurerm_mssql_server.this.id
  sku_name    = var.advanced_settings.sku_name
  max_size_gb = var.advanced_settings.max_size_gb
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  tags        = local.tags

  # Serverless pauses after an hour without connections and then bills storage only.
  auto_pause_delay_in_minutes = local.serverless ? 60 : null
  min_capacity                = local.serverless ? 0.5 : null

  transparent_data_encryption_enabled = true

  short_term_retention_policy {
    retention_days = var.advanced_settings.backup_retention_days
  }
}

# Logs of the server, the database and the Key Vault
resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-mssql-logs"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.advanced_settings.log_retention_days
  tags                = local.tags
}

# Server auditing goes through the diagnostic setting of the master database to Log Analytics.
resource "azurerm_monitor_diagnostic_setting" "audit" {
  name                       = "audit"
  target_resource_id         = "${azurerm_mssql_server.this.id}/databases/master"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "this" {
  server_id              = azurerm_mssql_server.this.id
  log_monitoring_enabled = true

  depends_on = [azurerm_monitor_diagnostic_setting.audit]
}

resource "azurerm_monitor_diagnostic_setting" "database" {
  name                       = "logs"
  target_resource_id         = azurerm_mssql_database.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = toset(["Errors", "Timeouts", "Blocks", "Deadlocks"])

    content {
      category = enabled_log.value
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "audit"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "AuditEvent"
  }
}
