resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-jobtrackr"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "main" {
  name                = "bastion-jobtrackr"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard" # needed for native-client SSH tunneling later
  tunneling_enabled = true

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
