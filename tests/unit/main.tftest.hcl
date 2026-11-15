# Unit tests: plan only, providers are mocked. No cloud account, no cost.
# Run: tofu test -test-directory=tests/unit
# Test case catalog: tests/README.md

# Some arguments are validated as Azure resource IDs or UUIDs, so mocked values must look real.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
      object_id = "00000000-0000-0000-0000-000000000002"
    }
  }

  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
    }
  }

  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
    }
  }

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock-subnet"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/networkSecurityGroups/mock-nsg"
    }
  }

  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net"
    }
  }

  mock_resource "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.KeyVault/vaults/mock-kv"
    }
  }

  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.OperationalInsights/workspaces/mock-law"
    }
  }

  mock_resource "azurerm_mssql_server" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Sql/servers/mock-sql"
    }
  }

  mock_resource "azurerm_mssql_database" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Sql/servers/mock-sql/databases/app"
    }
  }
}

# Mocked so the unit tests do not wait for the RBAC delay.
mock_provider "time" {
  mock_resource "time_offset" {
    defaults = {
      rfc3339 = "2027-11-02T00:00:00Z"
    }
  }
}

# U-01
run "defaults_are_valid" {
  command = plan

  assert {
    condition = (
      local.tags["Environment"] == "demo" &&
      local.tags["ManagedBy"] == "opentofu" &&
      local.tags["Project"] == var.name_prefix &&
      local.tags["Repository"] != ""
    )
    error_message = "Default tags are missing or wrong."
  }
}

# U-02
run "invalid_name_prefix_is_rejected" {
  command = plan

  variables {
    name_prefix = "Invalid_Prefix"
  }

  expect_failures = [var.name_prefix]
}

# U-03
run "custom_tags_are_merged" {
  command = plan

  variables {
    advanced_settings = {
      tags = {
        Owner = "tester"
      }
    }
  }

  assert {
    condition     = local.tags["Owner"] == "tester" && local.tags["ManagedBy"] == "opentofu"
    error_message = "Custom tags are not merged with the default tags."
  }
}

# U-04
run "public_access_is_disabled_and_tls_is_enforced" {
  command = apply

  assert {
    condition     = !azurerm_mssql_server.this.public_network_access_enabled
    error_message = "Public network access must be disabled."
  }

  assert {
    condition     = azurerm_mssql_server.this.minimum_tls_version == "1.2"
    error_message = "Minimum TLS version must be 1.2."
  }
}

# U-05
run "server_is_reachable_through_private_endpoint_only" {
  command = apply

  assert {
    condition = (
      azurerm_private_endpoint.sql.subnet_id == azurerm_subnet.endpoints.id &&
      azurerm_private_endpoint.sql.private_service_connection[0].private_connection_resource_id == azurerm_mssql_server.this.id &&
      azurerm_private_endpoint.sql.private_service_connection[0].subresource_names == tolist(["sqlServer"])
    )
    error_message = "The server must have a private endpoint in the endpoint subnet."
  }

  assert {
    condition = (
      azurerm_private_dns_zone.sql.name == "privatelink.database.windows.net" &&
      azurerm_private_dns_zone_virtual_network_link.sql.virtual_network_id == azurerm_virtual_network.this.id &&
      azurerm_private_endpoint.sql.private_dns_zone_group[0].private_dns_zone_ids == tolist([azurerm_private_dns_zone.sql.id])
    )
    error_message = "The server name must resolve to the private endpoint inside the VNet."
  }

  assert {
    condition = (
      azurerm_subnet.endpoints.private_endpoint_network_policies == "Enabled" &&
      azurerm_network_security_rule.sql_from_vnet.destination_port_range == "1433" &&
      azurerm_network_security_rule.sql_from_vnet.source_address_prefix == "VirtualNetwork"
    )
    error_message = "The NSG must apply to the endpoint and allow port 1433 only from the VNet."
  }
}

# U-06
run "password_is_write_only_and_in_key_vault" {
  command = apply

  assert {
    condition     = azurerm_mssql_server.this.administrator_login_password == null
    error_message = "The admin password must be set only through the write-only argument."
  }

  assert {
    condition     = azurerm_key_vault_secret.admin_password.value == null && azurerm_key_vault_secret.admin_password.expiration_date != null
    error_message = "The secret must be written through the write-only argument and have an expiry date."
  }

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled
    error_message = "Key Vault must use RBAC."
  }
}

# U-07
run "deployer_is_entra_admin" {
  command = apply

  assert {
    condition = (
      azurerm_mssql_server.this.azuread_administrator[0].object_id == data.azurerm_client_config.current.object_id &&
      !azurerm_mssql_server.this.azuread_administrator[0].azuread_authentication_only
    )
    error_message = "The deployer must be the Entra ID admin, with SQL logins still allowed for the admin password."
  }
}

# U-08
run "backups_and_encryption_are_enabled" {
  command = apply

  assert {
    condition     = azurerm_mssql_database.this.short_term_retention_policy[0].retention_days == 7
    error_message = "Point-in-time restore must be kept for 7 days by default."
  }

  assert {
    condition     = azurerm_mssql_database.this.transparent_data_encryption_enabled
    error_message = "Transparent data encryption must be enabled."
  }
}

# U-09
run "long_backup_retention_on_basic_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      backup_retention_days = 8
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-10
run "auditing_and_logs_are_enabled" {
  command = apply

  assert {
    condition = (
      azurerm_monitor_diagnostic_setting.audit.target_resource_id == "${azurerm_mssql_server.this.id}/databases/master" &&
      contains([for l in azurerm_monitor_diagnostic_setting.audit.enabled_log : l.category], "SQLSecurityAuditEvents") &&
      azurerm_mssql_server_extended_auditing_policy.this.log_monitoring_enabled
    )
    error_message = "Server auditing must go to Log Analytics."
  }

  assert {
    condition = (
      azurerm_monitor_diagnostic_setting.database.target_resource_id == azurerm_mssql_database.this.id &&
      azurerm_monitor_diagnostic_setting.key_vault.target_resource_id == azurerm_key_vault.this.id
    )
    error_message = "Database logs and Key Vault audit logs must go to Log Analytics."
  }
}

# U-11
run "serverless_sku_pauses_automatically" {
  command = plan

  variables {
    advanced_settings = {
      sku_name    = "GP_S_Gen5_1"
      max_size_gb = 30
    }
  }

  assert {
    condition     = azurerm_mssql_database.this.auto_pause_delay_in_minutes == 60 && azurerm_mssql_database.this.min_capacity == 0.5
    error_message = "Serverless databases must pause after 60 minutes with a minimum of 0.5 vCores."
  }
}

# U-12
run "basic_sku_has_no_serverless_settings" {
  command = plan

  assert {
    condition     = azurerm_mssql_database.this.sku_name == "Basic" && azurerm_mssql_database.this.max_size_gb == 2 && !local.serverless
    error_message = "The default must be a 2 GB Basic database without serverless settings."
  }
}

# U-13
run "basic_size_above_2_gb_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      max_size_gb = 5
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-14
run "unknown_sku_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      sku_name = "P1"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-15
run "reserved_administrator_login_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      administrator_login = "admin"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-16
run "system_database_name_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      database_name = "master"
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-17
run "dtu_size_not_offered_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      sku_name    = "S0"
      max_size_gb = 32
    }
  }

  expect_failures = [var.advanced_settings]
}
