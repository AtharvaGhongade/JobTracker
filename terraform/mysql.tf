resource "azurerm_private_dns_zone" "mysql" {
  name                = "${var.mysql_server_name}.private.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "mysql-dns-link"
  resource_group_name  = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_mysql_flexible_server" "main" {
  name                = var.mysql_server_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location # southindia — this is the fix

  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password

  sku_name = "B_Standard_B1ms"
  version  = "8.0.21"

  delegated_subnet_id = azurerm_subnet.data.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql.id

  storage {
    size_gb = 20
  }

  backup_retention_days = 7

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

# Azure MySQL Flexible Server only creates the server itself - the actual
# database (schema) inside it has to be created separately.
resource "azurerm_mysql_flexible_database" "jobtrackr" {
  name                = "jobtrackr"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}