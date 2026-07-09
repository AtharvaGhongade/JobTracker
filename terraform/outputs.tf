output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "mysql_server_fqdn" {
  value = azurerm_mysql_flexible_server.main.fqdn
}

output "bastion_name" {
  value = azurerm_bastion_host.main.name
}
