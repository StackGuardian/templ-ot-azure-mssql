resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.advanced_settings.vnet_cidr]
  tags                = local.tags
}

# Subnet for the private endpoint. Network policies are on, so the NSG applies to the endpoint.
resource "azurerm_subnet" "endpoints" {
  name                              = "private-endpoints"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [cidrsubnet(var.advanced_settings.vnet_cidr, 8, 0)]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "endpoints" {
  name                = "${var.name_prefix}-mssql-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "sql_from_vnet" {
  name                        = "allow-sql-from-vnet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "1433"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.endpoints.name
}

resource "azurerm_network_security_rule" "deny_inbound" {
  name                        = "deny-all-inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.endpoints.name
}

resource "azurerm_subnet_network_security_group_association" "endpoints" {
  subnet_id                 = azurerm_subnet.endpoints.id
  network_security_group_id = azurerm_network_security_group.endpoints.id
}

# The server name resolves to the private endpoint inside the VNet.
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                = "${var.name_prefix}-vnet"
  private_dns_zone_id = azurerm_private_dns_zone.sql.id
  virtual_network_id  = azurerm_virtual_network.this.id
  tags                = local.tags
}

resource "azurerm_private_endpoint" "sql" {
  name                = "${var.name_prefix}-mssql-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "sql-server"
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.sql,
    azurerm_subnet_network_security_group_association.endpoints,
  ]
}
